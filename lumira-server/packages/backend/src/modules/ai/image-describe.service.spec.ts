// lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts
// T2 穷尽式图像识别服务（Task 5，TDD）：mock visionChat → 解析 ImageDescription；非法 JSON → 抛可读错误

import { ImageDescribeService, mergeImageDescriptions, type ImageDescription } from './image-describe.service';
import { buildExhaustiveSystemPrompt } from './image-describe.prompt';
import { LlmJsonError, visionChatJson } from './llm-json';
import type { LlmEndpoint } from './llm-client';
import type { AiConfigService } from './ai-config.service';
import { AiUpstreamError } from './ai-upstream-error';

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

describe('ImageDescribeService.describeMany', () => {
  beforeEach(() => visionChatJsonMock.mockReset());

  const SECOND_DESC = {
    global: {
      subject: '第二张主体：户外野餐',
      mood: '温馨',
      season: '夏', timeOfDay: 'noon',
      palette: { dominant: ['#ffffff'], tone: '亮', brightness: '亮' },
      light: {},
      composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '', negativeSpace: '', depthOfField: '' },
      reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' },
    },
    people: [
      { role: '陪体', face: {}, body: {}, limbs: {}, outfit: {}, anchors: { positionInFrame: { x: 0, y: 0 }, scaleRatio: 1, rotationDegree: 0 }, lightOnPerson: {} },
    ],
    scene: { location: '户外草地', depthLayers: { near: ['草地'], middle: ['帐篷'], far: ['远山'] }, props: ['风筝'], furniture: [], texture: '草', cleanliness: '自然' },
    cameraLike: { lightSuggestion: 'x', wbSuggestion: 'shade', evSuggestion: '0', focusDepth: 'y' },
  };

  it('两张图逐张识别后合并：global/cameraLike 取第一张、people concat、scene.props/depthLayers 并集', async () => {
    visionChatJsonMock
      .mockResolvedValueOnce(LEGAL_DESC as Record<string, unknown>)
      .mockResolvedValueOnce(SECOND_DESC as Record<string, unknown>);
    const svc = buildService();

    const { description: merged, failedIndexes } = await svc.describeMany([
      { base64: 'aGk=', mime: 'image/jpeg' },
      { base64: 'aG8=', mime: 'image/png' },
    ]);

    // describe 内部逐张调用 visionChatJson（各一次），携带对应图字段
    expect(visionChatJsonMock).toHaveBeenCalledTimes(2);
    expect(visionChatJsonMock.mock.calls[0][1].imageBase64).toBe('aGk=');
    expect(visionChatJsonMock.mock.calls[1][1].imageBase64).toBe('aG8=');
    expect(failedIndexes).toEqual([]);
    // global / cameraLike 取第一张
    expect(merged.global.subject).toBe('年轻女性，坐姿，望向窗外');
    expect(merged.cameraLike.wbSuggestion).toBe('daylight');
    // people concat：第一张 1 人 + 第二张 1 人 = 2 人（保持顺序）
    expect(merged.people.map((p) => p.role)).toEqual(['主体', '陪体']);
    // scene.props / furniture 并集
    expect(merged.scene.props).toEqual(['风筝']);
    // depthLayers 三层各自并集（去重保留顺序）
    expect(merged.scene.depthLayers.near).toEqual(['窗台', '草地']);
    expect(merged.scene.depthLayers.middle).toEqual(['人', '帐篷']);
    expect(merged.scene.depthLayers.far).toEqual(['窗外景', '远山']);
    // 场景基调仍取第一张（location/texture/cleanliness）
    expect(merged.scene.location).toBe('室内飘窗');
  });

  it('任一张识别失败 → 跳过该张，其余正常合并（不再整体抛错）', async () => {
    visionChatJsonMock
      .mockResolvedValueOnce(LEGAL_DESC as Record<string, unknown>)
      .mockRejectedValueOnce(new LlmJsonError('AI 输出无法解析为 JSON'));
    const svc = buildService();

    const r = await svc.describeMany([{ base64: 'aGk=', mime: 'image/jpeg' }, { base64: 'aG8=', mime: 'image/png' }]);

    expect(r.failedIndexes).toEqual([1]);
    expect(r.description.global.subject).toBe('年轻女性，坐姿，望向窗外');
  });
});

describe('mergeImageDescriptions', () => {
  const baseDesc: ImageDescription = {
    global: {
      subject: 's', mood: 'm', season: 'se', timeOfDay: 't',
      palette: { dominant: [], tone: '', brightness: '' },
      light: {},
      composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '', negativeSpace: '', depthOfField: '' },
      reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' },
    },
    people: [],
    scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
    cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
  };

  it('单张列表短路：直接返回原对象（同一引用，不再复制）', () => {
    const out = mergeImageDescriptions([baseDesc]);
    expect(out).toBe(baseDesc);
  });

  it('空数组抛「无可合并的图片描述」', () => {
    expect(() => mergeImageDescriptions([])).toThrow('无可合并的图片描述');
  });
});

describe('ImageDescribeService.describeMany（逐张失败不致命）', () => {
  afterEach(() => jest.restoreAllMocks());

  /** 最小合法 ImageDescription（mock describe 的返回值；merge 只访问这些字段） */
  const okDesc = (subject: string) =>
    ({
      global: {
        subject, mood: '', season: '', timeOfDay: '',
        palette: { dominant: [], tone: '', brightness: '' },
        light: {},
        composition: { leadLines: '', framing: '', symmetry: '', subjectFrame: {}, cropRatio: '', negativeSpace: '', depthOfField: '' },
        reproducibility: { level: '', reason: '', enableFillLight: false, lightHint: '' },
      },
      people: [],
      scene: { location: '', depthLayers: { near: [], middle: [], far: [] }, props: [], furniture: [], texture: '', cleanliness: '' },
      cameraLike: { lightSuggestion: '', wbSuggestion: '', evSuggestion: '', focusDepth: '' },
    }) as ImageDescription;

  it('部分图片失败：返回成功图片的合并描述 + failedIndexes，并回调失败下标', async () => {
    const service = new ImageDescribeService({} as never);
    const calls: number[] = [];
    const failures: number[] = [];
    jest.spyOn(service, 'describe').mockImplementation(async () => {
      const n = calls.length;
      calls.push(n);
      if (n === 1) throw new Error('AI 请求超时，请稍后重试');
      return okDesc(`s${n}`);
    });

    const r = await service.describeMany(
      [
        { base64: 'a', mime: 'image/png' },
        { base64: 'b', mime: 'image/png' },
        { base64: 'c', mime: 'image/png' },
      ],
      { onImageFailure: (i) => failures.push(i) },
    );

    expect(r.failedIndexes).toEqual([1]);
    expect(failures).toEqual([1]);
    expect(r.description.people).toEqual([]);
  });

  it('全部图片失败：抛 AiUpstreamError，带全部失败下标', async () => {
    const service = new ImageDescribeService({} as never);
    jest.spyOn(service, 'describe').mockRejectedValue(new Error('AI 请求超时，请稍后重试'));

    const err: unknown = await service
      .describeMany([
        { base64: 'a', mime: 'image/png' },
        { base64: 'b', mime: 'image/png' },
      ])
      .then(
        () => null,
        (e: unknown) => e,
      );

    expect(err).toBeInstanceOf(AiUpstreamError);
    expect(err).toMatchObject({ code: 'upstream_timeout', failedIndexes: [0, 1] });
  });
});