// lumira-server/packages/backend/src/modules/ai/llm-json.ctx.spec.ts
// textChatJson 透传工具上下文（Task 7，TDD）：带 ctx → 走 chatWithTools；不带 ctx → 第三个参数 undefined（等价旧版 textChat）

import { textChatJson, type LlmJsonRuntime } from './llm-json';
import { chatWithTools } from './tools/text-tool-loop';

jest.mock('./llm-client', () => ({
  textChat: jest.fn(),
  visionChat: jest.fn(),
}));

jest.mock('./tools/text-tool-loop', () => ({ chatWithTools: jest.fn() }));

jest.mock('./llm-trace', () => ({ traceNote: jest.fn(), traceLlmCall: () => null }));

const chatWithToolsMock = chatWithTools as jest.Mock;

const RUNTIME: LlmJsonRuntime = { retryCount: 0, timeoutMs: 300000, maxTokens: 8192 };
const CFG = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };
const CTX = { tools: [{ name: 'crawl_website', description: 'd', parameters: {} }], execute: jest.fn(), maxToolCalls: 3 };

describe('textChatJson 透传工具上下文', () => {
  beforeEach(() => {
    chatWithToolsMock.mockReset();
  });

  afterEach(() => jest.restoreAllMocks());

  it('带 ctx → 走 chatWithTools', async () => {
    chatWithToolsMock.mockResolvedValueOnce('{"a":1}');
    const out = await textChatJson(CFG, { systemPrompt: 'sys', userText: 'hi', ctx: CTX }, RUNTIME);
    expect(out).toEqual({ a: 1 });
    expect(chatWithToolsMock.mock.calls[0][2]).toBe(CTX);
  });

  it('不带 ctx → chatWithTools 的第三个参数为 undefined（等价旧版 textChat）', async () => {
    chatWithToolsMock.mockResolvedValueOnce('{"b":2}');
    const out = await textChatJson(CFG, { systemPrompt: 'sys', userText: 'hi' }, RUNTIME);
    expect(out).toEqual({ b: 2 });
    expect(chatWithToolsMock.mock.calls[0][2]).toBeUndefined();
  });
});