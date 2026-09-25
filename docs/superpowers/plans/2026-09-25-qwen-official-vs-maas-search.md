# Qwen 联网搜索双通道拆分（官方百炼 / 三方 MaaS）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「AI 一键生图」联网搜索链路里的 Qwen 拆成两套**互斥可选、独立配置**的通道——`qwen-official`（官方百炼，新）与 `qwen`（三方 MaaS，现有行为不变）——后台「搜索方式」收敛为四选一。

**Architecture:** 后端新增 3 个可空列（`search_qwen_official_*`）承载官方通道配置；`getSearchConfig()` 新增 `qwen-official` 分支产出独立的 `SearchSourceConfig`；新增专用适配器 `web-search-qwen-official.ts`（`enable_search` + `search_options`，去掉 `response_format`，解析与三方「分支 0a」对齐：正文综述置首、顶层 `search_info.search_results[]` 引用随后，无 `search_info` 时仅综述兜底）；两个适配器共用从现有文件抽取的纯函数 `qwen-shared.ts`。后台表单四选一，官方/三方各自独立字段与校验。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8（后端）、Jest + ts-jest（后端单测）、Next.js 14 App Router + React 18 + Tailwind + shadcn/ui（后台 admin）、class-validator（DTO）。

## Global Constraints

以下为规格（`docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md`）中的硬约束，**每个 Task 都隐含包含本节**，逐条照抄：

- **provider 名**：官方 = `qwen-official`（新）；三方 = `qwen`（**不变**）。后台「搜索方式」四选一互斥：`qwen-official` / `qwen` / `searxng` / `off`。
- **列名**：新增 `search_qwen_official_base_url` / `search_qwen_official_api_key` / `search_qwen_official_model`（均为可空新增列）。现有 `search_qwen_base_url` / `search_qwen_api_key` / `search_qwen_model` 三列与 provider 名 `qwen` **保持不动**，归三方 MaaS，**线上数据零迁移**。
- **官方请求体**：必须带 `enable_search: true` 与 `search_options: { forced_search: true, enable_source: true }`；必须**去掉** `response_format: json_object`。
- **官方解析优先级**（与三方适配器「分支 0a」行为对齐，**正文综述绝不丢弃**）：① 顶层 `search_info.search_results[]` 命中时，`items` = 先插入正文综述条目（`message.content` 为非 JSON 实质文本 → `title: '联网综述'`、snippet 截断 **2000 字上限**（`SUMMARY_SNIPPET_CAP = 2000`）、`keywords: []`），再追加 `search_info` 映射出的结构化条目（`title` / `url`（缺省回退 `site_name`）/ 摘要）；② 无 `search_info` 但正文有实质文本 → 仅「联网综述」条目兜底；③ **两者皆空 → 抛错**（上层 `allSettled` 收进 `sourceErrors`，不编造 URL）。
- **缺端点或 Key → `sources: []`**（研究跑 0 条，trace 透传 `sourceErrors`，**绝不误写 `skip-research`**）。
- **绝不编造 URL**：任何取不到引用的情形只抛错，不得伪造链接。
- **互斥**：两套通道一次只启用一种；**不做并联多源**。
- **默认模型** `qwen-plus`（两套通道缺省值一致）。
- **超时**：`AbortSignal.timeout(180_000)`；HTTP 非 2xx → 抛可读中文错误；`trend-research` 的 `allSettled` 聚合失败入 `sourceErrors`，识别/生图主流程不因搜索失败中断。
- **不改动现有 `qwen`（三方）适配器的运行行为**，只允许「抽取公共纯函数」这种等价重构，且必须由 T2 回归测试证明。
- **不做**：Responses API / Anthropic 兼容 / 多模态流式；不改评分与细化闭环；**不改主对话端点**。
- **不修改 `lumira-app/`**（废弃 uni-app 原型）。
- 每个 Task 结尾只做**本地 commit**；**不执行 `git push`**（推送由主会话统一处理）。

> ⚠️ **与规格的一处不符（需主会话确认）**：规格 3.3 写迁移文件名为 `043_ai_config_search_qwen_official.sql`，但仓库现有 `src/database/migrations/` 已存在 `043_storage_migrations_source_target.sql`、`044_banner_search.sql`、`045_point_transactions_reason.sql`。本计划实际使用**下一个可用序号 `046_ai_config_search_qwen_official.sql`**（迁移加载器按文件名逐个执行并按 `_migrations` 表幂等，序号只需唯一且递增）。

---

## File Structure

| 文件 | 责任 | 动作 |
| --- | --- | --- |
| `lumira-server/packages/backend/src/database/migrations/046_ai_config_search_qwen_official.sql` | 新增官方 Qwen 三列 | Create |
| `lumira-server/packages/backend/src/database/schema.ts` | `aiProviderConfig` 增三列定义 | Modify |
| `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts` | `searchProvider`/`searchSources` 白名单 + 官方三字段 | Modify |
| `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts` | 读/写/映射官方通道配置 | Modify |
| `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts` | 官方通道单测 | Modify |
| `lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts` | 两适配器共用的纯函数 | Create |
| `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts` | 三方适配器（等价重构，行为不变） | Modify |
| `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts` | 官方百炼适配器 | Create |
| `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.spec.ts` | 官方适配器单测 | Create |
| `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts` | 工厂分发 `qwen-official` | Modify |
| `lumira-server/packages/admin/src/types/admin.ts` | 后台类型同步 | Modify |
| `lumira-server/packages/admin/src/components/ai-config-form.tsx` | 搜索方式四选一 + 官方字段 | Modify |

**任务划分理由（与建议 T1–T5 一致，未调整边界）**：T1（配置面）可独立验收——`getSearchConfig()` 已能产出 `qwen-official` source；T2（纯函数抽取）是**纯重构**，独立验收标准是「现有 `web-search-qwen.spec.ts` 全绿」，与 T3 解耦（T3 依赖 T2 的 `qwen-shared.ts`）；T3（适配器 + 新 spec）依赖 T2；T4（后台）只依赖 T1 的后端契约，可与 T3 并行；T5 做全量回归门禁。

---

### Task 1: 配置面接线（迁移 + schema + DTO + getSearchConfig + 白名单 + 单测）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/046_ai_config_search_qwen_official.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts:393-394`（在 `searchQwenModel` 之后插入三列）
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts:97-100,114-120,147-151`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts:37-38,82,122-135,176-188,252-272,304-306,337-339,420-435,493-497`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`（在文件末尾追加两个 `describe` 块）

**Interfaces:**
- Consumes: 无（首个任务）。
- Produces:
  - 新列（drizzle 字段名 → 列名）：`searchQwenOfficialBaseUrl` → `search_qwen_official_base_url VARCHAR(255) NULL`；`searchQwenOfficialApiKey` → `search_qwen_official_api_key VARCHAR(255) NULL`；`searchQwenOfficialModel` → `search_qwen_official_model VARCHAR(64) NULL`。
  - 类型：`AiConfigView.searchProvider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null`；`ActiveAiConfig.search.provider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null`；`AiConfigView.searchQwenOfficialBaseUrl: string`、`searchQwenOfficialApiKeyMasked: string`、`searchQwenOfficialModel: string`。
  - `getSearchConfig()` 在 `searchProvider === 'qwen-official'` 且端点+Key 齐备时返回 `sources: [{ name: 'qwen-official', provider: 'qwen-official', baseUrl: string, apiKey: string, model: string }]`，否则 `sources: []`。

- [ ] **Step 1: 写失败测试**

在 `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts` **文件末尾（第 615 行之后）追加**以下两个 `describe` 块（不要修改已有内容）：

```ts

