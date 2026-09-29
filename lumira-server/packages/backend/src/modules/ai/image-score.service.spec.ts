// lumira-server/packages/backend/src/modules/ai/image-score.service.spec.ts
// T6 LLM-as-Judge 评分闸门（Task 8，TDD）：mock textChat(jsonMode:true)
// → 高分 pass / 低分 retry 且 reasons 非空 / 非法 JSON 保守失败不抛
// / 分数 clamp 到 [0,1] / judgeModel 缺省走 cfg.text。

import { ImageScoreService, SCORE_PASS_THRESHOLD } from './image-score.service';
import { LlmJsonError, textChatJson } from './llm-json';
import type { LlmEndpoint } from './llm-client';
import type { AiModalityEndpoint } from './ai-config.service';
import type { AiConfigService } from './ai-config.service';
import type { ImageDescription } from './image-describe.service';
import type { PoseRefSheet } from './pose-ref-sheet.service';
import type { ResearchItem } from './trend-research/research-item';

jest.mock('./llm-json', () => ({
  visionChatJson: jest.fn(),
  textChatJson: jest.fn(),
  LlmJsonError: class LlmJsonError extends Error {},
}));

const textChatJsonMock = textChatJson as jest.MockedFunction<typeof textChatJson>;

const RUNTIME = { retryCount: 0, timeoutMs: 300_000, maxTokens: 8192 };

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
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT, runtime: RUNTIME }) } as unknown as AiConfigService;
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
  shared: { outfit: '米色针织', scene: '飘窗', light: '窗光', aspectRatio: '3:4', mood: '清冷慵懒', palette: '暖棕', styling: '针织开衫 + 细金链', expressionMood: '平静微松' },
  perPose: [
    { name: '坐姿侧靠', subjectPose: {}, camera: {}, frame: {}, lightOnPose: {}, differentiationNote: '侧靠偏左' },
  ],
};

const RESEARCH: ResearchItem[] = [{ source: 'bing', title: '秋季清冷感女装趋势', snippet: '低饱和莫兰迪色系流行', keywords: ['秋', '女装'] }];

const DRAFT = { meta: { name: '飘窗清冷少女人像模板' }, camera: { iso: 200 } };

function input(overrides: Record<string, unknown> = {}) {
  return { desc: DESC, poseSheet: POSE_SHEET, research: RESEARCH, draft: DRAFT, ...overrides };
}

beforeEach(() => textChatJsonMock.mockReset());

