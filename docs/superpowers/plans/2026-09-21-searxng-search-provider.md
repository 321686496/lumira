# SearXNG 自建搜索接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把研究管线（trend-research）的三方搜索引擎从已退役的 Bing Search API 替换为免费自建的 SearXNG 元搜索（含可选 `site:` 站点限定，用于小红书/抖音等自媒体趋势信号）。

**Architecture:** 新增 `searxng` 适配器（GET `{baseUrl}/search?q=&format=json`，无 Key），工厂/白名单/DTO/索引同步注册，删除 bing 适配器；`ai_provider_config` 增 `search_site` 列，存量 `bing` 配置读取时归一化为 `searxng`；后台搜索方式三选一改为「Qwen / SearXNG / 关闭」；`docker-compose.prod.yml` 加 `lumira-searxng` 容器（内部网络直连，不暴露端口）。

**Tech Stack:** NestJS + Fastify、Drizzle ORM + MySQL 8、Next.js (App Router) + shadcn/ui、Docker Compose（`searxng/searxng:latest`）。

## Global Constraints

- Flutter/Dart 无涉；改动仅限 `lumira-server/packages/backend`、`lumira-server/packages/admin`、`deploy/`、`AGENTS.md`。
- 后端每次修改完成必须 commit 并 **push 到双远程**（`origin`→gitee、`github`→github，均为 master）。
- Windows PowerShell：git commit 用多个 `-m` 参数，不用 heredoc。
- 遵守 UI 规范：后台样式沿用现有 shadcn/ui 组件（`Label` / `Input` / `Button` / `toast`），不引入新视觉语言。
- `qwen` 模型自带搜索保持可用，不删；`baidu` 保持占位抛错，不实现。
- 不引入 MediaCrawler 等自媒体爬虫（Non-Commercial License + 合规风险）；自媒体趋势以 `site:` 站点限定搜索实现。

---

### Task 1: 后端 searxng 适配器（替换 bing）+ 工厂/索引/DTO 接线 + 单测

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.ts`
- Delete: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-bing.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/index.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.spec.ts`

**Interfaces:**
- Consumes: `WebSearchProvider` / `WebSearchQuery`（`web-search.provider.ts`，已有）、`ResearchItem`（`research-item.ts`，已有：`{ source, title, snippet, url?, keywords }`）。
- Produces: `createSearxngSearchProvider(cfg: { baseUrl?: string; apiKey?: string; site?: string }): WebSearchProvider`；工厂 `createWebSearchProvider('searxng', cfg)` 可用；DTO 增 `searchSite?: string`。

- [ ] **Step 1: 写 searxng 适配器（含 site 拼接）**

