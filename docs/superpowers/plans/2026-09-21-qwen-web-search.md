# 千问(Qwen)模型自带联网搜索 + 后台「模型自带 / 三方搜索」切换 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「模型自带搜索」从「让模型凭记忆编 JSON」升级为真正调用千问联网搜索（`enable_search:true`），并在后台把「搜索方式」收敛为三选一单选：**模型自带(Qwen) / 三方(Bing) / 关闭**。

**Architecture:** 新增 `web-search-qwen.ts` 适配器（直连千问 Chat Completions + `enable_search`，宽松多形态解析引用），并入 `createWebSearchProvider` 分发；`ai-config` 用新字段 `search_qwen_*`（DB 列 + DTO + view + `getSearchConfig` 映射），沿用既有 `search_provider`/`search_sources` 承载「搜索方式」，向后兼容老字段；后台表单把「服务商单选 + 来源多选」收敛为「搜索方式三选一」。

**Tech Stack:** NestJS + Drizzle ORM + jest；后台 Next.js + Tailwind + shadcn/ui。

## Global Constraints

- Flutter 3.7.12 / Dart 2.19.6（本项目仅涉及 backend/admin，不需处理 Dart 语法）。
- 后端/后台在监于 `lumira-server/packages/`，改动后 commit + push **双远程**：`origin`(gitee) + `github`。
- 单条任务独立可测（TDD：先写失败测试→确认失败→实现→确认通过→commit）。
- 牵引相对：`git pull` 前确认无未提交改动；commit message 遵循仓库既有风格（`feat:`/`test:` 前缀）。
- 每完成一次对后端/admin 的修改与增强，**必须** `git commit` 并 `git push origin master` + `git push github master`。
- provider 名固定用 `qwen`；新配置项：`searchQwenBaseUrl` / `searchQwenApiKey` / `searchQwenModel`（默认 `qwen-plus`）。
- 向后兼容：老 `search_provider=general/vendor`、`search_sources=[bing/vendor/baidu]` 仍可正常读取；新字段只增不改。
- Qwen 搜索用**独立端点+Key**（不绕过/不改主对话端点）。
- 不做：baidu 适配器（仍 throw 降级）；多模态流式（仅支持 Chat Completions text 模型）。

---

### Task 1: 新增 Qwen 联网搜索适配器 + 并入分发

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.spec.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts`（加 `case 'qwen'` + `model` 配置项）
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/index.ts`（导出 `createQwenSearchProvider`）

**Interfaces:**
- Consumes: `ResearchItem`（`research-item.ts`）、`WebSearchProvider`/`WebSearchQuery`（`web-search.provider.ts`）。
- Produces: `createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider`，`name === 'qwen'`；`search(q)` 返回 `ResearchItem[]`（source 恒为 `'qwen'`），取不到引用时 **抛 Error**（供上层 allSettled 收集为 sourceErrors）。

- [ ] **Step 1: Write the failing test**

