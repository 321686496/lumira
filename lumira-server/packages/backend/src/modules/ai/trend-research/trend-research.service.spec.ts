// lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.spec.ts
// T1 trend-research 服务编排（Task 4，TDD）：来源并行 + allSettled 降级、source+title+snippet 去重、研究关闭返回 []

import { TrendResearchService, extractExplicitUrls } from './trend-research.service';
import type { SearchProviderFactory } from './trend-research.service';
import { AiConfigService } from '../ai-config.service';
import { ResearchDigestService } from './research-digest.service';
import { ResearchImageService } from './research-image.service';
import { ResearchVisionService } from './research-vision.service';
import { DEFAULT_RESEARCH_IMAGES_CONFIG } from './research-image';
import { clearWebSearchCache } from './web-search.provider';
import type { ResearchItem } from './research-item';
import { describeTodayUtc8 } from '../../../common/utils/date.util';

// 文本模型打桩：capture 提示词（重组查询词用例断言日期注入 + 时间约束规则）
jest.mock('../llm-client', () => ({ textChat: jest.fn(async () => '{"query": null}') }));

/** 资料整理打桩：本 spec 只验证检索编排，整理结论一律返回 null（走规则摘要降级） */
const digestStub = { summarize: async () => null } as unknown as ResearchDigestService;

/** 参考图抓取/解读打桩：未开图片支路的既有用例不会被调用 */
const imagesStub = {
  collect: async () => ({ images: [], errors: [] }),
  readBase64: async () => null,
} as unknown as ResearchImageService;
const visionStub = { interpret: async () => null } as unknown as ResearchVisionService;

function item(source: string, title: string, extra: Partial<ResearchItem> = {}): ResearchItem {
  return { source, title, snippet: '', keywords: [], ...extra };
}

/** 注入型 aiConfig + 工厂辅助 */
function build(factory: SearchProviderFactory, searchConfig: unknown) {
  const aiConfig = { getSearchConfig: async () => searchConfig } as unknown as AiConfigService;
  const svc = new TrendResearchService(aiConfig, digestStub, imagesStub, visionStub);
  svc.factory = factory;
  return svc;
}

beforeEach(() => {
  clearWebSearchCache();
});