创建 `web-search-searxng.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.ts
// SearXNG 元搜索适配器：GET {baseUrl}/search?q=...&format=json（无 API Key，免费自建）
// 设计文档：docs/superpowers/specs/2026-09-21-searxng-search-provider-design.md
//
// site 可选：拼接 site: 前缀做站点限定搜索（如 site:xiaohongshu.com），
// 用于把小红书/抖音等被搜索引擎收录的公开页面作为趋势信号源。
// 失败抛可读错误（上层 allSettled 降级跳过）；无结果返回 []。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

/** searxng 结果条目最小字段 */
interface SearxngResult {
  title?: unknown;
  url?: unknown;
  content?: unknown;
}

/** 摘要 → 关键词：按空白分词，保留含字母/数字/中日韩字的词（排除纯符号） */
function tokenizeKeywords(snippet: string, title: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  const hasContent = /[\p{L}\p{N}]/u;
  for (const text of [snippet, title]) {
    if (!text) continue;
    for (const w of text.split(/\s+/)) {
      const t = w.trim();
      if (t && hasContent.test(t) && !seen.has(t)) {
        seen.add(t);
        out.push(t);
      }
    }
  }
  return out.slice(0, 12);
}

/** 创建 searxng 适配器（site 可选：拼接 site: 前缀做站点限定搜索） */
export function createSearxngSearchProvider(cfg: { baseUrl?: string; apiKey?: string; site?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || 'http://lumira-searxng:8080').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const site = (cfg.site || '').trim();

  return {
    name: 'searxng',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      const query = site ? `site:${site} ${q.query}` : q.query;
      const params = new URLSearchParams({ q: query, format: 'json', language: 'zh-CN' });
      const headers: Record<string, string> = {};
      if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
      const res = await fetch(`${base}/search?${params.toString()}`, {
        headers,
        signal: AbortSignal.timeout(8000),
      }).catch((err: unknown) => {
        const name = (err as { name?: string } | null | undefined)?.name;
        if (name === 'AbortError' || name === 'TimeoutError') {
          throw new Error(`搜索服务超时（${q.query}）`);
        }
        throw new Error(`搜索服务无法连接（${q.query}）`);
      });
      if (!res.ok) {
        throw new Error(`搜索服务上游错误（HTTP ${res.status}，${q.query}）`);
      }
      const data = (await res.json()) as { results?: unknown } | null;
      const list = Array.isArray(data?.results) ? (data.results as SearxngResult[]) : [];
      return list.map((it): ResearchItem => {
        const title = typeof it.title === 'string' ? it.title.slice(0, 120) : '';
        const snippet = typeof it.content === 'string' ? it.content.slice(0, 300) : '';
        return {
          source: 'searxng',
          title,
          snippet,
          url: typeof it.url === 'string' ? it.url : undefined,
          keywords: tokenizeKeywords(snippet, title),
        };
      });
    },
  };
}
```

- [ ] **Step 2: 改写 web-search.spec.ts（bing 用例 → searxng 用例）**

保留 `cacheableSearch` describe 与 `createWebSearchProvider` 的「未知名称抛错」用例；替换其余 bing 相关用例：

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/web-search.spec.ts
// 覆盖：createWebSearchProvider 工厂 / 未知名称抛错 / searxng 请求形状与解析 / site 拼接 / apiKey 可选 /
// 空结果 / 网络失败与 HTTP 错误可读信息 / cacheableSearch 缓存命中不重复请求 / 失败抛错

