// lumira-server/packages/backend/src/modules/ai/llm-json.spec.ts
// 识别链路 JSON 重试封装（Task 4，TDD）：解析失败 / 超时 / 5xx / 空输出 → 有界重试；鉴权类错误不重试

import { LlmJsonError, runJsonChat, visionChatJsonMulti } from './llm-json';
import type { LlmEndpoint } from './llm-client';

jest.mock('./llm-client', () => ({
  visionChatMulti: jest.fn(async () => '{"ok":true}'),
}));

const RT = { retryCount: 2, timeoutMs: 300_000, maxTokens: 8192 };

describe('runJsonChat', () => {
  it('第 1 次即合法 JSON → 直接返回，不重试', async () => {
    const call = jest.fn(async () => '{"a":1}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ a: 1 });
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('解析失败后重试成功 → 第 2 次返回对象，且重试请求带纠正指令', async () => {
    const call = jest.fn()
      .mockResolvedValueOnce('不是 JSON')
      .mockResolvedValueOnce('{"a":2}');
    await expect(runJsonChat(RT, call, '原始提问')).resolves.toEqual({ a: 2 });
    expect(call).toHaveBeenCalledTimes(2);
    expect(call.mock.calls[1][0]).toContain('原始提问');
    expect(call.mock.calls[1][0]).toContain('JSON');
  });

  it('超时错误后重试成功 → 共 2 次调用', async () => {
    const call = jest.fn()
      .mockRejectedValueOnce(new Error('AI 请求超时，请稍后重试'))
      .mockResolvedValueOnce('{"ok":true}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ ok: true });
    expect(call).toHaveBeenCalledTimes(2);
  });

  it('5xx 与空输出同样可重试', async () => {
    const call = jest.fn()
      .mockRejectedValueOnce(new Error('AI 上游错误（HTTP 503）'))
      .mockRejectedValueOnce(new Error('AI 服务返回内容为空'))
      .mockResolvedValueOnce('{"ok":true}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ ok: true });
    expect(call).toHaveBeenCalledTimes(3);
  });

  it('鉴权错误不重试 → 原样抛出且只调用 1 次', async () => {
    const call = jest.fn().mockRejectedValue(new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查'));
    await expect(runJsonChat(RT, call, 'u')).rejects.toThrow('认证失败');
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('用尽重试仍解析失败 → 抛 LlmJsonError 且含「已重试 2 次」', async () => {
    const call = jest.fn(async () => '始终不是 JSON');
    await expect(runJsonChat(RT, call, 'u')).rejects.toBeInstanceOf(LlmJsonError);
    await expect(runJsonChat(RT, call, 'u')).rejects.toThrow('已重试 2 次');
    expect(call).toHaveBeenCalledTimes(6); // 两轮 × 3 次
  });

  it('retryCount=0 → 不重试，仅 1 次调用', async () => {
    const call = jest.fn(async () => '不是 JSON');
    await expect(runJsonChat({ ...RT, retryCount: 0 }, call, 'u')).rejects.toBeInstanceOf(LlmJsonError);
    expect(call).toHaveBeenCalledTimes(1);
  });
});

describe('visionChatJsonMulti', () => {
  const VISION: LlmEndpoint = {
    provider: 'qwen',
    baseUrl: 'https://x.example/v1',
    apiKey: 'sk',
    model: 'qwen-vl-max',
  };
  const { visionChatMulti } = jest.requireMock('./llm-client') as { visionChatMulti: jest.Mock };

  beforeEach(() => visionChatMulti.mockClear());

  it('多张 images 一次性交给 visionChatMulti（jsonMode）并解析 JSON', async () => {
    const json = await visionChatJsonMulti(
      VISION,
      {
        systemPrompt: 's',
        userText: '请识别这些参考图',
        images: [
          { base64: 'aGk=', mime: 'image/jpeg' },
          { base64: 'aG8=', mime: 'image/png' },
        ],
      },
      RT,
    );

    expect(json).toEqual({ ok: true });
    expect(visionChatMulti).toHaveBeenCalledTimes(1);
    const [endpoint, input] = visionChatMulti.mock.calls[0];
    expect(endpoint).toEqual(VISION);
    expect(input).toMatchObject({
      systemPrompt: 's',
      images: [
        { base64: 'aGk=', mime: 'image/jpeg' },
        { base64: 'aG8=', mime: 'image/png' },
      ],
      jsonMode: true,
    });
  });

  it('输出不可解析 → 用尽重试后抛 LlmJsonError', async () => {
    visionChatMulti.mockResolvedValue('不是 JSON');
    await expect(
      visionChatJsonMulti(
        VISION,
        { systemPrompt: 's', userText: 'u', images: [{ base64: 'aGk=', mime: 'image/jpeg' }] },
        RT,
      ),
    ).rejects.toBeInstanceOf(LlmJsonError);
    expect(visionChatMulti).toHaveBeenCalledTimes(3); // 首轮 + 2 次重试
  });
});