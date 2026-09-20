// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-vendor.spec.ts
// T1 厂商联网检索适配器（Task 3，TDD）：mock textChat 返回 JSON 数组 → ResearchItem[]；
// 非法 JSON → [] 不抛；query 透传给 textChat userText

import { createVendorSearchProvider } from './web-search-vendor';
import { textChat } from '../llm-client';
import type { LlmEndpoint } from '../llm-client';

jest.mock('../llm-client', () => ({
  textChat: jest.fn(),
}));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const VENDOR_ENDPOINT: LlmEndpoint = {
  provider: 'doubao',
  baseUrl: 'https://x.example/v1',
  apiKey: 'sk',
  model: '联网检索模型',
};

beforeEach(() => {
  textChatMock.mockReset();
});

function legalJson(): string {
  return JSON.stringify([
    { source: 'vendor', title: '小红书秋日人像', snippet: '暖阳 毛衣 胶片', keywords: ['秋日'], imgUrl: 'https://img.example.com/a.jpg', date: '2026-09-01' },
    { source: 'vendor', title: '站酷创意', snippet: '克制的布光', keywords: ['布光'] },
  ]);
}

describe('createVendorSearchProvider', () => {
  it('合法 JSON 数组 → 解析成 ResearchItem[]（source=vendor，字段映射）', async () => {
    textChatMock.mockResolvedValueOnce(legalJson());
    const provider = createVendorSearchProvider(VENDOR_ENDPOINT);

    const items = await provider.search({ query: '秋日人像趋势', limit: 5 });

    expect(provider.name).toBe('vendor');
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({
      source: 'vendor',
      title: '小红书秋日人像',
      snippet: '暖阳 毛衣 胶片',
      imgUrl: 'https://img.example.com/a.jpg',
      date: '2026-09-01',
    });
    expect(Array.isArray(items[0].keywords)).toBe(true);
  });

  it('query 透传给 textChat 的 userText，且 jsonMode:true', async () => {
    textChatMock.mockResolvedValueOnce(legalJson());
    const provider = createVendorSearchProvider(VENDOR_ENDPOINT);

    await provider.search({ query: '秋冬穿搭', limit: 3 });

    expect(textChatMock).toHaveBeenCalledTimes(1);
    const [cfg, input] = textChatMock.mock.calls[0];
    expect(cfg).toEqual(VENDOR_ENDPOINT);
    expect(input.userText).toContain('秋冬穿搭');
    expect(input.jsonMode).toBe(true);
  });

  it('非法 JSON → 返回 [] 不抛', async () => {
    textChatMock.mockResolvedValueOnce('抱歉，我无法联网搜索。');
    const provider = createVendorSearchProvider(VENDOR_ENDPOINT);

    await expect(provider.search({ query: 'x' })).resolves.toEqual([]);
  });
});