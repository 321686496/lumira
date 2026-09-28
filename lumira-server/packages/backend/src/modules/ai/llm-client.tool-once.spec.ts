import { toolChatOnce, type LlmEndpoint } from './llm-client';

const CFG: LlmEndpoint = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };

function parseBody(init?: RequestInit): Record<string, any> {
  return JSON.parse(String(init?.body));
}

const TOOLS = [{ name: 'crawl_website', description: '抓取网页正文', parameters: { type: 'object', properties: {} } }];

describe('toolChatOnce', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => fetchMock.mockReset());

  it('回填 assistant 消息且不修改入参数组', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          choices: [{ message: { role: 'assistant', content: null, tool_calls: [{ id: 'call_1', type: 'function', function: { name: 'crawl_website', arguments: '{"url":"https://a.com"}' } }] } }],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    const seed = [
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'hi' },
    ];

    const res = await toolChatOnce(CFG, { messages: seed, tools: TOOLS, systemPrompt: 'sys', userPrompt: 'hi' });

    expect(seed).toHaveLength(2); // 入参未被修改
    expect(res.messages).toHaveLength(3);
    expect(res.content).toBeNull();
    expect(res.toolCalls[0].tool_calls[0].function.name).toBe('crawl_website');
  });

  it('toolChoice=none 时请求体带 tools + tool_choice:none', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ choices: [{ message: { role: 'assistant', content: '{"ok":1}' } }] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    await toolChatOnce(CFG, { messages: [{ role: 'user', content: 'hi' }], tools: TOOLS, toolChoice: 'none', jsonMode: true });

    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.tool_choice).toBe('none');
    expect(body.tools).toHaveLength(1);
    expect(body.response_format).toEqual({ type: 'json_object' });
  });

  it('tools 按 OpenAI 契约序列化：type:"function" + function 外壳（厂商强校验，缺 type 会 400）', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ choices: [{ message: { role: 'assistant', content: 'ok' } }] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    await toolChatOnce(CFG, { messages: [{ role: 'user', content: 'hi' }], tools: TOOLS });

    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.tools).toEqual([
      {
        type: 'function',
        function: { name: 'crawl_website', description: '抓取网页正文', parameters: { type: 'object', properties: {} } },
      },
    ]);
  });
});