describe('ImageScoreService.score', () => {
  it('总分与分项全达标 → verdict pass，且 textChatJson 收到 text 端点 + runtime', async () => {
    textChatJsonMock.mockResolvedValueOnce({
        aesthetics: { composition: 0.9, pose: 0.88, styling: 0.9, expression: 0.86, lighting: 0.9, styleHit: 0.92 },
        realism: { anatomy: 0.95, material: 0.9, physical: 0.92 },
        consistency: 0.9,
        params: 0.9,
        metadata: 0.9,
        score: 0.9,
        reasons: [],
        suggests: [],
      });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('pass');
    expect(res.score).toBeCloseTo(0.9, 5);
    const [cfg, chatInput, runtime] = textChatJsonMock.mock.calls[0];
    expect(cfg).toEqual(TEXT);
    expect(chatInput.userText).toContain('飘窗清冷少女人像模板'); // draft 注入
    expect(runtime).toEqual(RUNTIME);
  });

  it('低分 0.6 → verdict retry 且保留 LLM 给出的 reasons/suggests', async () => {
    textChatJsonMock.mockResolvedValueOnce({ score: 0.6, reasons: ['姿势不一致'], suggests: ['重跑姿势面片'] });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('retry');
    expect(res.score).toBe(0.6);
    expect(res.reasons).toContain('姿势不一致');
    expect(res.suggests).toContain('重跑姿势面片');
  });

  it('非法 JSON / 超时（LlmJsonError）→ 标记 error 的保守结果不抛，上游据此收束', async () => {
    textChatJsonMock.mockRejectedValueOnce(
      new LlmJsonError('AI 输出无法解析为 JSON（已重试 2 次）：输出不是合法 JSON'),
    );
    const svc = buildService();

    const res = await svc.score(input());

    expect(res).toEqual({
      score: 0,
      verdict: 'retry',
      error: '评分调用失败/超时或输出无法解析',
      reasons: ['评分调用失败，未产出有效评审'],
      suggests: [],
    });
  });

  it('评分只允许单次尝试：runtime.retryCount 强制为 0（失败/超时不被 runJsonChat 重试放大）', async () => {
    // 配置默认 retryCount=2；评分必须覆盖为 0
    const aiConfigService = {
      getActiveConfig: async () => ({ text: TEXT, runtime: { retryCount: 2, timeoutMs: 300_000, maxTokens: 8192 } }),
    } as unknown as AiConfigService;
    const svc = new ImageScoreService(aiConfigService);
    textChatJsonMock.mockResolvedValueOnce({ score: 0.9, reasons: [], suggests: [] });

    await svc.score(input());

    const [, , runtime] = textChatJsonMock.mock.calls[0];
    expect(runtime).toEqual(RUNTIME);
  });

  it('非 LlmJsonError 的硬错误（如鉴权失败）→ 原样上抛，不降级为评分 0', async () => {
    textChatJsonMock.mockRejectedValueOnce(
      new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查'),
    );
    const svc = buildService();

    await expect(svc.score(input())).rejects.toThrow(
      'AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查',
    );
  });

  it('分数 clamp 到 [0,1]：1.4 → 1、-0.2 → 0', async () => {
    const svc = buildService();
    textChatJsonMock.mockResolvedValueOnce({ score: 1.4 }).mockResolvedValueOnce({ score: -0.2 });

    const hi = await svc.score(input());
    const lo = await svc.score(input());
    expect(hi.score).toBe(1);
    expect(lo.score).toBe(0);
  });

  it('传入 judgeModel 时使用独立评审端点而非 cfg.text', async () => {
    textChatJsonMock.mockResolvedValueOnce({ score: 0.5, reasons: [] });
    const svc = buildService();

    await svc.score(input({ judgeModel: JUDGE }));

    const [cfg] = textChatJsonMock.mock.calls[0];
    expect(cfg).toEqual(JUDGE);
  });

  it('阈值语义：score>=THRESHOLD 为 pass，否则 retry', () => {
    expect(SCORE_PASS_THRESHOLD).toBe(0.85);
    expect(0.85 >= SCORE_PASS_THRESHOLD).toBe(true);
    expect(0.84 >= SCORE_PASS_THRESHOLD).toBe(false);
  });
});

/** 达标分项基线（审美全 >=0.75 / 真实全 >=0.85） */
const OK_AESTHETICS = { composition: 0.9, pose: 0.9, styling: 0.9, expression: 0.9, lighting: 0.9, styleHit: 0.9 };
const OK_REALISM = { anatomy: 0.95, material: 0.9, physical: 0.92 };

