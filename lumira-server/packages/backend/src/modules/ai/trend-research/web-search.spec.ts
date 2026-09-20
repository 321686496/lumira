// lumira-server/packages/backend/src/modules/ai/trend-research/web-search.spec.ts
// T1 网络搜索抽象 + bing 适配器 + LRU 缓存（Task 2，TDD）
// 覆盖：createWebSearchProvider 工厂 / 未知名称抛错 / bing 请求形状与解析 / 空结果 / 网络失败可读错误 /
// cacheableSearch 缓存命中不重复请求 / 失败抛错

import { createWebSearchProvider, cacheableSearch, WebSearchProvider, WebSearchQuery } from './web-search.provider';
import { ResearchItem } from './research-item';

/** bing 搜索结果响应（webPages.value[]） */
function bingOkResponse(arr: unknown[]): Response {
  return new Response(JSON.stringify({ webPages: { value: arr } }), { status: 200 });
}

function bingItem(name: string, url: string, snippet: string): Record<string, unknown> {
  return { id: url, name, url, snippet };
}

describe('createWebSearchProvider', () => {
  it('bing → 返回带 search 的对象且 name==="bing"', () => {
    const p = createWebSearchProvider('bing', { baseUrl: 'https://api.bing.microsoft.com', apiKey: 'k' });
    expect(p.name).toBe('bing');
    expect(typeof p.search).toBe('function');
  });

  it('未知名称 → 抛错', () => {
    expect(() => createWebSearchProvider('douyin', {})).toThrow();
  });
});

describe('bing 适配器', () => {
  let provider: WebSearchProvider;
  beforeEach(() => {
    provider = createWebSearchProvider('bing', { baseUrl: 'https://api.bing.microsoft.com', apiKey: 'sk-bing' });
  });

  it('请求：GET {baseUrl}/v7.0/search？q=...&count=...，Authorization Bearer key', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(bingOkResponse([]));

    await provider.search({ query: '秋日人像', limit: 5 });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toContain('/v7.0/search');
    expect(String(url)).toContain('q=%E7%A7%8B%E6%97%A5%E4%BA%BA%E5%83%8F');
    expect(String(url)).toContain('count=5');
    expect((init as RequestInit).headers).toEqual({ Authorization: 'Bearer sk-bing' });
  });

  it('空结果 → 返回 []', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(bingOkResponse([]));
    await expect(provider.search({ query: 'x' })).resolves.toEqual([]);
  });

  it('解析 webPages.value[] → ResearchItem[]（source=bing，keywords 由 snippet 分词）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(
      bingOkResponse([
        bingItem('秋日少女写真', 'https://example.com/a', '秋日光影 温柔 少女'),
        bingItem('胶片感人像', 'https://example.com/b', '胶片 复古 质感'),
      ]),
    );

    const items = await provider.search({ query: '人像', limit: 10 });
    expect(items).toHaveLength(2);
    const first = items[0];
    expect(first.source).toBe('bing');
    expect(first.title).toBe('秋日少女写真');
    expect(first.url).toBe('https://example.com/a');
    expect(first.snippet).toBe('秋日光影 温柔 少女');
    expect(Array.isArray(first.keywords)).toBe(true);
    expect(first.keywords).toContain('秋日光影');
    // 尺寸字段
    expect((items[0] as ResearchItem).title).toBeTruthy();
  });

  it('网络失败 → 抛可读错误（含 baseUrl 连接提示）', async () => {
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('connect ECONNREFUSED'));
    await expect(provider.search({ query: 'x' })).rejects.toThrow();
  });
});

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