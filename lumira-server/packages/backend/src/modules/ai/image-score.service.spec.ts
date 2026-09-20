// lumira-server/packages/backend/src/modules/ai/image-score.service.spec.ts
// T6 LLM-as-Judge 评分闸门（Task 8，TDD）：mock textChat(jsonMode:true)
// → 高分 pass / 低分 retry 且 reasons 非空 / 非法 JSON 保守失败不抛
// / 分数 clamp 到 [0,1] / judgeModel 缺省走 cfg.text。

import { ImageScoreService, SCORE_PASS_THRESHOLD } from './image-score.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { AiModalityEndpoint } from './ai-config.service';
import type { AiConfigService } from './ai-config.service';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import type { ResearchItem } from './trend-research/research-item';

jest.mock('./llm-client', () => ({ textChat: jest.fn() }));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const TEXT: AiModalityEndpoint = {
  provider: 'qwen',
  baseUrl: 'https://x.example/v1',
  apiKey: 'sk',
  model: 'qwen-plus',
};

const JUDGE: LlmEndpoint = {
  provider: 'openai',
  baseUrl: 'https://y.example/v1',
  apiKey: 'sk2',
  model: 'gpt-4o',
};

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT }) } as unknown as AiConfigService;
  return new ImageScoreService(aiConfigService);
}

const DESC: ImageDescription = {
  global: {
    subject: '年轻女性，坐姿，望向窗外',
    mood: '清冷慵懒',
    season: '秋',
    timeOfDay: 'goldenHour',
    palette: { dominant: ['#d2b48c'], tone: '暖', brightness: '中间调偏亮' },
    light: { dir: '侧逆光' },
    composition: {
      leadLines: '窗框引导线',
      framing: '窗框式',
      symmetry: '否',
      subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 },
      cropRatio: '3:4',
      negativeSpace: '右上留白',
      depthOfField: '浅',
    },
    reproducibility: { level: 'high', reason: '窗光可复现', enableFillLight: true, lightHint: '侧逆补反光板' },
  },
  people: [{ role: '主体', face: {}, body: {}, limbs: {}, outfit: {}, anchors: { positionInFrame: { x: 0.5, y: 0.5 }, scaleRatio: 1, rotationDegree: 0 }, lightOnPerson: {} }],
  scene: { location: '室内飘窗', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '编织', cleanliness: '整洁' },
  cameraLike: { lightSuggestion: '开补光', wbSuggestion: 'daylight', evSuggestion: '0.3', focusDepth: '对焦眼睛' },
};

const POSE_SHEET: PoseRefSheet = {
  shared: { outfit: '米色针织', scene: '飘窗', light: '窗光', aspectRatio: '3:4', mood: '清冷慵懒', palette: '暖棕' },
  perPose: [
    { name: '坐姿侧靠', subjectPose: {}, camera: {}, frame: {}, lightOnPose: {}, differentiationNote: '侧靠偏左' },
  ],
};

const RESEARCH: ResearchItem[] = [{ source: 'bing', title: '秋季清冷感女装趋势', snippet: '低饱和莫兰迪色系流行', keywords: ['秋', '女装'] }];

const DRAFT = { meta: { name: '飘窗清冷少女人像模板' }, camera: { iso: 200 } };

function input(overrides: Record<string, unknown> = {}) {
  return { desc: DESC, poseSheet: POSE_SHEET, research: RESEARCH, draft: DRAFT, ...overrides };
}

beforeEach(() => textChatMock.mockReset());

describe('ImageScoreService.score', () => {
  it('高分 0.9 → verdict pass，且 textChat 收到 text 端点 + jsonMode:true', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ score: 0.9, reasons: ['风格成熟'], suggests: ['保持'] }));
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('pass');
    expect(res.score).toBe(0.9);
    expect(res.reasons).toContain('风格成熟');
    const [cfg, chatInput] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(TEXT);
    expect(chatInput.jsonMode).toBe(true);
    expect(chatInput.userText).toContain('飘窗清冷少女人像模板'); // draft 注入
  });

  it('低分 0.6 → verdict retry 且 reasons 非空', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ score: 0.6, reasons: ['姿势不一致'], suggests: ['重跑姿势面片'] }));
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('retry');
    expect(res.score).toBe(0.6);
    expect(res.reasons).toHaveLength(1);
    expect(res.suggests).toContain('重跑姿势面片');
  });

  it('非法 JSON → 保守 {score:0, verdict:retry, reasons:["评分为空"]} 不抛', async () => {
    textChatMock.mockResolvedValueOnce('抱歉，我评不了');
    const svc = buildService();

    const res = await svc.score(input());

    expect(res).toEqual({ score: 0, verdict: 'retry', reasons: ['评分为空'], suggests: [] });
  });

  it('分数 clamp 到 [0,1]：1.4 → 1、-0.2 → 0', async () => {
    const svc = buildService();
    textChatMock.mockResolvedValueOnce(JSON.stringify({ score: 1.4 })).mockResolvedValueOnce(JSON.stringify({ score: -0.2 }));

    const hi = await svc.score(input());
    const lo = await svc.score(input());
    expect(hi.score).toBe(1);
    expect(lo.score).toBe(0);
  });

  it('传入 judgeModel 时使用独立评审端点而非 cfg.text', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ score: 0.5, reasons: [] }));
    const svc = buildService();

    await svc.score(input({ judgeModel: JUDGE }));

    const [cfg] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(JUDGE);
  });

  it('阈值语义：score>=THRESHOLD 为 pass，否则 retry', () => {
    expect(SCORE_PASS_THRESHOLD).toBe(0.85);
    expect(0.85 >= SCORE_PASS_THRESHOLD).toBe(true);
    expect(0.84 >= SCORE_PASS_THRESHOLD).toBe(false);
  });
});