// lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.spec.ts
// Task 9 AiOrchestratorService（TDD）：mock 各工具服务，断言：
// 固定顺序 loop（research→describe→poseRefSheet→paramValidate→imageScore）、
// 研究关闭时跳过（trace 含 skip-research）、imageScore 先 retry 后 pass 触发再判、
// 最终 normalizeDraft 被调用、trace 覆盖各阶段。

import { AiOrchestratorService } from './ai-orchestrator.service';
import type { AiConfigService } from './ai-config.service';
import type { TrendResearchService } from './trend-research/trend-research.service';
import type { ImageDescribeService } from './image-describe.service';
import type { PoseRefSheetService } from './pose-ref-sheet.service';
import type { ImageScoreService } from './image-score.service';
import { ParamValidateService } from './param-validate.service';

const CATEGORIES = [
  { key: 'portrait', name: '人像', parentKey: null as string | null, level: 1 },
  { key: 'fresh_healing', name: '清新治愈', parentKey: 'portrait', level: 2 },
];

const DESC = {
  global: { subject: '年轻女性坐姿', mood: '清冷', season: '秋', timeOfDay: 'goldenHour' },
  people: [{ role: '主体' }],
  scene: { location: '飘窗' },
  cameraLike: {},
};

const POSE_SHEET = {
  shared: { outfit: '米色针织', scene: '飘窗', light: '窗光', aspectRatio: '3:4', mood: '清冷', palette: '暖棕' },
  perPose: [{ name: '坐姿侧靠', differentiationNote: '侧靠偏左' }],
};

const RESEARCH_ITEM = { source: 'bing', title: '秋日清冷感', snippet: '低饱和流行', keywords: ['秋'] };

/** 构造各工具 mock + run 选项 */
function build(opts: { searchEnabled?: boolean; scoreSequence?: Array<'pass' | 'retry'> } = {}) {
  const { searchEnabled = true, scoreSequence = ['pass'] } = opts;

  const research = { research: jest.fn().mockResolvedValue({ items: [RESEARCH_ITEM], sourceErrors: [] }) };
  const describe = { describe: jest.fn().mockResolvedValue(DESC) };
  const poseRefSheet = { generate: jest.fn().mockResolvedValue(POSE_SHEET) };
  const paramValidate = new ParamValidateService();
  const score = { score: jest.fn() };
  scoreSequence.forEach((v, i) => {
    score.score.mockImplementationOnce(async () => ({
      score: v === 'pass' ? 0.9 : 0.6,
      verdict: v,
      reasons: v === 'retry' ? ['姿势不一致'] : [],
      suggests: v === 'retry' ? ['重跑姿势面片'] : [],
    }));
  });
  // 超出 mockImplementationOnce 序列时默认 pass，避免循环卡死
  score.score.mockResolvedValue({ score: 0.9, verdict: 'pass', reasons: [], suggests: [] });

  const aiConfigService = {
    getActiveConfig: async () => ({ text: { provider: 'qwen', baseUrl: 'x', apiKey: 'sk', model: 'qwen-plus' } }),
    getSearchConfig: async () => ({
      enabled: searchEnabled,
      sources: searchEnabled ? [{ name: 'bing', provider: 'bing' }] : [],
    }),
  } as unknown as AiConfigService;

  const service = new AiOrchestratorService(
    aiConfigService,
    research as unknown as TrendResearchService,
    describe as unknown as ImageDescribeService,
    poseRefSheet as unknown as PoseRefSheetService,
    paramValidate,
    score as unknown as ImageScoreService,
  );

  const optsRun = {
    categories: CATEGORIES,
    draft: { meta: { name: '飘窗清冷少女人像模板' }, camera: { iso: 200 } },
  };

  return { service, research, describe, poseRefSheet, paramValidate, score, optsRun };
}

beforeEach(() => jest.clearAllMocks());