describe('extractExplicitUrls', () => {
  it('提取 http/https URL，并在中文/全角标点处截断', () => {
    const urls = extractExplicitUrls('参考这个网站制作模板：https://zhuanlan.zhihu.com/p/2003398601259373929，风格要类似');
    expect(urls).toEqual(['https://zhuanlan.zhihu.com/p/2003398601259373929']);
  });

  it('多个 URL 全部提取且去重', () => {
    const urls = extractExplicitUrls('看 https://a.com/p1 和 https://a.com/p1 还有 https://b.com/p2 吧');
    expect(urls).toEqual(['https://a.com/p1', 'https://b.com/p2']);
  });

  it('尾部 ASCII 标点容忍去除', () => {
    expect(extractExplicitUrls('参考 https://a.com/page. 这个页面')).toEqual(['https://a.com/page']);
  });

  it('无 URL / 非 http 协议 → 空数组', () => {
    expect(extractExplicitUrls('就想要清新风格')).toEqual([]);
    expect(extractExplicitUrls('ftp://a.com/x')).toEqual([]);
  });
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

  it('重复标题去重（保留先出现者，key=source+title+snippet）', async () => {
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

  it('同 source+title 但 snippet 不同 → 视为不同条目（多组查询的联网综述不被误去重）', async () => {
    const searchConfig = {
      enabled: true,
      sources: [{ name: 'qwen', provider: 'qwen' }],
    };
    const providerFactory: SearchProviderFactory = () => ({
      name: 'qwen',
      search: async () => [
        item('qwen', '联网综述', { snippet: '中秋 9/25 距今 2 天' }),
        item('qwen', '联网综述', { snippet: '万圣节 10/31 戏剧光' }),
        item('qwen', '联网综述', { snippet: '中秋 9/25 距今 2 天' }), // 完全重复 → 去重
      ],
    });

    const svc = build(providerFactory, searchConfig);
    const items = (await svc.research('x')).items;

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

  it('研究前调用查询词重组：重组后 query 用于搜索（reorganize 可注入文本端点）', async () => {
    const seen: string[] = [];
    const providerFactory: SearchProviderFactory = () => ({
      name: 'searxng',
      search: async (q) => {
        seen.push(q.query);
        return [item('searxng', '重组命中')];
      },
    });
    // 提供 getActiveConfig（text 端点 stub）：返回重组关键词查询
    const aiConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'searxng', provider: 'searxng' }] }),
      getActiveConfig: async () => ({
        text: { provider: 'test', baseUrl: 'http://x', apiKey: 'k', model: 'm' },
      }),
    } as unknown as AiConfigService;
    // 用真实 TrendResearchService + 覆写 reorganizeQuery 为返回重组结果（内联服务，不先跑 LLM）
    const svc = new TrendResearchService(aiConfig, digestStub, imagesStub, visionStub);
    svc.factory = providerFactory;
    // 打桩文本模型：textChat 不可直接注入，故覆写 reorganizeQuery 返回固定重组串，验证 research 使用之
    svc.reorganizeQuery = async () => '电影感人像 横构图 侧拍';

    await svc.research('电影感他拍，照片比例为横图16:9，三种不同姿势');
    expect(seen).toEqual(['电影感人像 横构图 侧拍']);
  });

  it('重组失败（无文本端点/AI 未配置）→ 回退原 topic，研究仍正常执行', async () => {
    const seen: string[] = [];
    const providerFactory: SearchProviderFactory = () => ({
      name: 'searxng',
      search: async (q) => {
        seen.push(q.query);
        return [item('searxng', '命中')];
      },
    });
    // getActiveConfig 抛错 → reorganizeQuery 兜底返回原 topic
    const aiConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'searxng', provider: 'searxng' }] }),
      getActiveConfig: async () => {
        throw new Error('AI 未配置');
      },
    } as unknown as AiConfigService;
    const svc = new TrendResearchService(aiConfig, digestStub, imagesStub, visionStub);
    svc.factory = providerFactory;

    const res = await svc.research('胶片感 都市夜晚');
    expect(seen).toEqual(['胶片感 都市夜晚']);
    expect(res.items).toHaveLength(1);
  });

  it('重组提示词注入当天日期，并要求把时间/节日类约束换算成含年份的具体节假名（不得丢弃）', async () => {
    const { textChat } = jest.requireMock('../llm-client') as { textChat: jest.Mock };
    textChat.mockResolvedValueOnce(JSON.stringify({ query: '2026年10月 中秋节 国庆节 人像模板' }));
    const aiConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'qwen', provider: 'qwen' }] }),
      getActiveConfig: async () => ({ text: { provider: 'test', baseUrl: 'http://x', apiKey: 'k', model: 'm' } }),
    } as unknown as AiConfigService;
    const svc = new TrendResearchService(aiConfig, digestStub, imagesStub, visionStub);

    const q = await svc.reorganizeQuery('距离当前时间最近节日的特色模板，三种不同姿势');
    expect(q).toBe('2026年10月 中秋节 国庆节 人像模板');

    const { systemPrompt, userText } = textChat.mock.calls[0][1] as { systemPrompt: string; userText: string };
    expect(systemPrompt).toContain(describeTodayUtc8()); // 今天是 YYYY-MM-DD（星期X），北京时间
    expect(userText).toContain(describeTodayUtc8());
    expect(systemPrompt).toContain('时间/节日/时令/档期类约束必须换算成具体可检索词');
  });

  it('reorganizeQuery 提示词要求补充社交平台语感词（小红书 / 抖音）', async () => {
    const { textChat } = jest.requireMock('../llm-client') as { textChat: jest.Mock };
    textChat.mockResolvedValueOnce(JSON.stringify({ query: '秋日 情侣照 出片' }));
    const aiConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'qwen', provider: 'qwen' }] }),
      getActiveConfig: async () => ({ text: { provider: 'test', baseUrl: 'http://x', apiKey: 'k', model: 'm' } }),
    } as unknown as AiConfigService;
    const svc = new TrendResearchService(aiConfig, digestStub, imagesStub, visionStub);

    await svc.reorganizeQuery('秋天的情侣照');

    const { systemPrompt } = textChat.mock.calls[0][1] as { systemPrompt: string };
    expect(systemPrompt).toContain('小红书');
    expect(systemPrompt).toContain('出片');
  });
});

