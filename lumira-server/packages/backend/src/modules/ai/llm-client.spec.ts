// lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts
// OpenAI 兼容 chat 客户端单测（Task 3，TDD）
// 用例 1~8 与 task-3-brief.md 关键用例一一对应；9~13 为补充用例
// （网络错误 / 空内容 / 404 降级 / 降级后仍失败 / 非 jsonMode 不重试）
// 用例 14~16 为 Task 2（textChat）追加：纯文本请求形状 / textModel 回退 / jsonMode 降级

import { LlmConfig, VisionChatInput, textChat, visionChat } from './llm-client';

/** baseUrl 故意带尾斜杠：验证拼接前先规范化去掉 */
const CFG: LlmConfig = {
  provider: 'qwen',
  baseUrl: 'https://dashscope.example.com/compatible-mode/v1/',
  apiKey: 'sk-test-key',
  visionModel: 'qwen-vl-max',
};

function baseInput(): VisionChatInput {
  return {
    systemPrompt: '你是摄影模板录入助手',
    userText: '请分析这张照片',
    imageBase64: 'aGVsbG8=',
    imageMime: 'image/jpeg',
  };
}

/** OpenAI 兼容成功响应 */
function okResponse(content: string): Response {
  return new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status: 200 });
}

/** 上游错误响应 */
function errorResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status });
}

/** 取出某次 fetch 调用的请求 body 并 JSON.parse */
function parseBody(init: unknown): Record<string, any> {
  return JSON.parse(String((init as RequestInit | undefined)?.body));
}

/** 断言「必定 reject」并捕获错误对象（避免重复调用导致 Response body 只能读一次） */
async function expectReject(promise: Promise<string>): Promise<Error> {
  return promise.then(
    () => new Error('不应成功'),
    (e: Error) => e,
  );
}

afterEach(() => {
  jest.restoreAllMocks();
});

