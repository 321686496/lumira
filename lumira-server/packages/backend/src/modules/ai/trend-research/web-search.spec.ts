// lumira-server/packages/backend/src/modules/ai/trend-research/web-search.spec.ts
// 覆盖：createWebSearchProvider 工厂 / 未知名称抛错 / searxng 请求形状与解析 / site 拼接 / apiKey 可选 /
// 空结果 / 网络失败与 HTTP 错误可读信息 / cacheableSearch 缓存命中不重复请求 / 失败抛错

import { createWebSearchProvider, cacheableSearch, WebSearchProvider, WebSearchQuery } from './web-search.provider';

// 每个用例独立 spy global.fetch：restore 防止跨用例 mock 状态与调用记录累积
afterEach(() => {
  jest.restoreAllMocks();
});

/** searxng 搜索结果响应（results[]） */
function searxngOkResponse(arr: unknown[]): Response {
  return new Response(JSON.stringify({ results: arr }), { status: 200 });
}

function searxngItem(title: string, url: string, content: string): Record<string, unknown> {
  return { title, url, content };
}

describe('createWebSearchProvider', () => {
  it('searxng → 返回带 search 的对象且 name==="searxng"', () => {
    const p = createWebSearchProvider('searxng', { baseUrl: 'http://lumira-searxng:8080' });
    expect(p.name).toBe('searxng');
    expect(typeof p.search).toBe('function');
  });

  it('未知名称 → 抛错', () => {
    expect(() => createWebSearchProvider('douyin', {})).toThrow();
  });
});

describe('searxng 适配器', () => {
  let provider: WebSearchProvider;
  beforeEach(() => {
    provider = createWebSearchProvider('searxng', { baseUrl: 'http://lumira-searxng:8080' });
  });

  it('请求：GET {baseUrl}/search？q=...&format=json，无鉴权头', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(searxngOkResponse([]));

    await provider.search({ query: '秋日人像', limit: 5 });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toContain('/search?');
    expect(String(url)).toContain('q=%E7%A7%8B%E6%97%A5%E4%BA%BA%E5%83%8F');
    expect(String(url)).toContain('format=json');
    expect((init as RequestInit).headers).toEqual({});
  });

  it('配置 site → 查询拼 site: 前缀', async () => {
    const p = createWebSearchProvider('searxng', { baseUrl: 'http://lumira-searxng:8080', site: 'xiaohongshu.com' });
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(searxngOkResponse([]));

    await p.search({ query: '秋季写真', limit: 10 });

    const [url] = fetchMock.mock.calls[0];
    expect(String(url)).toContain('q=site%3Axiaohongshu.com+%E7%A7%8B%E5%AD%A3%E5%86%99%E7%9C%9F');
  });

  it('apiKey 可选 → 配置时带 Authorization 头', async () => {
    const p = createWebSearchProvider('searxng', { baseUrl: 'http://lumira-searxng:8080', apiKey: 'tok' });
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(searxngOkResponse([]));

    await p.search({ query: 'x' });

    expect((fetchMock.mock.calls[0][1] as RequestInit).headers).toEqual({ Authorization: 'Bearer tok' });
  });

  it('空结果 → 返回 []', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(searxngOkResponse([]));
    await expect(provider.search({ query: 'x' })).resolves.toEqual([]);
  });

  it('解析 results[] → ResearchItem[]（source=searxng，keywords 由 content 分词）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(
      searxngOkResponse([
        searxngItem('秋日少女写真', 'https://example.com/a', '秋日光影 温柔 少女'),
        searxngItem('胶片感人像', 'https://example.com/b', '胶片 复古 质感'),
      ]),
    );

    const items = await provider.search({ query: '人像', limit: 10 });
    expect(items).toHaveLength(2);
    const first = items[0];
    expect(first.source).toBe('searxng');
    expect(first.title).toBe('秋日少女写真');
    expect(first.url).toBe('https://example.com/a');
    expect(first.snippet).toBe('秋日光影 温柔 少女');
    expect(first.keywords).toContain('秋日光影');
  });

  it('网络失败 → 抛可读错误', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('connect ECONNREFUSED'));
    await expect(provider.search({ query: 'x' })).rejects.toThrow();
  });

  it('HTTP 非 200 → 抛可读错误（含状态码）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 500 }));
    await expect(provider.search({ query: 'x' })).rejects.toThrow('HTTP 500');
  });
});

// —— 以下 cacheableSearch describe 原样保留（不含 bing 引用）——
describe('cacheableSearch', () => {
  /** 带调用计数的注入 provider */
  function countingProvider(): WebSearchProvider & { count: () => number } {
    let n = 0;
    return {
      name: 'mock',
      search: async (q: WebSearchQuery) => {
        n += 1;
        return [{ source: 'mock', title: q.query, snippet: '', keywords: [] }];
      },
      count: () => n,
    };
  }

  it('缓存命中 → 同 key 不重复请求（相同 name|query|limit）', async () => {
    const p = countingProvider();
    const q = { query: '秋日', limit: 3 };

    await cacheableSearch(p, q);
    await cacheableSearch(p, q);
    await cacheableSearch(p, q);

    expect(p.count()).toBe(1);
  });

  it('不同 query → 重新请求（LRU key 变化）', async () => {
    const p = countingProvider();
    await cacheableSearch(p, { query: 'A', limit: 3 });
    await cacheableSearch(p, { query: 'B', limit: 3 });
    expect(p.count()).toBe(2);
  });

  it('provider 失败 → 抛错', async () => {
    const p: WebSearchProvider = {
      name: 'bad',
      search: async () => {
        throw new Error('搜索服务不可用');
      },
    };
    await expect(cacheableSearch(p, { query: 'x' })).rejects.toThrow('搜索服务不可用');
  });
});