import { createWebSearchProvider, cacheableSearch, WebSearchProvider, WebSearchQuery } from './web-search.provider';

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
```

注意：删除对 `ResearchItem` 的 `import`（上面已移除；若仍引用则保留 `import type { ResearchItem } from './research-item';`）。

- [ ] **Step 3: 更新工厂 web-search.provider.ts（注册 searxng、移除 bing、透传 site）**

替换 import 行：

```ts
import { createSearxngSearchProvider } from './web-search-searxng';
```

移除：

```ts
import { createBingSearchProvider } from './web-search-bing';
```

工厂签名 `cfg` 类型加 `site`：

```ts
export function createWebSearchProvider(
  providerName: string,
  cfg: { baseUrl?: string; apiKey?: string; model?: string; site?: string; vendorEndpoint?: LlmEndpoint },
): WebSearchProvider {
```

switch 分支：

```ts
    case 'searxng':
      return createSearxngSearchProvider(cfg);
```

删除：

```ts
    case 'bing':
      return createBingSearchProvider(cfg);
```

文件底部 re-export：

```ts
// re-export，便于统一入口
export { createSearxngSearchProvider };
export { createQwenSearchProvider };
```

同时更新文件头注释第 5 行与第 35 行「bing / baidu / vendor」措辞为「searxng / baidu / vendor」（仅注释，保持描述与实现一致）。

- [ ] **Step 4: 更新 index.ts re-export**

```ts
export { createSearxngSearchProvider } from './web-search-searxng';
```

删除：

```ts
export { createBingSearchProvider } from './web-search-bing';
```

- [ ] **Step 5: 更新 DTO 白名单与新增 searchSite 字段**

`dto/update-ai-config.dto.ts`：

- 注释与校验：`/** 启用的搜索来源数组（searxng/vendor/baidu/qwen）；缺省 = 沿用原值 */`，`@IsIn(['searxng', 'vendor', 'baidu', 'qwen'], { each: true })`
- `searchSources` 字段后新增：

```ts
  /** SearXNG 站点限定（可选，如 xiaohongshu.com / v.douyin.com）；空串/缺省 = 全站搜索 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchSite?: string;
```

- [ ] **Step 6: 删除 web-search-bing.ts**

用 DeleteFile 删除 `web-search-bing.ts`。

- [ ] **Step 7: 运行单测验证**

```powershell
cd lumira-server
pnpm --filter @lumira/backend test -- web-search.spec.ts
```

Expected: 全部 PASS（原 bing 用例已替换为 searxng 用例；cacheableSearch 用例通过）。

- [ ] **Step 8: typecheck 验证**

```powershell
cd lumira-server
pnpm --filter @lumira/backend typecheck
```

Expected: 无类型错误（若 `web-search.provider.ts` 有对 `createBingSearchProvider` 的残留引用会报错，需清理）。

- [ ] **Step 9: Commit**

```powershell
git add lumira-server/packages/backend/src/modules/ai/trend-research lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts
git commit -m "feat(ai): SearXNG 搜索适配器替换已退役的 Bing（含 site 站点限定）"
```

---

### Task 2: ai-config 接线——白名单/归一化/迁移/列/view/update + SearchSourceConfig.site + 单测

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/042_ai_config_search_site.sql`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `createSearxngSearchProvider`（工厂透传 `site`）；`SearchSourceConfig`（本任务扩展）。
- Produces: `SearchSourceConfig.site?: string`；`AiConfigView.searchSite: string`；`getSearchConfig()` 对 `searxng` source 输出 `{ name, provider: 'searxng', baseUrl?, apiKey?, site? }`；存量 `bing` 归一化为 `searxng`。

- [ ] **Step 1: 扩展 SearchSourceConfig（trend-research.service.ts）**

在 `SearchSourceConfig` 接口 `apiKey?: string;` 之后加：

```ts
  /** SearXNG 站点限定（provider=searxng 时可选，拼接 site: 前缀） */
  site?: string;
```

同步更新 `defaultProviderFactory` 透传：

```ts
const defaultProviderFactory: SearchProviderFactory = (name, cfg) =>
  createWebSearchProvider(cfg.provider || name, {
    baseUrl: cfg.baseUrl,
    apiKey: cfg.apiKey,
    model: cfg.model,
    site: cfg.site,
    vendorEndpoint: cfg.vendorEndpoint as never,
  });
```

- [ ] **Step 2: 写失败测试（ai-config.service.spec.ts）**

在 `ai-config.service.spec.ts` 的 getSearchConfig describe 末尾（现有 bing 兼容用例之后）新增两条：

```ts
  it('search_provider=general + sources=[bing]（老数据）→ 归一化为 searxng source（向后兼容）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'general',
      searchBaseUrl: 'http://lumira-searxng:8080',
      searchSources: JSON.stringify(['bing']),
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({ name: 'searxng', provider: 'searxng' });
  });

  it('search_provider=general + sources=[searxng] + searchSite → source 带 site', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'general',
      searchBaseUrl: 'http://lumira-searxng:8080',
      searchSite: 'xiaohongshu.com',
      searchSources: JSON.stringify(['searxng']),
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.sources[0]).toMatchObject({ name: 'searxng', provider: 'searxng', site: 'xiaohongshu.com' });
  });