```ts
// web-search-qwen.spec.ts
import { createQwenSearchProvider } from './web-search-qwen';
import type { WebSearchProvider } from './web-search.provider';

const OK_TOOL_CALL = {
  message: {
    tool_calls: [{
      id: 'call_1', type: 'function',
      function: { name: 'web_search', arguments: JSON.stringify({ search_info: { search_results: [
        { title: '秋日少女写真', url: 'https://a.example', snippet: '秋日光影 温柔' },
        { title: '胶片感人像', url: 'https://b.example', content: '胶片 复古 质感' },
      ] } }) },
    }],
  },
};

const OK_JSON_CONTENT = {
  message: { content: JSON.stringify({ results: [
    { title: '公园人像构图', url: 'https://c.example', content: '构图 光比' },
  ] }) },
};

describe('web-search-qwen', () => {
  let provider: WebSearchProvider;
  beforeEach(() => {
    provider = createQwenSearchProvider({ baseUrl: 'https://qw.cn/v1', apiKey: 'sk-qw', model: 'qwen-plus' });
  });

  it('tool_calls.web_search.search_info.search_results → ResearchItem[]（source=qwen，url 取自 url，无 url 时回退 site）', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_TOOL_CALL), { status: 200 }));
    const items = await provider.search({ query: '人像', limit: 10 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0];
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.enable_search).toBe(true);
    expect((init as RequestInit).headers).toMatchObject({ Authorization: 'Bearer sk-qw' });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ source: 'qwen', title: '秋日少女写真', url: 'https://a.example' });
    expect(Array.isArray(items[0].keywords)).toBe(true);
  });

  it('content 为 JSON 字符串 {results} → 结构化兜底解析', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_JSON_CONTENT), { status: 200 }));
    const items = await provider.search({ query: '构图', limit: 10 });
    expect(items).toHaveLength(1);
    expect(items[0].title).toBe('公园人像构图');
  });

  it('无引用可解析 → 抛“未取到引用”错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ message: { content: '没有检索到相关资料。' } }), { status: 200 }));
    await expect(provider.search({ query: '冷门', limit: 10 })).rejects.toThrow('未取到引用');
  });

  it('缺 baseUrl → 抛可读错误', async () => {
    const p = createQwenSearchProvider({ apiKey: 'k' });
    await expect(p.search({ query: 'x' })).rejects.toThrow('baseUrl');
  });

  it('上游 HTTP 错误 → 抛可读错误', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 429 }));
    await expect(provider.search({ query: 'x' })).rejects.toThrow(/HTTP 429/);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test -- web-search-qwen`
Expected: FAIL（模块不存在 / `createQwenSearchProvider` 未定义）。

- [ ] **Step 3: Write minimal implementation** — create `web-search-qwen.ts`

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts
// 千问(Qwen)模型自带联网搜索适配器：直连 Chat Completions + enable_search
// 设计文档：docs/superpowers/specs/2026-09-21-qwen-web-search-design.md 3.1
//
// 多形态宽松解析引用：tool_calls.web_search.search_info.search_results[] /
// message.content 数组引用块 / content 文本 JSON{results}。取不到引用 → 抛 Error
// （上层 allSettled 收集为 sourceErrors，绝不编造 URL）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';

export const QWEN_SEARCH_DEFAULT_MODEL = 'qwen-plus';

const SYSTEM_PROMPT = '你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。';

/** 一条引用命中（松散字段） */
interface SearchHit {
  title?: unknown; url?: unknown; site?: unknown; caption?: unknown;
  snippet?: unknown; content?: unknown;
}

/** 宽松提取 JSON（对象/数组）：直接 parse，失败剥 markdown 代码块后再试，仍失败返回 null */
function extractJson(text: string): unknown | null {
  const candidates = [text];
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fence) candidates.unshift(fence[1]);
  const brace = text.match(/\{[\s\S]*\}/);
  if (brace) candidates.unshift(brace[0]);
  const bracket = text.match(/\[[\s\S]*\]/);
  if (bracket) candidates.unshift(bracket[0]);
  for (const c of candidates) {
    try { return JSON.parse(c); } catch { /* try next */ }
  }
  return null;
}

/** 取首个非空字符串 */
function firstStr(...vals: unknown[]): string | undefined {
  for (const v of vals) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return undefined;
}

/** 摘要/标题 → 关键词数组（保留含字母/数字/中日韩字，排除纯符号，前 12） */
function tokenize(...texts: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  const hasContent = /[\p{L}\p{N}]/u;
  for (const text of texts) {
    if (!text) continue;
    for (const w of text.split(/\s+/)) {
      const t = w.trim();
      if (t && hasContent.test(t) && !seen.has(t)) { seen.add(t); out.push(t); }
    }
  }
  return out.slice(0, 12);
}

function toResearchItem(hit: SearchHit): ResearchItem {
  const title = firstStr(hit.title) ?? '';
  const snippet = firstStr(hit.snippet, hit.content) ?? '';
  const url = firstStr(hit.url, hit.site, hit.caption);
  return { source: 'qwen', title, snippet, keywords: tokenize(snippet, title), url };
}