describe('AiOrchestratorService.run', () => {
  it('研究开启且有图：执行 describe→poseRefSheet→paramValidate→imageScore，track 覆盖各阶段，最终 normalizeDraft', async () => {
    const { service, research, describe, poseRefSheet, score, optsRun } = build();

    const res = await service.run(
      { imageBase64: 'aGk=', imageMime: 'image/jpeg', creationReq: '秋冬清冷感人像', poseCount: 2 },
      optsRun,
    );

    expect(research.research).toHaveBeenCalledWith('秋冬清冷感人像', expect.anything());
    expect(describe.describe).toHaveBeenCalledTimes(1);
    expect(poseRefSheet.generate).toHaveBeenCalled();
    expect(score.score).toHaveBeenCalledTimes(1);
    // 经过 normalizeDraft 归一化：meta.name / category 落在输出
    expect(res.draft.meta).toBeDefined();
    expect(res.draft.meta.category).toBe('portrait');
    // poseRefSheet 已写入草稿定稿：含 shared 锚点 + perPose 数组
    expect(res.draft.poseRefSheet).toMatchObject({
      shared: { outfit: '米色针织' },
      perPose: [{ name: '坐姿侧靠', differentiationNote: '侧靠偏左' }],
    });
    // trace 阶段覆盖
    const steps = res.trace.map((t) => t.step);
    expect(steps).toContain('research');
    expect(steps).toContain('describe');
    expect(steps).toContain('poseRefSheet');
    expect(steps).toContain('paramValidate');
    expect(steps).toContain('imageScore');
    expect(Array.isArray(res.warnings)).toBe(true);
  });

  it('研究关闭 → trace 含 skip-research，research 不被调用', async () => {
    const { service, research, optsRun } = build({ searchEnabled: false });

    const res = await service.run({ text: '随便'} as never, optsRun);

    const steps = res.trace.map((t) => t.resultBrief).concat(res.trace.map((t) => t.step));
    expect(JSON.stringify(res.trace)).toContain('skip-research');
    expect(research.research).not.toHaveBeenCalled();
  });

  it('研究开启但来源全部失败 → trace 为 research-0 而非 skip-research，并透传来源失败原因', async () => {
    const base = build();
    // 覆盖 research 返回：items 空 + sourceErrors 记录 vendor 失败
    (base.research.research as jest.Mock).mockResolvedValue({
      items: [],
      sourceErrors: [{ name: 'vendor', error: 'vendor 不可用' }],
    });

    const res = await base.service.run({ text: '随便秋景'} as never, base.optsRun);

    const researchTrace = res.trace.find((t) => t.step === 'research');
    expect(researchTrace).toBeDefined();
    expect(String(researchTrace?.resultBrief)).toContain('research-0');
    expect(String(researchTrace?.resultBrief)).toContain('vendor: vendor 不可用');
    expect(String(researchTrace?.resultBrief)).not.toContain('skip-research');
  });

  it('imageScore 先 retry 后 pass → 进入再判，score 被调用 2 次，二次通过后返回', async () => {
    const { service, score, optsRun } = build({ scoreSequence: ['retry', 'pass'] });

    const res = await service.run({ imageBase64: 'aGk=', imageMime: 'image/jpeg', poseCount: 1 }, optsRun);

    expect(score.score).toHaveBeenCalledTimes(2);
    const scores = res.trace.filter((t) => t.step === 'imageScore');
    expect(scores.length).toBeGreaterThanOrEqual(2);
    expect(scores[scores.length - 1].score).toBe(0.9);
  });

  it('仅文字（无图）→ 跳过 describe，poseRefSheet 仍执行（describe 参数为 undefined 时兜底）', async () => {
    const { service, describe, poseRefSheet, optsRun } = build();

    const res = await service.run({ text: '奶油风人像', poseCount: 1 }, optsRun);

    expect(describe.describe).not.toHaveBeenCalled();
    expect(poseRefSheet.generate).toHaveBeenCalled();
    expect(res.trace.some((t) => t.step === 'describe' && String(t.resultBrief).includes('skip'))).toBe(true);
  });
});