```

同时把现有 `it('search_provider=general + sources=[bing]（老数据）→ 仍返回 bing source（向后兼容）', ...)` 的**断言替换**为上面的归一化断言（`name/provider` 变为 `searxng`），避免重复用例。若 `row()` 辅助函数不支持 `searchSite` 字段，需在测试的 row 工厂里补上（与 `searchSources` 并列，类型为 `searchSite?: string`）。

- [ ] **Step 3: 运行测试确认失败**

```powershell
cd lumira-server
pnpm --filter @lumira/backend test -- ai-config.service.spec.ts
```

Expected: FAIL（白名单未含 searxng → sources 为空；`searchSite` 未接线 → site 缺失；bing 未归一化 → 仍为 bing）。

- [ ] **Step 4: 更新 parseSearchSources（白名单 + 归一化）**

```ts
/** 解析 search_sources JSON 数组为 string[]；非法/空返回空数组 */
function parseSearchSources(raw: string | null | undefined): string[] {
  if (!raw) return [];
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr)
      ? (arr
          .filter((s) => ['bing', 'vendor', 'baidu', 'qwen', 'searxng'].includes(s))
          // 老数据归一化：bing 已退役，按 searxng 处理（免费自建，无需 Key）
          .map((s) => (s === 'bing' ? 'searxng' : s)) as string[])
      : [];
  } catch {
    return [];
  }
}
```

- [ ] **Step 5: schema.ts 加列**

在 `searchSources`（`varchar('search_sources', { length: 255 })`）之后加：

```ts
  /** SearXNG 站点限定（可选，如 xiaohongshu.com / v.douyin.com） */
  searchSite: varchar('search_site', { length: 255 }),
```

- [ ] **Step 6: 新建迁移 042**

创建 `042_ai_config_search_site.sql`：

```sql
-- 042: AI 服务商配置新增 SearXNG 站点限定字段（searxng 适配器拼接 site: 前缀）
-- 可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
ALTER TABLE ai_provider_config
  ADD COLUMN search_site VARCHAR(255) NULL AFTER search_sources;
```

- [ ] **Step 7: get() view 加 searchSite**

`ai-config.service.ts` 的 `get()` 返回对象，`searchSources: parseSearchSources(row.searchSources),` 后加：

```ts
      searchSite: row.searchSite ?? '',
```

同步把接口 `AiConfigView`（本文件 L44）注释 `/** 启用的搜索来源（bing/vendor/baidu/qwen） */` 更新为 `/** 启用的搜索来源（searxng/vendor/baidu/qwen） */`。

- [ ] **Step 8: getSearchConfig() bing 分支 → searxng 分支**

```ts
      } else if (name === 'searxng') {
        sources.push({
          name,
          provider: 'searxng',
          baseUrl: row.searchBaseUrl ?? undefined,
          apiKey: row.searchApiKey ?? undefined,
          site: row.searchSite?.trim() || undefined,
        });
      }
```

删除：

```ts
      } else if (name === 'bing') {
        sources.push({
          name,
          provider: 'bing',
          baseUrl: row.searchBaseUrl ?? undefined,
          apiKey: row.searchApiKey ?? undefined,
        });
      }
```

（`parseSearchSources` 已归一化 bing→searxng，老数据自动走到此分支。）

- [ ] **Step 9: getActiveConfig() 的 search view 加 site**

在 `search: { ... apiKey: row.searchApiKey ?? '', sources: parseSearchSources(row.searchSources), ... }` 的 `apiKey` 行后加：

```ts
        site: row.searchSite ?? '',
```

- [ ] **Step 10: update() 持久化 searchSite + 放宽 general 校验**

在 `ai-config.service.ts` update 方法的常量区（`const searchSources = serializeSearchSources(...)` 之后）加：

```ts
    const searchSite = dto.searchSite?.trim() || existing?.searchSite || null;
```

将校验规则：

```ts
    if (searchEnabled === 1 && searchProvider === 'general') {
      if (!searchBaseUrl) throw new BadRequestException('通用搜索 API 必须填写 baseUrl');
      if (!resolvedSearchApiKey) throw new BadRequestException('首次启用通用搜索 API 必须填写 API Key');
    }
```

改为（SearXNG 无需 Key）：

```ts
    if (searchEnabled === 1 && searchProvider === 'general') {
      if (!searchBaseUrl) throw new BadRequestException('通用搜索 API 必须填写 baseUrl');
    }
