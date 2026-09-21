// lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.spec.ts
// T1 trend-research 服务编排（Task 4，TDD）：来源并行 + allSettled 降级、source+title 去重、研究关闭返回 []

import { TrendResearchService } from './trend-research.service';
import type { SearchProviderFactory } from './trend-research.service';
import { AiConfigService } from '../ai-config.service';
import { clearWebSearchCache } from './web-search.provider';
import type { ResearchItem } from './research-item';

function item(source: string, title: string, extra: Partial<ResearchItem> = {}): ResearchItem {
  return { source, title, snippet: '', keywords: [], ...extra };
}

/** 注入型 aiConfig + 工厂辅助 */
function build(factory: SearchProviderFactory, searchConfig: unknown) {
  const aiConfig = { getSearchConfig: async () => searchConfig } as unknown as AiConfigService;
  const svc = new TrendResearchService(aiConfig);
  svc.factory = factory;
  return svc;
}

beforeEach(() => {
  clearWebSearchCache();
});

describe('TrendResearchService', () => {
  it('一个来源失败一个成功 → 返回成功来源结果，不含失败项，且在 sourceErrors 记录失败原因', async () => {
    const searchConfig = {
      enabled: true,
      sources: [
        { name: 'bing', provider: 'bing' },
        { name: 'vendor', provider: 'vendor' },
      ],
    };

    // bing 成功、vendor 失败
    const providerFactory: SearchProviderFactory = (name: string) =>
      name === 'bing'
        ? { name: 'bing', search: async () => [item('bing', '秋日少女')] }
        : { name: 'vendor', search: async () => { throw new Error('vendor 不可用'); } };

    const svc = build(providerFactory, searchConfig);
    const res = await svc.research('秋日人像');
    const items = res.items;

    expect(items.map((i) => i.source)).toContain('bing');
    expect(items.map((i) => i.source)).not.toContain('vendor');
    expect(items).toHaveLength(1);
    expect(res.sourceErrors).toEqual([{ name: 'vendor', error: 'vendor 不可用' }]);
  });

  it('重复标题去重（保留先出现者，key=source+title）', async () => {
    const searchConfig = {
      enabled: true,
      sources: [
        { name: 'bing', provider: 'bing' },
        { name: 'vendor', provider: 'vendor' },
      ],
    };
    // 两来源均返回 (bing, 热门) 与 (vendor, 独立源)，其中 bing 源内出现重复标题
    const providerFactory: SearchProviderFactory = (name: string) => ({
      name,
      search: async () =>
        name === 'bing'
          ? [item('bing', '热门'), item('bing', '热门')] // 同 source+title → 应去重
          : [item('vendor', '独立源')],
    });

    const svc = build(providerFactory, searchConfig);
    const items = (await svc.research('x')).items;

    expect(items.filter((i) => i.source === 'bing' && i.title === '热门')).toHaveLength(1);
    // 不同来源的「热门」因 source 不同不属于同一 key，故总数为 2
    expect(items).toHaveLength(2);
  });

  it('研究关闭（enabled=false）→ 返回 []，不调用来源', async () => {
    const providerFactory: SearchProviderFactory = () => ({ name: 'bing', search: async () => [item('bing', '不应出现')] });
    const svc = build(providerFactory, { enabled: false, sources: [{ name: 'bing', provider: 'bing' }] });

    await expect(svc.research('x')).resolves.toEqual({ items: [] });
  });

  it('保留带 imgUrl 的条目原图地址（不做下载）', async () => {
    const providerFactory: SearchProviderFactory = () => ({
      name: 'bing',
      search: async () => [item('bing', '带图条目', { imgUrl: 'https://img.example.com/1.jpg' })],
    });
    const svc = build(providerFactory, { enabled: true, sources: [{ name: 'bing', provider: 'bing' }] });

    const items = (await svc.research('x')).items;
    expect(items[0].imgUrl).toBe('https://img.example.com/1.jpg');
  });
});