describe('TrendResearchService 参考图串接', () => {
  it('图片支路开启时回传 images 与 vision', async () => {
    const fakeConfig = {
      getSearchConfig: async () => ({
        enabled: true,
        sources: [{ name: 'searxng', provider: 'searxng' }],
        images: { ...DEFAULT_RESEARCH_IMAGES_CONFIG, enabled: true },
      }),
    } as never;
    const digest = { summarize: async () => null } as never;
    const images = {
      collect: async () => ({
        images: [{ id: 'a'.repeat(16), url: 'https://x/uploads/research/a.jpg', sourceUrl: 'https://a.com/1.jpg', source: 'searxng', layer: 'metadata' as const, bytes: 100 }],
        errors: [],
      }),
      readBase64: async () => ({ base64: 'AAA', mime: 'image/jpeg' }),
    } as never;
    const vision = { interpret: async () => ({ summary: '暖调', styles: ['新中式'], colorLight: [], composition: [], wardrobe: [], scene: [], adopted: [{ id: 'a'.repeat(16), reason: '光线好' }] }) } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    svc.factory = () => ({ name: 'searxng', search: async () => [] });
    // 直接跳过真实检索：reorganizeQuery 走降级返回 topic
    const r = await svc.research('旗袍', { limitPerSource: 1 });
    expect(r.images).toHaveLength(1);
    expect(r.vision?.styles).toEqual(['新中式']);
  });

  it('总开关关闭时不产生 images / vision', async () => {
    const fakeConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'searxng', provider: 'searxng' }], images: { ...DEFAULT_RESEARCH_IMAGES_CONFIG } }),
    } as never;
    const digest = { summarize: async () => null } as never;
    let collectCalled = false;
    const images = { collect: async () => { collectCalled = true; return { images: [], errors: [] }; }, readBase64: async () => null } as never;
    const vision = { interpret: async () => null } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    svc.factory = () => ({ name: 'searxng', search: async () => [] });
    const r = await svc.research('旗袍', { limitPerSource: 1 });
    expect(collectCalled).toBe(false);
    expect(r.images ?? []).toHaveLength(0);
    expect(r.vision ?? null).toBeNull();
  });

  it('抓图抛错不阻断 research（仍返回 items）', async () => {
    const fakeConfig = {
      getSearchConfig: async () => ({ enabled: true, sources: [{ name: 'searxng', provider: 'searxng' }], images: { ...DEFAULT_RESEARCH_IMAGES_CONFIG, enabled: true } }),
    } as never;
    const digest = { summarize: async () => null } as never;
    const images = { collect: async () => { throw new Error('磁盘满'); }, readBase64: async () => null } as never;
    const vision = { interpret: async () => null } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    svc.factory = () => ({ name: 'searxng', search: async () => [{ source: 'searxng', title: 't', snippet: 's', keywords: [] }] });
    const r = await svc.research('旗袍', { limitPerSource: 1 });
    expect(r.items.length).toBeGreaterThan(0);
  });

  it('userReference：抓文本条目 + 整页多图并回传 vision（独立于 research，不受开关限制）', async () => {
    const fakeConfig = {
      getSearchConfig: async () => ({ enabled: false, sources: [] }),
    } as never;
    const digest = { summarize: async () => null } as never;
    let capturedUrls: string[] | null = null;
    const images = {
      collect: async () => ({ images: [], errors: [] }),
      collectUserPage: async (input: { urls: string[] }) => {
        capturedUrls = input.urls;
        return {
          items: [{ source: 'user-reference', title: '人像构图', snippet: '侧逆光……', keywords: [], url: 'https://a.com/p' }],
          images: [{ id: 'b'.repeat(16), url: 'https://x/uploads/research/b.jpg', sourceUrl: 'https://a.com/1.jpg', source: 'user-reference', layer: 'user-reference' as const, bytes: 100 }],
          errors: [],
        };
      },
      readBase64: async () => ({ base64: 'BBB', mime: 'image/jpeg' }),
    } as never;
    const vision = { interpret: async () => ({ summary: '侧逆光', styles: [], colorLight: [], composition: [], wardrobe: [], scene: [], adopted: [] }) } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    const r = await svc.userReference(['https://a.com/p', 'https://a.com/p2'], '侧逆光人像');
    expect(capturedUrls).toEqual(['https://a.com/p', 'https://a.com/p2']);
    expect(r.items).toHaveLength(1);
    expect(r.items[0].source).toBe('user-reference');
    expect(r.images).toHaveLength(1);
    expect(r.vision?.summary).toBe('侧逆光');
  });

  it('userReference：无 URL 直接返回空结果（不调用抓取）', async () => {
    const fakeConfig = { getSearchConfig: async () => ({ enabled: false, sources: [] }) } as never;
    const digest = { summarize: async () => null } as never;
    const images = { collectUserPage: async () => { throw new Error('不应被调用'); } } as never;
    const vision = { interpret: async () => null } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    const r = await svc.userReference([], 'x');
    expect(r.items).toHaveLength(0);
    expect(r.images).toHaveLength(0);
    expect(r.errors).toHaveLength(0);
  });

  it('userReference：抓取失败返回空结果并记 errors（不抛错）', async () => {
    const fakeConfig = { getSearchConfig: async () => ({ enabled: false, sources: [] }) } as never;
    const digest = { summarize: async () => null } as never;
    const images = { collectUserPage: async () => { throw new Error('页面超时'); }, readBase64: async () => null } as never;
    const vision = { interpret: async () => null } as never;

    const svc = new TrendResearchService(fakeConfig, digest, images, vision);
    const r = await svc.userReference(['https://a.com/p'], 'x');
    expect(r.items).toHaveLength(0);
    expect(r.images).toHaveLength(0);
    expect(r.errors.length).toBeGreaterThan(0);
  });
});