```

（若存在断言「首次启用通用搜索 API 必须填写 API Key」的 spec 用例，同步删除。）

insert 对象（`create` 分支）`searchSources,` 后加 `searchSite,`；update 对象（`update` 分支）`searchSources,` 后加 `searchSite,`。update 分支的 key 语义保持「留空 = 不改」，与 `searchApiKey` 一致（`dto.searchSite?.trim() ? searchSite : existing.searchSite`），因此直接放 `searchSite,` 即可（`searchSite` 常量已是解析后的最终值）。

- [ ] **Step 11: 运行测试验证**

```powershell
cd lumira-server
pnpm --filter @lumira/backend test -- ai-config.service.spec.ts
```

Expected: PASS（bing 归一化用例 + searchSite 传递用例通过；qwen 相关既有用例不受影响）。

- [ ] **Step 12: typecheck 验证**

```powershell
pnpm --filter @lumira/backend typecheck
```

Expected: 无类型错误。

- [ ] **Step 13: Commit**

```powershell
git add lumira-server/packages/backend/src/modules/ai lumira-server/packages/backend/src/database
git commit -m "feat(ai): 研究搜索源白名单接入 searxng 并兼容老 bing 配置（search_site 迁移 042）"
```

---

### Task 3: 后台表单与 types（搜索方式三选一 + 站点限定字段）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`
- Modify: `lumira-server/packages/admin/src/types/admin.ts`

**Interfaces:**
- Consumes: `AiConfigView`（后端 `get()`，含新 `searchSite` 字段）；`UpdateAiConfigPayload`（admin.ts，本任务加 `searchSite?`）。
- Produces: 保存后 payload：`searchProvider: 'general'` + `searchSources: ['searxng']` + 可选 `searchBaseUrl/searchApiKey/searchSite`。

- [ ] **Step 1: admin.ts 类型补 searchSite**

`types/admin.ts`：
- `AiConfigView`（L445-458 区）：`searchSources: string[];` 后加 `searchSite: string;`，并把两处注释 `bing/vendor/baidu` 更新为 `searxng/vendor/baidu`。
- `UpdateAiConfigPayload`（L489-499 区）：`searchSources?: string[];` 后加 `searchSite?: string;`。

- [ ] **Step 2: SEARCH_MODE_OPTIONS 三选一**

`ai-config-form.tsx` L68-72 替换为：

```tsx
/** 搜索方式（研究管线）：模型自带(Qwen) / SearXNG 自建(免费) / 关闭 */
const SEARCH_MODE_OPTIONS: { value: 'qwen' | 'searxng' | 'off'; label: string }[] = [
  { value: 'qwen', label: '模型自带搜索（Qwen）' },
  { value: 'searxng', label: 'SearXNG 自建搜索（免费）' },
  { value: 'off', label: '关闭' },
];
```

- [ ] **Step 3: 表单 state 类型与初始值**

- 类型（L84）：`searchMode: 'qwen' | 'searxng' | 'off';` 并在 `searchBaseUrl` 前加 `searchSite: string;`
- 初始映射（L189-193 区）改为：

```tsx
          searchMode: initial.searchEnabled
            ? (initial.searchProvider === 'qwen' ? 'qwen' : 'searxng')
            : 'off',
          searchBaseUrl: initial.searchBaseUrl,
          searchSite: initial.searchSite ?? '',
          searchApiKey: '',
```

- 重置初始值（L208-211 区）：`searchMode: 'off', searchBaseUrl: '', searchSite: '', searchApiKey: '',`

- [ ] **Step 4: 校验逻辑替换**

L414 附近：

```tsx
    } else if (form.searchMode === 'searxng' && !form.searchBaseUrl.trim()) {
      toast({
        variant: 'destructive',
        title: '缺少 SearXNG Base URL',
        description: 'SearXNG 自建搜索必须填写 Base URL（如 http://lumira-searxng:8080）',
      });
      return;
    }
```

