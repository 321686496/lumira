// web-search-qwen-official.spec.ts
import { createQwenOfficialSearchProvider } from './web-search-qwen-official';
import type { WebSearchProvider } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { runWithTrace } from '../llm-trace';
import type { AiTraceEvent } from '../llm-trace';

/** DashScope 原生生成端点（由配置的 compatible-mode base 派生） */
const DASHSCOPE_URL = 'https://ws.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/text-generation/generation';

/** 官方百炼 DashScope 原生：output.search_info.search_results[]（content 为空，不产生综述条目） */
const OK_SEARCH_INFO = {
  output: {
    choices: [{ message: { role: 'assistant', content: '' } }],
    search_info: {
      search_results: [
        { index: 1, title: '秋日少女写真', url: 'https://a.example', site_name: 'a.example' },
        { index: 2, title: '胶片感人像', url: '', site_name: 'b.example' }, // url 为空 → 回退 site_name
      ],
    },
  },
};

/** 官方百炼：既有 search_info.search_results[] 又有正文综述（真实联网场景） */
const OK_SEARCH_INFO_WITH_CONTENT = {
  output: {
    choices: [{ message: { role: 'assistant', content: '这是带来源链接的正文综述（https://a.example）。' } }],
    search_info: {
      search_results: [
        { index: 1, title: '秋日少女写真', url: 'https://a.example', site_name: 'a.example' },
        { index: 2, title: '胶片感人像', url: '', site_name: 'b.example' },
      ],
    },
  },
};

