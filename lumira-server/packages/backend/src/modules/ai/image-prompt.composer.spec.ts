// lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts
// 生图提示词组织器单测：结构化素材（模板基本信息/本张姿势/网络趋势参考/照片参数/生图要求）
// 分节组织 + 文本模型整理（成功透传 / 失败回退 / 空白回退 fallback）。

import { buildPromptMaterial, composeImagePrompt } from './image-prompt.composer';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';

jest.mock('./llm-client', () => ({
  textChat: jest.fn(),
}));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const TEXT_ENDPOINT: LlmEndpoint = {
  provider: 'qwen',
  baseUrl: 'https://dashscope.example.com/compatible-mode/v1',
  apiKey: 'sk-test',
  model: 'qwen-plus',
};

const RESEARCH = [
  { source: 'sogou', title: '千金风他拍构图', snippet: '低调贵气、自然抓拍感正在流行', url: 'https://example.com/1', keywords: ['千金风', '他拍'] },
];

/** 完整草稿（单姿势模式，含锚点一致性 + 构图落位 + 相机参数 + 取景要领） */
const DRAFT = {
  meta: {
    category: 'portrait',
    name: '千金小姐他拍风格模板',
    tags: ['千金风', '他拍感'],
    shortDesc: '温柔又贵气',
    description: '千金小姐的日常他拍，松弛贵气',
  },
  composition: {
    overlayType: 'rule_of_thirds',
    aspectRatio: '3:4',
    description: '主体落在左侧三分线，右侧留白',
    subjectFrame: { x: 0.28, y: 0.2, w: 0.4, h: 0.62 },
  },
  camera: {
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/400',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '85mm f/1.8',
    lensSuggestion: 'telephoto',
  },
  sceneGuide: {
    lightDirection: '侧逆光',
    bestTime: '午后4-6点',
    shootingDistance: '2-3米（七分身）',
    background: '街边咖啡馆',
    props: ['针织开衫', '小皮鞋'],
    tips: ['机位降到胸口高度略仰拍', '先对焦眼睛再构图'],
  },
  postProcess: { lut: 'cinematic', grain: 10 },
  pose: [{ index: 0, name: '回眸浅笑', description: '侧身回眸，手轻扶包带', position: { x: 0.45, y: 0.5 }, scale: 1, rotation: 0 }],
  singlePose: true,
  consistency: { mode: 'strict', anchor: 'first' },
};

beforeEach(() => {
  textChatMock.mockReset();
});

