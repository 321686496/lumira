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
  { source: 'sogou', title: '千金风他拍构图', snippet: '低调贵气、自然抓拍感正在流行', url: 'https://example.com/1' },
];

/** 完整草稿（单姿势模式，含锚点一致性） */
const DRAFT = {
  meta: {
    category: 'portrait',
    name: '千金小姐他拍风格模板',
    tags: ['千金风', '他拍感'],
    shortDesc: '温柔又贵气',
    description: '千金小姐的日常他拍，松弛贵气',
  },
  composition: { aspectRatio: '3:4' },
  sceneGuide: { lightDirection: '侧逆光', bestTime: '午后4-6点', background: '街边咖啡馆', props: ['针织开衫', '小皮鞋'] },
  postProcess: { lut: 'cinematic', grain: 10 },
  pose: [{ index: 0, name: '回眸浅笑', description: '侧身回眸，手轻扶包带', position: '半身，中心偏右' }],
  singlePose: true,
  consistency: { mode: 'strict', anchor: 'first' },
};

beforeEach(() => {
  textChatMock.mockReset();
});

describe('buildPromptMaterial', () => {
  const material = buildPromptMaterial({ draft: DRAFT, research: RESEARCH, extraPrompt: '人物戴珍珠耳环' });

  it('五分节齐全：模板基本信息 / 本张姿势 / 网络趋势参考 / 照片参数 / 生图要求', () => {
    expect(material).toContain('【模板基本信息】');
    expect(material).toContain('千金小姐他拍风格模板');
    expect(material).toContain('千金风、他拍感');
    expect(material).toContain('主体类型：人像');
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