/** 多形态提取引用 → ResearchItem[]；无引用返回 null */
function extractResearchItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;
  const msg = root.message && typeof root.message === 'object' ? (root.message as Record<string, unknown>) : null;
  if (!msg) return null;

  // 1) tool_calls[web_search] → arguments.search_info.search_results[]
  const calls = Array.isArray(msg.tool_calls) ? msg.tool_calls : [];
  for (const call of calls) {
    if (!call || typeof call !== 'object') continue;
    const fn = (call as Record<string, unknown>).function;
    if (!fn || typeof fn !== 'object') continue;
    const f = fn as Record<string, unknown>;
    if (f.name !== 'web_search') continue;
    const parsed = extractJson(typeof f.arguments === 'string' ? f.arguments : '');
    if (!parsed || typeof parsed !== 'object') continue;
    const args = parsed as Record<string, unknown>;
    const si = args.search_info && typeof args.search_info === 'object' ? (args.search_info as Record<string, unknown>) : null;
    const results = Array.isArray(si?.search_results) ? (si.search_results as SearchHit[]) : [];
    const items = results.map(toResearchItem);
    if (items.length) return items;
  }

  // 2) content 数组的 search_result/reference 内容块
  if (Array.isArray(msg.content)) {
    const items: ResearchItem[] = [];
    for (const block of msg.content) {
      if (!block || typeof block !== 'object') continue;
      const b = block as Record<string, unknown>;
      const type = typeof b.type === 'string' ? b.type : '';
      if (!/search_result|reference|citation|web_page/i.test(type)) continue;
      items.push(toResearchItem({ title: b.title, url: b.url ?? b.link, snippet: b.snippet ?? b.content }));
    }
    if (items.length) return items;
  }

  // 3) 结构化兜底：content 文本 → Array | { results:[{title,url,content}] }
  if (typeof msg.content === 'string' && msg.content.trim()) {
    const parsed = extractJson(msg.content);
    if (parsed && typeof parsed === 'object') {
      const p = parsed as Record<string, unknown>;
      const list = Array.isArray(parsed) ? (parsed as SearchHit[]) : Array.isArray(p.results) ? (p.results as SearchHit[]) : [];
      const items = list.map(toResearchItem);
      if (items.length) return items;
    }
  }

  return null;
}

