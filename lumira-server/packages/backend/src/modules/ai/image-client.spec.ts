// lumira-server/packages/backend/src/modules/ai/image-client.spec.ts
// per-provider 生图客户端单测（Task 7，TDD）
// 按厂商分组：doubao/zhipu/openai 同步 /images/generations（openai 有参考图走 /images/edits FormData），
// qwen wanx 异步任务轮询（注入小 pollIntervalMs/pollTimeoutMs，不依赖真实 2s 计时）。
// mapSize 覆盖四厂商 + 未知 ratio/provider 兜底。

import { GenerateImageInput, GenerateImageOptions, generateImage, mapSize } from './image-client';
import { ActiveAiConfig } from './ai-config.service';

/** 各用例覆盖 provider；baseUrl 故意带尾斜杠：验证拼接前先规范化去掉 */
function cfg(provider: string, baseUrl: string): ActiveAiConfig {
  return { provider, baseUrl, apiKey: 'sk-test-key', visionModel: 'vision-model', imageModel: 'image-model', textModel: 'vision-model', hasCustomTextModel: false };
}

function input(overrides: Partial<GenerateImageInput> = {}): GenerateImageInput {
  return { prompt: '一张 3:4 竖构图的人像摄影作品', size: '864x1152', ...overrides };
}

/** 快速轮询参数（qwen 用例注入，避免真实 2s 间隔 / 60s 上限） */
const FAST_POLL: GenerateImageOptions = { pollIntervalMs: 5, pollTimeoutMs: 200 };

/** JSON 成功响应 */
function okResponse(body: unknown, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status: 200, headers });
}

/** 上游错误响应 */
function errorResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status });
}

/** 图片下载响应（url 兜底路径用） */
const PNG_BYTES = Buffer.from('fake-png-bytes');
const PNG_B64 = PNG_BYTES.toString('base64');
function imageDownloadResponse(mime = 'image/png'): Response {
  return new Response(PNG_BYTES, { status: 200, headers: { 'content-type': mime } });
}

/** 取出某次 fetch 调用的请求 body 并 JSON.parse */
function parseBody(init: unknown): Record<string, any> {
  return JSON.parse(String((init as RequestInit | undefined)?.body));
}

/** 断言「必定 reject」并捕获错误对象（避免重复调用导致 Response body 只能读一次） */
async function expectReject<T>(promise: Promise<T>): Promise<Error> {
  return promise.then(
    () => new Error('不应成功'),
    (e: Error) => e,
  );
}

afterEach(() => {
  jest.restoreAllMocks();
});