describe('visionChat', () => {
  it('1. 请求形状：URL 规范化拼 /chat/completions、Bearer 鉴权、system+user 消息结构、默认参数', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse('ok'));

    await visionChat(CFG, baseInput());

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toBe('https://dashscope.example.com/compatible-mode/v1/chat/completions');
    expect(init?.method).toBe('POST');
    expect(init?.headers).toEqual({
      'Content-Type': 'application/json',
      Authorization: 'Bearer sk-test-key',
    });

    const body = parseBody(init);
    expect(body.model).toBe('qwen-vl-max');
    expect(body.temperature).toBe(0.3);
    expect(body.max_tokens).toBe(4096);
    expect(body.response_format).toBeUndefined();
    expect(body.messages).toEqual([
      { role: 'system', content: '你是摄影模板录入助手' },
      {
        role: 'user',
        content: [
          { type: 'text', text: '请分析这张照片' },
          { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,aGVsbG8=' } },
        ],
      },
    ]);
  });

  it('2. 成功 → 返回 choices[0].message.content', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(okResponse('模板草稿 JSON 文本'));

    await expect(visionChat(CFG, baseInput())).resolves.toBe('模板草稿 JSON 文本');
  });

  it('3. jsonMode=true → body 含 response_format:{type:"json_object"}，temperature 可覆盖', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse('{}'));

    await visionChat(CFG, { ...baseInput(), jsonMode: true, temperature: 0.7 });

    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.response_format).toEqual({ type: 'json_object' });
    expect(body.temperature).toBe(0.7);
  });

  it('4. jsonMode 首次 400 → 自动去掉 response_format 重试一次成功', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(errorResponse(400, { error: { message: 'response_format not supported' } }))
      .mockResolvedValueOnce(okResponse('{"ok":1}'));

    await expect(visionChat(CFG, { ...baseInput(), jsonMode: true })).resolves.toBe('{"ok":1}');

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(parseBody(fetchMock.mock.calls[0][1]).response_format).toEqual({ type: 'json_object' });
    expect(parseBody(fetchMock.mock.calls[1][1]).response_format).toBeUndefined();
  });

  it('5. 401 → 抛 apiKey 无效或无权限、指向 AI 设置的运营可读错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(401, { error: { message: 'invalid api key' } }));

    const err = await expectReject(visionChat(CFG, baseInput()));
    expect(err).toBeInstanceOf(Error);
    expect(err.message).toContain('apiKey 无效或无权限');
    expect(err.message).toContain('AI 设置');
  });

  it('6. 403 → 同 401 抛认证失败错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(403, {}));

    await expect(visionChat(CFG, baseInput())).rejects.toThrow('apiKey 无效或无权限');
  });

  it('7. 超时（never-resolving fetch + timeoutMs:10）→ 抛含「超时」的错误', async () => {
    // 模拟真实 fetch 对 abort signal 的行为：signal abort 时以 AbortError reject
    jest.spyOn(global, 'fetch').mockImplementation(
      (_url: any, init?: any) =>
        new Promise((_resolve, reject) => {
          init?.signal?.addEventListener('abort', () => {
            const e = new Error('The operation was aborted');
            e.name = 'AbortError';
            reject(e);
          });
        }),
    );

    await expect(visionChat(CFG, { ...baseInput(), timeoutMs: 10 })).rejects.toThrow('超时');
  });

  it('8. 上游 500 + body {error:{message}} → 错误透传上游 message 并拼接 status', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(500, { error: { message: '上游内部错误' } }));

    const err = await expectReject(visionChat(CFG, baseInput()));
    expect(err).toBeInstanceOf(Error);
    expect(err.message).toContain('上游内部错误');
    expect(err.message).toContain('500');
  });

  it('9. 网络层错误（连接拒绝）→ 抛 AI 服务无法连接', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('connect ECONNREFUSED 1.2.3.4:443'));

    await expect(visionChat(CFG, baseInput())).rejects.toThrow('无法连接');
  });

  it('10. 成功响应但 content 为空 → 抛 AI 服务返回内容为空', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(okResponse(''));

    await expect(visionChat(CFG, baseInput())).rejects.toThrow('内容为空');
  });

  it('11. jsonMode 首次 404 → 同 400 走降级重试', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(errorResponse(404, { message: 'unknown field response_format' }))
      .mockResolvedValueOnce(okResponse('{}'));

    await expect(visionChat(CFG, { ...baseInput(), jsonMode: true })).resolves.toBe('{}');

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(parseBody(fetchMock.mock.calls[1][1]).response_format).toBeUndefined();
  });

  it('12. jsonMode 降级重试后仍失败 → 抛上游错误（不无限重试）', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(errorResponse(400, { error: { message: 'bad request' } }))
      .mockResolvedValueOnce(errorResponse(500, { error: { message: '上游内部错误' } }));

    await expect(visionChat(CFG, { ...baseInput(), jsonMode: true })).rejects.toThrow('上游内部错误');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('13. 非 jsonMode 的 400 → 不重试直接抛上游错误', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue(errorResponse(400, { error: { message: '参数错误' } }));

    await expect(visionChat(CFG, baseInput())).rejects.toThrow('参数错误');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});

// ===== textChat（Task 2 追加）=====
describe('textChat', () => {
  /** textChat 用：配置了独立 textModel */
  const TEXT_CFG: LlmConfig = {
    provider: 'qwen',
    baseUrl: 'https://x.example/v1',
    apiKey: 'sk-test',
    visionModel: 'qwen-vl-max',
    textModel: 'qwen-plus',
  };

  it('14. 请求体为纯文本 messages（无 image_url），model 取 textModel', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValueOnce(okResponse('hello'));

    const out = await textChat(TEXT_CFG, { systemPrompt: 'sys', userText: 'hi' });

    expect(out).toBe('hello');
    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.model).toBe('qwen-plus');
    expect(body.messages).toEqual([
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'hi' },
    ]);
  });

  it('15. 未配置 textModel → model 回退 visionModel', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValueOnce(okResponse('hello'));

    await textChat({ ...TEXT_CFG, textModel: undefined }, { systemPrompt: 'sys', userText: 'hi' });

    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.model).toBe('qwen-vl-max');
  });

  it('16. jsonMode 400 时自动降级重试（复用 visionChat 同款逻辑）', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(errorResponse(400, { error: { message: 'response_format not supported' } }))
      .mockResolvedValueOnce(okResponse('{"a":1}'));

    const out = await textChat(TEXT_CFG, { systemPrompt: 'sys', userText: 'hi', jsonMode: true });

    expect(out).toBe('{"a":1}');
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(parseBody(fetchMock.mock.calls[0][1]).response_format).toEqual({ type: 'json_object' });
    expect(parseBody(fetchMock.mock.calls[1][1]).response_format).toBeUndefined();
  });
});