/** 创建千问联网搜索适配器（provider 名 qwen） */
export function createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 搜索端点');
      if (!apiKey) throw new Error('Qwen 搜索未配置 API Key，请到后台「研究管线」填写');

      const res = await fetch(`${base}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify({
          model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: q.query },
          ],
          enable_search: true,
          temperature: 0.3,
          max_tokens: 4096,
          response_format: { type: 'json_object' },
        }),
        signal: AbortSignal.timeout(120_000),
      }).catch((err: unknown) => {
        const name = (err as { name?: string } | null | undefined)?.name;
        if (name === 'AbortError' || name === 'TimeoutError') throw new Error(`Qwen 网上搜索超时（${q.query}）`);
        throw new Error(`Qwen 网上搜索无效连接（${q.query}）`);
      });

      if (!res.ok) throw new Error(`Qwen 网上搜索上游错误（HTTP ${res.status}，${q.query}）`);
      const data = await res.json().catch(() => null);
      const items = extractResearchItems(data);
      if (!items) throw new Error(`Qwen 网上搜索本次未取到引用（${q.query}）`);
      return items;
    },
  };
}
```

- [ ] **Step 4: Wire into the factory** — modify `web-search.provider.ts`

Add import and `model` config + `case 'qwen'`:

```ts
import { createQwenSearchProvider } from './web-search-qwen';
// ...existing import lines unchanged

export function createWebSearchProvider(
  providerName: string,
  cfg: { baseUrl?: string; apiKey?: string; model?: string; vendorEndpoint?: LlmEndpoint },
): WebSearchProvider {
  const name = (providerName || '').trim().toLowerCase();
  switch (name) {
    case 'bing':
      return createBingSearchProvider(cfg);
    case 'qwen':
      return createQwenSearchProvider(cfg);
    case 'baidu':
      throw new Error('baidu 搜索适配器尚未接入');
    case 'vendor':
    case 'llm':
      if (!cfg.vendorEndpoint) throw new Error('vendor 联网检索需配置联网模型端点');
      return createVendorSearchProvider(cfg.vendorEndpoint);
    default:
      throw new Error(`未知的搜索服务商：${providerName}`);
  }
}
```

- [ ] **Step 5: Export from `index.ts`** — add `export { createQwenSearchProvider } from './web-search-qwen';`

- [ ] **Step 6: Run tests to verify they pass**

Run: `pnpm test -- web-search-qwen web-search`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/
git commit -m "feat(ai): 新增千问联网搜索适配器(qwen, enable_search)并并入分发"
```

---

### Task 2: DB 列 + 迁移 + DTO + `ai-config.service` 接线（含 getSearchConfig 映射）

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（`aiProviderConfig` 新增 3 列）
- Create: `lumira-server/packages/backend/src/database/migrations/040_ai_config_search_qwen.sql`
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`（view + save + getSearchConfig）
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts`（`SearchSourceConfig` 增 `model`，factory 透传）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`（新增 qwen 相关用例）

**Interfaces:**
- Consumes: `SearchConfig`/`SearchSourceConfig`（`trend-research.service.ts`，本次为其加 `model?: string`）。
- Produces: `SearchSourceConfig.model?: string`；`AiConfigView` 增 `searchQwenBaseUrl`/`searchQwenApiKeyMasked`/`searchQwenModel`；`getSearchConfig()` 在新 `search_provider='qwen'` 时返回 `[{ name:'qwen', provider:'qwen', baseUrl, apiKey, model }]`；qwen 方式但缺端点/Key 时返回 `{ enabled: searchEnabled===1, sources: [] }`（研究跑 0 条，绝不误写为 skip-research）。

- [ ] **Step 1: schema 加列** — 在 `schema.ts` `maxIterations` 之后插入

```ts
  /** Qwen 模型自带联网搜索端点（search_provider=qwen 时使用） */
  searchQwenBaseUrl: varchar('search_qwen_base_url', { length: 255 }),
  /** Qwen 搜索 API key（脱敏返回，永不回传明文） */
  searchQwenApiKey: varchar('search_qwen_api_key', { length: 255 }),
  /** Qwen 搜索模型（默认 qwen-plus） */
  searchQwenModel: varchar('search_qwen_model', { length: 64 }),
```

- [ ] **Step 2: 迁移 SQL** — create `040_ai_config_search_qwen.sql`

```sql
-- 040: AI 服务商配置新增 Qwen 模型自带联网搜索字段（search_provider=qwen 时使用）
-- 均为可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
ALTER TABLE ai_provider_config
  ADD COLUMN search_qwen_base_url VARCHAR(255) NULL AFTER max_iterations,
  ADD COLUMN search_qwen_api_key VARCHAR(255) NULL AFTER search_qwen_base_url,
  ADD COLUMN search_qwen_model VARCHAR(64) NULL AFTER search_qwen_api_key;
```

- [ ] **Step 3: DTO 扩展** — modify `update-ai-config.dto.ts`

- `searchProvider` 的 `@IsIn` 从 `['general', 'vendor', 'off']` 改为 `['general', 'vendor', 'off', 'qwen']`。
- `searchSources` 每项的 `@IsIn` 从 `['bing', 'vendor', 'baidu']` 改为 `['bing', 'vendor', 'baidu', 'qwen']`。
- 文件末尾追加三字段：

```ts
  /** Qwen 模型自带搜索端点（searchProvider=qwen 时使用） */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenBaseUrl?: string;

  /** Qwen 搜索 API key：空串/缺省 = 保留原值；首次启用 Qwen 搜索必填 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenApiKey?: string;

  /** Qwen 搜索模型（缺省 = qwen-plus） */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  searchQwenModel?: string;
```

- [ ] **Step 4: `ai-config.service.ts` view 增字段**

- `AiConfigView` 接口增：
  ```ts
  /** Qwen 模型自带搜索端点（searchProvider=qwen 时使用） */
  searchQwenBaseUrl: string;
  /** Qwen 搜索 API key（脱敏） */
  searchQwenApiKeyMasked: string;
  /** Qwen 搜索模型（缺省 = qwen-plus） */
  searchQwenModel: string;
  ```
- `get()` 返回对象尾部增：
  ```ts
  searchQwenBaseUrl: row.searchQwenBaseUrl ?? '',
  searchQwenApiKeyMasked: maskKey(row.searchQwenApiKey ?? ''),
  searchQwenModel: row.searchQwenModel ?? 'qwen-plus',
  ```

- [ ] **Step 5: `save()` 处理 qwen 校验与写列**

在 `searchBaseUrl`/`resolvedSearchApiKey` 附近新增解析，并在「研究管线校验」段与 `insert`/`update` 的 `.values`/`.set` 中带上：

在方法内（`searchEnabled` 解析之后）追加：

```ts
    const searchQwenBaseUrl = dto.searchQwenBaseUrl?.trim() || existing?.searchQwenBaseUrl || null;
    const resolvedSearchQwenApiKey = dto.searchQwenApiKey?.trim() || existing?.searchQwenApiKey || null;
    const searchQwenModel = dto.searchQwenModel?.trim() || existing?.searchQwenModel || null;
```

把既有校验条件 `if (searchEnabled === 1 && searchProvider === 'general') { ... }` 后面追加：

```ts
    if (searchEnabled === 1 && searchProvider === 'qwen') {
      if (!searchQwenBaseUrl) throw new BadRequestException('Qwen 搜索必须填写 baseUrl');
      if (!resolvedSearchQwenApiKey) throw new BadRequestException('首次启用 Qwen 搜索必须填写 API Key');
    }
```

在 `insert(...).values({ ... })` 与 `update(...).set({ ... })` 对象中各加三项：

```ts
        searchQwenBaseUrl,
        searchQwenApiKey: dto.searchQwenApiKey?.trim() ? resolvedSearchQwenApiKey : existing?.searchQwenApiKey, // 留空 = 不改（仅 update 分支；insert 直接给 resolvedSearchQwenApiKey）
        searchQwenModel,
```

> 说明：`insert` 分支无需「留空不改」逻辑，直接 `searchQwenApiKey: resolvedSearchQwenApiKey`；`update` 分支用上述带条件表达式。请按所在分支分别写入合适表达式。

- [ ] **Step 6: `getSearchConfig()` 增 qwen 方式**

在 `parseSearchSources` 之后、`sources` 循环之前插入 qwen 分支（新「搜索方式」优先）：

```ts
    // 搜索方式 = qwen（模型自带）：用独立 Qwen 端点 + Key；缺任一 → sources 空（研究跑 0 条，绝不误写 skip-research）
    if (row.searchProvider === 'qwen') {
      const hasQwen = Boolean((row.searchQwenBaseUrl ?? '').trim() && (row.searchQwenApiKey ?? '').trim());
      return {
        enabled: row.searchEnabled === 1,
        sources: hasQwen
          ? [{
              name: 'qwen',
              provider: 'qwen',
              baseUrl: (row.searchQwenBaseUrl ?? '').trim(),
              apiKey: (row.searchQwenApiKey ?? '').trim(),
              model: (row.searchQwenModel ?? '').trim() || 'qwen-plus',
            }]
          : [],
      };
    }
```

> 保留原有 `for (const name of names)` 循环不变（兼容老 `general`→`bing`、`vendor` 逻辑）。

- [ ] **Step 7: `trend-research.service.ts` 增 `model`**

- `SearchSourceConfig` 接口加 `model?: string;`。
- `defaultProviderFactory` 中传给工厂加 `model`：

```ts
const defaultProviderFactory: SearchProviderFactory = (name, cfg) =>
  createWebSearchProvider(cfg.provider || name, {
    baseUrl: cfg.baseUrl,
    apiKey: cfg.apiKey,
    model: cfg.model,
    vendorEndpoint: cfg.vendorEndpoint as never,
  });
```

- [ ] **Step 8: Write failing tests** — append to `ai-config.service.spec.ts`

```ts
describe('AiConfigService — search qwen', () => {
  it('search_provider=qwen 且端点+Key 齐全 → getSearchConfig 返回 sources=[qwen]（含 model）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen',
      searchSources: JSON.stringify(['qwen']),
      searchQwenBaseUrl: 'https://qw.cn/v1',
      searchQwenApiKey: 'sk-qwen-long',
      searchQwenModel: 'qwen-plus',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.enabled).toBe(true);
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({ name: 'qwen', provider: 'qwen', baseUrl: 'https://qw.cn/v1', apiKey: 'sk-qwen-long', model: 'qwen-plus' });
  });

  it('search_provider=qwen 但缺端点/Key → sources 为空且 enabled 保持开关状态（不抛）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen',
      searchSources: JSON.stringify(['qwen']),
      searchQwenBaseUrl: '',
      searchQwenApiKey: '',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.enabled).toBe(true);
    expect(cfg?.sources).toHaveLength(0);
  });

  it('search_provider=general + sources=[bing]（老数据）→ 仍返回 bing source（向后兼容）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'general',
      searchBaseUrl: 'https://api.bing.microsoft.com',
      searchApiKey: 'sk-bing-long',
      searchSources: JSON.stringify(['bing']),
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({ name: 'bing', provider: 'bing' });
  });
});
```

> `readonlyDb`/`row` 为文件内既有夹具，直接复用。若 `row()` 夹具缺少 `search*` 字段（保持 undefined），不影响以上用例（均有 `overrides`）。

- [ ] **Step 9: Run tests to verify fail → pass**

Run: `pnpm test -- ai-config.service`
Expected: 先 FAIL（缺字段/未实现），实现后 PASS。

- [ ] **Step 10: Commit**

```bash
git add lumira-server/packages/backend/src/database lumira-server/packages/backend/src/modules/ai
git commit -m "feat(ai): qwen 联网搜索配置接线(getSearchConfig/save/DTO/迁移 040)"
```

---

### Task 3: 后台表单收敛为「搜索方式三选一」

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（`AiProviderConfigView` + `UpdateAiConfigPayload` 增 qwen 字段）
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`（常量、FormState、load、save、render）

**Interfaces:**
- Consumes: `AiProviderConfigView`/`UpdateAiConfigPayload`（`types/admin.ts`），`saveAiConfigAction`（直接透传 payload，无需改）。
- Produces: 表单 `searchMode: 'qwen' | 'bing' | 'off'`；保存映射 `qwen→{searchProvider:'qwen',searchSources:['qwen'],searchQwen*}`、`bing→{searchProvider:'general',searchSources:['bing'],searchBaseUrl/searchApiKey}`、`off→{searchProvider:'off',searchEnabled:false}`。

- [ ] **Step 1: 后端返回类型增字段** — `types/admin.ts`

`AiProviderConfigView` 加：
```ts
  /** Qwen 模型自带搜索端点（searchProvider=qwen 时使用） */
  searchQwenBaseUrl: string;
  /** Qwen 搜索 API key（脱敏） */
  searchQwenApiKeyMasked: string;
  /** Qwen 搜索模型（缺省 = qwen-plus） */
  searchQwenModel: string;
```
`UpdateAiConfigPayload` 加：
```ts
  searchQwenBaseUrl?: string;
  searchQwenApiKey?: string;
  searchQwenModel?: string;
```

- [ ] **Step 2: 表单常量 + FormState** — `ai-config-form.tsx`

把 `SEARCH_PROVIDER_OPTIONS`/`SEARCH_SOURCE_OPTIONS` 替换为三选一模式：

```ts
/** 搜索方式（研究管线）：模型自带(Qwen) / 三方(Bing) / 关闭 */
const SEARCH_MODE_OPTIONS: { value: 'qwen' | 'bing' | 'off'; label: string }[] = [
  { value: 'qwen', label: '模型自带搜索（Qwen）' },
  { value: 'bing', label: '三方搜索引擎（Bing）' },
  { value: 'off', label: '关闭' },
];
```
删除 `SEARCH_SOURCE_OPTIONS`（不再显示来源多选）。

`FormState` 中把 `searchProvider`/`searchSources` 替换为：
```ts
  searchMode: 'qwen' | 'bing' | 'off';
  searchQwenBaseUrl: string;
  searchQwenApiKey: string; // 留空 = 不修改原值
  searchQwenModel: string;
```
（保留 `searchBaseUrl`/`searchApiKey` 字段用于 bing 方式与通用 key。）

- [ ] **Step 3: load 回填** — `useState(initial)` 分支

configured 分支改为：
```ts
          searchMode: initial.searchEnabled
            ? (initial.searchProvider === 'qwen' ? 'qwen' : 'bing')
            : 'off',
          searchBaseUrl: initial.searchBaseUrl,
          searchApiKey: '',
          searchQwenBaseUrl: initial.searchQwenBaseUrl,
          searchQwenApiKey: '',
          searchQwenModel: initial.searchQwenModel,
          maxIterations: initial.maxIterations,
```
未配置分支：
```ts
          searchMode: 'off',
          searchBaseUrl: '',
          searchApiKey: '',
          searchQwenBaseUrl: '',
          searchQwenApiKey: '',
          searchQwenModel: '',
          maxIterations: 2,
```

> 说明：老 `vendor` 行回显为 `bing`（因新 UI 三选一去掉了厂商项）；DB 字段仍保留，用户在后台重选即可。这是可接受的向后兼容读取。

- [ ] **Step 4: save payload 组装** — 替换现有「研究管线」赋值块（原 L436-444）

```ts
      // 研究管线（Agentic）：搜索方式三选一 → provider/sources/字段映射
      payload.searchEnabled = form.searchMode !== 'off';
      payload.maxIterations = form.maxIterations;
      if (form.searchMode === 'qwen') {
        payload.searchProvider = 'qwen';
        payload.searchSources = ['qwen'];
        if (form.searchQwenBaseUrl.trim()) payload.searchQwenBaseUrl = form.searchQwenBaseUrl.trim();
        if (form.searchQwenApiKey.trim()) payload.searchQwenApiKey = form.searchQwenApiKey.trim();
        payload.searchQwenModel = form.searchQwenModel.trim() || 'qwen-plus';
      } else if (form.searchMode === 'bing') {
        payload.searchProvider = 'general';
        payload.searchSources = ['bing'];
        if (form.searchBaseUrl.trim()) payload.searchBaseUrl = form.searchBaseUrl.trim();
        if (form.searchApiKey.trim()) payload.searchApiKey = form.searchApiKey.trim();
      } else {
        payload.searchProvider = 'off';
      }
```

并在保存成功后（`setSearchApiKeyMasked(...)` 附近）加 `setSearchQwenApiKeyMasked(config.searchQwenApiKeyMasked)`（需新增一个 state，见 Step 5）。

- [ ] **Step 5: qwen Key 脱敏 state**

新增一条 state（放在 `searchApiKeyMasked` 声明旁）：
```ts
  const [searchQwenApiKeyMasked, setSearchQwenApiKeyMasked] = useState(
    configured ? initial.searchQwenApiKeyMasked : '',
  );
```

- [ ] **Step 6: 校验** — 原「研究管线」前端校验（约 L394-403）按新方式调整

将原 `form.searchProvider === 'general' && ...` 校验改为按 `searchMode`：
```ts
    if (form.searchMode === 'qwen') {
      if (!form.searchQwenBaseUrl.trim()) { toast(...); return; }
      if (!searchQwenApiKeyMasked && !form.searchQwenApiKey.trim()) { toast(...); return; }
    } else if (form.searchMode === 'bing' && !searchApiKeyMasked && !form.searchApiKey.trim()) {
      toast(...); return;
    }
```
（把原错误提示文案中的「通用搜索 API」对应替换为「Qwen 搜索」/「Bing 搜索」。

- [ ] **Step 7: render 区重写** — 替换 L801-917「研究管线」整块

```tsx
          {/* 研究管线（Agentic）：搜索方式三选一 */}
          <div className="space-y-4 rounded-lg border border-border p-4">
            <div>
              <div className="text-sm font-medium text-foreground">研究管线（Agentic 趋势研究）</div>
              <div className="mt-0.5 text-xs text-muted-foreground">
                生成模板时结合联网趋势研究提升热点 / 真实感。关闭时走原单次识别路径。
              </div>
            </div>

            <div className="space-y-2">
              <Label>搜索方式</Label>
              <div className="inline-flex rounded-md border border-border p-0.5">
                {SEARCH_MODE_OPTIONS.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => setForm((f) => ({ ...f, searchMode: option.value }))}
                    className={cn(
                      'rounded px-3 py-1 text-sm transition-colors',
                      form.searchMode === option.value
                        ? 'bg-primary text-primary-foreground'
                        : 'text-muted-foreground hover:text-foreground',
                    )}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            </div>

            {form.searchMode === 'qwen' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-base-url">Qwen 搜索端点（Base URL）</Label>
                  <Input
                    id="ai-qwen-base-url"
                    value={form.searchQwenBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenBaseUrl: e.target.value }))}
                    placeholder="https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-api-key">Qwen 搜索 API Key</Label>
                  <Input
                    id="ai-qwen-api-key"
                    type="password"
                    value={form.searchQwenApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenApiKey: e.target.value }))}
                    placeholder={searchQwenApiKeyMasked ? `${searchQwenApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-model">Qwen 搜索模型</Label>
                  <Input
                    id="ai-qwen-model"
                    value={form.searchQwenModel}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenModel: e.target.value }))}
                    placeholder="qwen-plus"
                  />
                </div>
              </div>
            )}

            {form.searchMode === 'bing' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-bing-base-url">Bing 搜索 Base URL</Label>
                  <Input
                    id="ai-bing-base-url"
                    value={form.searchBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchBaseUrl: e.target.value }))}
                    placeholder="https://api.bing.microsoft.com/v7.0/search"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-bing-api-key">Bing 搜索 API Key</Label>
                  <Input
                    id="ai-bing-api-key"
                    type="password"
                    value={form.searchApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchApiKey: e.target.value }))}
                    placeholder={searchApiKeyMasked ? `${searchApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
              </div>
            )}

            {form.searchMode !== 'off' && (
              <div className="space-y-2 md:max-w-xs">
                <Label htmlFor="ai-max-iterations">迭代上限（预算护栏）</Label>
                <Input
                  id="ai-max-iterations"
                  type="number"
                  min={1}
                  max={3}
                  value={form.maxIterations}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      maxIterations: Number(e.target.value) || 1,
                    }))
                  }
                />
                <p className="text-xs text-muted-foreground">
                  质量不达标时依评审建议微调重试，最多迭代该次数；1~3，绝不无限迭代。费用与耗时递增。
                </p>
              </div>
            )}
          </div>