describe('generateImage', () => {
  describe('doubao（同步 /images/generations，支持参考图）', () => {
    it('文生图：POST {baseUrl}/images/generations，body {model,prompt,size}（无 image 字段）→ data[0].b64_json', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: 'aGVsbG8=' }] }));

      const res = await generateImage(cfg('doubao', 'https://ark.example.com/api/v3/'), input());

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [url, init] = fetchMock.mock.calls[0];
      expect(String(url)).toBe('https://ark.example.com/api/v3/images/generations');
      expect(init?.method).toBe('POST');
      expect(init?.headers).toEqual({
        'Content-Type': 'application/json',
        Authorization: 'Bearer sk-test-key',
      });

      const body = parseBody(init);
      expect(body.model).toBe('image-model');
      expect(body.prompt).toBe('一张 3:4 竖构图的人像摄影作品');
      expect(body.size).toBe('864x1152');
      expect(body.image).toBeUndefined();
      expect(res).toEqual({ base64: 'aGVsbG8=', mimeType: 'image/png' });
    });

    it('图生图：有 referenceBase64 → body.image 为 data URL', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: 'aGVsbG8=' }] }));

      await generateImage(
        cfg('doubao', 'https://ark.example.com/api/v3'),
        input({ referenceBase64: 'cmVmLWJ5dGVz', referenceMime: 'image/jpeg' }),
      );

      const body = parseBody(fetchMock.mock.calls[0][1]);
      expect(body.image).toBe('data:image/jpeg;base64,cmVmLWJ5dGVz');
    });

    it('返回 url 而非 b64_json → fetch 该 url 下载转 base64（content-type 作 mimeType）', async () => {
      const fetchMock = jest
        .spyOn(global, 'fetch')
        .mockResolvedValueOnce(okResponse({ data: [{ url: 'https://cdn.example.com/img.png' }] }))
        .mockResolvedValueOnce(imageDownloadResponse());

      const res = await generateImage(cfg('doubao', 'https://ark.example.com/api/v3'), input());

      expect(fetchMock).toHaveBeenCalledTimes(2);
      expect(String(fetchMock.mock.calls[1][0])).toBe('https://cdn.example.com/img.png');
      expect(res).toEqual({ base64: PNG_B64, mimeType: 'image/png' });
    });

    it('data[0] 缺失 / b64_json 与 url 均空 → 抛生图服务返回内容为空', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: '', url: '' }] }));

      await expect(generateImage(cfg('doubao', 'https://ark.example.com/api/v3'), input()))
        .rejects.toThrow('生图服务返回内容为空');
    });
  });

  describe('zhipu（同步 /images/generations，纯文生图忽略参考图）', () => {
    it('body {model,prompt,size}，即使传参考图也不带 image 字段 → data[0].b64_json', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: 'emhpcHU=' }] }));

      const res = await generateImage(
        cfg('zhipu', 'https://open.bigmodel.example.com/api/paas/v4'),
        input({ referenceBase64: 'cmVmLWJ5dGVz', referenceMime: 'image/jpeg' }),
      );

      const [url, init] = fetchMock.mock.calls[0];
      expect(String(url)).toBe('https://open.bigmodel.example.com/api/paas/v4/images/generations');
      const body = parseBody(init);
      expect(body).toEqual({
        model: 'image-model',
        prompt: '一张 3:4 竖构图的人像摄影作品',
        size: '864x1152',
      });
      expect(body.image).toBeUndefined();
      expect(res).toEqual({ base64: 'emhpcHU=', mimeType: 'image/png' });
    });

    it('b64_json 缺失时 url 兜底下载', async () => {
      jest
        .spyOn(global, 'fetch')
        .mockResolvedValueOnce(okResponse({ data: [{ url: 'https://cdn.example.com/zhipu.png' }] }))
        .mockResolvedValueOnce(imageDownloadResponse());

      const res = await generateImage(cfg('zhipu', 'https://open.bigmodel.example.com/api/paas/v4'), input());

      expect(res).toEqual({ base64: PNG_B64, mimeType: 'image/png' });
    });
  });

  describe('openai（无参考图 /images/generations；有参考图 /images/edits FormData）', () => {
    it('无参考图 → POST /images/generations，body 含 response_format:b64_json', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: 'b3BlbmFp' }] }));

      const res = await generateImage(cfg('openai', 'https://api.openai.example.com/v1'), input({ size: '1024x1536' }));

      const [url, init] = fetchMock.mock.calls[0];
      expect(String(url)).toBe('https://api.openai.example.com/v1/images/generations');
      const body = parseBody(init);
      expect(body.model).toBe('image-model');
      expect(body.prompt).toBe('一张 3:4 竖构图的人像摄影作品');
      expect(body.size).toBe('1024x1536');
      expect(body.response_format).toBe('b64_json');
      expect(res).toEqual({ base64: 'b3BlbmFp', mimeType: 'image/png' });
    });

    it('有参考图 → POST /images/edits，FormData 含 image Blob + prompt + model + size', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ data: [{ b64_json: 'ZWRpdHM=' }] }));

      const res = await generateImage(
        cfg('openai', 'https://api.openai.example.com/v1'),
        input({
          size: '1024x1536',
          referenceBase64: 'cmVmLWJ5dGVz',
          referenceMime: 'image/jpeg',
        }),
      );

      const [url, init] = fetchMock.mock.calls[0];
      expect(String(url)).toBe('https://api.openai.example.com/v1/images/edits');
      expect(init?.method).toBe('POST');
      // FormData 由 undici 自动带 multipart Content-Type（含 boundary），只手动传鉴权头
      expect(init?.headers).toEqual({ Authorization: 'Bearer sk-test-key' });
      expect(init?.body).toBeInstanceOf(FormData);

      const fd = init?.body as FormData;
      expect(fd.get('prompt')).toBe('一张 3:4 竖构图的人像摄影作品');
      expect(fd.get('model')).toBe('image-model');
      expect(fd.get('size')).toBe('1024x1536');
      const imagePart = fd.get('image');
      expect(imagePart).toBeInstanceOf(Blob);
      expect((imagePart as Blob).type).toBe('image/jpeg');
      expect(Buffer.from(await (imagePart as Blob).arrayBuffer()).toString('base64')).toBe('cmVmLWJ5dGVz');

      expect(res).toEqual({ base64: 'ZWRpdHM=', mimeType: 'image/png' });
    });
  });

  describe('qwen（wanx 异步任务轮询）', () => {
    const ORIGIN = 'https://dashscope.example.com';
    const SUBMIT_URL = `${ORIGIN}/api/v1/services/aigc/text2image/image-synthesis`;

    it('提交任务 → 轮询 → SUCCEEDED → 下载 results[0].url 转 base64；提交请求形状正确', async () => {
      const calls: string[] = [];
      const fetchMock = jest.spyOn(global, 'fetch').mockImplementation(async (url: any) => {
        const u = String(url);
        calls.push(u);
        if (u === SUBMIT_URL) return okResponse({ output: { task_id: 'task-abc' } });
        if (u === `${ORIGIN}/api/v1/tasks/task-abc`) {
          return okResponse({ output: { task_status: 'SUCCEEDED', results: [{ url: `${ORIGIN}/result.png` }] } });
        }
        if (u === `${ORIGIN}/result.png`) return imageDownloadResponse();
        throw new Error('unexpected url: ' + u);
      });

      const res = await generateImage(
        cfg('qwen', `${ORIGIN}/compatible-mode/v1`),
        input({ size: '720*1280' }),
        FAST_POLL,
      );

      // 调用序列：提交 → 查询任务 → 下载结果
      expect(calls).toEqual([SUBMIT_URL, `${ORIGIN}/api/v1/tasks/task-abc`, `${ORIGIN}/result.png`]);

      // 提交请求形状：origin 从 baseUrl 去掉路径得到
      const [submitUrl, submitInit] = fetchMock.mock.calls[0];
      expect(String(submitUrl)).toBe(SUBMIT_URL);
      expect(submitInit?.method).toBe('POST');
      expect(submitInit?.headers).toEqual({
        'Content-Type': 'application/json',
        Authorization: 'Bearer sk-test-key',
        'X-DashScope-Async': 'enable',
      });
      const body = parseBody(submitInit);
      expect(body.model).toBe('image-model');
      expect(body.input).toEqual({ prompt: '一张 3:4 竖构图的人像摄影作品' });
      expect(body.parameters).toEqual({ size: '720*1280', n: 1 });

      // 任务查询带 Bearer
      const pollInit = fetchMock.mock.calls[1][1];
      expect(pollInit?.headers).toEqual({ Authorization: 'Bearer sk-test-key' });

      expect(res).toEqual({ base64: PNG_B64, mimeType: 'image/png' });
    });

    it('轮询：PENDING → RUNNING → SUCCEEDED（多次查询后成功）', async () => {
      let pollCount = 0;
      jest.spyOn(global, 'fetch').mockImplementation(async (url: any) => {
        const u = String(url);
        if (u === SUBMIT_URL) return okResponse({ output: { task_id: 'task-abc' } });
        if (u === `${ORIGIN}/api/v1/tasks/task-abc`) {
          pollCount += 1;
          const status = pollCount <= 2 ? (pollCount === 1 ? 'PENDING' : 'RUNNING') : 'SUCCEEDED';
          return okResponse({
            output:
              status === 'SUCCEEDED'
                ? { task_status: status, results: [{ url: `${ORIGIN}/result.png` }] }
                : { task_status: status },
          });
        }
        if (u === `${ORIGIN}/result.png`) return imageDownloadResponse();
        throw new Error('unexpected url: ' + u);
      });

      const res = await generateImage(cfg('qwen', `${ORIGIN}/compatible-mode/v1`), input({ size: '1024*1024' }), FAST_POLL);

      expect(pollCount).toBe(3);
      expect(res.base64).toBe(PNG_B64);
    });

    it('任务一直未完成 → 到达 pollTimeoutMs 抛「生图任务超时」', async () => {
      jest.spyOn(global, 'fetch').mockImplementation(async (url: any) => {
        const u = String(url);
        if (u === SUBMIT_URL) return okResponse({ output: { task_id: 'task-abc' } });
        if (u === `${ORIGIN}/api/v1/tasks/task-abc`) return okResponse({ output: { task_status: 'PENDING' } });
        throw new Error('unexpected url: ' + u);
      });

      const t0 = Date.now();
      const err = await expectReject(generateImage(cfg('qwen', `${ORIGIN}/compatible-mode/v1`), input(), FAST_POLL));
      expect(err.message).toBe('生图任务超时');
      expect(Date.now() - t0).toBeLessThan(5000); // 不依赖真实 60s 计时
    });

    it('任务 FAILED → 抛生图任务失败（含状态）', async () => {
      jest.spyOn(global, 'fetch').mockImplementation(async (url: any) => {
        const u = String(url);
        if (u === SUBMIT_URL) return okResponse({ output: { task_id: 'task-abc' } });
        if (u === `${ORIGIN}/api/v1/tasks/task-abc`) {
          return okResponse({ output: { task_status: 'FAILED', message: 'internal error' } });
        }
        throw new Error('unexpected url: ' + u);
      });

      await expect(generateImage(cfg('qwen', `${ORIGIN}/compatible-mode/v1`), input(), FAST_POLL))
        .rejects.toThrow('生图任务失败（FAILED）');
    });

    it('提交响应缺 task_id → 抛生图服务未返回任务 ID', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({ output: {} }));

      await expect(generateImage(cfg('qwen', `${ORIGIN}/compatible-mode/v1`), input(), FAST_POLL))
        .rejects.toThrow('生图服务未返回任务 ID');
    });
  });

  describe('通用错误处理（同 llm-client 风格）', () => {
    it('401 → 抛 apiKey 无效或无权限、指向 AI 设置的运营可读错误', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(401, { error: { message: 'invalid api key' } }));

      const err = await expectReject(generateImage(cfg('doubao', 'https://ark.example.com/api/v3'), input()));
      expect(err.message).toContain('apiKey 无效或无权限');
      expect(err.message).toContain('AI 设置');
    });

    it('403 → 同 401 抛认证失败错误', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(403, {}));

      await expect(generateImage(cfg('zhipu', 'https://open.bigmodel.example.com/api/paas/v4'), input()))
        .rejects.toThrow('apiKey 无效或无权限');
    });

    it('上游 500 + body {error:{message}} → 错误透传上游 message 并拼接 status', async () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(errorResponse(500, { error: { message: '上游内部错误' } }));

      const err = await expectReject(generateImage(cfg('doubao', 'https://ark.example.com/api/v3'), input()));
      expect(err.message).toContain('上游内部错误');
      expect(err.message).toContain('500');
    });

    it('单请求超时（never-resolving fetch + requestTimeoutMs:10）→ 抛含「超时」的错误', async () => {
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

      await expect(
        generateImage(cfg('doubao', 'https://ark.example.com/api/v3'), input(), { requestTimeoutMs: 10 }),
      ).rejects.toThrow('超时');
    });

    it('网络层错误（连接拒绝）→ 抛 AI 服务无法连接', async () => {
      jest.spyOn(global, 'fetch').mockRejectedValue(new Error('connect ECONNREFUSED 1.2.3.4:443'));

      await expect(generateImage(cfg('openai', 'https://api.openai.example.com/v1'), input()))
        .rejects.toThrow('无法连接');
    });

    it('未知 provider → 抛不支持的厂商错误，不发请求', async () => {
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(okResponse({}));

      await expect(generateImage(cfg('bogus', 'https://x.example.com'), input())).rejects.toThrow('不支持');
      expect(fetchMock).not.toHaveBeenCalled();
    });
  });
});

