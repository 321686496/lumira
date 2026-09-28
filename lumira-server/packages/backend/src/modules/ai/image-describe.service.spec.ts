// lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts
// T2 穷尽式图像识别服务（Task 5，TDD）：mock visionChat → 解析 ImageDescription；非法 JSON → 抛可读错误

import { ImageDescribeService } from './image-describe.service';
import { buildExhaustiveSystemPrompt } from './image-describe.prompt';
import { LlmJsonError, visionChatJson } from './llm-json';
import type { LlmEndpoint } from './llm-client';
import type { AiConfigService } from './ai-config.service';

jest.mock('./llm-json', () => ({
  visionChatJson: jest.fn(),
  textChatJson: jest.fn(),
  LlmJsonError: class LlmJsonError extends Error {},
}));

const visionChatJsonMock = visionChatJson as jest.MockedFunction<typeof visionChatJson>;

const RUNTIME = { retryCount: 0, timeoutMs: 300_000, maxTokens: 8192 };

const VISION: LlmEndpoint = {
  provider: 'qwen',
  baseUrl: 'https://x.example/v1',
  apiKey: 'sk',
  model: 'qwen-vl-max',
};

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ vision: VISION, runtime: RUNTIME }) } as unknown as AiConfigService;
  return new ImageDescribeService(aiConfigService);
}

const LEGAL_DESC = {
  global: {
    subject: '年轻女性，坐姿，望向窗外',
    mood: '清冷慵懒',
    season: '秋', timeOfDay: 'goldenHour',
    palette: { dominant: ['#d2b48c', '#8b7d5c'], tone: '暖', brightness: '中间调偏亮' },
    light: { dir: '侧逆光', kind: '自然窗光', colorTemp: '偏暖', tone: '通透', contrast: '中等', key: '中间调', softness: '柔', shadowDir: '偏左' },
    composition: { leadLines: '窗框引导线', framing: '窗框式', symmetry: '否', subjectFrame: { x: 0.3, y: 0.2, w: 0.4, h: 0.6 }, cropRatio: '3:4', negativeSpace: '右上留白', depthOfField: '浅' },
    reproducibility: { level: 'high', reason: '窗光可复现', enableFillLight: true, lightHint: '侧逆补反光板' },
  },
  people: [
    { role: '主体', face: { expression: '平静', gazeDir: '窗外', headTilt: '0.1', angle: '侧4/3', openMouth: false } },
  ],
  scene: { location: '室内飘窗', depthLayers: { near: ['窗台'], middle: ['人'], far: ['窗外景'] }, props: [], furniture: ['飘窗'], texture: '编织材质', cleanliness: '整洁' },
  cameraLike: { lightSuggestion: '开补光', wbSuggestion: 'daylight', evSuggestion: '0.3', focusDepth: '对焦眼睛' },
};

describe('image-describe.prompt', () => {
  it('buildExhaustiveSystemPrompt 含九宫格指令与禁止省略词', () => {
    const p = buildExhaustiveSystemPrompt();
    expect(p).toContain('九宫格');
    expect(p).toContain('禁止');
    expect(p).toContain('unknown');
  });
});

describe('ImageDescribeService.describe', () => {
  beforeEach(() => visionChatJsonMock.mockReset());

  it('合法 JSON → 解析成 ImageDescription，global/people/scene/cameraLike 齐全', async () => {
    visionChatJsonMock.mockResolvedValueOnce(LEGAL_DESC as Record<string, unknown>);
    const svc = buildService();

    const desc = await svc.describe({ base64: 'aGk=', mime: 'image/jpeg' });

    expect(desc.global.subject).toBe('年轻女性，坐姿，望向窗外');
    expect(Array.isArray(desc.people)).toBe(true);
    expect(desc.people[0].role).toBe('主体');
    expect(desc.scene.location).toBe('室内飘窗');
    expect(desc.cameraLike.wbSuggestion).toBe('daylight');
    // visionChatJson 收到 vision 端点 + 图字段 + runtime
    const [cfg, input, runtime] = visionChatJsonMock.mock.calls[0];
    expect(cfg).toEqual(VISION);
    expect(input.imageBase64).toBe('aGk=');
    expect(input.imageMime).toBe('image/jpeg');
    expect(runtime).toEqual(RUNTIME);
  });

  it('缺字段时兜底：people 缺 → []、cameraLike 缺 → unknown 结构，不抛错', async () => {
    visionChatJsonMock.mockResolvedValueOnce({ global: { subject: '景' } });
    const svc = buildService();

    const desc = await svc.describe({ base64: 'aGk=', mime: 'image/png' });

    expect(Array.isArray(desc.people)).toBe(true);
    expect(desc.people).toHaveLength(0);
    expect(desc.cameraLike).toBeDefined();
  });

  it('非法 JSON（重试用尽 → LlmJsonError）→ 抛可读错误（含「无法解析为 JSON」）', async () => {
    visionChatJsonMock.mockRejectedValueOnce(
      new LlmJsonError('AI 输出无法解析为 JSON（已重试 2 次）：输出不是合法 JSON'),
    );
    const svc = buildService();

    await expect(svc.describe({ base64: 'aGk=', mime: 'image/jpeg' })).rejects.toThrow(/无法解析为 JSON/);
  });

  it('新契约：people[].expression/styling 与 global.styleRead 可解析，缺失时不崩', async () => {
    visionChatJsonMock.mockResolvedValueOnce({
      ...LEGAL_DESC,
      global: { ...LEGAL_DESC.global, styleRead: '小红书网感、轻精修' },
      people: [{ ...LEGAL_DESC.people[0], expression: '嘴角微松、眼神看侧前方', styling: '米色针织开衫 + 细金链' }],
    });
    const desc = await buildService().describe({ base64: 'aGk=', mime: 'image/jpeg' });
    expect(desc.global.styleRead).toBe('小红书网感、轻精修');
    expect(desc.people[0].expression).toBe('嘴角微松、眼神看侧前方');
    expect(desc.people[0].styling).toBe('米色针织开衫 + 细金链');
  });

  it('新契约缺失：styleRead 非字符串 → 空串兜底，不抛错', async () => {
    visionChatJsonMock.mockResolvedValueOnce(LEGAL_DESC as Record<string, unknown>);
    const desc = await buildService().describe({ base64: 'aGk=', mime: 'image/png' });
    expect(typeof desc.global.styleRead).toBe('string');
    expect(typeof desc.people[0].expression).toBe('string');
  });
});