```

> `cn`、`Label`、`Input` 已在文件顶部 import，无需新增。

- [ ] **Step 8: typecheck + lint + build**

Run（在 `lumira-server/packages/admin` 目录）：
```bash
pnpm typecheck && pnpm lint && pnpm build
```
Expected: 全部通过，无 TS 错误。

- [ ] **Step 9: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(admin): 研究管线搜索方式收敛为模型自带/三方/关闭三选一"
```

---

### Task 4: 后端测试回看 + 全量约束 + 双远程推送

**Files:** 无新文件；仅运行既有测试确认无回归。

- [ ] **Step 1: 跑后端相关测试套件**

Run（仓库根 `lumira-server`）：`pnpm test`
Expected: 全部通过（含 `web-search-qwen`、`ai-config.service`、`trend-research.service`）。

- [ ] **Step 2: 确认 `git status` 干净、无遗漏**

```bash
git status
```
确认 migrated/schema/dto/service/form 改动均已在本轮各 Task committed。

- [ ] **Step 3: push 双远程**

```bash
git commit -m "feat(ai): 千问联网搜索(enable_search) + 后台搜索方式三选一" --allow-empty   # 如已有各 Task 提交则无需此空提交
git push origin master
git push github master
```
Expected: 两端均成功推送，无冲突。

---