describe('AiConfigService — search qwen-official（官方百炼）', () => {
  it('get() search_provider=qwen-official + search_sources 含 qwen-official → 白名单透传 + 官方字段/脱敏', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen-official',
      searchSources: JSON.stringify(['qwen-official']),
      searchQwenOfficialBaseUrl: 'https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
      searchQwenOfficialApiKey: 'sk-official-long',
      searchQwenOfficialModel: 'qwen-plus',
    })));
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.searchProvider).toBe('qwen-official');
    // parseSearchSources 白名单未含 qwen-official 时这里会是 []（失败点）
    expect(view.searchSources).toEqual(['qwen-official']);
    expect(view.searchQwenOfficialBaseUrl).toBe('https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1');
    expect(view.searchQwenOfficialApiKeyMasked).toBe('sk-****ng');
    expect(view.searchQwenOfficialModel).toBe('qwen-plus');
  });

  it('search_provider=qwen-official 且官方端点+Key 齐全 → getSearchConfig 返回 sources=[qwen-official]（model 缺省 qwen-plus）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen-official',
      searchSources: JSON.stringify(['qwen-official']),
      searchQwenOfficialBaseUrl: 'https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
      searchQwenOfficialApiKey: 'sk-official-long',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.enabled).toBe(true);
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({
      name: 'qwen-official',
      provider: 'qwen-official',
      baseUrl: 'https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1',
      apiKey: 'sk-official-long',
      model: 'qwen-plus',
    });
  });

  it('search_provider=qwen-official 但缺 Key → sources 为空且 enabled 保持开关状态（不抛，绝不误写 skip-research）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen-official',
      searchSources: JSON.stringify(['qwen-official']),
      searchQwenOfficialBaseUrl: 'https://ws.example/v1',
      searchQwenOfficialApiKey: '',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.enabled).toBe(true);
    expect(cfg?.sources).toHaveLength(0);
  });

  it('两种 Qwen 互斥：search_provider=qwen-official 只读官方字段（不串三方 MaaS 字段）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen-official',
      searchQwenBaseUrl: 'https://maas.example/v1',
      searchQwenApiKey: 'sk-maas',
      searchQwenModel: 'qwen3.7-max',
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({
      name: 'qwen-official',
      provider: 'qwen-official',
      baseUrl: 'https://official.example/v1',
      apiKey: 'sk-official',
      model: 'qwen-max',
    });
  });

  it('两种 Qwen 互斥：search_provider=qwen 只读三方 MaaS 字段（不串官方字段）', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen',
      searchQwenBaseUrl: 'https://maas.example/v1',
      searchQwenApiKey: 'sk-maas',
      searchQwenModel: 'qwen3.7-max',
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
    })));
    const cfg = await service.getSearchConfig();
    expect(cfg?.sources).toHaveLength(1);
    expect(cfg?.sources[0]).toMatchObject({
      name: 'qwen',
      provider: 'qwen',
      baseUrl: 'https://maas.example/v1',
      apiKey: 'sk-maas',
      model: 'qwen3.7-max',
    });
  });

  it('getActiveConfig() search.provider 透传 qwen-official', async () => {
    const service = new AiConfigService(readonlyDb(row({
      enabled: 1,
      searchEnabled: 1,
      searchProvider: 'qwen-official',
      searchSources: JSON.stringify(['qwen-official']),
    })));
    const cfg = await service.getActiveConfig();
    expect(cfg.search.provider).toBe('qwen-official');
  });
});

