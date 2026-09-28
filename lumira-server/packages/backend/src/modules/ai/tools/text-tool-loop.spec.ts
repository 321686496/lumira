import { chatWithTools, TOOL_LOOP_MAX_ROUNDS, type TextToolContext } from './text-tool-loop';
import { toolChatOnce, textChat } from '../llm-client';

jest.mock('../llm-client', () => ({
  textChat: jest.fn(),
  toolChatOnce: jest.fn(),
}));

const toolChatOnceMock = toolChatOnce as jest.Mock;
const textChatMock = textChat as jest.Mock;

const CFG = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };
const INPUT = { systemPrompt: 'sys', userText: 'hi' };

function ctxOf(execute: jest.Mock, maxToolCalls = 3): TextToolContext {
  return { tools: [{ name: 'crawl_website', description: 'd', parameters: {} }], execute, maxToolCalls };
}

function toolCallsResult(name = 'crawl_website', args = '{"url":"https://a.com"}') {
  return {
    content: null,
    toolCalls: [{ role: 'assistant' as const, content: null, tool_calls: [{ id: 'call_1', type: 'function' as const, function: { name, arguments: args } }] }],
    messages: [{ role: 'user', content: 'hi' }, { role: 'assistant', content: null }],
  };
}

function contentResult(content: string) {
  return { content, toolCalls: [], messages: [{ role: 'user', content: 'hi' }, { role: 'assistant', content }] };
}

describe('chatWithTools', () => {
  beforeEach(() => {
    toolChatOnceMock.mockReset();
    textChatMock.mockReset();
  });

  it('ctx 缺省 → 直接走 textChat（不调用工具）', async () => {
    textChatMock.mockResolvedValueOnce('plain');
    const out = await chatWithTools(CFG, INPUT);
    expect(out).toBe('plain');
    expect(toolChatOnceMock).not.toHaveBeenCalled();
  });

  it('首轮 tool_calls → 执行工具 → 次轮返回正文', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"抓到的正文"}');
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('最终 JSON'));

    const out = await chatWithTools(CFG, { ...INPUT, jsonMode: true }, ctxOf(execute));

    expect(out).toBe('最终 JSON');
    expect(execute).toHaveBeenCalledWith('crawl_website', '{"url":"https://a.com"}');
    // 第二轮消息历史里带上了 role:'tool' 回填
    const secondCallMessages = toolChatOnceMock.mock.calls[1][1].messages as Array<{ role: string }>;
    expect(secondCallMessages.some((m) => m.role === 'tool')).toBe(true);
  });

  it('工具执行抛错 → 回填 error 文本并继续', async () => {
    const execute = jest.fn().mockRejectedValue(new Error('抓取超时（8 秒）'));
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('降级结果'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute));

    expect(out).toBe('降级结果');
    const secondCallMessages = toolChatOnceMock.mock.calls[1][1].messages as Array<{ role: string; content?: string }>;
    const toolMsg = secondCallMessages.find((m) => m.role === 'tool');
    expect(toolMsg?.content).toContain('抓取超时');
  });

  it('工具次数用尽 → 进入 tool_choice:none 收尾轮', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"a"}');
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('收尾结果'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute, 1));

    expect(out).toBe('收尾结果');
    expect(execute).toHaveBeenCalledTimes(1);
    const lastCall = toolChatOnceMock.mock.calls[toolChatOnceMock.mock.calls.length - 1][1];
    expect(lastCall.toolChoice).toBe('none');
    // 收尾轮仍带 tools，为规避「tools + response_format 兼容性」风险不传 jsonMode
    expect(lastCall.jsonMode).toBeUndefined();
  });

  it('全部轮次都只发 tool_calls → 收尾轮强制定稿', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"a"}');
    for (let i = 0; i < TOOL_LOOP_MAX_ROUNDS; i += 1) toolChatOnceMock.mockResolvedValueOnce(toolCallsResult());
    toolChatOnceMock.mockResolvedValueOnce(contentResult('定稿'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute, 99));

    expect(out).toBe('定稿');
    expect(toolChatOnceMock).toHaveBeenCalledTimes(TOOL_LOOP_MAX_ROUNDS + 1);
    expect(toolChatOnceMock.mock.calls[TOOL_LOOP_MAX_ROUNDS][1].toolChoice).toBe('none');
  });

  it('工具轮整体异常 → 回退一次无工具调用', async () => {
    toolChatOnceMock.mockRejectedValue(new Error('AI 服务认证失败'));
    textChatMock.mockResolvedValueOnce('保底结果');

    const out = await chatWithTools(CFG, INPUT, ctxOf(jest.fn()));

    expect(out).toBe('保底结果');
  });

  afterEach(() => jest.restoreAllMocks());
});
