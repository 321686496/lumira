import { StyleProfileService } from './style-profile.service';
import { textChat } from './llm-client';
import type { LlmEndpoint } from './llm-client';
import type { AiConfigService } from './ai-config.service';
import { STYLE_ARCHETYPE_PRESETS } from './style-profile.presets';

jest.mock('./llm-client', () => ({ textChat: jest.fn() }));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const TEXT: LlmEndpoint = { provider: 'qwen', baseUrl: 'https://x.example/v1', apiKey: 'sk', model: 'qwen-plus' };

const STYLE_PRESET_BIAS = STYLE_ARCHETYPE_PRESETS.fashion_editorial.compositionBias;

function buildService() {
  const aiConfigService = { getActiveConfig: async () => ({ text: TEXT }) } as unknown as AiConfigService;
  return new StyleProfileService(aiConfigService);
}

describe('StyleProfileService.resolve', () => {
  beforeEach(() => textChatMock.mockReset());

  it('正常解析：返回 llm 档案，含模型给出的穿搭与表情', async () => {
    textChatMock.mockResolvedValueOnce(
      JSON.stringify({
        category: 'portrait',
        archetype: 'fashion_editorial',
        aestheticTarget: '秋冬杂志大片',
        subjectStyling: '驼色大衣 + 硬挺皮革手套',
        expressionMood: '冷峻直视镜头',
        retouchLevel: 'polished',
        extraNotes: '背景留出大面积灰墙负空间',
      }),
    );
    const res = await buildService().resolve({ creationReq: '秋冬时尚大片人像' });

    expect(res.source).toBe('llm');
    expect(res.profile.archetype).toBe('fashion_editorial');
    expect(res.profile.retouchLevel).toBe('polished');
    expect(res.profile.subjectStyling).toBe('驼色大衣 + 硬挺皮革手套');
    expect(res.profile.compositionBias).toBe(STYLE_PRESET_BIAS); // 缺字段回填档案默认
    const [cfg, input] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(TEXT);
    expect(input.jsonMode).toBe(true);
    expect(input.temperature).toBe(0.3);
    expect(input.timeoutMs).toBe(60_000);
    expect(String(input.userText)).toContain('秋冬时尚大片人像');
  });

  it('枚举越界 → 归一化兜底 candid_lifestyle + portrait', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ category: 'anime', archetype: '二次元' }));
    const res = await buildService().resolve({ text: '随便' });
    expect(res.profile.archetype).toBe('candid_lifestyle');
    expect(res.profile.category).toBe('portrait');
    expect(res.profile.retouchLevel).toBe('none');
  });

  it('retouchLevel 非法 → 取档案默认（polished）', async () => {
    textChatMock.mockResolvedValueOnce(JSON.stringify({ archetype: 'photo_portrait', retouchLevel: 'ultra' }));
    const res = await buildService().resolve({ text: '写真' });
    expect(res.profile.retouchLevel).toBe('light');
  });

  it('调用失败 → 降级 fallback，不抛错，note 含原因', async () => {
    textChatMock.mockRejectedValueOnce(new Error('ECONNRESET'));
    const res = await buildService().resolve({ text: '夜景' });
    expect(res.source).toBe('fallback');
    expect(res.profile.archetype).toBe('candid_lifestyle');
    expect(res.note).toContain('ECONNRESET');
  });

  it('JSON 非法 → 降级 fallback，不抛错', async () => {
    textChatMock.mockResolvedValueOnce('我觉得这是一组很美的照片');
    const res = await buildService().resolve({ text: '海边' });
    expect(res.source).toBe('fallback');
    expect(res.note.length).toBeGreaterThan(0);
  });

  it('无输入 → 不调用模型，直接 fallback', async () => {
    const res = await buildService().resolve({});
    expect(textChatMock).not.toHaveBeenCalled();
    expect(res.source).toBe('fallback');
  });
});