describe('AiConfigService — save() qwen-official', () => {
  const dto = (overrides: Record<string, unknown> = {}) => ({
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    enabled: true,
    searchEnabled: true,
    ...overrides,
  });

  it('searchProvider=qwen-official 首次无存量 Key 且未传 Key → 400', async () => {
    const { service } = writableDb(row());
    await expect(service.save(dto({
      searchProvider: 'qwen-official',
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
    }))).rejects.toThrow('首次启用 Qwen 官方搜索必须填写 API Key');
  });

  it('searchProvider=qwen-official 但缺 baseUrl → 400', async () => {
    const { service } = writableDb(row());
    await expect(service.save(dto({
      searchProvider: 'qwen-official',
      searchQwenOfficialApiKey: 'sk-official',
    }))).rejects.toThrow('Qwen 官方搜索必须填写 baseUrl');
  });

  it('searchProvider=qwen-official 齐全 → update set 收到官方三列，且三方三列保持不动', async () => {
    const { service, updateSet } = writableDb(row({
      searchQwenBaseUrl: 'https://maas.example/v1',
      searchQwenApiKey: 'sk-maas',
      searchQwenModel: 'qwen3.7-max',
    }));
    await service.save(dto({
      searchProvider: 'qwen-official',
      searchSources: ['qwen-official'],
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
    }));
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({
      searchProvider: 'qwen-official',
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
      searchQwenBaseUrl: 'https://maas.example/v1',
      searchQwenApiKey: 'sk-maas',
      searchQwenModel: 'qwen3.7-max',
    }));
  });

  it('searchProvider=qwen-official 首次保存 → insert values 收到官方三列', async () => {
    const { service, insertValues } = writableDb(undefined);
    await service.save(dto({
      searchProvider: 'qwen-official',
      searchSources: ['qwen-official'],
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
    }));
    expect(insertValues).toHaveBeenCalledWith(expect.objectContaining({
      searchQwenOfficialBaseUrl: 'https://official.example/v1',
      searchQwenOfficialApiKey: 'sk-official',
      searchQwenOfficialModel: 'qwen-max',
    }));
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/ai-config.service.spec.ts
```
Expected: FAIL。典型失败为 `expect(view.searchSources).toEqual(['qwen-official'])` 收到 `[]`、`cfg?.sources` 为 `undefined`（`expect(undefined).toHaveLength` 报错）、`view.searchQwenOfficialBaseUrl` 为 `undefined`。

- [ ] **Step 3: 新建迁移文件**

创建 `lumira-server/packages/backend/src/database/migrations/046_ai_config_search_qwen_official.sql`：

```sql
-- 046: AI 服务商配置新增 Qwen 官方百炼联网搜索字段（search_provider=qwen-official 时使用）
-- 均为可空新增列，不影响存量配置（幂等由 _migrations 表保证只执行一次）。
-- 现有 search_qwen_*（第三方 MaaS，search_provider=qwen）字段保持不动，线上数据零迁移。
ALTER TABLE ai_provider_config
  ADD COLUMN search_qwen_official_base_url VARCHAR(255) NULL AFTER search_qwen_model,
  ADD COLUMN search_qwen_official_api_key VARCHAR(255) NULL AFTER search_qwen_official_base_url,
  ADD COLUMN search_qwen_official_model VARCHAR(64) NULL AFTER search_qwen_official_api_key;
```

- [ ] **Step 4: 在 drizzle schema 增列**

修改 `lumira-server/packages/backend/src/database/schema.ts`：把第 392-393 行

```ts
  /** Qwen 搜索模型（默认 qwen-plus） */
  searchQwenModel: varchar('search_qwen_model', { length: 64 }),
```

替换为

```ts
  /** Qwen 搜索模型（默认 qwen-plus）；search_provider=qwen（三方 MaaS）时使用 */
  searchQwenModel: varchar('search_qwen_model', { length: 64 }),
  /** Qwen 官方百炼联网搜索端点（search_provider=qwen-official 时使用） */
  searchQwenOfficialBaseUrl: varchar('search_qwen_official_base_url', { length: 255 }),
  /** Qwen 官方百炼搜索 API key（脱敏返回，永不回传明文） */
  searchQwenOfficialApiKey: varchar('search_qwen_official_api_key', { length: 255 }),
  /** Qwen 官方百炼搜索模型（默认 qwen-plus） */
  searchQwenOfficialModel: varchar('search_qwen_official_model', { length: 64 }),
```

- [ ] **Step 5: 改 DTO**

修改 `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`：

(5a) 第 97-100 行的 `searchProvider` 替换为：

```ts
  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（Qwen 三方 MaaS）| 'qwen-official'（Qwen 官方百炼）| 'off'（关闭） */
  @IsOptional()
  @IsIn(['general', 'vendor', 'off', 'qwen', 'qwen-official'] as const)
  searchProvider?: string;
```

(5b) 第 114-120 行的 `searchSources` 替换为：

```ts
  /** 启用的搜索来源数组（searxng/vendor/baidu/qwen/qwen-official）；缺省 = 沿用原值 */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(3)
  @ArrayNotEmpty()
  @IsIn(['searxng', 'vendor', 'baidu', 'qwen', 'qwen-official'], { each: true })
  searchSources?: string[];
```

(5c) 在文件末尾 `}`（第 152 行）之前、`searchQwenModel` 声明之后插入：

```ts
  /** Qwen 官方百炼搜索端点（searchProvider=qwen-official 时使用） */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenOfficialBaseUrl?: string;

  /** Qwen 官方百炼搜索 API key：空串/缺省 = 保留原值；首次启用官方搜索必填 */
  @IsOptional()
  @IsString()
  @MaxLength(255)
  searchQwenOfficialApiKey?: string;

  /** Qwen 官方百炼搜索模型（缺省 = qwen-plus） */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  searchQwenOfficialModel?: string;
```

- [ ] **Step 6: 改 `parseSearchSources` 白名单**

修改 `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts` 第 128 行：

```ts
          .filter((s) => ['bing', 'vendor', 'baidu', 'qwen', 'searxng'].includes(s))
```

替换为：

```ts
          .filter((s) => ['bing', 'vendor', 'baidu', 'qwen', 'qwen-official', 'searxng'].includes(s))
```

- [ ] **Step 7: 改 `AiConfigView` 与 `ActiveAiConfig` 类型**

(7a) 第 37-38 行：

```ts
  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（Qwen 模型自带搜索）| null（未启用） */
  searchProvider: 'general' | 'vendor' | 'qwen' | null;
```

替换为：

```ts
  /** 搜索服务商：'general' | 'vendor' | 'qwen'（Qwen 三方 MaaS）| 'qwen-official'（Qwen 官方百炼）| null（未启用） */
  searchProvider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null;
```

(7b) 第 43 行 `/** 启用的搜索来源（searxng/vendor/baidu/qwen） */` 替换为：

```ts
  /** 启用的搜索来源（searxng/vendor/baidu/qwen/qwen-official） */
```

(7c) 第 53-54 行（`searchQwenModel` 声明）之后追加：

```ts
  /** Qwen 官方百炼搜索端点（searchProvider=qwen-official 时使用） */
  searchQwenOfficialBaseUrl: string;
  /** Qwen 官方百炼搜索 API key（脱敏） */
  searchQwenOfficialApiKeyMasked: string;
  /** Qwen 官方百炼搜索模型（缺省 = qwen-plus） */
  searchQwenOfficialModel: string;
```

(7d) 第 82 行（`ActiveAiConfig.search.provider`）：

```ts
    provider: 'general' | 'vendor' | 'qwen' | null;
```

替换为：

```ts
    provider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null;
```

- [ ] **Step 8: 改 `get()` 映射**

(8a) 第 176-179 行：

```ts
      searchProvider:
        row.searchProvider === 'general' || row.searchProvider === 'vendor' || row.searchProvider === 'qwen'
          ? row.searchProvider
          : null,
```

替换为：

```ts
      searchProvider:
        row.searchProvider === 'general' || row.searchProvider === 'vendor' || row.searchProvider === 'qwen' || row.searchProvider === 'qwen-official'
          ? row.searchProvider
          : null,
```

(8b) 第 187 行（`searchQwenModel: row.searchQwenModel ?? 'qwen-plus',`）之后追加：

```ts
      searchQwenOfficialBaseUrl: row.searchQwenOfficialBaseUrl ?? '',
      searchQwenOfficialApiKeyMasked: maskKey(row.searchQwenOfficialApiKey ?? ''),
      searchQwenOfficialModel: row.searchQwenOfficialModel ?? 'qwen-plus',
```

- [ ] **Step 9: 改 `save()` 解析 / 校验 / 写入**

(9a) 第 264 行（`const searchQwenModel = ...`）之后插入：

```ts
    const searchQwenOfficialBaseUrl = dto.searchQwenOfficialBaseUrl?.trim() || existing?.searchQwenOfficialBaseUrl || null;
    const resolvedSearchQwenOfficialApiKey = dto.searchQwenOfficialApiKey?.trim() || existing?.searchQwenOfficialApiKey || null;
    const searchQwenOfficialModel = dto.searchQwenOfficialModel?.trim() || existing?.searchQwenOfficialModel || null;
```

(9b) 第 269-272 行（`qwen` 校验块）之后插入：

```ts
    if (searchEnabled === 1 && searchProvider === 'qwen-official') {
      if (!searchQwenOfficialBaseUrl) throw new BadRequestException('Qwen 官方搜索必须填写 baseUrl');
      if (!resolvedSearchQwenOfficialApiKey) throw new BadRequestException('首次启用 Qwen 官方搜索必须填写 API Key');
    }
```

(9c) insert 分支第 305-306 行：

```ts
        searchQwenApiKey: resolvedSearchQwenApiKey,
        searchQwenModel,
```

替换为：

```ts
        searchQwenApiKey: resolvedSearchQwenApiKey,
        searchQwenModel,
        searchQwenOfficialBaseUrl,
        searchQwenOfficialApiKey: resolvedSearchQwenOfficialApiKey,
        searchQwenOfficialModel,
```

(9d) update 分支第 338-339 行：

```ts
          searchQwenApiKey: dto.searchQwenApiKey?.trim() ? resolvedSearchQwenApiKey : existing?.searchQwenApiKey,
          searchQwenModel,
```

替换为：

```ts
          searchQwenApiKey: dto.searchQwenApiKey?.trim() ? resolvedSearchQwenApiKey : existing?.searchQwenApiKey,
          searchQwenModel,
          searchQwenOfficialBaseUrl,
          searchQwenOfficialApiKey: dto.searchQwenOfficialApiKey?.trim() ? resolvedSearchQwenOfficialApiKey : existing?.searchQwenOfficialApiKey,
          searchQwenOfficialModel,
```

- [ ] **Step 10: 改 `getSearchConfig()` 新增官方分支**

在第 420-421 行（现有 `qwen` 分支注释 + `if (row.searchProvider === 'qwen') {`）**之前**插入：

```ts
    // 搜索方式 = qwen-official（Qwen 官方百炼）：用官方端点 + Key；缺任一 → sources 空（研究跑 0 条，绝不误写 skip-research）
    if (row.searchProvider === 'qwen-official') {
      const hasOfficial = Boolean((row.searchQwenOfficialBaseUrl ?? '').trim() && (row.searchQwenOfficialApiKey ?? '').trim());
      return {
        enabled: row.searchEnabled === 1,
        sources: hasOfficial
          ? [{
              name: 'qwen-official',
              provider: 'qwen-official',
              baseUrl: (row.searchQwenOfficialBaseUrl ?? '').trim(),
              apiKey: (row.searchQwenOfficialApiKey ?? '').trim(),
              model: (row.searchQwenOfficialModel ?? '').trim() || 'qwen-plus',
            }]
          : [],
      };
    }
```

同时把现有第 420 行注释 `// 搜索方式 = qwen（模型自带）：用独立 Qwen 端点 + Key；缺任一 → sources 空（研究跑 0 条，绝不误写 skip-research）` 替换为：

```ts
    // 搜索方式 = qwen（Qwen 三方 MaaS）：用独立 Qwen 端点 + Key；缺任一 → sources 空（研究跑 0 条，绝不误写 skip-research）
```

- [ ] **Step 11: 改 `getActiveConfig().search.provider` 透传**

第 493-496 行：

```ts
        provider:
          row.searchProvider === 'general' || row.searchProvider === 'vendor' || row.searchProvider === 'qwen'
            ? row.searchProvider
            : null,
```

替换为：

```ts
        provider:
          row.searchProvider === 'general' || row.searchProvider === 'vendor' || row.searchProvider === 'qwen' || row.searchProvider === 'qwen-official'
            ? row.searchProvider
            : null,
```

- [ ] **Step 12: 运行测试确认通过**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/ai-config.service.spec.ts
```
Expected: PASS，`Tests:` 行全部通过（原有 30+ 用例 + 新增 10 用例）。

- [ ] **Step 13: 类型检查**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/shared build; pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 无输出、退出码 0（若报错先修类型再继续）。

- [ ] **Step 14: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/046_ai_config_search_qwen_official.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts
git commit -m "feat(ai): 新增 Qwen 官方百炼搜索配置通道（列/DTO/getSearchConfig 分支）"
```

---

### Task 2: 抽取公共纯函数 `qwen-shared.ts`（等价重构，回归证明）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts`（整文件重写为下方内容）
- Test（回归，**不修改**）：`lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.spec.ts`

**Interfaces:**
- Consumes: `ResearchItem`（`./research-item`）。
- Produces（供 T3 官方适配器 import）：
  - `export const QWEN_SEARCH_DEFAULT_MODEL = 'qwen-plus'`
  - `export const SUMMARY_SNIPPET_CAP = 2000`
  - `export interface SearchHit { title?: unknown; url?: unknown; site?: unknown; caption?: unknown; snippet?: unknown; content?: unknown }`
  - `export function extractJson(text: string): unknown | null`
  - `export function firstStr(...vals: unknown[]): string | undefined`
  - `export function tokenize(...texts: string[]): string[]`
  - `export function clean(field: string): string`
  - `export function toResearchItem(hit: SearchHit, source: string): ResearchItem`
  - `export function toSummaryItem(msg: Record<string, unknown>, source: string): ResearchItem | null`
  - `web-search-qwen.ts` 仍导出 `createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider` 与 `QWEN_SEARCH_DEFAULT_MODEL`（re-export）。

> **TDD 说明**：本任务是纯重构，没有新行为可测。**验收标准 = 现有 `web-search-qwen.spec.ts` 全绿**（该文件覆盖 13 个用例，覆盖 `enable_search`、顶层 `sources[]`、`tool_calls`、content 数组块、content JSON、正文兜底、抛错、trace）。先跑基线，重构后必须逐字仍绿。

- [ ] **Step 1: 跑基线测试（重构前必须绿）**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen.spec.ts
```
Expected: PASS（13 passed）。若此刻不绿，先停止并在**不修改该文件**的前提下排查环境。

- [ ] **Step 2: 新建 `qwen-shared.ts`**

创建 `lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts
// Qwen 联网搜索公共纯函数：三方 MaaS（web-search-qwen）与官方百炼（web-search-qwen-official）共用。
// 设计文档：docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md 3.2
//
// 只放与「响应形态」无关的纯工具：JSON 宽松提取 / 字段清洗 / 分词 / 引用条目映射 / 正文「联网综述」兜底。
// 各适配器自己的解析优先级（顶层 sources[] vs search_info.search_results[]）留在各自文件内。

import type { ResearchItem } from './research-item';

/** 两个适配器的缺省模型名（后台留空时回退） */
export const QWEN_SEARCH_DEFAULT_MODEL = 'qwen-plus';

/** 一条引用命中（松散字段；官方 search_info.search_results[] 的 site_name 由调用方映射到 site） */
export interface SearchHit {
  title?: unknown; url?: unknown; site?: unknown; caption?: unknown;
  snippet?: unknown; content?: unknown;
}

/** 宽松提取 JSON（对象/数组）：直接 parse，失败剥 markdown 代码块后再试，仍失败返回 null */
export function extractJson(text: string): unknown | null {
  const candidates: string[] = [];
  // 设计意图“直接 parse”：原始文本优先；失败再剥 markdown 代码块/对象/数组片段
  candidates.push(text);
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fence) candidates.push(fence[1]);
  const brace = text.match(/\{[\s\S]*\}/);
  if (brace) candidates.push(brace[0]);
  const bracket = text.match(/\[[\s\S]*\]/);
  if (bracket) candidates.push(bracket[0]);
  for (const c of candidates) {
    try { return JSON.parse(c); } catch { /* try next */ }
  }
  return null;
}

/** 取首个非空字符串 */
export function firstStr(...vals: unknown[]): string | undefined {
  for (const v of vals) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return undefined;
}

/** 摘要/标题 → 关键词数组（保留含字母/数字/中日韩字，排除纯符号，前 12） */
export function tokenize(...texts: string[]): string[] {
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

/** 清洗引用字段：去掉 markdown 代码反引号、加粗星号、两端空白，返回干净字符串 */
export function clean(field: string): string {
  return field.replace(/`+|[*_~]+/g, '').trim();
}

/** 引用命中 → ResearchItem（source 由调用方传入，用于区分 qwen / qwen-official） */
export function toResearchItem(hit: SearchHit, source: string): ResearchItem {
  const title = clean(firstStr(hit.title) ?? '');
  const snippet = clean(firstStr(hit.snippet, hit.content) ?? '');
  const url = clean(firstStr(hit.url, hit.site, hit.caption) ?? '');
  return { source, title, snippet, keywords: tokenize(snippet, title), url };
}

/** 正文综述捕获上限：保住节日日历/趋势清单核心信息，同时约束透传载荷 */
export const SUMMARY_SNIPPET_CAP = 2000;

/** message.content 正文综述 → 首条 ResearchItem（title=联网综述）。
 *  仅捕获非 JSON 的实质性文本（结构化 {results} 引用走各适配器的正式解析分支）；
 *  keywords 留空——长综述无分词意义，避免污染下游 keywords 汇集。 */
export function toSummaryItem(msg: Record<string, unknown>, source: string): ResearchItem | null {
  if (typeof msg.content !== 'string') return null;
  const text = msg.content.trim();
  if (!text || extractJson(text)) return null;
  return { source, title: '联网综述', snippet: text.slice(0, SUMMARY_SNIPPET_CAP), keywords: [] };
}
```

- [ ] **Step 3: 等价重构 `web-search-qwen.ts`**

用以下完整内容**整体替换** `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts
// 千问(Qwen)模型自带联网搜索适配器——三方 MaaS 网关形态：直连 Chat Completions + enable_search
// 设计文档：docs/superpowers/specs/2026-09-21-qwen-web-search-design.md 3.1
//          docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md（双通道拆分）
//
// 多形态宽松解析引用：顶层 sources[] / tool_calls.web_search.search_info.search_results[] /
// message.content 数组引用块 / content 文本 JSON{results}。仍取不到任何引用时，
// 退化为保留「联网综述」正文（提示词已要求正文标注来源链接），只有正文也为空才抛 Error
// （上层 allSettled 收集为 sourceErrors，绝不编造 URL）。
//
// 纯函数（extractJson / toResearchItem / toSummaryItem 等）已抽到 ./qwen-shared 与官方适配器共用；
// 本文件保留「三方 MaaS」形态的解析优先级，运行行为与抽取前完全一致（由 web-search-qwen.spec.ts 回归保证）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceLlmCall } from '../llm-trace';
import {
  QWEN_SEARCH_DEFAULT_MODEL,
  extractJson,
  toResearchItem,
  toSummaryItem,
} from './qwen-shared';
import type { SearchHit } from './qwen-shared';

// 保持既有导出面（历史上由本文件导出默认模型名）
export { QWEN_SEARCH_DEFAULT_MODEL } from './qwen-shared';

/** 系统提示词按次构造（注入当天日期）：模块级常量会跨天变旧，导致节日/时效类判断错乱。 */
function buildSystemPrompt(): string {
  return [
    '你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。',
    describeTodayUtc8(),
    '## 硬性要求',
    '1. 凡涉及时效信息（节日、近期热点、季节时令、最新流行趋势），必须以上面的今天日期为基准，并且只采用联网检索到的结果；',
    '   严禁凭训练记忆猜测节日名称或日期（例如把近期节日说成端午）。检索不到的时效信息，直接说明未检索到，不要编造。',
    '2. 主题要求「最近的节日」时，先列出今天之后最近的 1~3 个节日及其公历日期与距今天数，再围绕其中最近的节日给灵感。',
    '3. 输出的每条关键结论都要带可核验的来源链接（markdown 链接或裸 URL）；没有来源支撑的信息不要写。',
  ].join('\n');
}

/** 多形态提取引用 → ResearchItem[]；无引用返回 null */
function extractResearchItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;

  // 0) 解析 message（root.message 或 choices[0].message），供综述捕获与各分支复用
  let msg = root.message && typeof root.message === 'object' ? (root.message as Record<string, unknown>) : null;
  if (!msg && Array.isArray(root.choices) && root.choices.length) {
    const first = root.choices[0];
    if (first && typeof first === 'object' && (first as Record<string, unknown>).message && typeof (first as Record<string, unknown>).message === 'object') {
      msg = (first as Record<string, unknown>).message as Record<string, unknown>;
    }
  }
  if (!msg) return null;

  // 0a) 三方中转站 OpenAI 兼容格式：顶层 sources[]({title,url}) + choices[0].message.content
  //    （如 qwen3.7-max 直连 enable_search 时由网关把引用放到顶层 sources，而非 tool_calls）。
  //    message.content 的正文综述（节日日历/趋势清单类长文本）是最有价值的时效信息，
  //    作为首条「联网综述」条目带出，顶层引用排其后 —— 不再因早返回丢弃正文。
  const topSources = Array.isArray(root.sources) ? (root.sources as SearchHit[]) : [];
  if (topSources.length) {
    const items: ResearchItem[] = [];
    const summary = toSummaryItem(msg, 'qwen');
    if (summary) items.push(summary);
    items.push(...topSources.map((hit) => toResearchItem(hit, 'qwen')).filter((i) => i.title || i.url));
    if (items.length) return items;
  }

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
    const items = results.map((hit) => toResearchItem(hit, 'qwen'));
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
      items.push(toResearchItem({ title: b.title, url: b.url ?? b.link, snippet: b.snippet ?? b.content }, 'qwen'));
    }
    if (items.length) return items;
  }

  // 3) 结构化兜底：content 文本 → Array | { results:[{title,url,content}] }
  if (typeof msg.content === 'string' && msg.content.trim()) {
    const parsed = extractJson(msg.content);
    if (parsed && typeof parsed === 'object') {
      const p = parsed as Record<string, unknown>;
      const list = Array.isArray(parsed) ? (parsed as SearchHit[]) : Array.isArray(p.results) ? (p.results as SearchHit[]) : [];
      const items = list.map((hit) => toResearchItem(hit, 'qwen'));
      if (items.length) return items;
    }
  }

  // 4) 兜底：正文有实质文本但未命中任何结构化引用形态（网关只返正文综述、无顶层 sources）
  //    → 仍作为「联网综述」带出，不再整体丢弃；正文为空/纯 JSON 时才判为未取到引用。
  const fallbackSummary = toSummaryItem(msg, 'qwen');
  if (fallbackSummary) return [fallbackSummary];

  return null;
}

/** 创建千问联网搜索适配器（provider 名 qwen，三方 MaaS 网关形态） */
export function createQwenSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 搜索端点');
      if (!apiKey) throw new Error('Qwen 搜索未配置 API Key，请到后台「研究管线」填写');

      // 实时过程采集：本次既是检索也是大模型调用（enable_search），提示词与原始响应都要留痕
      const handle = traceLlmCall({
        model,
        systemPrompt: buildSystemPrompt(),
        userPrompt: q.query,
        title: '千问联网搜索 · 大模型调用',
      });

      let res: Response;
      try {
        res = await fetch(`${base}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: buildSystemPrompt() },
              { role: 'user', content: q.query },
            ],
            enable_search: true,
            temperature: 0.3,
            max_tokens: 4096,
            response_format: { type: 'json_object' },
          }),
          signal: AbortSignal.timeout(180_000),
        });
      } catch (err) {
        const name = (err as { name?: string } | null | undefined)?.name;
        const message = name === 'AbortError' || name === 'TimeoutError'
          ? `Qwen 网上搜索超时（${q.query}）`
          : `Qwen 网上搜索无效连接（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }

      if (!res.ok) {
        const message = `Qwen 网上搜索上游错误（HTTP ${res.status}，${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      const rawText = await res.text();
      let data: unknown = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        data = null;
      }
      const items = extractResearchItems(data);
      if (!items) {
        const message = `Qwen 网上搜索本次未取到引用（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      handle?.done(items[0]?.title === '联网综述' ? items[0].snippet : items.map((i) => i.title).filter(Boolean).join('、'), {
        rawResponse: rawText,
        resultBrief: `${items.length} 条`,
      });
      return items;
    },
  };
}
```

- [ ] **Step 4: 运行回归测试确认仍通过**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen.spec.ts
```
Expected: PASS（13 passed，与 Step 1 基线一致）。任一条失败说明重构不等价，必须修到全绿。

- [ ] **Step 5: 类型检查**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 无输出、退出码 0。

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts
git commit -m "refactor(ai): 抽取 Qwen 搜索公共纯函数 qwen-shared（三方链路行为不变）"
```

---

### Task 3: 官方百炼适配器 `web-search-qwen-official.ts` + 工厂分发 + 新 spec

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.spec.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts:9,44-58,118-120`

**Interfaces:**
- Consumes（来自 T2）：`QWEN_SEARCH_DEFAULT_MODEL`、`toResearchItem(hit: SearchHit, source: string): ResearchItem`、`toSummaryItem(msg: Record<string, unknown>, source: string): ResearchItem | null`（均来自 `./qwen-shared`）；`WebSearchProvider` / `WebSearchQuery`（`./web-search.provider`）；`traceLlmCall`（`../llm-trace`）；`describeTodayUtc8`（`../../../common/utils/date.util`）。
- Produces：
  - `export function createQwenOfficialSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider`，其 `name === 'qwen-official'`。
  - `createWebSearchProvider('qwen-official', cfg)` 返回该适配器；`web-search.provider.ts` re-export `createQwenOfficialSearchProvider`。

- [ ] **Step 1: 写失败测试**

创建 `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.spec.ts`：

```ts
// web-search-qwen-official.spec.ts
import { createQwenOfficialSearchProvider } from './web-search-qwen-official';
import type { WebSearchProvider } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { runWithTrace } from '../llm-trace';
import type { AiTraceEvent } from '../llm-trace';

/** 官方百炼：仅有顶层 search_info.search_results[]（content 为空，不产生综述条目） */
const OK_SEARCH_INFO = {
  choices: [{ message: { role: 'assistant', content: '' } }],
  search_info: {
    search_results: [
      { index: 1, title: '秋日少女写真', url: 'https://a.example', site_name: 'a.example' },
      { index: 2, title: '胶片感人像', url: '', site_name: 'b.example' }, // url 为空 → 回退 site_name
    ],
  },
};

/** 官方百炼：既有 search_info.search_results[] 又有正文综述（真实联网场景） */
const OK_SEARCH_INFO_WITH_CONTENT = {
  choices: [{ message: { role: 'assistant', content: '这是带来源链接的正文综述（https://a.example）。' } }],
  search_info: {
    search_results: [
      { index: 1, title: '秋日少女写真', url: 'https://a.example', site_name: 'a.example' },
      { index: 2, title: '胶片感人像', url: '', site_name: 'b.example' },
    ],
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

  it('仅有 search_info.search_results → ResearchItem[]（source=qwen-official；url 缺省回退 site_name）', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify(OK_SEARCH_INFO), { status: 200 }));
    const items = await provider.search({ query: '人像', limit: 10 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toBe('https://ws.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions');
    const body = JSON.parse(String((init as RequestInit).body));
    expect(body.enable_search).toBe(true);
    expect(body.search_options).toEqual({ forced_search: true, enable_source: true });
    expect(body.response_format).toBeUndefined(); // 官方走「正文 + search_info」，绝不带强 JSON
    expect(body.temperature).toBe(0.3);
    expect(body.max_tokens).toBe(4096);
    expect((init as RequestInit).headers).toMatchObject({ Authorization: 'Bearer sk-official' });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ source: 'qwen-official', title: '秋日少女写真', url: 'https://a.example' });
    expect(items[1]).toMatchObject({ source: 'qwen-official', title: '胶片感人像', url: 'b.example' });
    expect(Array.isArray(items[0].keywords)).toBe(true);
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
      choices: [{ message: { role: 'assistant', content: '根据检索到的公开资料：中秋为 9/25，国庆为 10/1。' } }],
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
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(JSON.stringify({ choices: [{ message: { content: '   ' } }] }), { status: 200 }));
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
    const sys = (body.messages as { role: string; content: string }[]).find((m) => m.role === 'system')!.content;
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
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen-official.spec.ts
```
Expected: FAIL，`Cannot find module './web-search-qwen-official'`。

- [ ] **Step 3: 新建官方适配器**

创建 `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts
// 千问(Qwen)官方百炼联网搜索适配器：OpenAI 兼容 Chat Completions + enable_search + search_info
// 设计文档：docs/superpowers/specs/2026-09-25-qwen-official-vs-maas-search-design.md 3.1
// 参考：https://docs.bailian.console.aliyun.com/zh/model-studio/web-search
//
// 与三方 MaaS 适配器（web-search-qwen.ts）的三处差异：
// 1) 请求加 search_options.{forced_search,enable_source}：官方模型可能自行判断不检索，
//    研究管线每次都要真实检索且需要来源列表；
// 2) 请求去掉 response_format:{type:'json_object'}：官方联网返回「正文 + search_info」，
//    强 JSON 会丢掉带链接的正文综述；
// 3) 解析与三方适配器「分支 0a」行为对齐，正文综述绝不丢弃：
//    顶层 search_info.search_results[] 命中时，「正文综述」置首、结构化引用（title / url（缺省
//    回退 site_name）/ 摘要）随后；无 search_info 时仅「正文综述」兜底（2000 字上限）；
//    两者皆空 → 抛错（上层 allSettled 收进 sourceErrors，主流程不中断，绝不编造 URL）。

import type { ResearchItem } from './research-item';
import type { WebSearchProvider, WebSearchQuery } from './web-search.provider';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceLlmCall } from '../llm-trace';
import {
  QWEN_SEARCH_DEFAULT_MODEL,
  toResearchItem,
  toSummaryItem,
} from './qwen-shared';

/** 系统提示词按次构造（注入当天日期）：模块级常量会跨天变旧，导致节日/时效类判断错乱。 */
function buildSystemPrompt(): string {
  return [
    '你是资深摄影/时尚编辑，请基于联网检索结果输出对主题的发现。',
    describeTodayUtc8(),
    '## 硬性要求',
    '1. 凡涉及时效信息（节日、近期热点、季节时令、最新流行趋势），必须以上面的今天日期为基准，并且只采用联网检索到的结果；',
    '   严禁凭训练记忆猜测节日名称或日期（例如把近期节日说成端午）。检索不到的时效信息，直接说明未检索到，不要编造。',
    '2. 主题要求「最近的节日」时，先列出今天之后最近的 1~3 个节日及其公历日期与距今天数，再围绕其中最近的节日给灵感。',
    '3. 输出的每条关键结论都要带可核验的来源链接（markdown 链接或裸 URL）；没有来源支撑的信息不要写。',
  ].join('\n');
}

/** 取 message：root.message 或 choices[0].message */
function pickMessage(root: Record<string, unknown>): Record<string, unknown> | null {
  if (root.message && typeof root.message === 'object') return root.message as Record<string, unknown>;
  if (Array.isArray(root.choices) && root.choices.length) {
    const first = root.choices[0];
    if (first && typeof first === 'object') {
      const m = (first as Record<string, unknown>).message;
      if (m && typeof m === 'object') return m as Record<string, unknown>;
    }
  }
  return null;
}

/** 官方形态解析（与三方适配器「分支 0a」行为对齐，正文综述绝不丢弃）：
 *  1) 正文综述（content 为非 JSON 实质文本 → 「联网综述」，2000 字上限、keywords 留空）置首；
 *  2) search_info.search_results[] → 结构化引用（url 缺省回退 site_name）随后；
 *  3) 无 search_info 时仅返回综述兜底；两者皆空 → null（由调用方抛错）。 */
function extractOfficialItems(data: unknown): ResearchItem[] | null {
  if (!data || typeof data !== 'object') return null;
  const root = data as Record<string, unknown>;

  // 正文综述：真实联网场景官方会在正文给带链接的结论，必须保留（不能用引用条目顶替）
  const msg = pickMessage(root);
  const summary = msg ? toSummaryItem(msg, 'qwen-official') : null;

  // 结构化引用：site_name → site，借用 toResearchItem 的 url 回退链（url → site → caption）
  const si = root.search_info && typeof root.search_info === 'object' ? (root.search_info as Record<string, unknown>) : null;
  const results = Array.isArray(si?.search_results) ? (si?.search_results as Record<string, unknown>[]) : [];
  const refs = results
    .map((r) => toResearchItem(
      { title: r.title, url: r.url, site: r.site_name, snippet: r.snippet, content: r.content },
      'qwen-official',
    ))
    .filter((i) => i.title || i.url);

  const items: ResearchItem[] = [];
  if (summary) items.push(summary);
  items.push(...refs);
  return items.length ? items : null;
}

/** 创建千问官方百炼联网搜索适配器（provider 名 qwen-official） */
export function createQwenOfficialSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || '').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const model = (cfg.model || '').trim() || QWEN_SEARCH_DEFAULT_MODEL;

  return {
    name: 'qwen-official',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 官方搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 官方搜索端点');
      if (!apiKey) throw new Error('Qwen 官方搜索未配置 API Key，请到后台「研究管线」填写');

      // 实时过程采集：本次既是检索也是大模型调用（enable_search），提示词与原始响应都要留痕
      const handle = traceLlmCall({
        model,
        systemPrompt: buildSystemPrompt(),
        userPrompt: q.query,
        title: '千问官方联网搜索 · 大模型调用',
      });

      let res: Response;
      try {
        res = await fetch(`${base}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: buildSystemPrompt() },
              { role: 'user', content: q.query },
            ],
            enable_search: true,
            search_options: { forced_search: true, enable_source: true },
            temperature: 0.3,
            max_tokens: 4096,
            // 刻意不带 response_format：官方联网返回「正文 + search_info」，强 JSON 会丢掉带链接的正文综述
          }),
          signal: AbortSignal.timeout(180_000),
        });
      } catch (err) {
        const name = (err as { name?: string } | null | undefined)?.name;
        const message = name === 'AbortError' || name === 'TimeoutError'
          ? `Qwen 官方网上搜索超时（${q.query}）`
          : `Qwen 官方网上搜索无效连接（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }

      if (!res.ok) {
        const message = `Qwen 官方网上搜索上游错误（HTTP ${res.status}，${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      const rawText = await res.text();
      let data: unknown = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        data = null;
      }
      const items = extractOfficialItems(data);
      if (!items) {
        const message = `Qwen 官方网上搜索本次未取到引用（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      handle?.done(items[0]?.title === '联网综述' ? items[0].snippet : items.map((i) => i.title).filter(Boolean).join('、'), {
        rawResponse: rawText,
        resultBrief: `${items.length} 条`,
      });
      return items;
    },
  };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen-official.spec.ts
```
Expected: PASS（11 passed）。

- [ ] **Step 5: 工厂分发接线**

修改 `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts`：

(5a) 第 9 行 `import { createQwenSearchProvider } from './web-search-qwen';` 之后插入新行：

```ts
import { createQwenOfficialSearchProvider } from './web-search-qwen-official';
```

(5b) 第 47-48 行：

```ts
    case 'qwen':
      return createQwenSearchProvider(cfg);
```

替换为：

```ts
    case 'qwen':
      return createQwenSearchProvider(cfg);
    case 'qwen-official':
      return createQwenOfficialSearchProvider(cfg);
```

(5c) 第 120 行 `export { createQwenSearchProvider };` 之后插入：

```ts
export { createQwenOfficialSearchProvider };
```

同时把第 36 行注释 `按名称创建搜索适配器：searxng / baidu / vendor；未知名称 → 抛错。` 替换为：

```ts
 * 按名称创建搜索适配器：searxng / qwen / qwen-official / baidu / vendor；未知名称 → 抛错。
```

- [ ] **Step 6: 运行两个适配器 + 配置相关测试 + 类型检查**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen.spec.ts src/modules/ai/trend-research/web-search-qwen-official.spec.ts src/modules/ai/ai-config.service.spec.ts
pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 两个 spec 全绿（13 + 11 passed），`tsc --noEmit` 无输出、退出码 0。

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.spec.ts lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts
git commit -m "feat(ai): 新增 Qwen 官方百炼搜索适配器并接入 web-search 工厂"
```

---

### Task 4: 后台类型 + 表单四选一（校验 / 保存 / 回显）

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts:453-472,498-513`
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx:67-72,83-92,190-218,256-259,400-417,451-468,479-480,825,855-886`

**Interfaces:**
- Consumes（来自 T1 的后端契约）：字段名 `searchQwenOfficialBaseUrl` / `searchQwenOfficialApiKeyMasked` / `searchQwenOfficialModel`（GET 视图），`searchQwenOfficialBaseUrl` / `searchQwenOfficialApiKey` / `searchQwenOfficialModel`（PUT 请求体）；`searchProvider` 取值 `'qwen-official'`；`searchSources` 取值 `['qwen-official']`。
- Produces：无（UI 终点）。本任务无新增可被 import 的符号，只改类型与组件。

> **验证方式说明**：admin 无该组件的既有测试（`ai-config-form` 无 spec，`vitest run` 无相关用例）。本任务的「测试」= `tsc --noEmit` + `next build` 的类型门禁（JSX/类型错会直接构建失败），因此不需要先写失败测试，而是先改类型让编译驱动出所有需要同步的字段。

- [ ] **Step 1: 改 `types/admin.ts`**

(1a) 第 454-455 行：

```ts
  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（模型自带搜索）| null（未启用） */
  searchProvider: 'general' | 'vendor' | 'qwen' | null;
```

替换为：

```ts
  /** 搜索服务商：'general'（通用搜索 API）| 'vendor'（厂商联网检索）| 'qwen'（三方 MaaS）| 'qwen-official'（官方百炼）| null（未启用） */
  searchProvider: 'general' | 'vendor' | 'qwen' | 'qwen-official' | null;
```

(1b) 第 460-461 行：

```ts
  /** 启用的搜索来源（searxng/vendor/baidu） */
  searchSources: string[];
```

替换为：

```ts
  /** 启用的搜索来源（searxng/vendor/baidu/qwen/qwen-official） */
  searchSources: string[];
```

(1c) 第 468-469 行（`searchQwenModel` 声明）之后追加：

```ts
  /** Qwen 官方百炼搜索端点（searchProvider=qwen-official 时使用） */
  searchQwenOfficialBaseUrl: string;
  /** Qwen 官方百炼搜索 API key（脱敏） */
  searchQwenOfficialApiKeyMasked: string;
  /** Qwen 官方百炼搜索模型（缺省 = qwen-plus） */
  searchQwenOfficialModel: string;
```

(1d) 第 500-501 行：

```ts
  /** 搜索服务商：'general' | 'vendor' | 'off'（关闭） */
  searchProvider?: string;
```

替换为：

```ts
  /** 搜索服务商：'general' | 'vendor' | 'qwen' | 'qwen-official' | 'off'（关闭） */
  searchProvider?: string;
```

(1e) 第 504-505 行：

```ts
  /** 启用的搜索来源（searxng/vendor/baidu） */
  searchSources?: string[];
```

替换为：

```ts
  /** 启用的搜索来源（searxng/vendor/baidu/qwen/qwen-official） */
  searchSources?: string[];
```

(1f) 第 510 行（`searchQwenModel?: string;`）之后追加：

```ts
  searchQwenOfficialBaseUrl?: string;
  searchQwenOfficialApiKey?: string;
  searchQwenOfficialModel?: string;
```

- [ ] **Step 2: 改搜索方式选项常量与 `FormState`**

(2a) 第 67-72 行整体替换为：

```ts
/** 搜索方式（研究管线，四选一互斥）：Qwen 官方百炼 / Qwen 三方 MaaS / SearXNG 自建(免费) / 关闭 */
const SEARCH_MODE_OPTIONS: { value: 'qwen-official' | 'qwen' | 'searxng' | 'off'; label: string }[] = [
  { value: 'qwen-official', label: 'Qwen 官方百炼' },
  { value: 'qwen', label: 'Qwen 三方 MaaS' },
  { value: 'searxng', label: 'SearXNG 自建搜索（免费）' },
  { value: 'off', label: '关闭' },
];
```

(2b) 第 84 行 `searchMode: 'qwen' | 'searxng' | 'off';` 替换为：

```ts
  searchMode: 'qwen-official' | 'qwen' | 'searxng' | 'off';
```

(2c) 第 88-90 行：

```ts
  searchQwenBaseUrl: string;
  searchQwenApiKey: string; // 留空 = 不修改原值
  searchQwenModel: string;
```

替换为：

```ts
  searchQwenBaseUrl: string;
  searchQwenApiKey: string; // 留空 = 不修改原值
  searchQwenModel: string;
  searchQwenOfficialBaseUrl: string;
  searchQwenOfficialApiKey: string; // 留空 = 不修改原值
  searchQwenOfficialModel: string;
```

- [ ] **Step 3: 改初始 state（回显）**

(3a) 第 190-192 行：

```ts
          searchMode: initial.searchEnabled
            ? (initial.searchProvider === 'qwen' ? 'qwen' : 'searxng')
            : 'off',
```

替换为：

```ts
          searchMode: initial.searchEnabled
            ? initial.searchProvider === 'qwen-official'
              ? 'qwen-official'
              : initial.searchProvider === 'qwen'
                ? 'qwen'
                : 'searxng'
            : 'off',
```

(3b) 第 196-198 行：

```ts
          searchQwenBaseUrl: initial.searchQwenBaseUrl,
          searchQwenApiKey: '',
          searchQwenModel: initial.searchQwenModel,
```

替换为：

```ts
          searchQwenBaseUrl: initial.searchQwenBaseUrl,
          searchQwenApiKey: '',
          searchQwenModel: initial.searchQwenModel,
          searchQwenOfficialBaseUrl: initial.searchQwenOfficialBaseUrl,
          searchQwenOfficialApiKey: '',
          searchQwenOfficialModel: initial.searchQwenOfficialModel,
```

(3c) 第 214-216 行（未配置分支）：

```ts
          searchQwenBaseUrl: '',
          searchQwenApiKey: '',
          searchQwenModel: '',
```

替换为：

```ts
          searchQwenBaseUrl: '',
          searchQwenApiKey: '',
          searchQwenModel: '',
          searchQwenOfficialBaseUrl: '',
          searchQwenOfficialApiKey: '',
          searchQwenOfficialModel: '',
```

(3d) 第 256-259 行：

```ts
  /** 已保存 Qwen 搜索 API 的脱敏 Key（占位符展示） */
  const [searchQwenApiKeyMasked, setSearchQwenApiKeyMasked] = useState(
    configured ? initial.searchQwenApiKeyMasked : '',
  );
```

替换为：

```ts
  /** 已保存 Qwen 搜索 API 的脱敏 Key（占位符展示） */
  const [searchQwenApiKeyMasked, setSearchQwenApiKeyMasked] = useState(
    configured ? initial.searchQwenApiKeyMasked : '',
  );
  /** 已保存 Qwen 官方百炼搜索 API 的脱敏 Key（占位符展示） */
  const [searchQwenOfficialApiKeyMasked, setSearchQwenOfficialApiKeyMasked] = useState(
    configured ? initial.searchQwenOfficialApiKeyMasked : '',
  );
```

- [ ] **Step 4: 改校验逻辑**

第 400 行 `if (form.searchMode === 'qwen') {` 之前插入官方分支：

```ts
    if (form.searchMode === 'qwen-official') {
      if (!form.searchQwenOfficialBaseUrl.trim()) {
        toast({
          variant: 'destructive',
          title: '请填写完整',
          description: 'Qwen 官方搜索必须填写 baseUrl',
        });
        return;
      }
      if (!searchQwenOfficialApiKeyMasked && !form.searchQwenOfficialApiKey.trim()) {
        toast({
          variant: 'destructive',
          title: '缺少 API Key',
          description: '首次启用 Qwen 官方搜索必须填写 API Key',
        });
        return;
      }
    } else if (form.searchMode === 'qwen') {
```

（即把原 `if (form.searchMode === 'qwen') {` 改为上方的 `} else if (form.searchMode === 'qwen') {`，保持后续 `searxng` 的 `else if` 链不变。）

- [ ] **Step 5: 改保存 payload**

第 451-454 行：

```ts
      // 研究管线（Agentic）：搜索方式三选一 → provider/sources/字段映射
      payload.searchEnabled = form.searchMode !== 'off';
      payload.maxIterations = form.maxIterations;
      if (form.searchMode === 'qwen') {
```

替换为：

```ts
      // 研究管线（Agentic）：搜索方式四选一互斥 → provider/sources/字段映射
      payload.searchEnabled = form.searchMode !== 'off';
      payload.maxIterations = form.maxIterations;
      if (form.searchMode === 'qwen-official') {
        payload.searchProvider = 'qwen-official';
        payload.searchSources = ['qwen-official'];
        if (form.searchQwenOfficialBaseUrl.trim()) payload.searchQwenOfficialBaseUrl = form.searchQwenOfficialBaseUrl.trim();
        if (form.searchQwenOfficialApiKey.trim()) payload.searchQwenOfficialApiKey = form.searchQwenOfficialApiKey.trim();
        payload.searchQwenOfficialModel = form.searchQwenOfficialModel.trim() || 'qwen-plus';
      } else if (form.searchMode === 'qwen') {
```

- [ ] **Step 6: 改保存后回填**

第 480 行 `setSearchQwenApiKeyMasked(config.searchQwenApiKeyMasked);` 之后插入：

```ts
      setSearchQwenOfficialApiKeyMasked(config.searchQwenOfficialApiKeyMasked);
```

- [ ] **Step 7: 改 JSX（区块标题 + 新增官方字段块 + 三方文案）**

(7a) 第 825 行 `{/* 研究管线（Agentic）：搜索方式三选一 */}` 替换为：

```tsx
          {/* 研究管线（Agentic）：搜索方式四选一（互斥） */}
```

(7b) 在第 855 行 `{form.searchMode === 'qwen' && (` **之前**插入官方字段块：

```tsx
            {form.searchMode === 'qwen-official' && (
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-base-url">Qwen 官方端点（Base URL）</Label>
                  <Input
                    id="ai-qwen-official-base-url"
                    value={form.searchQwenOfficialBaseUrl}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialBaseUrl: e.target.value }))}
                    placeholder="https://{WorkspaceId}.cn-beijing.maas.aliyuncs.com/compatible-mode/v1"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-api-key">Qwen 官方 API Key</Label>
                  <Input
                    id="ai-qwen-official-api-key"
                    type="password"
                    value={form.searchQwenOfficialApiKey}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialApiKey: e.target.value }))}
                    placeholder={searchQwenOfficialApiKeyMasked ? `${searchQwenOfficialApiKeyMasked}（留空 = 不修改）` : '…'}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-qwen-official-model">Qwen 官方模型</Label>
                  <Input
                    id="ai-qwen-official-model"
                    value={form.searchQwenOfficialModel}
                    onChange={(e) => setForm((f) => ({ ...f, searchQwenOfficialModel: e.target.value }))}
                    placeholder="qwen-plus"
                  />
                </div>
              </div>
            )}

```

(7c) 把第 858 行 `Qwen 搜索端点（Base URL）` 替换为 `Qwen 三方 MaaS 端点（Base URL）`、第 867 行 `Qwen 搜索 API Key` 替换为 `Qwen 三方 MaaS API Key`、第 877 行 `Qwen 搜索模型` 替换为 `Qwen 三方 MaaS 模型`（仅文案，`id`/`value`/`onChange` 不变）。

- [ ] **Step 8: 类型检查（构建门禁）**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/shared build; pnpm --filter @lumira/admin exec tsc --noEmit
```
Expected: 无输出、退出码 0。若报 `Property 'searchQwenOfficialBaseUrl' does not exist`，说明 Step 1/3 未同步。

- [ ] **Step 9: Lint + Build**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/admin lint
pnpm --filter @lumira/admin build
```
Expected: `lint` 无 error；`build` 输出 `Compiled successfully` 与路由表（若 `next build` 因 SSR 阶段缺 `BACKEND_URL` 报错，用 `pnpm --filter @lumira/admin exec tsc --noEmit` 的结果作为本任务门禁并在提交信息中说明）。

- [ ] **Step 10: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(admin): AI 配置搜索方式四选一，新增 Qwen 官方百炼字段与校验"
```

---

### Task 5: 全量验证（typecheck + 相关单测 + admin build）

**Files:**
- 无文件改动（纯验证门禁）；若发现失败，回到对应 Task 修复后再跑。

**Interfaces:**
- Consumes：T1–T4 的全部产出。
- Produces：可发布的绿线证据（命令 + 期望输出）。

- [ ] **Step 1: 构建 shared（backend / admin 都依赖）**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/shared build
```
Expected: tsc 无错误、退出码 0。

- [ ] **Step 2: 后端类型检查**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 无输出、退出码 0（等同 CI `.github/workflows/backend-ci.yml` 的 Typecheck 步骤）。

- [ ] **Step 3: 后端相关单测（本次改动三处）**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test -- src/modules/ai/trend-research/web-search-qwen.spec.ts src/modules/ai/trend-research/web-search-qwen-official.spec.ts src/modules/ai/ai-config.service.spec.ts
```
Expected: `Test Suites: 3 passed, 3 total`，`Tests:` 全 passed（三方回归 13 + 官方 9 + 配置 ~40）。

- [ ] **Step 4: 后端全量单测（确保无波及）**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/backend test
```
Expected: 全部 suites passed，0 failed。若有既存与本改动无关的失败，记录清单并在提交信息中标注。

- [ ] **Step 5: 后台类型检查 + Lint + Build**

Run（在 `lumira-server/` 目录）：
```powershell
pnpm --filter @lumira/admin exec tsc --noEmit
pnpm --filter @lumira/admin lint
pnpm --filter @lumira/admin build
```
Expected: 三者均无 error；`build` 打印 `Compiled successfully`（Vercel 走同一套 `vercel.json` 命令）。

- [ ] **Step 6: 自检勾选（人工过一遍硬约束）**

- [ ] 官方 provider 名是 `qwen-official`；三方仍是 `qwen`。
- [ ] 官方请求体含 `enable_search: true` + `search_options: { forced_search: true, enable_source: true }`，且**不含** `response_format`（T3 spec 已断言）。
- [ ] 官方解析与三方「分支 0a」对齐：正文综述置首、`search_info.search_results[]` 引用随后（`url` 缺省回退 `site_name`；综述 2000 字上限、keywords 留空）；无 `search_info` 时仅综述兜底；皆空抛错。
- [ ] 缺端点/Key → `sources: []`，未触碰任何 `skip-research` 写入路径（`getSearchConfig()` 只返回 `sources`，不写标记）。
- [ ] 现有 `search_qwen_*` 三列与 `qwen` 分支零改动（仅注释/文案），迁移只新增三列。
- [ ] `lumira-app/` 无任何改动。

- [ ] **Step 7: 记录提交**

若 Step 6 过程中有微调，按所属 Task 追加提交：

```bash
git add <被修改的文件>
git commit -m "chore(ai): Qwen 官方/三方搜索双通道全量验证微调"
```

---

## Self-Review

**1. Spec coverage**
- 规格 3.1 官方适配器（请求体三差异 + 解析：综述置首/引用随后、无 `search_info` 仅综述兜底、皆空抛错）→ Task 3。
- 规格 3.2 公共工具 `qwen-shared.ts` → Task 2。
- 规格 3.3 迁移 + DTO + `getSearchConfig` 分支 + `parseSearchSources` 白名单 + `getActiveConfig().search.provider` union + 工厂分发 → Task 1（工厂分发落在 Task 3 Step 5，因其依赖适配器文件）。
- 规格 3.4 后台表单四选一 + `types/admin.ts` → Task 4。
- 规格 四 错误处理（AbortSignal 超时 / 非 2xx / 无引用 / 非法 JSON 抛可读中文错误 / allSettled 入 sourceErrors / 主流程不中断）→ Task 3 实现（复用现有链路，未改 `trend-research.service.ts` 的 `allSettled`）。
- 规格 五 测试 → Task 1（配置面 10 用例）、Task 3（官方 11 用例）、Task 2（三方回归）。
- 规格 六 不做项 → Global Constraints 明列，未引入 Responses API / 并联 / 主对话端点改动。
- 规格 七 落地顺序 → T1→T2→T3→T4→T5 一致（唯一差异：迁移序号 `046`，已在 Global Constraints 标注待确认）。

**2. Placeholder scan**：无 "TODO" / "适当处理" / "参考 Task N"；每个改代码的 Step 都给出完整可粘贴代码块；测试 Step 给出完整 spec 代码；命令均来自 `package.json` / `lumira-server/package.json` / CI workflow 实证。

**3. Type consistency**：字段名在 T1（schema/DTO/service/AiConfigView）与 T4（`types/admin.ts` / 表单 state / payload）完全一致：`searchQwenOfficialBaseUrl` / `searchQwenOfficialApiKey` / `searchQwenOfficialApiKeyMasked` / `searchQwenOfficialModel`；provider 名全程 `qwen-official`；共享函数签名在 T2 定义、T3 按同一签名调用（`toResearchItem(hit, source)`、`toSummaryItem(msg, source)`）。