describe('buildPromptMaterial', () => {
  const material = buildPromptMaterial({ draft: DRAFT, research: RESEARCH, extraPrompt: '人物戴珍珠耳环' });

  it('六分节齐全：模板基本信息 / 构图与机位 / 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求', () => {
    expect(material).toContain('【模板基本信息】');
    expect(material).toContain('千金小姐他拍风格模板');
    expect(material).toContain('千金风、他拍感');
    expect(material).toContain('主体类型：人像');
    expect(material).toContain('【构图与机位】');
    expect(material).toContain('【本张姿势】');
    expect(material).toContain('回眸浅笑');
    expect(material).toContain('侧身回眸，手轻扶包带');
    expect(material).toContain('【网络趋势参考】');
    expect(material).toContain('千金风他拍构图');
    expect(material).toContain('低调贵气');
    expect(material).toContain('【照片参数】');
    expect(material).toContain('3:4');
    expect(material).toContain('侧逆光');
    expect(material).toContain('街边咖啡馆');
    expect(material).toContain('针织开衫、小皮鞋');
    expect(material).toContain('电影感'); // LUT cinematic 标签
    expect(material).toContain('【生图要求】');
  });

  it('构图与机位下发给模型：构图类型中文转译 + 构图说明 + 主体落位与占比 + 景别 + 拍摄要领 + 人物落位', () => {
    expect(material).toContain('构图类型：三等分'); // overlayType rule_of_thirds → 中文标签
    expect(material).toContain('构图说明：主体落在左侧三分线，右侧留白');
    expect(material).toContain('主体落位：主体位于画面中部纵向居中，横向占画幅约 40%、纵向约占 62%');
    expect(material).toContain('拍摄距离与景别：2-3米（七分身）');
    expect(material).toContain('拍摄要领：1) 机位降到胸口高度略仰拍；2) 先对焦眼睛再构图');
    expect(material).toContain('人物落位与大小：人物位于画面中部纵向居中，人物在画面中占比适中（半身到七分身）');
  });

  it('照片参数下发相机全套参数（原先整段丢失 → 表现为「没有参数优化」）', () => {
    expect(material).toContain('镜头：85mm f/1.8，建议长焦');
    expect(material).toContain('快门：1/400');
    expect(material).toContain('感光度：ISO 200（手动）');
    expect(material).toContain('白平衡：日光 5500K');
    expect(material).toContain('曝光补偿：+0.3EV');
    expect(material).toContain('对焦：自动');
    expect(material).not.toContain('闪光灯：关闭'); // off 不产生噪声行
  });

  it('生图要求：随拍感只作用于质感，构图/机位/参数必须专业且不得随意构图', () => {
    expect(material).toContain('「随拍感」只用于质感与瞬间感');
    expect(material).toContain('画面水平、主体落位与留白经设计、肢体线条舒展');
    expect(material).toContain('构图 / 机位 / 相机参数以【构图与机位】【照片参数】给出的值为准');
    expect(material).not.toContain('水平线轻微倾斜');
    expect(material).not.toContain('构图抓拍式');
  });

  it('生图要求含真实感去 AI 味 + 锚点一致性 + 用户额外要求权重最高', () => {
    expect(material).toContain('真实相机直出');
    expect(material).toContain('毛孔');
    expect(material).toContain('参考图是同一套模板的第一张姿势图');
    expect(material).toContain('用户额外要求（权重最高，必须满足）：人物戴珍珠耳环');
  });

  it('research 为空 → 无网络趋势参考分节', () => {
    const m = buildPromptMaterial({ draft: DRAFT, research: [] });
    expect(m).not.toContain('【网络趋势参考】');
  });
});

describe('composeImagePrompt', () => {
  it('textChat 成功 → 返回整理后的提示词（composed: true），素材随 userText 下发', async () => {
    textChatMock.mockResolvedValueOnce('  整理后的生图提示词  ');

    const res = await composeImagePrompt(TEXT_ENDPOINT, { draft: DRAFT, research: RESEARCH }, 'fallback');

    expect(res).toEqual({ prompt: '整理后的生图提示词', composed: true });
    const [endpoint, input] = textChatMock.mock.calls[0];
    expect(endpoint).toEqual(TEXT_ENDPOINT);
    expect(input.systemPrompt).toContain('生图提示词');
    // 随拍感只作用于质感与瞬间，不得再写成「构图随意 / 水平线倾斜 / 真实感高于画面美观」
    expect(input.systemPrompt).toContain('「随拍感」只作用于质感与瞬间感');
    expect(input.systemPrompt).not.toContain('水平线轻微倾斜');
    expect(input.systemPrompt).not.toContain('第一优先级，高于画面美观');
    expect(input.userText).toContain('千金小姐他拍风格模板');
    expect(input.userText).toContain('千金风他拍构图');
  });

  it('textChat 失败 → 静默回退 fallback（composed: false，不抛错）', async () => {
    textChatMock.mockRejectedValueOnce(new Error('timeout'));

    const res = await composeImagePrompt(TEXT_ENDPOINT, { draft: DRAFT, research: [] }, 'fallback');

    expect(res).toEqual({ prompt: 'fallback', composed: false });
  });

  it('textChat 空白输出 → 回退 fallback', async () => {
    textChatMock.mockResolvedValueOnce('   ');

    const res = await composeImagePrompt(TEXT_ENDPOINT, { draft: DRAFT, research: [] }, 'fallback');

    expect(res).toEqual({ prompt: 'fallback', composed: false });
  });
});
