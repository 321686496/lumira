// lumira-server/packages/backend/src/modules/ai/prompt-polisher.spec.ts
// prompt 润色单测：成功 / 抛错回退 / 空白回退 / 入参断言

import { polishPrompt } from './prompt-polisher';
import { textChat } from './llm-client';
import type { ActiveAiConfig } from './ai-config.service';

jest.mock('./llm-client', () => ({
  textChat: jest.fn(),
}));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const CFG: ActiveAiConfig = {
  provider: 'qwen',
  baseUrl: 'https://x.example',
  apiKey: 'sk-test',
  visionModel: 'qwen-vl-max',
  imageModel: 'wanx2.1-t2i-turbo',
  textModel: 'qwen-plus',
  hasCustomTextModel: true,
};

describe('polishPrompt', () => {
  beforeEach(() => textChatMock.mockReset());

  it('成功 → 返回 trim 后的润色值 + polished: true', async () => {
    textChatMock.mockResolvedValue('  润色后的提示词  ');
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '润色后的提示词', polished: true });
  });

  it('textChat 抛错 → 静默回退 rawPrompt + polished: false', async () => {
    textChatMock.mockRejectedValue(new Error('timeout'));
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '原始拼接 prompt', polished: false });
  });

  it('textChat 返回空白 → 回退 rawPrompt', async () => {
    textChatMock.mockResolvedValue('   ');
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '原始拼接 prompt', polished: false });
  });

  it('入参：temperature 0.4、timeoutMs 30s、userText = rawPrompt、模型取有效 textModel', async () => {
    textChatMock.mockResolvedValue('润色');
    await polishPrompt(CFG, '原始拼接 prompt');
    const [cfgArg, inputArg] = textChatMock.mock.calls[0];
    expect(cfgArg.textModel).toBe('qwen-plus');
    expect(inputArg.userText).toBe('原始拼接 prompt');
    expect(inputArg.temperature).toBe(0.4);
    expect(inputArg.timeoutMs).toBe(30_000);
    expect(inputArg.systemPrompt).toContain('摄影');
  });
});