describe('web-search-qwen-official', () => {
  let provider: WebSearchProvider;
  beforeEach(() => {
    provider = createQwenOfficialSearchProvider({
      baseUrl: 'https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
      apiKey: 'sk-official',
      model: 'qwen-plus',
    });
  });

  it('provider.name = qwen-official（与三方 MaaS 的 qwen 区分，缓存 key 不冲突）', () => {
    expect(provider.name).toBe('qwen-official');
  });

  it('走 DashScope 原生生成端点（兼容模式不返回来源），请求体按 input/parameters 组织', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_SEARCH_INFO), { status: 200 }));
    const items = await provider.search({ query: '人像', limit: 10 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toBe(DASHSCOPE_URL);
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.model).toBe('qwen-plus');
    expect((body.input as { messages: { role: string }[] }).messages.map((m) => m.role)).toEqual(['system', 'user']);
    expect(body.parameters).toMatchObject({
      enable_search: true,
      search_options: { forced_search: true, enable_source: true },
      result_format: 'message',
      temperature: 0.3,
      max_tokens: 4096,
    });
    expect((init as RequestInit).headers).toMatchObject({ Authorization: 'Bearer sk-official' });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ source: 'qwen-official', title: '秋日少女写真', url: 'https://a.example' });
    expect(items[1]).toMatchObject({ source: 'qwen-official', title: '胶片感人像', url: 'b.example' });
    expect(Array.isArray(items[0].keywords)).toBe(true);
  });

  it('base 已含 /api/v1 或为域名根时，同样派生出正确的 DashScope 端点', async () => {
    for (const baseUrl of ['https://ws.cn-beijing.maas.aliyuncs.com', 'https://ws.cn-beijing.maas.aliyuncs.com/api/v1']) {
      const p = createQwenOfficialSearchProvider({ baseUrl, apiKey: 'k', model: 'qwen-plus' });
      const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_SEARCH_INFO), { status: 200 }));
      await p.search({ query: '人像', limit: 10 });
      expect(String(fetchMock.mock.calls[0][0])).toBe(DASHSCOPE_URL);
      fetchMock.mockRestore();
    }
  });

  it('既有 search_info 又有正文 → 「联网综述」置首，其后为带 url 的引用条目（顺序稳定）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_SEARCH_INFO_WITH_CONTENT), { status: 200 }));
    const items = await provider.search({ query: '人像', limit: 10 });
    expect(items).toHaveLength(3);
    // 首条：正文综述（keywords 留空，无 url）
    expect(items[0]).toMatchObject({
      source: 'qwen-official',
      title: '联网综述',
      snippet: '这是带来源链接的正文综述（https://a.example）。',
    });
    expect(items[0].url).toBeUndefined();
    expect(items[0].keywords).toEqual([]);
    // 其后：search_info 引用按原顺序
    expect(items[1]).toMatchObject({ source: 'qwen-official', title: '秋日少女写真', url: 'https://a.example' });
    expect(items[2]).toMatchObject({ source: 'qwen-official', title: '胶片感人像', url: 'b.example' });
  });

  it('search_info 为空但正文有实质内容 → 「联网综述」兜底（source=qwen-official，keywords 为空）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({
      output: { choices: [{ message: { role: 'assistant', content: '根据检索到的公开资料：中秋为 9/25，国庆为 10/1。' } }] },
    }), { status: 200 }));
    const items = await provider.search({ query: '最近节日', limit: 10 });
    expect(items).toHaveLength(1);
    expect(items[0]).toMatchObject({
      source: 'qwen-official',
      title: '联网综述',
      snippet: '根据检索到的公开资料：中秋为 9/25，国庆为 10/1。',
    });
    expect(items[0].keywords).toEqual([]);
  });

  it('search_info 与正文皆空 → 抛「未取到引用」错误（绝不编造 URL）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ output: { choices: [{ message: { content: '   ' } }] } }), { status: 200 }));
    await expect(provider.search({ query: '冷门', limit: 10 })).rejects.toThrow('未取到引用');
  });

  it('上游 HTTP 非 2xx → 抛可读错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 429 }));
    await expect(provider.search({ query: 'x', limit: 10 })).rejects.toThrow(/HTTP 429/);
  });

  it('缺 baseUrl → 抛可读错误', async () => {
    const p = createQwenOfficialSearchProvider({ apiKey: 'k' });
    await expect(p.search({ query: 'x' })).rejects.toThrow('baseUrl');
  });

  it('缺 API Key → 抛可读错误', async () => {
    const p = createQwenOfficialSearchProvider({ baseUrl: 'https://o.example/v1' });
    await expect(p.search({ query: 'x' })).rejects.toThrow('API Key');
  });

  it('系统提示词注入当天日期与「禁止凭记忆猜节日 / 结论须带来源链接」硬性要求', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_SEARCH_INFO), { status: 200 }));
    await provider.search({ query: '最近的节日 摄影模板', limit: 10 });
    const [, init] = fetchMock.mock.calls[0];
    const body = JSON.parse(String((init as RequestInit).body));
    const messages = (body.input as { messages: { role: string; content: string }[] }).messages;
    const sys = messages.find((m) => m.role === 'system')!.content;
    expect(sys).toContain(describeTodayUtc8());
    expect(sys).toContain('严禁凭训练记忆猜测节日名称或日期');
    expect(sys).toContain('来源链接');
  });

  it('采集上下文内：记录提示词与上游原始响应体；无上下文时照常返回', async () => {
    const raw = JSON.stringify(OK_SEARCH_INFO);
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(raw, { status: 200 }));
    const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];

    const items = await runWithTrace((e) => events.push(e), () => provider.search({ query: '人像', limit: 10 }));

    expect(items).toHaveLength(2);
    const llm = events.filter((e) => e.type === 'llm');
    expect(llm).toHaveLength(2);
    expect(llm[0]).toMatchObject({ status: 'running', model: 'qwen-plus', userPrompt: '人像' });
    expect(llm[0]!.systemPrompt).toContain('摄影');
    expect(llm[1]!.rawResponse).toBe(raw);
    expect(llm[1]!.resultBrief).toBe('2 条');
  });

  it('采集上下文内：上游报错时记录 fail 事件', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('boom', { status: 500 }));
    const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];

    await expect(
      runWithTrace((e) => events.push(e), () => provider.search({ query: '人像', limit: 10 })),
    ).rejects.toThrow('HTTP 500');

    const fail = events.find((e) => e.type === 'llm' && e.status === 'fail')!;
    expect(fail.error).toContain('HTTP 500');
  });
});