（删除原 bing 分支的 `searchApiKey` 必填校验。）

- [ ] **Step 5: payload 映射替换**

L457-462 区：

```tsx
      } else if (form.searchMode === 'searxng') {
        payload.searchProvider = 'general';
        payload.searchSources = ['searxng'];
        if (form.searchBaseUrl.trim()) payload.searchBaseUrl = form.searchBaseUrl.trim();
        if (form.searchApiKey.trim()) payload.searchApiKey = form.searchApiKey.trim();
        if (form.searchSite.trim()) payload.searchSite = form.searchSite.trim();
      }
```

（删除原 bing 分支。）

- [ ] **Step 6: 字段组 JSX 替换**

L885-907 的 `{form.searchMode === 'bing' && (...)}` 整体替换为：

```tsx
            {form.searchMode === 'searxng' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-searxng-base-url">SearXNG Base URL</Label>
                  <Input
                    id="ai-searxng-base-url"
                    value={form.searchBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchBaseUrl: e.target.value }))}
                    placeholder="http://lumira-searxng:8080"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-searxng-api-key">SearXNG API Key（可选）</Label>
                  <Input
                    id="ai-searxng-api-key"
                    type="password"
                    value={form.searchApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchApiKey: e.target.value }))}
                    placeholder={searchApiKeyMasked ? `${searchApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2 md:col-span-2">
                  <Label htmlFor="ai-searxng-site">站点限定（可选）</Label>
                  <Input
                    id="ai-searxng-site"
                    value={form.searchSite}
                    onChange={(e) => setForm((f) => ({ ...f, searchSite: e.target.value }))}
                    placeholder="xiaohongshu.com / v.douyin.com，留空 = 全站搜索"
                  />
                  <p className="text-xs text-muted-foreground">
                    用于把小红书/抖音等被搜索引擎收录的公开页面作为自媒体趋势信号源。
                  </p>
                </div>
              </div>
            )}
```

- [ ] **Step 7: 构建验证**

```powershell
cd lumira-server
pnpm --filter @lumira/admin build
```

Expected: 构建成功（`pnpm --filter @lumira/shared build` 由 vercel.json / 脚本先执行；若 admin 脚本已依赖 shared 先构建则直接成功）。

- [ ] **Step 8: 全量测试（后端）**

```powershell
pnpm --filter @lumira/backend test
```

Expected: 全部 PASS（确认无其他引用 bing 适配器的断言残留）。

- [ ] **Step 9: Commit**

```powershell
git add lumira-server/packages/admin
git commit -m "feat(admin): 搜索方式改为 Qwen/SearXNG/关闭并新增站点限定字段"
```

---

### Task 4: 部署——SearXNG 容器 + settings.yml + AGENTS.md 部署章节

**Files:**
- Create: `deploy/searxng/settings.yml`
- Modify: `deploy/docker-compose.prod.yml`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 1-3 的 `searxng` provider 默认 baseUrl `http://lumira-searxng:8080`。
- Produces: 后端容器可经内部网络访问 `http://lumira-searxng:8080/search?format=json`；服务器 `.env` 需新增 `SEARXNG_SECRET`。

- [ ] **Step 1: 新建 deploy/searxng/settings.yml**

```yaml
# SearXNG 配置（研究管线免费搜索源）
# 卷挂载：./repo/deploy/searxng/settings.yml:/etc/searxng/settings.yml:ro
# 要点：开启 JSON 输出（format=json）；引擎限定为国内可访问集（排除被墙的 Google 等）；
#       内部专用（limiter 关闭、非 public instance），不暴露端口到公网。
use_default_settings: true
general:
  instance_name: Lumira Search
search:
  formats:
    - html
    - json
  safe_search: 0
server:
  limiter: false
  public_instance: false
engines:
  - name: bing
    disabled: false
  - name: duckduckgo
    disabled: false
  - name: qwant
    disabled: false
  - name: baidu
    disabled: false
```

