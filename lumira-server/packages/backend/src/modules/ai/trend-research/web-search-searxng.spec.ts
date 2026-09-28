// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.spec.ts
// 覆盖：categories 透传（图片搜索）+ 结果条目图片字段映射（img_src → thumbnail_src）

import { createSearxngSearchProvider } from './web-search-searxng';

describe('图片字段与 categories', () => {
  it('透传 categories=images 并映射 img_src → imgUrl', async () => {
    const calls: string[] = [];
    const originalFetch = global.fetch;
    global.fetch = (async (url: string) => {
      calls.push(String(url));
      return {
        ok: true,
        json: async () => ({ results: [{ title: 't', url: 'https://a.com/p', content: 'c', img_src: 'https://img.com/1.jpg' }] }),
      } as unknown as Response;
    }) as typeof fetch;
    try {
      const p = createSearxngSearchProvider({ baseUrl: 'http://x:8080' });
      const items = await p.search({ query: '旗袍', categories: 'images' });
      expect(calls[0]).toContain('categories=images');
      expect(items[0].imgUrl).toBe('https://img.com/1.jpg');
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('无 img_src 时回退 thumbnail_src', async () => {
    const originalFetch = global.fetch;
    global.fetch = (async () => ({
      ok: true,
      json: async () => ({ results: [{ title: 't', url: 'https://a.com/p', content: 'c', thumbnail_src: 'https://img.com/t.jpg' }] }),
    } as unknown as Response)) as typeof fetch;
    try {
      const p = createSearxngSearchProvider({ baseUrl: 'http://x:8080' });
      const items = await p.search({ query: '旗袍' });
      expect(items[0].imgUrl).toBe('https://img.com/t.jpg');
    } finally {
      global.fetch = originalFetch;
    }
  });
});