describe('ImageScoreService.score 三段闸门', () => {
  it('总分够但审美分项不够（composition 0.6）→ retry，reasons 指明维度', async () => {
    textChatJsonMock.mockResolvedValueOnce({
        aesthetics: { ...OK_AESTHETICS, composition: 0.6 },
        realism: OK_REALISM,
        score: 0.9,
        reasons: [],
        suggests: [],
      });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('retry');
    expect(res.reasons.join(' ')).toContain('composition');
  });

  it('审美够但真实分项不够（anatomy 0.6）→ retry，reasons 指明真实底线', async () => {
    textChatJsonMock.mockResolvedValueOnce({
        aesthetics: OK_AESTHETICS,
        realism: { ...OK_REALISM, anatomy: 0.6 },
        score: 0.9,
        reasons: [],
        suggests: [],
      });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('retry');
    expect(res.reasons.join(' ')).toContain('anatomy');
  });

  it('分项缺失 → 保守 retry', async () => {
    textChatJsonMock.mockResolvedValueOnce({ score: 0.9, reasons: [], suggests: [] });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.verdict).toBe('retry');
    expect(res.reasons.join(' ')).toContain('审美分项缺失');
    expect(res.reasons.join(' ')).toContain('真实分项缺失');
  });

  it('无参考图（textOnly）→ 阈值放宽：aesthetics min 0.70 / score 0.8 即可 pass', async () => {
    textChatJsonMock.mockResolvedValueOnce({
        aesthetics: { ...OK_AESTHETICS, composition: 0.72 },
        realism: OK_REALISM,
        score: 0.82,
        reasons: [],
        suggests: [],
      });
    const svc = buildService();

    const res = await svc.score(input({ textOnly: true }));

    expect(res.verdict).toBe('pass');
  });

  it('无参考图但真实底线不够（anatomy 0.8）→ 仍 retry（真实底线不豁免）', async () => {
    textChatJsonMock.mockResolvedValueOnce({
        aesthetics: OK_AESTHETICS,
        realism: { ...OK_REALISM, anatomy: 0.8 },
        score: 0.9,
        reasons: [],
        suggests: [],
      });
    const svc = buildService();

    const res = await svc.score(input({ textOnly: true }));

    expect(res.verdict).toBe('retry');
    expect(res.reasons.join(' ')).toContain('anatomy');
  });

  it('suggests 硬要求写入系统提示词：落到具体字段与补法', async () => {
    textChatJsonMock.mockResolvedValueOnce({ aesthetics: OK_AESTHETICS, realism: OK_REALISM, score: 0.9 });
    const svc = buildService();

    await svc.score(input());

    const prompt = String(textChatJsonMock.mock.calls[0][1].systemPrompt);
    expect(prompt).toContain('pose[0].description');
    expect(prompt).toContain('补：');
    expect(prompt).toContain('styleHit');
    expect(prompt).toContain('真实底线分项');
  });

  it('trace 分项：返回 result 含结构化 aesthetics / realism', async () => {
    textChatJsonMock.mockResolvedValueOnce({ aesthetics: OK_AESTHETICS, realism: OK_REALISM, score: 0.9 });
    const svc = buildService();

    const res = await svc.score(input());

    expect(res.aesthetics).toEqual(OK_AESTHETICS);
    expect(res.realism).toEqual(OK_REALISM);
  });

  it('有风格档案时系统提示词注入档案约束块', async () => {
    textChatJsonMock.mockResolvedValueOnce({ aesthetics: OK_AESTHETICS, realism: OK_REALISM, score: 0.9 });
    const svc = buildService();

    await svc.score(
      input({ styleProfile: { archetype: 'fashion_editorial', retouchLevel: 'polished' } }),
    );

    const prompt = String(textChatJsonMock.mock.calls[0][1].systemPrompt);
    expect(prompt).toContain('本次风格档案（必须遵守）');
    expect(prompt).toContain('时尚大片');
  });

  it('评分不携带工具上下文（ctx 缺省 → 纯文本评审，避免工具循环拖超时）', async () => {
    textChatJsonMock.mockResolvedValueOnce({ aesthetics: OK_AESTHETICS, realism: OK_REALISM, score: 0.9 });
    const svc = buildService();

    await svc.score(input());

    const chatInput = textChatJsonMock.mock.calls[0][1];
    expect(chatInput.ctx).toBeUndefined();
    // 单次超时 10 分钟：评审模型慢响应（实测 ~174s）不能被 180s 窗口误杀
    expect(chatInput.timeoutMs).toBe(600_000);
  });

  it('趋势研究条目在评审输入中截断（条数与 snippet 长度限制，控制载荷）', async () => {
    textChatJsonMock.mockResolvedValueOnce({ aesthetics: OK_AESTHETICS, realism: OK_REALISM, score: 0.9 });
    const svc = buildService();
    const many = Array.from({ length: 30 }, (_, i) => ({ source: 'bing', title: `t${i}`, snippet: 'x'.repeat(500), keywords: ['秋'] }));

    await svc.score(input({ research: many }));

    const userText = String(textChatJsonMock.mock.calls[0][1].userText);
    expect(userText).toContain('仅展示前 12 / 30 条');
    expect(userText).not.toContain('x'.repeat(500)); // 单条 snippet 已截断
  });
});