- [ ] **Step 2: docker-compose.prod.yml 加 lumira-searxng 服务**

在 `lumira-redis` 服务块之后、`networks:` 之前插入：

```yaml
  # ---- SearXNG 元搜索服务（2026-09，研究管线免费搜索源）----
  # 后端经内部网络访问 http://lumira-searxng:8080，不暴露端口到宿主机。
  # settings.yml 由仓库 deploy/searxng/ 提供（compose 运行目录下 repo/ 为仓库克隆，CI 无需额外同步）。
  # 服务器 .env 需新增：SEARXNG_SECRET=<openssl rand -hex 32>
  lumira-searxng:
    image: searxng/searxng:latest
    restart: always
    environment:
      - SEARXNG_SECRET=${SEARXNG_SECRET}
      - SEARXNG_BASE_URL=http://lumira-searxng:8080
    volumes:
      - ./repo/deploy/searxng/settings.yml:/etc/searxng/settings.yml:ro
    networks:
      - lumira-net
```

同时更新文件头注释 `.env 文件需要包含` 列表，追加 `SEARXNG_SECRET`（可空——未配置时 SearXNG 容器每次重启自动生成新 secret，仅影响实例状态保持；建议配置）。

- [ ] **Step 3: AGENTS.md 部署章节补充**

在「服务器 `.env` 必填变量」表中追加一行：

| `SEARXNG_SECRET` | SearXNG 实例密钥（`openssl rand -hex 32` 生成；可空，未配置时容器重启会重生成） |

并在「部署/CI 相关文件清单」表中追加一行：

| `deploy/searxng/settings.yml` | SearXNG 配置（开启 json 格式 + 国内可访问引擎集），部署时随仓库同步 |

- [ ] **Step 4: Commit**

```powershell
git add deploy/searxng/settings.yml deploy/docker-compose.prod.yml AGENTS.md
git commit -m "deploy(ai): 新增 SearXNG 容器与研究管线免费搜索部署说明"
```

---

### Task 5: 全量验证 + push 双远程

**Files:** 无（验证 + 推送）。

- [ ] **Step 1: 后端 typecheck + 全量单测**

```powershell
cd lumira-server
pnpm --filter @lumira/backend typecheck
pnpm --filter @lumira/backend test
```

Expected: typecheck 无错；测试全 PASS。

- [ ] **Step 2: admin 构建验证**

```powershell
cd lumira-server
pnpm --filter @lumira/admin build
```

Expected: 构建成功。

- [ ] **Step 3: 全仓库 git 状态确认**

```powershell
git status
```

Expected: 仅计划内的改动文件；无遗漏（尤其确认 `web-search-bing.ts` 已删除、`web-search-searxng.ts` 已新增）。

- [ ] **Step 4: commit（若上一步有未提交内容）**

```powershell
git add -A
git commit -m "chore(ai): SearXNG 接入收尾"
```

- [ ] **Step 5: push 双远程**

```powershell
git push origin master
git push github master
```

Expected: 两个远程均推送成功（gitee `origin` + github `github`）。CI 会自动触发：后端 `backend-deploy.yml`（改动 backend/database/deploy 路径）在服务器重建并 `docker compose up -d`；后台 Vercel 监听 admin/shared 自动部署。

---

## Self-Review

- **Spec 覆盖**：D1 适配器（Task 1）、D2 白名单/归一化/迁移/接线（Task 2）、D3 后台表单（Task 3）、D4 部署（Task 4）、D5 测试（Task 1/2 内嵌 TDD；Task 5 全量验证）——全覆盖。
- **占位扫描**：无 TBD/TODO；每步含完整代码与命令。
- **类型一致**：`createSearxngSearchProvider`（Task 1）→ `SearchSourceConfig.site` + `defaultProviderFactory` 透传（Task 2）→ 后台 `payload.searchSite`（Task 3）→ 迁移 `search_site` 列（Task 2）命名链一致；`searchMode: 'qwen' | 'searxng' | 'off'` 全链一致。