describe('mapSize', () => {
  it('doubao：Seedream 支持尺寸（x 分隔）', () => {
    expect(mapSize('doubao', '3:4')).toBe('864x1152');
    expect(mapSize('doubao', '1:1')).toBe('1024x1024');
    expect(mapSize('doubao', '9:16')).toBe('720x1440');
    expect(mapSize('doubao', '4:3')).toBe('1152x864');
    expect(mapSize('doubao', '16:9')).toBe('1440x720');
  });

  it('zhipu：CogView 支持尺寸（x 分隔）', () => {
    expect(mapSize('zhipu', '3:4')).toBe('864x1152');
    expect(mapSize('zhipu', '9:16')).toBe('768x1344');
    expect(mapSize('zhipu', '4:3')).toBe('1152x864');
    expect(mapSize('zhipu', '16:9')).toBe('1344x768');
    expect(mapSize('zhipu', '1:1')).toBe('1024x1024');
  });

  it('openai：gpt-image 系列尺寸（x 分隔）', () => {
    expect(mapSize('openai', '3:4')).toBe('1024x1536');
    expect(mapSize('openai', '9:16')).toBe('1024x1536');
    expect(mapSize('openai', '16:9')).toBe('1536x1024');
    expect(mapSize('openai', '4:3')).toBe('1536x1024');
    expect(mapSize('openai', '1:1')).toBe('1024x1024');
  });

  it('qwen：wanx 支持尺寸（* 分隔）', () => {
    expect(mapSize('qwen', '3:4')).toBe('720*1280');
    expect(mapSize('qwen', '1:1')).toBe('1024*1024');
    expect(mapSize('qwen', '9:16')).toBe('720*1280');
    expect(mapSize('qwen', '4:3')).toBe('1280*720');
    expect(mapSize('qwen', '16:9')).toBe('1280*720');
  });

  it('未知 ratio（含 undefined/空串）→ 兜底 1:1 尺寸', () => {
    expect(mapSize('doubao', '21:9')).toBe('1024x1024');
    expect(mapSize('zhipu', undefined)).toBe('1024x1024');
    expect(mapSize('qwen', undefined)).toBe('1024*1024');
    expect(mapSize('openai', 'bogus')).toBe('1024x1024');
  });

  it('未知 provider → 兜底 1024x1024', () => {
    expect(mapSize('bogus', '3:4')).toBe('1024x1024');
    expect(mapSize('bogus', undefined)).toBe('1024x1024');
  });
});
