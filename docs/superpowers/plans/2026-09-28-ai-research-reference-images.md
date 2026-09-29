# AI 参考图抓取 → 多模态转述 → 识别流程可视化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 联网检索后三层递进抓取参考网站图片（短 TTL 落盘），交给多模态模型转述成文字注入生图提示词，并在后台识别流程时间线中可视化「参考了哪些图 / 哪些被采纳」。

**Architecture:** 全部新增逻辑归属 `lumira-server/packages/backend/src/modules/ai/trend-research/`；两个新阶段（`researchImages` 抓图、`researchVision` 解读）串接在 `TrendResearchService.research()` 内、用 `traceStep` 包裹，天然获得 `parentStep='research'`；结果经 `ResearchResult` → `AiAnalyzeResult` → 任务对象 → 状态接口 → admin 时间线/结果弹窗。生图侧把 `vision` 文本与 `brief` 并列注入 `composeImagePrompt`。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8；`sharp`（压缩/尺寸探测）；`node:dns/promises`（SSRF DNS 校验）；`node:crypto`（sha256）；进程内 `LruCache`；Next.js App Router + Tailwind + shadcn/ui（admin）。

## Global Constraints

- 权威设计文档：`docs/superpowers/specs/2026-09-28-ai-research-reference-images-design.md`（下称「spec」）。与本计划冲突处以本计划为准（本计划已修正 spec 的两处错误，见下）。
- **迁移编号修正**：spec 第 8 章写的 `043_ai_config_research_images.sql` 已过时——`src/database/migrations/` 现有最高为 `047_ai_config_llm_stability.sql`。本计划使用 **`048_ai_config_research_images.sql`**。
- **多模态修正**：spec 6.2 称「`llm-client` 已支持 `image_url` 多模态消息」不准确——现有 `visionChat` 只接受**单张**图。本计划新增 `visionChatMulti`，**不改动** `visionChat`。
- **存储修正**：`StorageAdapter.write(category, id, filename)` 的 category 白名单不含 `research`，且产出路径为 `/uploads/{category}/{id}/{filename}`，与 spec 4.3 的扁平 `uploads/research/{id}.jpg` 不符。本计划**不走存储适配器**，直接 fs 写 `{UPLOAD_DIR}/research/{id}.jpg`；URL 用 `process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000'` 拼接（对齐 `admin-templates.service.ts` 的 `buildPublicUrl`）。
- **图片格式恒为 JPEG**：抓到的候选图统一经 sharp 重编码为 `jpeg q80`、长边 ≤1280，故文件名恒为 `{id}.jpg`，`ResearchImage` 不需要 `ext` 字段。
- **绝不作 img2img 底图**：参考图只用于多模态转述与后台核查，`image-client.ts` 的 `referenceBase64` 通道不变。
- **任何图片相关失败一律不阻断识别主流程**（与既有 `sourceErrors` 取向一致）。
- Flutter 端与 `lumira-app/`（已废弃 uni-app）**不涉及**。
- 后端 Dart 无关；后端测试命令 `pnpm --filter @lumira/backend test`，类型检查 `pnpm --filter @lumira/backend typecheck`；admin 验证 `pnpm --filter @lumira/admin build`。
- 每个后端 / admin 任务完成后立即 commit 并**同时推送两个远程**：`git push origin master` 与 `git push github master`。

---

## 文件结构

**新建（backend，全部在 `lumira-server/packages/backend/src/modules/ai/trend-research/`）**

| 文件 | 职责 |
|---|---|
| `research-image.ts` | 参考图数据模型（`ResearchImage` / `ResearchImagesResult` / `ResearchImagesConfig` / `ImageCandidate` / `TraceImage`）+ 常量 + `toTraceImage` |
| `research-image-fetch.ts` | 纯抓取工具：SSRF 校验、受控重定向下载、限流读体、图片白名单校验、页面 HTML 抓取、`og:image` 提取 |
| `research-image-store.ts` | 落盘与生命周期：URL/内容哈希、压缩写盘、读盘、公网 URL 拼接、TTL 清理 |
| `research-image.service.ts` | 三层递进编排（并发 3 + 20s 软预算）+ 定时清理 + `readBase64` |
| `research-vision.ts` | `ResearchVision` 类型 / `normalizeVision` / `visionHasContent` / `renderResearchVision` |
| `research-vision.service.ts` | 多模态解读（一次调用带 N 张图） |

**新建（admin）**

| 文件 | 职责 |
|---|---|
| `lumira-server/packages/admin/src/components/ai-create/trace-image-grid.tsx` | 参考图缩略图网格（来源域名 / 命中检索词 / 「已采用」徽标 / 点击看大图 / 加载失败占位） |

**修改（backend）**

- `trend-research/research-item.ts`（`imgUrl` 语义注释）
- `trend-research/web-search.provider.ts`（`WebSearchQuery.categories`、工厂透传、缓存键补 categories）
- `trend-research/web-search-searxng.ts`（`categories` 请求参数 + 图片字段映射）
- `trend-research/qwen-shared.ts`（`SearchHit` 图片字段 + `toResearchItem` 映射）
- `trend-research/web-search-qwen-official.ts`（图片字段透传）
- `trend-research/trend-research.service.ts`（`SearchConfig.images` / `imageSource`、串接两阶段、`ResearchResult` 扩展）
- `trend-research/index.ts`（导出新模块）
- `trend-research/ai-config` 相关：`dto/update-ai-config.dto.ts`、`ai-config.service.ts`、`database/schema.ts`、`database/migrations/048_ai_config_research_images.sql`
- `llm-trace.ts`（`images` / `adoptedImageIds` 字段 + `traceStep` 的 `attach` 参数）
- `llm-client.ts`（`visionChatMulti`）
- `ai-analyze.service.ts`（回传 `researchImages` / `researchVision`）
- `ai-templates.controller.ts`（状态接口回传）
- `ai-generate-image.service.ts`（解析 `vision`）
- `image-prompt.composer.ts`（`vision` 入参 +【参考视觉要点】区块）

**修改（admin）**

- `src/types/admin.ts`、`src/components/ai-create/analyze-trace-stream.tsx`、`src/components/ai-create/analyze-result-dialog.tsx`、`src/components/ai-config-form.tsx`、`src/lib/ai-task.ts`、`src/components/ai-create/wizard.tsx`、`src/components/ai-create/step-cover.tsx`

**修改（部署）**

- `deploy/searxng/settings.yml`（启用 `sogou images` 引擎）

---

### Task 1: 数据层（参考图 + 视觉结论类型与归一化）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.spec.ts`

**Interfaces:**
- Consumes: 无（纯类型 + 纯函数）
- Produces:
  - `type ResearchImageLayer = 'metadata' | 'page' | 'image-search'`
  - `interface ResearchImage { id: string; url: string; sourceUrl: string; pageUrl?: string; source: string; query?: string; layer: ResearchImageLayer; width?: number; height?: number; bytes: number }`
  - `interface ResearchImagesResult { images: ResearchImage[]; errors: { name: string; error: string }[] }`
  - `interface ResearchImagesConfig { enabled: boolean; max: number; pageFetch: boolean; searchFallback: boolean; vision: boolean; ttlDays: number }`
  - `const DEFAULT_RESEARCH_IMAGES_CONFIG: ResearchImagesConfig`
  - `interface ImageCandidate { sourceUrl: string; pageUrl?: string; source: string; query?: string; layer: ResearchImageLayer }`
  - `interface TraceImage { id: string; url: string; sourceUrl?: string; pageUrl?: string; source: string; query?: string }`
  - `function toTraceImage(img: ResearchImage): TraceImage` / `function toTraceImages(images: ResearchImage[]): TraceImage[]`
  - 常量：`RESEARCH_IMAGE_MAX_BYTES = 5 * 1024 * 1024`、`RESEARCH_IMAGE_MIN_SIDE = 400`、`RESEARCH_IMAGE_MAX_SIDE = 1280`、`RESEARCH_IMAGE_JPEG_QUALITY = 80`、`RESEARCH_IMAGE_CONCURRENCY = 3`、`RESEARCH_IMAGE_TOTAL_BUDGET_MS = 20_000`、`RESEARCH_IMAGE_FETCH_TIMEOUT_MS = 5_000`、`RESEARCH_IMAGE_PAGE_TIMEOUT_MS = 5_000`、`RESEARCH_IMAGE_ALLOWED_MIMES: string[]`
  - `interface ResearchVision { summary: string; styles: string[]; colorLight: string[]; composition: string[]; wardrobe: string[]; scene: string[]; adopted: { id: string; reason: string }[] }`
  - `function normalizeVision(raw: unknown, allowedIds?: Iterable<string>): ResearchVision | null`
  - `function visionHasContent(v: ResearchVision): boolean`
  - `function renderResearchVision(v: ResearchVision): string`

- [ ] **Step 1: 写 `research-image.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image.ts
// 参考图抓取的数据模型与常量（spec 2026-09-28-ai-research-reference-images-design.md 第 4 章）

/** 命中的哪一层：检索条目自带图 / 命中页面解析 / 图片搜索兜底 */
export type ResearchImageLayer = 'metadata' | 'page' | 'image-search';

/** 一张已抓取落盘的参考图 */
export interface ResearchImage {
  /** 内容哈希（sha256 前 16 位）：去重键 + 落盘文件名 */
  id: string;
  /** 落盘后的公网可访问 URL */
  url: string;
  /** 原图地址（外链，仅作溯源展示，不保证可访问） */
  sourceUrl: string;
  /** 来源页面 URL（若图片来自网页解析） */
  pageUrl?: string;
  /** 来源标识：引擎名（searxng / qwen-official / vendor）或页面域名 */
  source: string;
  /** 命中的检索词 */
  query?: string;
  layer: ResearchImageLayer;
  width?: number;
  height?: number;
  bytes: number;
}

/** 参考图抓取整体结果 */
export interface ResearchImagesResult {
  images: ResearchImage[];
  /** 单条抓取失败原因（不阻断主流程） */
  errors: { name: string; error: string }[];
}

/** 参考图抓取配置（由 ai-config 提供） */
export interface ResearchImagesConfig {
  enabled: boolean;
  /** 每主题最多保留张数 */
  max: number;
  /** 是否启用第二层（抓页面 og:image） */
  pageFetch: boolean;
  /** 是否启用第三层（图片搜索兜底） */
  searchFallback: boolean;
  /** 是否启用多模态解读 */
  vision: boolean;
  /** 落盘图片保留天数 */
  ttlDays: number;
}

export const DEFAULT_RESEARCH_IMAGES_CONFIG: ResearchImagesConfig = {
  enabled: false,
  max: 6,
  pageFetch: true,
  searchFallback: true,
  vision: true,
  ttlDays: 7,
};

/** 尚未抓取的候选图 */
export interface ImageCandidate {
  sourceUrl: string;
  pageUrl?: string;
  source: string;
  query?: string;
  layer: ResearchImageLayer;
}

/** trace 事件里携带的精简图（只留展示必需字段，不含宽高/体积） */
export interface TraceImage {
  id: string;
  url: string;
  sourceUrl?: string;
  pageUrl?: string;
  source: string;
  query?: string;
}

export function toTraceImage(img: ResearchImage): TraceImage {
  return {
    id: img.id,
    url: img.url,
    sourceUrl: img.sourceUrl || undefined,
    pageUrl: img.pageUrl || undefined,
    source: img.source,
    query: img.query || undefined,
  };
}

export function toTraceImages(images: ResearchImage[]): TraceImage[] {
  return images.map(toTraceImage);
}

// ===== 管线护栏常量（spec 5.3 / 5.4）=====

/** 单张下载体积上限 */
export const RESEARCH_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
/** 尺寸门槛：任一边小于此值丢弃 */
export const RESEARCH_IMAGE_MIN_SIDE = 400;
/** 落盘长边上限 */
export const RESEARCH_IMAGE_MAX_SIDE = 1280;
/** 落盘 JPEG 质量 */
export const RESEARCH_IMAGE_JPEG_QUALITY = 80;
/** 抓取并发上限 */
export const RESEARCH_IMAGE_CONCURRENCY = 3;
/** 整体软预算（超预算即停止抓取，用已得结果） */
export const RESEARCH_IMAGE_TOTAL_BUDGET_MS = 20_000;
/** 单图下载超时 */
export const RESEARCH_IMAGE_FETCH_TIMEOUT_MS = 5_000;
/** 单页 HTML 抓取超时 */
export const RESEARCH_IMAGE_PAGE_TIMEOUT_MS = 5_000;
/** 重定向最大跳数 */
export const RESEARCH_IMAGE_MAX_REDIRECTS = 3;
/** content-type 白名单 */
export const RESEARCH_IMAGE_ALLOWED_MIMES = ['image/jpeg', 'image/png', 'image/webp'];
```

- [ ] **Step 2: 写 `research-vision.spec.ts` 的失败用例**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.spec.ts
import { normalizeVision, renderResearchVision, visionHasContent } from './research-vision';

describe('normalizeVision', () => {
  it('非对象 / 数组 / null → null', () => {
    expect(normalizeVision(null)).toBeNull();
    expect(normalizeVision([])).toBeNull();
    expect(normalizeVision('x')).toBeNull();
  });

  it('全空 → null', () => {
    expect(normalizeVision({})).toBeNull();
    expect(normalizeVision({ summary: '  ', styles: [], adopted: [] })).toBeNull();
  });

  it('去重 / 去空 / 截断', () => {
    const v = normalizeVision({ styles: ['新中式', '新中式', '', ' 胶片感 '], summary: '一句话' });
    expect(v?.styles).toEqual(['新中式', '胶片感']);
    expect(v?.summary).toBe('一句话');
  });

  it('adopted 只保留 allowedIds 内且带 reason 的项', () => {
    const raw = { scene: ['咖啡馆'], adopted: [{ id: 'a', reason: '光线好' }, { id: 'b', reason: '' }, { id: 'zz', reason: '不存在' }] };
    const v = normalizeVision(raw, new Set(['a', 'b']));
    expect(v?.adopted).toEqual([{ id: 'a', reason: '光线好' }]);
  });

  it('未传 allowedIds 时不做 id 过滤', () => {
    const v = normalizeVision({ scene: ['街景'], adopted: [{ id: 'a', reason: '构图佳' }] });
    expect(v?.adopted).toEqual([{ id: 'a', reason: '构图佳' }]);
  });

  it('有内容时 visionHasContent 为 true', () => {
    const v = normalizeVision({ colorLight: ['暖调逆光'] });
    expect(v).not.toBeNull();
    expect(visionHasContent(v!)).toBe(true);
  });
});

describe('renderResearchVision', () => {
  it('渲染分节小标题与采纳说明', () => {
    const v = normalizeVision({ summary: '暖调逆光氛围', styles: ['新中式'], scene: ['咖啡馆'] })!;
    const text = renderResearchVision(v);
    expect(text).toContain('风格倾向：新中式');
    expect(text).toContain('场景：咖啡馆');
    expect(text).toContain('综合结论：暖调逆光氛围');
  });
});
```

- [ ] **Step 3: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- research-vision.spec`
Expected: FAIL（`Cannot find module './research-vision'`）

- [ ] **Step 4: 写 `research-vision.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.ts
// 参考图多模态转述产物（结构化）：由多模态模型看图后产出可注入生图提示词的视觉结论。
// 与 research-brief.ts 同构：宽松归一化 + 渲染为分节文本块。

/** 参考图多模态解读结论 */
export interface ResearchVision {
  /** 一句话结论（时间线 resultBrief / 后台展示） */
  summary: string;
  styles: string[];
  colorLight: string[];
  composition: string[];
  wardrobe: string[];
  scene: string[];
  /** 真正被采纳的图（id 对应 ResearchImage.id）+ 采纳理由 */
  adopted: { id: string; reason: string }[];
}

/** 渲染总长上限 */
const TOTAL_CAP = 1200;
/** 单项条目上限 */
const ITEM_CAP = 60;
/** 单个数组最多条目数 */
const LIST_CAP = 10;
/** summary 长度上限 */
const SUMMARY_CAP = 160;
/** adopted 最多条数 */
const ADOPTED_CAP = 8;

function toStr(v: unknown, cap: number): string {
  if (typeof v !== 'string') return '';
  const s = v.trim();
  return s.length > cap ? s.slice(0, cap) : s;
}

/** 字符串数组归一化：去空、去重、限长、限条目数 */
function toStrList(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of v) {
    const s = toStr(raw, ITEM_CAP);
    if (!s || seen.has(s)) continue;
    seen.add(s);
    out.push(s);
    if (out.length >= LIST_CAP) break;
  }
  return out;
}

/** 是否含有效内容（全空 → 视为解读失败） */
export function visionHasContent(v: ResearchVision): boolean {
  return Boolean(
    v.summary ||
      v.styles.length ||
      v.colorLight.length ||
      v.composition.length ||
      v.wardrobe.length ||
      v.scene.length,
  );
}

/**
 * 模型原始 JSON → ResearchVision。
 * allowedIds 提供时（真实存在的图片 id），adopted 只保留其中的项，防止模型编造 id。
 */
export function normalizeVision(raw: unknown, allowedIds?: Iterable<string>): ResearchVision | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const rec = raw as Record<string, unknown>;
  const allow = allowedIds ? new Set(allowedIds) : null;

  const adopted: { id: string; reason: string }[] = [];
  const seen = new Set<string>();
  if (Array.isArray(rec.adopted)) {
    for (const item of rec.adopted) {
      if (typeof item !== 'object' || item === null) continue;
      const it = item as Record<string, unknown>;
      const id = toStr(it.id, 64);
      const reason = toStr(it.reason, ITEM_CAP);
      if (!id || !reason || seen.has(id)) continue;
      if (allow && !allow.has(id)) continue;
      seen.add(id);
      adopted.push({ id, reason });
      if (adopted.length >= ADOPTED_CAP) break;
    }
  }

  const vision: ResearchVision = {
    summary: toStr(rec.summary, SUMMARY_CAP),
    styles: toStrList(rec.styles),
    colorLight: toStrList(rec.colorLight),
    composition: toStrList(rec.composition),
    wardrobe: toStrList(rec.wardrobe),
    scene: toStrList(rec.scene),
    adopted,
  };
  return visionHasContent(vision) ? vision : null;
}

/** 分节定义（顺序即渲染顺序，非空才输出） */
const SECTIONS: { label: string; pick: (v: ResearchVision) => string[] }[] = [
  { label: '风格倾向', pick: (v) => v.styles },
  { label: '色彩与光影', pick: (v) => v.colorLight },
  { label: '构图', pick: (v) => v.composition },
  { label: '穿搭/妆造', pick: (v) => v.wardrobe },
  { label: '场景', pick: (v) => v.scene },
];

/** 渲染为带分节小标题的文本块（注入生图提示词） */
export function renderResearchVision(v: ResearchVision): string {
  const lines: string[] = [];
  for (const { label, pick } of SECTIONS) {
    const vals = pick(v);
    if (vals.length) lines.push(`- ${label}：${vals.join('；')}`);
  }
  if (v.summary) lines.push(`- 综合结论：${v.summary}`);
  return lines.join('\n').slice(0, TOTAL_CAP);
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- research-vision.spec`
Expected: PASS（7 个用例）

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/research-image.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.spec.ts
git commit -m "feat(ai): 新增参考图与视觉结论数据层"
```

---

### Task 2: 检索层（categories 透传 + 图片字段映射）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search.provider.ts:18-24,41-62,78-95`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.ts:13-17,38-79`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/qwen-shared.ts:14-17,65-70`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen-official.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/research-item.ts:15`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-searxng.spec.ts`

**Interfaces:**
- Consumes: Task 1 无直接依赖
- Produces:
  - `WebSearchQuery` 新增 `categories?: string`
  - `createWebSearchProvider(cfg: { baseUrl?: string; apiKey?: string; model?: string; site?: string; categories?: string; vendorEndpoint?: LlmEndpoint })`
  - `SearxngResult` 支持 `img_src` / `thumbnail` / `thumbnail_src`，映射进 `ResearchItem.imgUrl`
  - `toResearchItem(hit, source)` 支持 `SearchHit.imgSrc?` / `SearchHit.thumbnail?` / `SearchHit.thumbnailSrc?` → `imgUrl`

- [ ] **Step 1: 写失败用例（追加到现有 spec）**

在 `web-search-searxng.spec.ts` 末尾追加：

```ts
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
```

（若文件已 `import` 了 `createSearxngSearchProvider` 与 `global.fetch` 处理范式则复用；否则按文件内既有 `describe` 风格补 import。）

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- web-search-searxng.spec`
Expected: FAIL（`categories` 未被拼进 URL / `imgUrl` 为 undefined）

- [ ] **Step 3: 改 `web-search.provider.ts`**

`WebSearchQuery`（第 18-24 行）改为：

```ts
export interface WebSearchQuery {
  query: string;
  /** 返回条数上限 */
  limit?: number;
  /** 可选来源限定 */
  source?: string;
  /** 可选结果类别（如 'images' 走图片搜索；缺省为综合网页搜索） */
  categories?: string;
}
```

工厂签名（第 41-44 行）改为：

```ts
export function createWebSearchProvider(
  providerName: string,
  cfg: { baseUrl?: string; apiKey?: string; model?: string; site?: string; categories?: string; vendorEndpoint?: LlmEndpoint },
): WebSearchProvider {
```

`searxng` 分支（第 47-48 行）改为透传 categories：

```ts
    case 'searxng':
      return createSearxngSearchProvider(cfg);
```

（`createSearxngSearchProvider` 的 cfg 类型同时扩展 `categories?: string`，见 Task 2 Step 4。）

缓存键（第 79 行）改为（**必须补 categories，否则图片搜索与文本搜索串味**）：

```ts
  const key = `${provider.name}|${q.query}|${q.limit ?? 10}|${q.categories ?? ''}`;
```

- [ ] **Step 4: 改 `web-search-searxng.ts`**

`SearxngResult`（第 13-17 行）改为：

```ts
/** searxng 结果条目最小字段 */
interface SearxngResult {
  title?: unknown;
  url?: unknown;
  content?: unknown;
  img_src?: unknown;
  thumbnail?: unknown;
  thumbnail_src?: unknown;
}
```

工厂签名（第 38 行）与请求参数（第 47-49 行）改为：

```ts
export function createSearxngSearchProvider(cfg: { baseUrl?: string; apiKey?: string; site?: string; categories?: string }): WebSearchProvider {
  const base = (cfg.baseUrl || 'http://lumira-searxng:8080').replace(/\/+$/, '');
  const apiKey = cfg.apiKey || '';
  const site = (cfg.site || '').trim();
  const categories = (cfg.categories || '').trim();

  return {
    name: site ? `searxng:${site}` : 'searxng',
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      const query = site ? `site:${site} ${q.query}` : q.query;
      const params = new URLSearchParams({ q: query, format: 'json', language: 'zh-CN' });
      const cats = (q.categories ?? categories).trim();
      if (cats) params.set('categories', cats);
      // ...以下 fetch / 解析不变，仅 map 内补 imgUrl
```

映射体（第 67-77 行）改为：

```ts
      return list.map((it): ResearchItem => {
        const title = typeof it.title === 'string' ? it.title.slice(0, 120) : '';
        const snippet = typeof it.content === 'string' ? it.content.slice(0, 300) : '';
        const imgUrl = firstImageUrl(it);
        return {
          source: 'searxng',
          title,
          snippet,
          url: typeof it.url === 'string' ? it.url : undefined,
          imgUrl,
          keywords: tokenizeKeywords(snippet, title),
        };
      });
```

并在文件内新增私有工具：

```ts
/** 图片地址优先级：img_src → thumbnail_src → thumbnail（仅接受 http/https 字符串） */
function firstImageUrl(it: SearxngResult): string | undefined {
  for (const raw of [it.img_src, it.thumbnail_src, it.thumbnail]) {
    if (typeof raw === 'string') {
      const s = raw.trim();
      if (/^https?:\/\//i.test(s)) return s;
    }
  }
  return undefined;
}
```

- [ ] **Step 5: 改 `qwen-shared.ts`**

`SearchHit`（第 14-17 行）改为：

```ts
export interface SearchHit {
  title?: unknown; url?: unknown; site?: unknown; caption?: unknown;
  snippet?: unknown; content?: unknown;
  imgSrc?: unknown; thumbnail?: unknown; thumbnailSrc?: unknown;
}
```

`toResearchItem`（第 65-70 行）改为：

```ts
/** 引用命中 → ResearchItem（source 由调用方传入，用于区分 qwen / qwen-official） */
export function toResearchItem(hit: SearchHit, source: string): ResearchItem {
  const title = clean(firstStr(hit.title) ?? '');
  const snippet = clean(firstStr(hit.snippet, hit.content) ?? '');
  const url = clean(firstStr(hit.url, hit.site, hit.caption) ?? '');
  const imgUrl = clean(firstStr(hit.imgSrc, hit.thumbnailSrc, hit.thumbnail) ?? '');
  return {
    source,
    title,
    snippet,
    keywords: tokenize(snippet, title),
    url,
    imgUrl: imgUrl && /^https?:\/\//i.test(imgUrl) ? imgUrl : undefined,
  };
}
```

- [ ] **Step 6: 改 `web-search-qwen-official.ts`**

在 `extractOfficialItems` 内把 `search_results[]` 映射到 `SearchHit` 时补图片字段（键名按上游宽松命名）：

```ts
      const hit: SearchHit = {
        title: r.title,
        url: r.url,
        site: r.site_name,
        snippet: r.snippet,
        content: r.content,
        imgSrc: r.img_src ?? r.image ?? r.image_url,
        thumbnailSrc: r.thumbnail_src ?? r.thumbnail,
      };
```

（实施时先读该文件确认现有映射对象的字面量与字段名，保持其余字段不变，仅增补上述键。）

- [ ] **Step 7: 更新 `research-item.ts` 注释**

第 15 行注释改为：

```ts
  /** 命中条目若带图则保留原图地址（第一层参考图来源；由 research-image.service 抓取落盘） */
  imgUrl?: string;
```

- [ ] **Step 8: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- web-search`
Expected: PASS（含新增 2 个用例，原有用例不回归）

- [ ] **Step 9: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/
git commit -m "feat(ai): 检索适配器支持 categories 与图片字段映射"
```

---

### Task 3: 抓取层（SSRF 防护 + 受控下载 + 页面 og:image 提取）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `RESEARCH_IMAGE_*` 常量
- Produces:
  - `function isPrivateAddress(ip: string): boolean`
  - `async function assertPublicHttpUrl(raw: string): Promise<URL>`
  - `async function fetchGuarded(url: string, opts: { timeoutMs: number; maxBytes?: number }): Promise<Response>`
  - `async function readCapped(res: Response, maxBytes: number): Promise<Buffer>`
  - `async function fetchImageSafely(sourceUrl: string): Promise<{ buffer: Buffer; mime: string }>`
  - `async function fetchPageHtml(url: string, timeoutMs: number): Promise<string>`
  - `function extractPageImageUrl(html: string, pageUrl: string): string | null`

- [ ] **Step 1: 写失败用例**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.spec.ts
import { isPrivateAddress, extractPageImageUrl } from './research-image-fetch';

describe('isPrivateAddress', () => {
  it('拦截 IPv4 私网 / 环回 / 链路本地 / 保留段', () => {
    for (const ip of ['10.1.2.3', '172.16.0.1', '172.31.255.254', '192.168.1.1', '127.0.0.1', '169.254.1.1', '0.0.0.0', '100.64.0.1', '198.18.0.1', '224.0.0.1', '240.0.0.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv4', () => {
    for (const ip of ['8.8.8.8', '1.1.1.1', '203.0.113.9']) {
      expect(isPrivateAddress(ip)).toBe(false);
    }
  });

  it('拦截 IPv6 环回 / ULA / 链路本地 / v4 映射私网', () => {
    for (const ip of ['::1', 'fc00::1', 'fd12:3456::1', 'fe80::1', '::ffff:192.168.1.1']) {
      expect(isPrivateAddress(ip)).toBe(true);
    }
  });

  it('放行公网 IPv6', () => {
    expect(isPrivateAddress('2001:4860:4860::8888')).toBe(false);
  });
});

describe('extractPageImageUrl', () => {
  it('优先 og:image', () => {
    const html = `<html><head><meta property="og:image" content="https://cdn.a.com/o.jpg"><meta name="twitter:image" content="https://cdn.a.com/t.jpg"></head></html>`;
    expect(extractPageImageUrl(html, 'https://a.com/p')).toBe('https://cdn.a.com/o.jpg');
  });

  it('无 og 时回退 twitter:image', () => {
    const html = `<head><meta name="twitter:image" content="https://cdn.a.com/t.jpg"></head>`;
    expect(extractPageImageUrl(html, 'https://a.com/p')).toBe('https://cdn.a.com/t.jpg');
  });

  it('相对路径解析为绝对地址', () => {
    const html = `<head><meta property="og:image" content="/img/o.png"></head>`;
    expect(extractPageImageUrl(html, 'https://a.com/p/q')).toBe('https://a.com/img/o.png');
  });

  it('都没有时返回 null', () => {
    expect(extractPageImageUrl('<head></head>', 'https://a.com/p')).toBeNull();
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- research-image-fetch.spec`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 写 `research-image-fetch.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts
// 参考图抓取的网络工具层：SSRF 拦截 + 受控重定向下载 + 限流读体 + 页面 og:image 提取。
// 全部失败都抛可读 Error（调用方决定是降级跳过还是记入 errors）。

import { lookup } from 'node:dns/promises';
import {
  RESEARCH_IMAGE_ALLOWED_MIMES,
  RESEARCH_IMAGE_MAX_BYTES,
  RESEARCH_IMAGE_MAX_REDIRECTS,
} from './research-image';

/** IPv4 → 32 位整数 */
function ipv4ToInt(ip: string): number | null {
  const parts = ip.split('.');
  if (parts.length !== 4) return null;
  let n = 0;
  for (const p of parts) {
    if (!/^\d{1,3}$/.test(p)) return null;
    const v = Number(p);
    if (v > 255) return null;
    n = (n << 8) | v;
  }
  return n >>> 0;
}

/** IPv4 私网 / 环回 / 链路本地 / 保留段判定 */
function isPrivateV4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  if (n === null) return false;
  const inRange = (base: string, bits: number): boolean => {
    const b = ipv4ToInt(base);
    if (b === null) return false;
    const mask = bits === 0 ? 0 : (0xffffffff << (32 - bits)) >>> 0;
    return (n & mask) === (b & mask);
  };
  return (
    inRange('0.0.0.0', 8) ||
    inRange('10.0.0.0', 8) ||
    inRange('100.64.0.0', 10) ||
    inRange('127.0.0.0', 8) ||
    inRange('169.254.0.0', 16) ||
    inRange('172.16.0.0', 12) ||
    inRange('192.0.0.0', 24) ||
    inRange('192.168.0.0', 16) ||
    inRange('198.18.0.0', 15) ||
    inRange('224.0.0.0', 4) ||
    inRange('240.0.0.0', 4)
  );
}

/** IP 字面量是否属于私网 / 环回 / 链路本地 / 保留段（IPv4 与 IPv6） */
export function isPrivateAddress(ip: string): boolean {
  const s = (ip || '').trim().toLowerCase().replace(/^\[|\]$/g, '');
  if (!s) return true;
  // v4 映射 v6
  const mapped = s.match(/^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (mapped) return isPrivateV4(mapped[1]);
  if (s.includes(':')) {
    if (s === '::1' || s === '::') return true;
    if (/^f[cd][0-9a-f]{2}:/.test(s)) return true; // fc00::/7（ULA）
    if (/^fe[89ab][0-9a-f]:/.test(s)) return true; // fe80::/10（链路本地）
    return false;
  }
  return isPrivateV4(s);
}

const IPV4_LITERAL = /^\d{1,3}(?:\.\d{1,3}){3}$/;

/**
 * 校验 URL 可安全外发：仅 http/https；host 为 IP 字面量时直接判定，
 * 否则 DNS 解析全部地址，任一为私网即拒绝。
 */
export async function assertPublicHttpUrl(raw: string): Promise<URL> {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('图片地址非法');
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`不支持的协议：${url.protocol}`);
  }
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (IPV4_LITERAL.test(host) || host.includes(':')) {
    if (isPrivateAddress(host)) throw new Error('目标地址位于内网，已拦截');
    return url;
  }
  let addrs: { address: string }[];
  try {
    addrs = await lookup(host, { all: true });
  } catch {
    throw new Error(`域名解析失败：${host}`);
  }
  if (!addrs.length) throw new Error(`域名无解析结果：${host}`);
  if (addrs.some((a) => isPrivateAddress(a.address))) throw new Error('目标地址解析到内网，已拦截');
  return url;
}

/**
 * 受控下载：手动跟随重定向（≤ RESEARCH_IMAGE_MAX_REDIRECTS 跳），每跳重新做 SSRF 校验。
 * 返回最终 Response（调用方负责读体与 content-type 判断）。
 */
export async function fetchGuarded(
  url: string,
  opts: { timeoutMs: number; accept?: string },
): Promise<Response> {
  let current = url;
  for (let hop = 0; hop <= RESEARCH_IMAGE_MAX_REDIRECTS; hop++) {
    await assertPublicHttpUrl(current);
    const headers: Record<string, string> = { 'User-Agent': 'Mozilla/5.0 (compatible; LumiraBot/1.0)' };
    if (opts.accept) headers.Accept = opts.accept;
    const res = await fetch(current, {
      headers,
      redirect: 'manual',
      signal: AbortSignal.timeout(opts.timeoutMs),
    }).catch((err: unknown) => {
      const name = (err as { name?: string } | null | undefined)?.name;
      if (name === 'AbortError' || name === 'TimeoutError') throw new Error('抓取超时');
      throw new Error('抓取失败（网络不可达）');
    });
    if (res.status >= 300 && res.status < 400) {
      const loc = res.headers.get('location');
      if (!loc) throw new Error(`重定向缺少 location（HTTP ${res.status}）`);
      current = new URL(loc, current).toString();
      continue;
    }
    return res;
  }
  throw new Error('重定向次数超出上限');
}

/** 读响应体，超过上限即抛错（边读边累计，防止超大响应吃满内存） */
export async function readCapped(res: Response, maxBytes: number): Promise<Buffer> {
  const chunks: Buffer[] = [];
  let total = 0;
  const body = res.body;
  if (!body) {
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.byteLength > maxBytes) throw new Error('图片体积超出上限');
    return buf;
  }
  const reader = body.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw new Error('图片体积超出上限');
    }
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks);
}

/** 下载并校验一张图片：MIME 白名单 + 体积上限；任一不满足抛错 */
export async function fetchImageSafely(sourceUrl: string): Promise<{ buffer: Buffer; mime: string }> {
  const res = await fetchGuarded(sourceUrl, { timeoutMs: 5_000, accept: 'image/*' });
  if (!res.ok) throw new Error(`图片下载失败（HTTP ${res.status}）`);
  const mime = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (!RESEARCH_IMAGE_ALLOWED_MIMES.includes(mime)) throw new Error(`不支持的图片类型：${mime || '未知'}`);
  const buffer = await readCapped(res, RESEARCH_IMAGE_MAX_BYTES);
  if (!buffer.byteLength) throw new Error('图片内容为空');
  return { buffer, mime };
}

/** 抓取页面 HTML（只取前 512KB，够解析 head 元信息） */
export async function fetchPageHtml(url: string, timeoutMs: number): Promise<string> {
  const res = await fetchGuarded(url, { timeoutMs, accept: 'text/html,application/xhtml+xml' });
  if (!res.ok) throw new Error(`页面抓取失败（HTTP ${res.status}）`);
  const buffer = await readCapped(res, 512 * 1024);
  return buffer.toString('utf8');
}

/** 从 HTML 中按优先级提取首图：og:image → twitter:image → JSON-LD image → 首个 <img src> */
export function extractPageImageUrl(html: string, pageUrl: string): string | null {
  const meta = (patterns: RegExp[]): string | null => {
    for (const re of patterns) {
      const m = html.match(re);
      if (m?.[1]) {
        try {
          return new URL(decodeHtml(m[1].trim()), pageUrl).toString();
        } catch {
          /* 试下一个 */
        }
      }
    }
    return null;
  };
  const byMeta = meta([
    /<meta[^>]+(?:property|name)=["']og:image(?::url)?["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']og:image(?::url)?["']/i,
    /<meta[^>]+(?:property|name)=["']twitter:image["'][^>]*content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']twitter:image["']/i,
  ]);
  if (byMeta) return byMeta;

  const jsonLd = html.match(/"image"\s*:\s*"([^"]+)"/i);
  if (jsonLd?.[1]) {
    try {
      return new URL(decodeHtml(jsonLd[1].trim()), pageUrl).toString();
    } catch {
      /* 落回 img */
    }
  }
  const img = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  if (img?.[1]) {
    try {
      return new URL(decodeHtml(img[1].trim()), pageUrl).toString();
    } catch {
      return null;
    }
  }
  return null;
}

/** 常见 HTML 实体反转义（只处理会出现在 URL 中的少数几个） */
function decodeHtml(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#47;/g, '/')
    .replace(/&quot;/g, '"');
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- research-image-fetch.spec`
Expected: PASS（`isPrivateAddress` 4 组 + `extractPageImageUrl` 4 组）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.spec.ts
git commit -m "feat(ai): 新增参考图抓取网络层（SSRF 防护 + 受控下载 + og:image 提取）"
```

---

### Task 4: 存储层（哈希 / 压缩落盘 / 读盘 / URL / TTL 清理）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.spec.ts`

**Interfaces:**
- Consumes: Task 1 常量
- Produces:
  - `function hashUrl(url: string): string`（sha256 前 16 位 hex）
  - `function hashBuffer(buf: Buffer): string`
  - `function researchDir(): string`
  - `function researchImageUrl(id: string): string`
  - `interface WrittenImage { url: string; width: number; height: number; bytes: number }`
  - `async function writeResearchImage(id: string, buffer: Buffer): Promise<WrittenImage | null>`（null = 尺寸不达标）
  - `async function readResearchImage(id: string): Promise<Buffer | null>`
  - `async function cleanupResearchImages(ttlDays: number): Promise<number>`

- [ ] **Step 1: 写失败用例**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.spec.ts
import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import sharp from 'sharp';
import { hashBuffer, hashUrl, cleanupResearchImages, writeResearchImage, readResearchImage, researchDir } from './research-image-store';

/** 生成一张纯色 PNG（指定边长） */
async function makePng(size: number): Promise<Buffer> {
  return sharp({ create: { width: size, height: size, channels: 3, background: { r: 200, g: 120, b: 80 } } })
    .png()
    .toBuffer();
}

describe('research-image-store', () => {
  const originalUploadDir = process.env.UPLOAD_DIR;
  let tmp: string;

  beforeEach(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-research-'));
    process.env.UPLOAD_DIR = tmp;
  });

  afterEach(async () => {
    if (originalUploadDir === undefined) delete process.env.UPLOAD_DIR;
    else process.env.UPLOAD_DIR = originalUploadDir;
    await fs.rm(tmp, { recursive: true, force: true });
  });

  it('hashUrl 稳定且为 16 位 hex', () => {
    expect(hashUrl('https://a.com/1.jpg')).toBe(hashUrl('https://a.com/1.jpg'));
    expect(hashUrl('https://a.com/1.jpg')).toMatch(/^[0-9a-f]{16}$/);
  });

  it('内容哈希与 URL 哈希不同键', () => {
    expect(hashBuffer(Buffer.from('abc'))).not.toBe(hashBuffer(Buffer.from('abd')));
  });

  it('尺寸达标的图压缩落盘为 jpg，长边 ≤1280', async () => {
    const id = 'id-ok';
    const written = await writeResearchImage(id, await makePng(800));
    expect(written).not.toBeNull();
    expect(written!.url).toContain('/uploads/research/id-ok.jpg');
    expect(Math.max(written!.width, written!.height)).toBeLessThanOrEqual(1280);
    const back = await readResearchImage(id);
    expect(back).not.toBeNull();
  });

  it('长边超 1280 会被下采样', async () => {
    const written = await writeResearchImage('id-big', await makePng(2400));
    expect(written!.width).toBeLessThanOrEqual(1280);
    expect(written!.height).toBeLessThanOrEqual(1280);
  });

  it('任一边 <400px → null（画面太小不用）', async () => {
    expect(await writeResearchImage('id-small', await makePng(200))).toBeNull();
  });

  it('cleanupResearchImages 删过期保留未过期', async () => {
    const dir = researchDir();
    await fs.mkdir(dir, { recursive: true });
    const oldFile = path.join(dir, 'old.jpg');
    const newFile = path.join(dir, 'new.jpg');
    await fs.writeFile(oldFile, Buffer.from('x'));
    await fs.writeFile(newFile, Buffer.from('y'));
    const past = new Date(Date.now() - 10 * 24 * 3600 * 1000);
    await fs.utimes(oldFile, past, past);

    const removed = await cleanupResearchImages(7);
    expect(removed).toBe(1);
    await expect(fs.stat(oldFile)).rejects.toThrow();
    await expect(fs.stat(newFile)).resolves.toBeTruthy();
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- research-image-store.spec`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 写 `research-image-store.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.ts
// 参考图落盘与生命周期：URL/内容哈希、压缩写盘、读盘、公网 URL 拼接、TTL 清理。
//
// 不走 StorageAdapter：参考图是短 TTL 的内部缓存，固定写本地 UPLOAD_DIR/research/，
// 由后端自身 /uploads 静态服务对外，URL 用 BACKEND_PUBLIC_URL 拼接（与 admin-templates 的 buildPublicUrl 同款）。

import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import sharp from 'sharp';
import {
  RESEARCH_IMAGE_JPEG_QUALITY,
  RESEARCH_IMAGE_MAX_SIDE,
  RESEARCH_IMAGE_MIN_SIDE,
} from './research-image';

/** sha256 前 16 位 hex */
function sha16(input: Buffer | string): string {
  return createHash('sha256').update(input).digest('hex').slice(0, 16);
}

/** 归一化原图 URL → 去重键 / 文件名 */
export function hashUrl(url: string): string {
  return sha16((url || '').trim());
}

/** 图片内容 → 去重键（同图不同 URL 只保留一张） */
export function hashBuffer(buf: Buffer): string {
  return sha16(buf);
}

/** 参考图落盘目录（测试可通过 UPLOAD_DIR 隔离） */
export function researchDir(): string {
  return path.join(process.env.UPLOAD_DIR || './data/uploads', 'research');
}

/** 落盘后的公网可访问 URL */
export function researchImageUrl(id: string): string {
  const base = (process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000').replace(/\/+$/, '');
  return `${base}/uploads/research/${id}.jpg`;
}

/** 压缩落盘结果 */
export interface WrittenImage {
  url: string;
  width: number;
  height: number;
  bytes: number;
}

/**
 * 压缩（长边 ≤1280、jpeg q80）并落盘为 `{id}.jpg`。
 * 任一边 <400px → 返回 null（画面太小，不保留）。
 */
export async function writeResearchImage(id: string, buffer: Buffer): Promise<WrittenImage | null> {
  const meta = await sharp(buffer, { failOn: 'error' }).metadata();
  const width0 = meta.width ?? 0;
  const height0 = meta.height ?? 0;
  if (!width0 || !height0) throw new Error('无法解析图片尺寸');
  if (Math.min(width0, height0) < RESEARCH_IMAGE_MIN_SIDE) return null;

  const out = await sharp(buffer, { failOn: 'error' })
    .rotate()
    .resize({ width: RESEARCH_IMAGE_MAX_SIDE, height: RESEARCH_IMAGE_MAX_SIDE, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: RESEARCH_IMAGE_JPEG_QUALITY })
    .toBuffer({ resolveWithObject: true });

  const dir = researchDir();
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, `${id}.jpg`), out.data);
  return {
    url: researchImageUrl(id),
    width: out.info.width,
    height: out.info.height,
    bytes: out.info.size,
  };
}

/** 读回图片字节（多模态解读用）；不存在 → null */
export async function readResearchImage(id: string): Promise<Buffer | null> {
  if (!/^[0-9a-f]{16}$/.test(id)) return null;
  try {
    return await fs.readFile(path.join(researchDir(), `${id}.jpg`));
  } catch {
    return null;
  }
}

/** 删除 mtime 超过 ttlDays 的落盘图片，返回删除数量 */
export async function cleanupResearchImages(ttlDays: number): Promise<number> {
  const dir = researchDir();
  let names: string[];
  try {
    names = await fs.readdir(dir);
  } catch {
    return 0;
  }
  const ttlMs = Math.max(1, ttlDays) * 24 * 3600 * 1000;
  const deadline = Date.now() - ttlMs;
  let removed = 0;
  for (const name of names) {
    if (!name.endsWith('.jpg')) continue;
    const file = path.join(dir, name);
    try {
      const st = await fs.stat(file);
      if (st.mtimeMs < deadline) {
        await fs.unlink(file);
        removed += 1;
      }
    } catch {
      // 单个文件异常不影响整体清理
    }
  }
  return removed;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- research-image-store.spec`
Expected: PASS（6 个用例）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-image-store.spec.ts
git commit -m "feat(ai): 新增参考图落盘存储层（压缩/去重/TTL 清理）"
```

---

### Task 5: `ResearchImageService`（三层递进 + 并发 + 软预算 + 定时清理）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 类型/常量、Task 3 `fetchImageSafely` / `fetchPageHtml` / `extractPageImageUrl`、Task 4 `hashUrl` / `hashBuffer` / `writeResearchImage` / `readResearchImage` / `cleanupResearchImages`
- Produces:
  - `class ResearchImageService implements OnModuleInit, OnModuleDestroy`
    - `async collect(input: { items: ResearchItem[]; queries: string[]; imagesSearch?: ((query: string) => Promise<ResearchItem[]>) | null; cfg: ResearchImagesConfig; now?: () => number }): Promise<ResearchImagesResult>`
    - `async readBase64(id: string): Promise<{ base64: string; mime: string } | null>`

**设计要点（实施时严格照做）**
- 三层顺序累计，命中 `cfg.max` 即停止后续层。
- 候选去重：先按 `hashUrl(sourceUrl)`，下载后再按 `hashBuffer`。
- 并发 3（自实现 `runPool`），软预算 20s：每次取候选前检查 `now() - startedAt > budget` 则停止。
- 每层失败记 `errors`：第二层按页面记 `{ name: 域名, error }`；第三层整体失败记 `{ name: 'image-search', error }`；单张图的 SSRF/MIME/体积/尺寸拦截静默跳过。
- TTL 清理：`onModuleInit` 兜底清一次 + `setInterval` 每小时（`.unref()`）；TTL 从 `AiConfigService.getSearchConfig()` 读，失败用默认 7。

- [ ] **Step 1: 写失败用例**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.spec.ts
import * as os from 'node:os';
import * as path from 'node:path';
import { promises as fs } from 'node:fs';
import sharp from 'sharp';
import { ResearchImageService } from './research-image.service';
import { DEFAULT_RESEARCH_IMAGES_CONFIG } from './research-image';
import type { ResearchImagesConfig } from './research-image';
import type { ResearchItem } from './research-item';

/** 最小 AiConfigService 替身：TTL 用默认 */
const fakeConfig = { getSearchConfig: async () => null } as never;

async function makePng(size = 800): Promise<Buffer> {
  return sharp({ create: { width: size, height: size, channels: 3, background: { r: 10, g: 20, b: 30 } } })
    .png()
    .toBuffer();
}

function item(partial: Partial<ResearchItem>): ResearchItem {
  return { source: 'searxng', title: 't', snippet: 's', keywords: [], ...partial };
}

const cfg = (over: Partial<ResearchImagesConfig> = {}): ResearchImagesConfig => ({
  ...DEFAULT_RESEARCH_IMAGES_CONFIG,
  enabled: true,
  ...over,
});

describe('ResearchImageService.collect', () => {
  let tmp: string;
  const originalUploadDir = process.env.UPLOAD_DIR;

  beforeEach(async () => {
    tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-rimg-'));
    process.env.UPLOAD_DIR = tmp;
  });
  afterEach(async () => {
    if (originalUploadDir === undefined) delete process.env.UPLOAD_DIR;
    else process.env.UPLOAD_DIR = originalUploadDir;
    await fs.rm(tmp, { recursive: true, force: true });
  });

  it('第一层：条目 imgUrl 命中并落盘', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg', url: 'https://a.com/p' })],
      queries: ['旗袍'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('metadata');
    expect(res.images[0].source).toBe('searxng');
    expect(res.images[0].query).toBe('旗袍');
  });

  it('同一 URL 只保留一张（URL 去重）', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/1.jpg' })],
      queries: ['x'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
  });

  it('max 截断：命中上限后不再抓后续层', async () => {
    const svc = new ResearchImageService(fakeConfig);
    let called = 0;
    svc.fetchImage = async () => {
      called += 1;
      return { buffer: await makePng(), mime: 'image/png' };
    };
    svc.fetchPage = async () => '<html></html>';
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/2.jpg' }), item({ url: 'https://b.com/p' })],
      queries: ['x'],
      cfg: cfg({ max: 2 }),
    });
    expect(res.images).toHaveLength(2);
    expect(called).toBe(2);
  });

  it('第二层：条目无图时抓页面 og:image', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => '<meta property="og:image" content="https://cdn.b.com/o.jpg">';
    const res = await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['x'],
      cfg: cfg(),
    });
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('page');
    expect(res.images[0].pageUrl).toBe('https://b.com/p');
  });

  it('第二层抓页失败：记 errors 且不阻断', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => {
      throw new Error('页面抓取失败（HTTP 403）');
    };
    const res = await svc.collect({ items: [item({ url: 'https://b.com/p' })], queries: ['x'], cfg: cfg() });
    expect(res.images).toHaveLength(0);
    expect(res.errors.length).toBeGreaterThan(0);
  });

  it('第三层：图片搜索兜底（仅在前两层不足时触发）', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => 'no-image-here';
    let searchQuery = '';
    const res = await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['旗袍'],
      imagesSearch: async (q) => {
        searchQuery = q;
        return [item({ imgUrl: 'https://img.c.com/x.jpg', source: 'searxng' })];
      },
      cfg: cfg(),
    });
    expect(searchQuery).toBe('旗袍');
    expect(res.images).toHaveLength(1);
    expect(res.images[0].layer).toBe('image-search');
  });

  it('第三层关闭时不调用图片搜索', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
    svc.fetchPage = async () => 'no-image';
    let called = false;
    await svc.collect({
      items: [item({ url: 'https://b.com/p' })],
      queries: ['x'],
      imagesSearch: async () => {
        called = true;
        return [];
      },
      cfg: cfg({ searchFallback: false }),
    });
    expect(called).toBe(false);
  });

  it('单张图拦截（SSRF / 类型）静默跳过且不记 errors', async () => {
    const svc = new ResearchImageService(fakeConfig);
    svc.fetchImage = async () => {
      throw new Error('目标地址位于内网，已拦截');
    };
    const res = await svc.collect({ items: [item({ imgUrl: 'https://a.com/1.jpg' })], queries: ['x'], cfg: cfg() });
    expect(res.images).toHaveLength(0);
    expect(res.errors).toHaveLength(0);
  });

  it('软预算耗尽后停止抓取并使用已得结果', async () => {
    const svc = new ResearchImageService(fakeConfig);
    let t = 0;
    svc.fetchImage = async () => {
      t += 15_000;
      return { buffer: await makePng(), mime: 'image/png' };
    };
    const res = await svc.collect({
      items: [item({ imgUrl: 'https://a.com/1.jpg' }), item({ imgUrl: 'https://a.com/2.jpg' }), item({ imgUrl: 'https://a.com/3.jpg' })],
      queries: ['x'],
      cfg: cfg(),
      now: () => t,
    });
    expect(res.images.length).toBeLessThanOrEqual(2);
  });
});

describe('ResearchImageService.readBase64', () => {
  it('读回 jpeg base64', async () => {
    const tmp = await fs.mkdtemp(path.join(os.tmpdir(), 'lumira-rimg2-'));
    const original = process.env.UPLOAD_DIR;
    process.env.UPLOAD_DIR = tmp;
    try {
      const svc = new ResearchImageService(fakeConfig);
      svc.fetchImage = async () => ({ buffer: await makePng(), mime: 'image/png' });
      const res = await svc.collect({ items: [item({ imgUrl: 'https://a.com/1.jpg' })], queries: ['x'], cfg: cfg() });
      const id = res.images[0].id;
      const loaded = await svc.readBase64(id);
      expect(loaded?.mime).toBe('image/jpeg');
      expect(loaded?.base64.length).toBeGreaterThan(100);
      expect(await svc.readBase64('0000000000000000')).toBeNull();
    } finally {
      if (original === undefined) delete process.env.UPLOAD_DIR;
      else process.env.UPLOAD_DIR = original;
      await fs.rm(tmp, { recursive: true, force: true });
    }
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- research-image.service.spec`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 写 `research-image.service.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.ts
// 参考图抓取编排（spec 5.1~5.4）：三层递进（条目自带图 → 页面 og:image → 图片搜索兜底），
// 并发 3、整体软预算 20s、URL + 内容双哈希去重、任何失败静默降级不阻断识别。
// 另负责落盘图片的 TTL 清理（启动兜底 + 每小时一次）。

import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import {
  DEFAULT_RESEARCH_IMAGES_CONFIG,
  RESEARCH_IMAGE_CONCURRENCY,
  RESEARCH_IMAGE_FETCH_TIMEOUT_MS,
  RESEARCH_IMAGE_PAGE_TIMEOUT_MS,
  RESEARCH_IMAGE_TOTAL_BUDGET_MS,
  hashUrlPlaceholder,
} from './research-image';
import type {
  ImageCandidate,
  ResearchImage,
  ResearchImagesConfig,
  ResearchImagesResult,
} from './research-image';
import type { ResearchItem } from './research-item';
import { extractPageImageUrl, fetchImageSafely, fetchPageHtml } from './research-image-fetch';
import { cleanupResearchImages, hashBuffer, hashUrl, readResearchImage, writeResearchImage } from './research-image-store';

const logger = new Logger('ResearchImageService');
/** 定时清理间隔：每小时 */
const CLEANUP_INTERVAL_MS = 3600 * 1000;

/** 有界并发执行器（保持输入顺序无关，仅限制在跑数量） */
async function runPool<T>(items: T[], limit: number, worker: (item: T) => Promise<void>): Promise<void> {
  let cursor = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    for (;;) {
      const idx = cursor;
      cursor += 1;
      if (idx >= items.length) return;
      await worker(items[idx]);
    }
  });
  await Promise.all(runners);
}

/** 取 URL 的域名（失败回退为原串） */
function hostOf(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

@Injectable()
export class ResearchImageService implements OnModuleInit, OnModuleDestroy {
  /** 测试可替换：下载一张图（默认走 SSRF 受控抓取） */
  fetchImage: (url: string) => Promise<{ buffer: Buffer; mime: string }> = fetchImageSafely;
  /** 测试可替换：抓页面 HTML */
  fetchPage: (url: string, timeoutMs: number) => Promise<string> = fetchPageHtml;

  private timer?: ReturnType<typeof setInterval>;

  constructor(private readonly aiConfigService: AiConfigService) {}

  /** 启动兜底清扫 + 每小时 TTL 清理（不引入 @nestjs/schedule） */
  async onModuleInit(): Promise<void> {
    await this.sweep();
    this.timer = setInterval(() => void this.sweep(), CLEANUP_INTERVAL_MS);
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** 按配置 TTL 清扫过期图片；配置读取失败用默认 7 天 */
  private async sweep(): Promise<void> {
    try {
      const cfg = await this.aiConfigService.getSearchConfig?.();
      const ttl = cfg?.images?.ttlDays ?? DEFAULT_RESEARCH_IMAGES_CONFIG.ttlDays;
      const removed = await cleanupResearchImages(ttl);
      if (removed) logger.log(`清理过期参考图 ${removed} 张（TTL ${ttl} 天）`);
    } catch {
      // 清理失败不影响服务
    }
  }

  /** 读回落盘图片 → base64（多模态解读用） */
  async readBase64(id: string): Promise<{ base64: string; mime: string } | null> {
    const buf = await readResearchImage(id);
    if (!buf) return null;
    return { base64: buf.toString('base64'), mime: 'image/jpeg' };
  }

  /**
   * 三层递进抓取参考图。
   * - items：检索命中条目（第一层用 imgUrl、第二层用 url 抓页面）
   * - queries：本次检索词（第三层图片搜索用第一组）
   * - imagesSearch：第三层图片搜索（由 TrendResearchService 注入；缺省则该层跳过）
   */
  async collect(input: {
    items: ResearchItem[];
    queries: string[];
    imagesSearch?: ((query: string) => Promise<ResearchItem[]>) | null;
    cfg: ResearchImagesConfig;
    now?: () => number;
  }): Promise<ResearchImagesResult> {
    const { items, queries, imagesSearch } = input;
    const cfg = input.cfg;
    const now = input.now ?? Date.now;
    const images: ResearchImage[] = [];
    const errors: { name: string; error: string }[] = [];
    const startedAt = now();
    const overBudget = (): boolean => now() - startedAt > RESEARCH_IMAGE_TOTAL_BUDGET_MS;

    /** 已处理的 URL 哈希（跨层去重） */
    const seenUrl = new Set<string>();
    /** 已落盘的内容哈希（同图不同 URL 去重） */
    const seenContent = new Set<string>();
    /** 图片搜索是否已调用过（避免重复请求） */
    let searchRan = false;

    /** 处理一批候选：逐张下载 → 压缩落盘 → 计入结果；返回是否达到 max */
    const drain = async (candidates: ImageCandidate[]): Promise<boolean> => {
      const pending: ImageCandidate[] = [];
      for (const c of candidates) {
        const key = hashUrl(c.sourceUrl);
        if (seenUrl.has(key)) continue;
        seenUrl.add(key);
        pending.push(c);
        if (images.length + pending.length >= cfg.max) break;
      }
      await runPool(pending, RESEARCH_IMAGE_CONCURRENCY, async (c) => {
        if (images.length >= cfg.max || overBudget()) return;
        try {
          const { buffer } = await this.fetchImage(c.sourceUrl);
          const contentKey = hashBuffer(buffer);
          if (seenContent.has(contentKey)) return;
          seenContent.add(contentKey);
          const id = contentKey;
          const written = await writeResearchImage(id, buffer);
          if (!written) return; // 尺寸不达标：静默跳过
          images.push({
            id,
            url: written.url,
            sourceUrl: c.sourceUrl,
            pageUrl: c.pageUrl,
            source: c.source,
            query: c.query,
            layer: c.layer,
            width: written.width,
            height: written.height,
            bytes: written.bytes,
          });
        } catch {
          // SSRF / MIME / 体积 / 超时 / 落盘失败：丢弃该候选，静默继续
        }
      });
      return images.length >= cfg.max;
    };

    // ===== 第一层：检索条目自带图 =====
    const l1: ImageCandidate[] = items
      .filter((it) => typeof it.imgUrl === 'string' && /^https?:\/\//i.test(it.imgUrl))
      .map((it) => ({
        sourceUrl: it.imgUrl as string,
        pageUrl: it.url,
        source: it.source,
        query: queries[0],
        layer: 'metadata' as const,
      }));
    if (l1.length && (await drain(l1))) return { images, errors };

    // ===== 第二层：抓命中页面 og:image =====
    if (cfg.pageFetch && !overBudget()) {
      const pages = items.filter((it) => typeof it.url === 'string' && /^https?:\/\//i.test(it.url ?? ''));
      await runPool(pages, RESEARCH_IMAGE_CONCURRENCY, async (it) => {
        if (images.length >= cfg.max || overBudget()) return;
        const pageUrl = it.url as string;
        try {
          const html = await this.fetchPage(pageUrl, RESEARCH_IMAGE_PAGE_TIMEOUT_MS);
          const imgUrl = extractPageImageUrl(html, pageUrl);
          if (!imgUrl) return;
          const key = hashUrl(imgUrl);
          if (seenUrl.has(key)) return;
          seenUrl.add(key);
          const { buffer } = await this.fetchImage(imgUrl);
          const contentKey = hashBuffer(buffer);
          if (seenContent.has(contentKey)) return;
          seenContent.add(contentKey);
          const written = await writeResearchImage(contentKey, buffer);
          if (!written) return;
          images.push({
            id: contentKey,
            url: written.url,
            sourceUrl: imgUrl,
            pageUrl,
            source: it.source,
            query: queries[0],
            layer: 'page',
            width: written.width,
            height: written.height,
            bytes: written.bytes,
          });
        } catch (err) {
          errors.push({ name: hostOf(pageUrl), error: err instanceof Error ? err.message : String(err) });
        }
      });
    }
    if (images.length >= cfg.max) return { images, errors };

    // ===== 第三层：图片搜索兜底 =====
    if (cfg.searchFallback && imagesSearch && queries[0] && !overBudget()) {
      searchRan = true;
      try {
        const hits = await imagesSearch(queries[0]);
        const l3: ImageCandidate[] = hits
          .filter((it) => typeof it.imgUrl === 'string' && /^https?:\/\//i.test(it.imgUrl))
          .map((it) => ({
            sourceUrl: it.imgUrl as string,
            pageUrl: it.url,
            source: it.source,
            query: queries[0],
            layer: 'image-search' as const,
          }));
        await drain(l3);
      } catch (err) {
        errors.push({ name: 'image-search', error: err instanceof Error ? err.message : String(err) });
      }
    }
    void searchRan;

    return { images, errors };
  }
}
```

> **实施注意**：上面的 `import { ... hashUrlPlaceholder } from './research-image'` 是**错误残留**——`hashUrl/hashBuffer` 从 `./research-image-store` 导入，`./research-image` 只导入常量与类型。落地时请删除该行，保持 import 为：
>
> ```ts
> import {
>   DEFAULT_RESEARCH_IMAGES_CONFIG,
>   RESEARCH_IMAGE_CONCURRENCY,
>   RESEARCH_IMAGE_FETCH_TIMEOUT_MS,
>   RESEARCH_IMAGE_PAGE_TIMEOUT_MS,
>   RESEARCH_IMAGE_TOTAL_BUDGET_MS,
> } from './research-image';
> ```
>
> 同时删除未使用的 `RESEARCH_IMAGE_FETCH_TIMEOUT_MS`（`fetchImageSafely` 内部已用 5s 固定值）与 `searchRan` 变量（连同 `void searchRan`）。若 lint 报未使用，按此清理。

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- research-image.service.spec`
Expected: PASS（10 个用例）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-image.service.spec.ts
git commit -m "feat(ai): 新增参考图三层抓取服务（并发/软预算/TTL 清理）"
```

---

### Task 6: `ResearchVisionService` + `visionChatMulti`

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`（在 `visionChat` 之后新增 `visionChatMulti`）
- Create: `lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 `normalizeVision`、Task 5 `ResearchImageService.readBase64`
- Produces:
  - `interface VisionMessageImage { base64: string; mime: string }`
  - `interface VisionChatMultiInput { systemPrompt: string; userText: string; images: VisionMessageImage[]; temperature?: number; jsonMode?: boolean; timeoutMs?: number; maxTokens?: number }`
  - `async function visionChatMulti(cfg: LlmEndpoint, input: VisionChatMultiInput): Promise<string>`
  - `class ResearchVisionService { async interpret(topic: string, images: { image: ResearchImage; base64: string; mime: string }[]): Promise<ResearchVision | null> }`

- [ ] **Step 1: 写失败用例**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.spec.ts
import { ResearchVisionService } from './research-vision.service';
import type { ResearchImage } from './research-image';

const img = (id: string): ResearchImage => ({
  id, url: `https://x/uploads/research/${id}.jpg`, sourceUrl: 'https://a.com/1.jpg', source: 'searxng', layer: 'metadata', bytes: 1000,
});

describe('ResearchVisionService.interpret', () => {
  it('无图 → null（不调用模型）', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    let called = false;
    svc.chat = async () => { called = true; return '{}'; };
    expect(await svc.interpret('旗袍', [])).toBeNull();
    expect(called).toBe(false);
  });

  it('正常解析出结论与 adopted', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () =>
      JSON.stringify({ summary: '暖调逆光', styles: ['新中式'], adopted: [{ id: 'aaaaaaaaaaaaaaaa', reason: '光线好' }] });
    const v = await svc.interpret('旗袍', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'AAA', mime: 'image/jpeg' }]);
    expect(v?.styles).toEqual(['新中式']);
    expect(v?.adopted).toEqual([{ id: 'aaaaaaaaaaaaaaaa', reason: '光线好' }]);
  });

  it('模型编造的 image id 被过滤', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => JSON.stringify({ scene: ['咖啡馆'], adopted: [{ id: 'ffffffffffffffff', reason: '不存在' }] });
    const v = await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'AAA', mime: 'image/jpeg' }]);
    expect(v?.adopted).toEqual([]);
    expect(v?.scene).toEqual(['咖啡馆']);
  });

  it('解析失败 / 调用抛错 → null', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => { throw new Error('AI 请求超时，请稍后重试'); };
    expect(await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'A', mime: 'image/jpeg' }])).toBeNull();
  });

  it('返回非 JSON → null', async () => {
    const svc = new ResearchVisionService({ getActiveConfig: async () => ({ text: {} }) } as never);
    svc.chat = async () => '这不是 JSON';
    expect(await svc.interpret('主题', [{ image: img('aaaaaaaaaaaaaaaa'), base64: 'A', mime: 'image/jpeg' }])).toBeNull();
  });
});
```

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- research-vision.service.spec`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 在 `llm-client.ts` 新增 `visionChatMulti`**

在 `visionChat`（第 208-237 行）之后插入：

```ts
/** 多图输入的一项 */
export interface VisionMessageImage {
  /** 不含 data: 前缀的 base64 */
  base64: string;
  /** image/jpeg | image/png | image/webp */
  mime: string;
}

export interface VisionChatMultiInput {
  systemPrompt: string;
  userText: string;
  /** 一次调用携带的多张图（建议 ≤6 张，避免载荷与 token 过大） */
  images: VisionMessageImage[];
  temperature?: number;
  jsonMode?: boolean;
  timeoutMs?: number;
  maxTokens?: number;
}

/**
 * 多图 chat：一次 user 消息携带文本 + 多张 image_url。
 * 复用 chatRequest（fetch + 错误映射 + jsonMode 降级），trace 记录总图片字节数。
 * images 为空时直接抛错（调用方应先判空）。
 */
export async function visionChatMulti(cfg: LlmEndpoint, input: VisionChatMultiInput): Promise<string> {
  if (!input.images.length) throw new Error('多图调用缺少图片');
  const messages = [
    { role: 'system', content: input.systemPrompt },
    {
      role: 'user',
      content: [
        { type: 'text', text: input.userText },
        ...input.images.map((img) => ({
          type: 'image_url',
          image_url: { url: `data:${img.mime};base64,${img.base64}` },
        })),
      ],
    },
  ];
  const handle = traceLlmCall({
    model: cfg.model,
    systemPrompt: input.systemPrompt,
    userPrompt: `${input.userText}（附 ${input.images.length} 张参考图）`,
    imageBytes: input.images.reduce((sum, img) => sum + Math.round(img.base64.length * 0.75), 0),
  });
  try {
    const { content, rawText, attempts } = await chatRequest(cfg, {
      model: cfg.model,
      messages,
      temperature: input.temperature ?? DEFAULT_TEMPERATURE,
      jsonMode: input.jsonMode ?? false,
      timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
      maxTokens: input.maxTokens,
    });
    handle?.done(content, { rawResponse: rawText, attempts });
    return content;
  } catch (err) {
    handle?.fail(err);
    throw err;
  }
}
```

- [ ] **Step 4: 写 `research-vision.service.ts`**

```ts
// lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.ts
// 参考图多模态解读（spec 第 6 章）：把抓到的 N 张参考图交给多模态模型，
// 产出结构化视觉结论（ResearchVision），失败/超时/解析失败一律 null（静默降级，不阻断识别）。

import { Injectable } from '@nestjs/common';
import { AiConfigService } from '../ai-config.service';
import { visionChatMulti } from '../llm-client';
import { extractJson } from '../normalize';
import { describeTodayUtc8 } from '../../../common/utils/date.util';
import { traceStep } from '../llm-trace';
import { normalizeVision } from './research-vision';
import type { ResearchVision } from './research-vision';
import type { ResearchImage } from './research-image';

/** 单次解读最多带入的图片数（与抓取上限解耦，防止载荷过大） */
const MAX_IMAGES = 6;

const SYSTEM_PROMPT = [
  '你是资深人像摄影指导。用户会提供一组「从参考网站抓取到的图片」以及本次模板的创作意图。',
  '## 任务',
  '只描述图片中**真实可见**的视觉信息，把这些信息提炼成可用于指导拍摄/生图的结构化结论。',
  '## 规则',
  '1. 绝不编造：图片里没有的题材、人物、场景、道具一律不得出现；看不清就留空。',
  '2. 每条结论写成简短名词短语（≤30 字），同义合并去重；不要整句照抄任何文案，也不要引用图中的文字/水印/账号名。',
  '3. 描述摄影语言而非评价好坏：风格倾向、色彩与光影、构图与机位、穿搭与妆造、场景与道具。',
  '4. adopted 只登记「对本轮模板构思确实有参考价值」的图：id 必须来自给定图片列表的 id，reason 用一句话说明为什么值得参考（可空数组）。',
  '5. summary 用一句话概括这组参考图最有价值的共性（≤60 字）；没有价值就输出空串。',
  '## 输出',
  '只输出 JSON，不要 markdown 代码块或解释：',
  '{"summary":"","styles":[],"colorLight":[],"composition":[],"wardrobe":[],"scene":[],"adopted":[{"id":"","reason":""}]}',
].join('\n');

/** 渲染送入模型图片的 id 清单（让模型能按 id 采纳） */
function renderImageList(images: { image: ResearchImage; base64: string; mime: string }[]): string {
  return images
    .map((it, i) => `${i + 1}. id=${it.image.id}｜来源=${it.image.source}${it.image.query ? `｜检索词=${it.image.query}` : ''}`)
    .join('\n');
}

@Injectable()
export class ResearchVisionService {
  /** 测试可替换：默认走 visionChatMulti */
  chat: (
    images: { image: ResearchImage; base64: string; mime: string }[],
    topic: string,
    model: { text: { provider: string; baseUrl: string; apiKey: string; model: string } },
  ) => Promise<string> = async (images, topic, model) =>
    visionChatMulti(model.text, {
      systemPrompt: SYSTEM_PROMPT,
      userText: [
        describeTodayUtc8(),
        `创作意图：${(topic || '').trim() || '（未提供）'}`,
        '',
        `参考图列表（共 ${images.length} 张，按顺序随消息附带）：`,
        renderImageList(images),
      ].join('\n'),
      images: images.map((it) => ({ base64: it.base64, mime: it.mime })),
      temperature: 0.3,
      jsonMode: true,
      timeoutMs: 120_000,
    });

  constructor(private readonly aiConfigService: AiConfigService) {}

  /**
   * 多模态解读参考图。无图 / 未配置 / 失败 / 解析失败 → null。
   */
  async interpret(
    topic: string,
    images: { image: ResearchImage; base64: string; mime: string }[],
  ): Promise<ResearchVision | null> {
    if (!images.length) return null;
    const used = images.slice(0, MAX_IMAGES);
    try {
      const cfg = await this.aiConfigService.getActiveConfig();
      const vision = await traceStep(
        'researchVision',
        '参考图解读',
        async () => {
          const content = await this.chat(used, topic, { text: cfg.text });
          const allowed = new Set(used.map((it) => it.image.id));
          return normalizeVision(extractJson(content), allowed);
        },
        (v) => (v ? `采纳 ${v.adopted.length} 张 / 提炼 ${v.styles.length + v.colorLight.length + v.composition.length + v.wardrobe.length + v.scene.length} 条视觉要点` : '解读失败（跳过）'),
        (v) => ({ adoptedImageIds: v ? v.adopted.map((a) => a.id) : [] }),
      );
      return vision;
    } catch {
      return null;
    }
  }
}
```

> 实施提示：`traceStep` 的第 5 个参数 `attach` 由 Task 7 引入；**Task 6 与 Task 7 需一起落地**（若顺序上先做 Task 6，可先省略该参数，Task 7 完成后再回填）。建议实施顺序：Task 7 先于 Task 6。

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- research-vision.service.spec`
Expected: PASS（5 个用例）

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.ts lumira-server/packages/backend/src/modules/ai/trend-research/research-vision.service.spec.ts
git commit -m "feat(ai): 新增多模态参考图解读（visionChatMulti + ResearchVisionService）"
```

---

### Task 7: Trace 事件扩展（`images` / `adoptedImageIds` + `traceStep.attach`）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-trace.ts:15-50,101-153`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-trace.spec.ts`（追加用例）

**Interfaces:**
- Consumes: Task 1 的 `TraceImage` 结构（结构化同形，不 import，避免循环依赖）
- Produces:
  - `AiTraceEvent` 新增 `images?: { id: string; url: string; sourceUrl?: string; pageUrl?: string; source: string; query?: string }[]` 与 `adoptedImageIds?: string[]`
  - `traceStep<T>(step, title, fn, brief?, attach?)`，其中 `attach?: (value: T) => Partial<Pick<AiTraceEvent, 'images' | 'adoptedImageIds'>>`

- [ ] **Step 1: 追加失败用例**

在 `llm-trace.spec.ts` 末尾追加：

```ts
import { runWithTrace, traceStep } from './llm-trace';
import type { AiTraceEvent } from './llm-trace';

describe('traceStep attach', () => {
  it('attach 返回值合并进 done 事件', async () => {
    const events: AiTraceEvent[] = [];
    let seq = 0;
    await runWithTrace(
      (ev) => {
        seq += 1;
        events.push({ ...ev, seq, ts: 0 } as AiTraceEvent);
      },
      async () => {
        await traceStep(
          'researchImages',
          '参考图抓取',
          async () => ({ images: [{ id: 'a', url: 'https://x/a.jpg', source: 'searxng' }] }),
          (v) => `${v.images.length} 张`,
          (v) => ({ images: v.images }),
        );
      },
    );
    const done = events.find((e) => e.type === 'step' && e.status === 'done');
    expect(done?.images?.[0].id).toBe('a');
    expect(done?.resultBrief).toBe('1 张');
  });

  it('attach 未提供时不带 images 字段', async () => {
    const events: AiTraceEvent[] = [];
    let seq = 0;
    await runWithTrace(
      (ev) => {
        seq += 1;
        events.push({ ...ev, seq, ts: 0 } as AiTraceEvent);
      },
      async () => {
        await traceStep('x', 'X', async () => 1, () => 'ok');
      },
    );
    expect(events.find((e) => e.status === 'done')?.images).toBeUndefined();
  });
});
```

（若文件顶部已 import `runWithTrace` / `traceStep` / `AiTraceEvent` 则不重复 import。）

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- llm-trace.spec`
Expected: FAIL（`traceStep` 不接受第 5 个参数）

- [ ] **Step 3: 改 `llm-trace.ts`**

`AiTraceEvent`（第 44-49 行之间，`resultBrief` 之前）插入：

```ts
  /** 参考图抓取阶段产出的图片（只存 URL 与溯源信息，不存 base64） */
  images?: {
    id: string;
    url: string;
    sourceUrl?: string;
    pageUrl?: string;
    source: string;
    query?: string;
  }[];
  /** 参考图解读阶段被采纳的图片 id（前端据此给缩略图打「已采用」徽标） */
  adoptedImageIds?: string[];
```

`traceStep`（第 106-153 行）改为：

```ts
export async function traceStep<T>(
  step: string,
  title: string,
  fn: () => Promise<T>,
  brief?: (value: T) => string,
  attach?: (value: T) => Partial<Pick<AiTraceEvent, 'images' | 'adoptedImageIds'>>,
): Promise<T> {
  const store = storage.getStore();
  if (!store) return fn();

  const parentStep = topStep()?.step;
  store.stack.push({ step, title });
  const startedAt = Date.now();
  store.sink({ type: 'step', step, title, parentStep, status: 'running' });
  try {
    const value = await fn();
    store.sink({
      type: 'step',
      step,
      title,
      parentStep,
      status: 'done',
      resultBrief: brief?.(value),
      ...(attach?.(value) ?? {}),
      durationMs: Date.now() - startedAt,
    });
    return value;
  } catch (err) {
    // 原有 fail 分支不变
    store.sink({
      type: 'step',
      step,
      title,
      parentStep,
      status: 'fail',
      error: err instanceof Error ? err.message : String(err),
      durationMs: Date.now() - startedAt,
    });
    throw err;
  } finally {
    // 原有出栈逻辑不变
    const top = store.stack[store.stack.length - 1];
    if (top && top.step === step) {
      store.stack.pop();
    } else {
      const last = store.stack.map((s) => s.step).lastIndexOf(step);
      if (last >= 0) store.stack.splice(last, 1);
    }
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- llm-trace.spec`
Expected: PASS（原有用例不回归 + 新增 2 个）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-trace.ts lumira-server/packages/backend/src/modules/ai/llm-trace.spec.ts
git commit -m "feat(ai): trace 事件支持参考图与采纳 id 透传"
```

---

### Task 8: 编排（`TrendResearchService.research()` 串接两阶段）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts:31-72,132-190`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/index.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 `ResearchImagesConfig` / `DEFAULT_RESEARCH_IMAGES_CONFIG` / `toTraceImages`、Task 5 `ResearchImageService`、Task 6 `ResearchVisionService`、Task 7 `traceStep.attach`
- Produces:
  - `SearchSourceConfig` 新增 `categories?: string`
  - `SearchConfig` 新增 `images?: ResearchImagesConfig` 与 `imageSource?: SearchSourceConfig | null`
  - `ResearchResult` 新增 `images?: ResearchImage[]`、`imageErrors?: { name: string; error: string }[]`、`vision?: ResearchVision | null`
  - 构造器变为 `(aiConfigService, researchDigest, researchImages, researchVision)`

- [ ] **Step 1: 追加失败用例**

在 `trend-research.service.spec.ts` 末尾追加：

```ts
import { DEFAULT_RESEARCH_IMAGES_CONFIG } from './research-image';

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
});
```

（若文件已构造 `TrendResearchService` 的旧签名实例，需一并改为 4 参构造。）

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- trend-research.service.spec`
Expected: FAIL（构造器参数数量 / `images` 未定义）

- [ ] **Step 3: 改 `trend-research.service.ts`**

顶部 import 追加：

```ts
import { ResearchImageService } from './research-image.service';
import { ResearchVisionService } from './research-vision.service';
import { DEFAULT_RESEARCH_IMAGES_CONFIG, toTraceImages } from './research-image';
import type { ResearchImage, ResearchImagesConfig } from './research-image';
import type { ResearchVision } from './research-vision';
```

`SearchSourceConfig`（第 32-45 行）追加：

```ts
  /** 检索结果类别（缺省综合网页；'images' 走图片搜索） */
  categories?: string;
```

`SearchConfig`（第 48-51 行）改为：

```ts
export interface SearchConfig {
  enabled: boolean;
  sources: SearchSourceConfig[];
  /** 参考图抓取配置（缺省视为关闭） */
  images?: ResearchImagesConfig;
  /** 第三层图片搜索来源（缺省则不启用图片搜索兜底） */
  imageSource?: SearchSourceConfig | null;
}
```

`ResearchResult`（第 66-72 行）改为：

```ts
export interface ResearchResult {
  items: ResearchItem[];
  sourceErrors?: { name: string; error: string }[];
  brief?: ResearchBrief | null;
  /** 抓取落盘的参考图（总开关关闭时为空数组） */
  images?: ResearchImage[];
  /** 参考图抓取的单条失败原因 */
  imageErrors?: { name: string; error: string }[];
  /** 参考图多模态解读结论（未启用/无图/失败 → null） */
  vision?: ResearchVision | null;
}
```

构造器（第 79-82 行）改为：

```ts
  constructor(
    private readonly aiConfigService: AiConfigService,
    private readonly researchDigest: ResearchDigestService,
    private readonly researchImages: ResearchImageService,
    private readonly researchVision: ResearchVisionService,
  ) {}
```

`research()` 末尾（第 186-189 行）改为：

```ts
    // 二次整理：把原始条目交给文本模型提炼成结构化结论（内部以 traceStep 记录为「趋势研究」的
    // 子步骤「资料整理」）。失败/无有效内容 → null，由调用方回退规则摘要 buildResearchDigest。
    const brief = out.length ? await this.researchDigest.summarize(topic, out) : null;

    // ===== 参考图支路：抓取（三层递进）→ 多模态解读 =====
    // 两阶段都包在 traceStep 内，因 research() 自身已在 traceStep('research') 上下文里，
    // 它们的 parentStep 天然为 'research'，后台时间线自动渲染为子阶段。
    const imagesCfg = cfg.images ?? DEFAULT_RESEARCH_IMAGES_CONFIG;
    let images: ResearchImage[] = [];
    let imageErrors: { name: string; error: string }[] = [];
    let vision: ResearchVision | null = null;
    if (imagesCfg.enabled) {
      // 第三层图片搜索：由本服务按 imageSource 配置构建（缺省不启用该层）
      const imageSource = cfg.imageSource;
      const imagesSearch = imageSource
        ? async (q: string): Promise<ResearchItem[]> => {
            const provider = this.factory(imageSource.name, imageSource);
            return cacheableSearch(provider, { query: q, limit, categories: 'images' });
          }
        : null;
      try {
        const r = await traceStep(
          'researchImages',
          '参考图抓取',
          () => this.researchImages.collect({ items: out, queries, imagesSearch, cfg: imagesCfg }),
          (res) => (res.images.length ? `抓取 ${res.images.length} 张参考图${res.errors.length ? `（${res.errors.length} 处失败）` : ''}` : '未抓到参考图'),
          (res) => ({ images: toTraceImages(res.images) }),
        );
        images = r.images;
        imageErrors = r.errors;
      } catch (err) {
        imageErrors.push({ name: 'collect', error: err instanceof Error ? err.message : String(err) });
      }

      if (imagesCfg.vision && images.length) {
        try {
          const loaded = (
            await Promise.all(
              images.map(async (image) => {
                const data = await this.researchImages.readBase64(image.id);
                return data ? { image, base64: data.base64, mime: data.mime } : null;
              }),
            )
          ).filter((v): v is { image: ResearchImage; base64: string; mime: string } => v !== null);
          vision = await this.researchVision.interpret(topic, loaded);
        } catch {
          vision = null;
        }
      }
    }

    return { items: out, sourceErrors, brief, images, imageErrors, vision };
```

- [ ] **Step 4: 改 `index.ts`**

追加导出：

```ts
export { ResearchImageService } from './research-image.service';
export { ResearchVisionService } from './research-vision.service';
export {
  DEFAULT_RESEARCH_IMAGES_CONFIG,
  toTraceImage,
  toTraceImages,
} from './research-image';
export type {
  ResearchImage,
  ResearchImagesResult,
  ResearchImagesConfig,
  ResearchImageLayer,
  ImageCandidate,
  TraceImage,
} from './research-image';
export { normalizeVision, renderResearchVision, visionHasContent } from './research-vision';
export type { ResearchVision } from './research-vision';
```

- [ ] **Step 5: 在 `ai.module.ts` 注册新服务**

在 `lumira-server/packages/backend/src/modules/ai/ai.module.ts` 的 providers 数组里，`ResearchDigestService` 旁追加 `ResearchImageService`、`ResearchVisionService`（若模块以 `TrendResearchService` 等聚合数组声明，按同一风格补充；实施时先读该文件确认声明方式）。

- [ ] **Step 6: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- trend-research`
Expected: PASS（新增 3 个用例 + 原有不回归）

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/
git commit -m "feat(ai): 趋势研究串接参考图抓取与多模态解读"
```

---

### Task 9: 配置层（迁移 048 + schema + DTO + service）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/048_ai_config_research_images.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（`aiProviderConfig` 表定义）
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`（追加用例，若不存在则新建）

**Interfaces:**
- Consumes: Task 1 `ResearchImagesConfig` / `DEFAULT_RESEARCH_IMAGES_CONFIG`
- Produces:
  - 表 `ai_provider_config` 新列：`research_images_enabled`、`research_images_max`、`research_images_page_fetch`、`research_images_search_fallback`、`research_images_vision`、`research_images_ttl_days`
  - `AiProviderConfigView` 新增 `researchImagesEnabled` / `researchImagesMax` / `researchImagesPageFetch` / `researchImagesSearchFallback` / `researchImagesVision` / `researchImagesTtlDays`
  - `getSearchConfig()` 返回值新增 `images: ResearchImagesConfig`，并在 searxng 分支提供 `imageSource`

- [ ] **Step 1: 写迁移 SQL**

```sql
-- 048_ai_config_research_images.sql
-- AI 参考图抓取配置（spec 2026-09-28-ai-research-reference-images-design.md 第 8 章）
-- 参考图是短 TTL 内部缓存，不为图片新建表；配置随 ai_provider_config 单行配置扩展。

ALTER TABLE `ai_provider_config`
  ADD COLUMN `research_images_enabled` TINYINT NOT NULL DEFAULT 0 COMMENT '参考图抓取总开关',
  ADD COLUMN `research_images_max` INT NOT NULL DEFAULT 6 COMMENT '每主题最多保留张数',
  ADD COLUMN `research_images_page_fetch` TINYINT NOT NULL DEFAULT 1 COMMENT '启用抓页面 og:image',
  ADD COLUMN `research_images_search_fallback` TINYINT NOT NULL DEFAULT 1 COMMENT '启用图片搜索兜底',
  ADD COLUMN `research_images_vision` TINYINT NOT NULL DEFAULT 1 COMMENT '启用多模态解读',
  ADD COLUMN `research_images_ttl_days` INT NOT NULL DEFAULT 7 COMMENT '落盘图片保留天数';
```

- [ ] **Step 2: 改 `schema.ts`**

在 `aiProviderConfig` 表定义（`opencode` 中位于 `047` 迁移对应的 `llmRetryCount` / `llmTimeoutMs` / `llmMaxTokens` 列旁边）追加 6 列，风格与既有列一致：

```ts
  researchImagesEnabled: tinyint('research_images_enabled').notNull().default(0),
  researchImagesMax: int('research_images_max').notNull().default(6),
  researchImagesPageFetch: tinyint('research_images_page_fetch').notNull().default(1),
  researchImagesSearchFallback: tinyint('research_images_search_fallback').notNull().default(1),
  researchImagesVision: tinyint('research_images_vision').notNull().default(1),
  researchImagesTtlDays: int('research_images_ttl_days').notNull().default(7),
```

（`tinyint` / `int` helper 名以该文件既有用法为准；实施时先读 `schema.ts` 中 `aiProviderConfig` 段落确认。）

- [ ] **Step 3: 追加失败用例**

在 `ai-config.service.spec.ts` 末尾追加：

```ts
describe('researchImages 配置', () => {
  it('默认关闭且张数/ TTL 有默认值', async () => {
    // 复用文件内既有的 fake DB 构造范式；断言 getSearchConfig().images 的默认值
    // 关键断言（与实现保持一致）：
    //   images.enabled === false
    //   images.max === 6
    //   images.pageFetch === true
    //   images.searchFallback === true
    //   images.vision === true
    //   images.ttlDays === 7
  });
});
```

> 说明：该用例需复用 `ai-config.service.spec.ts` 内既有的 DB 替身范式（文件里已有对 `getSearchConfig` 的测试）。实施时按既有写法补齐断言，**不要**引入新的测试基建。

- [ ] **Step 4: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- ai-config.service.spec`
Expected: FAIL（`getSearchConfig().images` 为 undefined）

- [ ] **Step 5: 改 `update-ai-config.dto.ts`**

追加 6 个可选字段（风格与既有字段一致，使用 `@IsOptional()` + 相应 `@IsBoolean()` / `@IsInt()` / `@Min` / `@Max`）：

```ts
  @IsOptional()
  @IsBoolean()
  researchImagesEnabled?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  researchImagesMax?: number;

  @IsOptional()
  @IsBoolean()
  researchImagesPageFetch?: boolean;

  @IsOptional()
  @IsBoolean()
  researchImagesSearchFallback?: boolean;

  @IsOptional()
  @IsBoolean()
  researchImagesVision?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  researchImagesTtlDays?: number;
```

（class-validator 装饰器 import 若未含 `IsBoolean` 需补上。）

- [ ] **Step 6: 改 `ai-config.service.ts`**

1. `AiProviderConfigView` 追加 6 个字段（与 schema 列名 camelCase 对齐）：

```ts
  researchImagesEnabled: boolean;
  researchImagesMax: number;
  researchImagesPageFetch: boolean;
  researchImagesSearchFallback: boolean;
  researchImagesVision: boolean;
  researchImagesTtlDays: number;
```

2. `AiConfigView` 转 `AiProviderConfigView` 的映射处补 6 项：

```ts
    researchImagesEnabled: row.researchImagesEnabled === 1,
    researchImagesMax: row.researchImagesMax,
    researchImagesPageFetch: row.researchImagesPageFetch === 1,
    researchImagesSearchFallback: row.researchImagesSearchFallback === 1,
    researchImagesVision: row.researchImagesVision === 1,
    researchImagesTtlDays: row.researchImagesTtlDays,
```

3. `save(dto)` 的 upsert `values` 与 `onDuplicateKeyUpdate` 对象同步补 6 项（boolean 入库转 1/0）：

```ts
  researchImagesEnabled: dto.researchImagesEnabled ? 1 : 0,
  researchImagesMax: dto.researchImagesMax,
  researchImagesPageFetch: dto.researchImagesPageFetch ? 1 : 0,
  researchImagesSearchFallback: dto.researchImagesSearchFallback ? 1 : 0,
  researchImagesVision: dto.researchImagesVision ? 1 : 0,
  researchImagesTtlDays: dto.researchImagesTtlDays,
```

> 注意：`save()` 是「未传字段保留原值」语义时，需按该文件既有范式处理（既有字段如 `searchSite` 已有此逻辑，照抄其分支写法），不得让未传的 `researchImages*` 覆盖为默认值。

4. `getSearchConfig()` 返回对象补 `images` 与 `imageSource`：

```ts
    const images: ResearchImagesConfig = {
      enabled: row.researchImagesEnabled === 1,
      max: row.researchImagesMax,
      pageFetch: row.researchImagesPageFetch === 1,
      searchFallback: row.researchImagesSearchFallback === 1,
      vision: row.researchImagesVision === 1,
      ttlDays: row.researchImagesTtlDays,
    };
```

searxng 分支（既有展开 4 个平台站 + `searxng-all` 之处）在 `return` 对象里追加图片搜索来源——**复用第一个 searxng 站点的 baseUrl/apiKey，仅把 categories 固定为 images**：

```ts
      imageSource: {
        name: 'searxng-images',
        provider: 'searxng',
        baseUrl: searchBaseUrl,
        apiKey: searchApiKey,
        categories: 'images',
      },
```

非 searxng 分支与 `enabled: false` 分支：`images` 仍按上表回填（TTL/上限供清理服务使用），`imageSource: null`。

- [ ] **Step 7: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- ai-config.service.spec`
Expected: PASS

- [ ] **Step 8: 类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 无错误（该包无 `typecheck` 脚本，`build` 即 `tsc -p tsconfig.build.json`）

- [ ] **Step 9: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/048_ai_config_research_images.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts
git commit -m "feat(ai): 新增参考图抓取配置项（迁移 048）"
```

---

### Task 10: 生图注入（vision 写入提示词）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts`（`PromptComposeInput`、`buildPromptMaterial`、`COMPOSE_SYSTEM_PROMPT`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts`（解析 `researchJson.vision`）
- Test: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts`（追加用例）

**Interfaces:**
- Consumes: Task 1 `renderResearchVision`（渲染后端已渲染为文本，因此入参是字符串）、Task 8 `ResearchResult.vision`
- Produces:
  - `PromptComposeInput` 新增 `vision?: string | null`
  - `composeImagePrompt(textEndpoint, { draft, research, brief, vision, extraPrompt }, fallbackPrompt)`

**关键约束**：`vision` 只以**文本**注入；此任务**不触碰** `image-client.ts` 的 `referenceBase64` 通道。

- [ ] **Step 1: 追加失败用例**

```ts
describe('composeImagePrompt 参考视觉要点', () => {
  it('传入 vision 时提示词含【参考视觉要点】区块且保留结论文本', () => {
    const text = buildPromptMaterial({
      draft: { topic: '旗袍写真' } as never,
      research: [],
      vision: '- 风格倾向：新中式\n- 综合结论：暖调逆光',
    });
    expect(text).toContain('【参考视觉要点】');
    expect(text).toContain('暖调逆光');
  });

  it('未传 vision 时不出现该区块', () => {
    const text = buildPromptMaterial({ draft: { topic: 'x' } as never, research: [] });
    expect(text).not.toContain('【参考视觉要点】');
  });
});
```

（`buildPromptMaterial` 若为模块内私有函数，测试文件需先 `export` 它；本任务允许把该函数 `export` 出来以便测试。若文件内已有对它的测试，直接复用其 import 方式。）

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- image-prompt.composer.spec`
Expected: FAIL（`vision` 未生效 / `buildPromptMaterial` 未导出）

- [ ] **Step 3: 改 `image-prompt.composer.ts`**

`PromptComposeInput` 追加字段：

```ts
  /** 参考图多模态解读结论（已由 renderResearchVision 渲染为分节文本；仅作文本注入，不作底图） */
  vision?: string | null;
```

`buildPromptMaterial` 在 ④.5【趋势要点（结构化）】之后、⑤【照片参数】之前插入新区块（编号 ④.6，与 spec 5 章一致）：

```ts
  const visionText = (input.vision ?? '').trim();
  if (visionText) {
    sections.push(['【参考视觉要点】', visionText].join('\n'));
  }
```

（`sections` 为该函数内既有的分节累积数组；实施时按该文件实际变量名接入。）

`COMPOSE_SYSTEM_PROMPT` 规则末尾追加一条：

```
7. 【参考视觉要点】来自对参考网站图片的视觉提炼：可作为风格/色彩/构图/穿搭/场景的参考依据，但不得照抄具体人物身份、品牌或可识别标识。
```

- [ ] **Step 4: 改 `ai-generate-image.service.ts`**

`researchJson` 解析处（支持数组与 `{ items, brief }` 的既有分支）扩展为同时取 `vision`：

```ts
  let researchItems: ResearchItem[] = [];
  let researchBrief: ResearchBrief | null = null;
  let researchVision: string | null = null;
  if (Array.isArray(parsedResearch)) {
    researchItems = parsedResearch;
  } else if (parsedResearch && typeof parsedResearch === 'object') {
    const rec = parsedResearch as { items?: ResearchItem[]; brief?: ResearchBrief | null; vision?: unknown };
    researchItems = Array.isArray(rec.items) ? rec.items : [];
    researchBrief = rec.brief ?? null;
    researchVision = typeof rec.vision === 'string' ? rec.vision : null;
  }
```

调用处改为：

```ts
  const prompt = await composeImagePrompt(
    cfg.text,
    { draft, research: researchItems, brief: researchBrief, vision: researchVision, extraPrompt },
    fallbackPrompt,
  );
```

> 实施时先读该文件确认既有变量名（`parsedResearch` / `researchItems` / `researchBrief` 可能命名不同），保持其余逻辑不变，仅新增 `vision` 一路。

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- image-prompt`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.spec.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts
git commit -m "feat(ai): 参考视觉要点注入生图提示词"
```

---

### Task 11: 后端接口回传（识别结果携带 images / vision）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`（`AiAnalyzeResult` + `research` 步骤产物捕获 + 两个 return 分支）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`（任务状态接口）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts`（追加用例）

**Interfaces:**
- Consumes: Task 8 `ResearchResult.images` / `vision`、Task 1 `ResearchVision`
- Produces:
  - `AiAnalyzeResult` 新增 `researchImages?: ResearchImage[]`、`researchVision?: ResearchVision | null`
  - `GET /api/v1/admin/ai/templates/analyze/:taskId` 响应新增 `researchImages` 与 `researchVision`

- [ ] **Step 1: 追加失败用例**

在 `ai-analyze.service.spec.ts` 末尾追加（复用文件内既有的 `trendResearch` 替身范式）：

```ts
describe('AiAnalyzeService 参考图回传', () => {
  it('research 结果里的 images / vision 被回传到 AiAnalyzeResult', async () => {
    // 关键断言（与实现一致）：
    //   result.researchImages 深等于 research 替身返回的 images
    //   result.researchVision 深等于 research 替身返回的 vision
  });
});
```

> 该用例需复用文件内既有构造 `AiAnalyzeService` 的方式；仅把 `trendResearch.research` 替身返回值扩展为同时带 `images` / `vision`。

- [ ] **Step 2: 运行确认失败**

Run: `pnpm --filter @lumira/backend test -- ai-analyze.service.spec`
Expected: FAIL（`researchImages` 为 undefined）

- [ ] **Step 3: 改 `ai-analyze.service.ts`**

`AiAnalyzeResult` 追加：

```ts
  /** 抓取落盘的参考图（供后台时间线/结果弹窗展示；未启用为空数组） */
  researchImages?: ResearchImage[];
  /** 参考图多模态解读结论（未启用/失败为 null） */
  researchVision?: ResearchVision | null;
```

`const r = await traceStep('research', '趋势研究（联网检索）', ...)` 之后追加：

```ts
    const researchImages = r.images ?? [];
    const researchVision = r.vision ?? null;
```

两个 return 分支各补两项：

```ts
      researchImages,
      researchVision,
```

- [ ] **Step 4: 改 `ai-templates.controller.ts`**

任务状态接口返回对象补：

```ts
      researchImages: task.result?.researchImages ?? [],
      researchVision: task.result?.researchVision ?? null,
```

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- ai-analyze`
Expected: PASS

- [ ] **Step 6: 类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 无错误（该包无 `typecheck` 脚本，`build` 即 `tsc -p tsconfig.build.json`）

- [ ] **Step 7: Commit 并推送两个远程**

```bash
git add lumira-server/packages/backend/src/modules/ai/
git commit -m "feat(ai): 识别接口回传参考图与视觉结论"
git push origin master
git push github master
```

---

### Task 12: 后台 UI（时间线图片网格 + 结果弹窗 + 配置表单 + vision 透传）

**Files:**
- Create: `lumira-server/packages/admin/src/components/ai-create/trace-image-grid.tsx`
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx`
- Modify: `lumira-server/packages/admin/src/components/ai-create/analyze-result-dialog.tsx`
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts`
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`
- Modify: `lumira-server/packages/admin/src/components/ai-create/step-cover.tsx`

**Interfaces:**
- Consumes: Task 11 接口响应字段 `researchImages` / `researchVision`；Task 7 trace 事件字段 `images` / `adoptedImageIds`
- Produces:
  - `interface AiResearchImage { id: string; url: string; sourceUrl?: string; pageUrl?: string; source: string; query?: string; layer: string; width?: number; height?: number; bytes: number }`
  - `interface AiResearchVision { summary: string; styles: string[]; colorLight: string[]; composition: string[]; wardrobe: string[]; scene: string[]; adopted: { id: string; reason: string }[] }`
  - `function TraceImageGrid({ images, adoptedImageIds, className }: { images: AiTraceImage[]; adoptedImageIds?: string[]; className?: string })`

- [ ] **Step 1: 改 `types/admin.ts`**

1. `AiTraceEvent` 追加：

```ts
  /** 参考图抓取阶段产出的图片 */
  images?: Array<{ id: string; url: string; sourceUrl?: string; pageUrl?: string; source: string; query?: string }>;
  /** 参考图解读阶段被采纳的图片 id */
  adoptedImageIds?: string[];
```

2. 新增类型：

```ts
export interface AiTraceImage {
  id: string;
  url: string;
  sourceUrl?: string;
  pageUrl?: string;
  source: string;
  query?: string;
}

export interface AiResearchImage extends AiTraceImage {
  layer: string;
  width?: number;
  height?: number;
  bytes: number;
}

export interface AiResearchVision {
  summary: string;
  styles: string[];
  colorLight: string[];
  composition: string[];
  wardrobe: string[];
  scene: string[];
  adopted: { id: string; reason: string }[];
}
```

3. `AiAnalyzeStatusResult`、`AiAnalyzeResult` 各追加：

```ts
  researchImages?: AiResearchImage[];
  researchVision?: AiResearchVision | null;
```

4. `AiProviderConfigView` 与 `UpdateAiConfigPayload` 各追加 6 项（与后端 Task 9 的 `AiProviderConfigView` 同名）：

```ts
  researchImagesEnabled?: boolean;
  researchImagesMax?: number;
  researchImagesPageFetch?: boolean;
  researchImagesSearchFallback?: boolean;
  researchImagesVision?: boolean;
  researchImagesTtlDays?: number;
```

（`AiProviderConfigView` 中这 6 项为**必填**——后端已恒返回；`UpdateAiConfigPayload` 中为可选。实施时按两个类型各自既有字段的可选性风格对齐。）

- [ ] **Step 2: 新建 `trace-image-grid.tsx`**

```tsx
// 参考图缩略图网格：来源域名 / 命中检索词 / 「已采用」徽标 / 点击看大图 / 加载失败占位。
'use client';

import { useState } from 'react';
import type { AiTraceImage } from '@/types/admin';
import { cn } from '@/lib/utils';

/** 从 URL 取域名用于展示 */
function hostOf(url?: string): string {
  if (!url) return '';
  try {
    return new URL(url).hostname;
  } catch {
    return '';
  }
}

export function TraceImageGrid({
  images,
  adoptedImageIds,
  className,
}: {
  images: AiTraceImage[];
  adoptedImageIds?: string[];
  className?: string;
}) {
  const [preview, setPreview] = useState<AiTraceImage | null>(null);
  if (!images.length) return null;
  const adopted = new Set(adoptedImageIds ?? []);

  return (
    <div className={cn('space-y-2', className)}>
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-6">
        {images.map((img) => {
          const isAdopted = adopted.has(img.id);
          const host = hostOf(img.pageUrl ?? img.sourceUrl);
          return (
            <button
              key={img.id}
              type="button"
              onClick={() => setPreview(img)}
              className={cn(
                'group relative overflow-hidden rounded-md border bg-muted text-left',
                isAdopted ? 'border-primary ring-1 ring-primary/40' : 'border-border',
              )}
              title={img.sourceUrl ?? img.url}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={img.url}
                alt={img.query ?? '参考图'}
                loading="lazy"
                className="h-20 w-full object-cover transition-transform group-hover:scale-105"
              />
              {isAdopted ? (
                <span className="absolute left-1 top-1 rounded bg-primary px-1 py-0.5 text-[10px] font-medium text-primary-foreground">
                  已采用
                </span>
              ) : null}
              <span className="block truncate px-1 py-0.5 text-[10px] text-muted-foreground">
                {host}
                {img.query ? ` · ${img.query}` : ''}
              </span>
            </button>
          );
        })}
      </div>

      {preview ? (
        <div
          role="presentation"
          onClick={() => setPreview(null)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={preview.url} alt={preview.query ?? '参考图'} className="max-h-[80vh] max-w-[90vw] object-contain" />
        </div>
      ) : null}
    </div>
  );
}
```

- [ ] **Step 3: 改 `analyze-trace-stream.tsx`**

1. `StepNode` 追加：

```ts
  images?: AiTraceImage[];
  adoptedImageIds?: string[];
```

2. `buildTimeline()` 中「done 事件关闭 running 节点」处，把事件字段带入节点：

```ts
      node.images = event.images ?? node.images;
      node.adoptedImageIds = event.adoptedImageIds ?? node.adoptedImageIds;
```

3. 顶层组件算出全量采纳集合并向下传（`researchImages` 与 `researchVision` 是同父两兄弟节点，需要在顶层合并）：

```tsx
  const adoptedImageIds = events.flatMap((e) => e.adoptedImageIds ?? []);
```

4. `renderItems(items)` / `StepRow` / `RowDetail` 增加 `adoptedImageIds: string[]` 形参并逐层透传；在 `RowDetail` 的 brief/error 之后渲染：

```tsx
        {row.node.images?.length ? (
          <TraceImageGrid images={row.node.images} adoptedImageIds={adoptedImageIds} className="mt-2" />
        ) : null}
```

（`renderItems` 是自由函数，需把 `adoptedImageIds` 作为参数传入并在其递归调用中继续传递。）

- [ ] **Step 4: 改 `analyze-result-dialog.tsx`**

`ResearchTab` 改为接收视觉结论；在既有条目列表之上插入图片网格与结论：

```tsx
function ResearchTab({ items, images, vision }: { items: AiResearchRef[]; images?: AiResearchImage[]; vision?: AiResearchVision | null }) {
  return (
    <div className="space-y-3">
      {images?.length ? (
        <div className="space-y-2">
          <div className="text-xs font-medium text-muted-foreground">参考图片（{images.length} 张）</div>
          <TraceImageGrid images={images} adoptedImageIds={vision?.adopted.map((a) => a.id) ?? []} />
        </div>
      ) : null}
      {vision ? (
        <div className="space-y-1 rounded-md border p-3 text-sm">
          <div className="text-xs font-medium text-muted-foreground">视觉结论</div>
          {vision.styles.length ? <div>风格倾向：{vision.styles.join('；')}</div> : null}
          {vision.colorLight.length ? <div>色彩与光影：{vision.colorLight.join('；')}</div> : null}
          {vision.composition.length ? <div>构图：{vision.composition.join('；')}</div> : null}
          {vision.wardrobe.length ? <div>穿搭/妆造：{vision.wardrobe.join('；')}</div> : null}
          {vision.scene.length ? <div>场景：{vision.scene.join('；')}</div> : null}
          {vision.summary ? <div className="text-muted-foreground">综合结论：{vision.summary}</div> : null}
        </div>
      ) : null}
      {/* 既有 <ul> URL 列表保持不变 */}
    </div>
  );
}
```

Tab 调用处传入 `researchImages={result.researchImages}` / `researchVision={result.researchVision}`。

- [ ] **Step 5: 改 `ai-config-form.tsx`**

1. `FormState` 追加：

```ts
  researchImagesEnabled: boolean;
  researchImagesMax: number;
  researchImagesPageFetch: boolean;
  researchImagesSearchFallback: boolean;
  researchImagesVision: boolean;
  researchImagesTtlDays: number;
```

2. `useState` 初始化（configured 分支）补 6 项读取 `initial.researchImages*`，未配置分支与 `DEFAULT` 一致（`enabled: false, max: 6, pageFetch: true, searchFallback: true, vision: true, ttlDays: 7`）。

3. payload 构建处（研究管线分支）补 6 项。

4. UI：在「迭代上限」块（约 1013-1033 行）之后、识别稳定性块（约 1035 行）之前插入参考图配置块：

```tsx
        <div className="space-y-3 rounded-lg border p-3">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm font-medium">参考图抓取</div>
              <p className="text-xs text-muted-foreground">联网检索后抓取参考网站图片，交给多模态模型转述后注入生图提示词（仅作文本参考，不作底图）</p>
            </div>
            <Switch
              checked={form.researchImagesEnabled}
              onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesEnabled: v }))}
            />
          </div>
          {form.researchImagesEnabled ? (
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label htmlFor="ri-max">最多保留张数</Label>
                <Input id="ri-max" type="number" min={1} max={12} value={form.researchImagesMax}
                  onChange={(e) => setForm((s) => ({ ...s, researchImagesMax: Number(e.target.value) || 6 }))} />
              </div>
              <div className="space-y-1">
                <Label htmlFor="ri-ttl">图片保留天数</Label>
                <Input id="ri-ttl" type="number" min={1} max={90} value={form.researchImagesTtlDays}
                  onChange={(e) => setForm((s) => ({ ...s, researchImagesTtlDays: Number(e.target.value) || 7 }))} />
              </div>
              <label className="flex items-center gap-2 text-sm">
                <Switch checked={form.researchImagesPageFetch}
                  onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesPageFetch: v }))} />
                抓取命中页面 og:image
              </label>
              <label className="flex items-center gap-2 text-sm">
                <Switch checked={form.researchImagesSearchFallback}
                  onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesSearchFallback: v }))} />
                图片搜索兜底
              </label>
              <label className="flex items-center gap-2 text-sm">
                <Switch checked={form.researchImagesVision}
                  onCheckedChange={(v) => setForm((s) => ({ ...s, researchImagesVision: v }))} />
                多模态解读
              </label>
            </div>
          ) : null}
        </div>
```

- [ ] **Step 6: vision 透传（`ai-task.ts` / `wizard.tsx` / `step-cover.tsx`）**

1. `ai-task.ts`：`generateAiPoseImages` 的 options 类型与解构增加 `researchVision?: AiResearchVision | null`（第 77 行解构处），并在构造 research 请求体的地方把它带上：

```ts
      research: research ?? null,
      researchBrief: researchBrief ?? null,
      researchVision: researchVision ?? null,
```

同时后端 `AiAnalyzeResult` 的 vision 需要渲染文本：**在 admin 侧直接把 `AiResearchVision` 序列化透传即可**——后端 `ai-generate-image.service.ts` 读取 `vision` 字段时若为非字符串对象，则调用 `renderResearchVision` 渲染（在 Task 10 的解析分支追加：`typeof rec.vision === 'string' ? rec.vision : rec.vision ? renderResearchVision(rec.vision) : null`，需从 trend-research 导入 `renderResearchVision`）。

2. `wizard.tsx:377-378` 与 `869-870`：在传 `research` / `researchBrief` 处一并传 `researchVision: analyzeResult.researchVision ?? null` 与 `researchVision={analyzeDetail?.researchVision ?? null}`。

3. `step-cover.tsx:175-176`：解构 `research, researchBrief,` 处补 `researchVision,`，并原样传下去。

- [ ] **Step 7: 构建验证**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建成功、无类型错误、无 lint 阻断

- [ ] **Step 8: Commit 并推送两个远程**

```bash
git add lumira-server/packages/admin/src/
git commit -m "feat(admin): 识别流程展示参考图与采纳标记，新增参考图抓取配置"
git push origin master
git push github master
```

---

### Task 13: 部署配置与全量验证

**Files:**
- Modify: `deploy/searxng/settings.yml`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/index.ts`（若有遗漏导出）

- [ ] **Step 1: 启用 searxng 图片引擎**

在 `engines:` 下按既有 `sogou` 条目风格追加：

```yaml
  - name: sogou images
    engine: sogou_images
    categories: [images]
    disabled: false
```

（`sogou_images` 为 SearXNG 内置引擎名；若当前 SearXNG 版本引擎名不同，用 `docker exec` 进容器执行 `python -m searx.engines` 或查阅该版本 `searx/settings.yml` 确认后修正。）

- [ ] **Step 2: 后端全量测试**

Run: `pnpm --filter @lumira/backend test`
Expected: 全部 PASS（含本计划新增的全部 spec）

- [ ] **Step 3: 后端类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 无错误（该包无 `typecheck` 脚本，`build` 即 `tsc -p tsconfig.build.json`）

- [ ] **Step 4: 后台构建**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建成功

- [ ] **Step 5: 端到端人工核对清单**

在后台「AI 一键生成模板」页：
1. AI 配置里开启「参考图抓取」，保存后刷新页面配置回显正确。
2. 发起一次识别，时间线出现「参考图抓取」与「参考图解读」两个子阶段（`parentStep='research'`）。
3. 「参考图抓取」阶段下方出现缩略图网格；被采纳的图带「已采用」徽标。
4. 结果弹窗「参考来源」Tab 同时出现图片网格与「视觉结论」区块。
5. 生图提示词（结果弹窗 raw / 后端日志）中出现【参考视觉要点】区块。
6. 等 TTL 到期后（或手动改小 TTL 重启发服务）`{UPLOAD_DIR}/research/` 下过期文件被清理。

- [ ] **Step 6: Commit 并推送两个远程**

```bash
git add deploy/searxng/settings.yml
git commit -m "chore(deploy): searxng 启用图片搜索引擎"
git push origin master
git push github master
```

---

## 自查（Self-Review）

**1. Spec 覆盖检查**

| spec 章节 | 覆盖任务 |
|---|---|
| 3 总体链路 | Task 8（编排）、Task 11（接口回传）、Task 12（可视化） |
| 4 数据模型 | Task 1（类型）、Task 4（落盘 URL/TTL） |
| 5.1 三层递进 | Task 5（collect 三层） |
| 5.2 后处理管线 | Task 3（抓取校验）、Task 4（压缩） |
| 5.3 护栏（并发/预算/去重） | Task 5 |
| 5.4 失败降级 | Task 5（静默跳过 + errors） |
| 6 多模态解读 | Task 6（`visionChatMulti` + service）、Task 1（`normalizeVision` 过滤） |
| 7 识别流程可视化 | Task 7（trace 字段）、Task 12（时间线与弹窗） |
| 8 配置表 | Task 9（迁移 048 + schema + dto + service）、Task 12（表单） |
| 9 错误降级表 | Task 5、Task 8（try/catch 包裹）、Task 6（返回 null） |
| 10 测试策略 | 各任务 spec |
| 11 实施顺序 | 本计划 13 个任务（编号 048 已修正） |
| 部署（searxng 图片引擎） | Task 13 |

**2. 占位符检查**：已通读——除 Task 9 Step 3 与 Task 11 Step 1 的测试用例因需复用既有测试替身范式而以「关键断言清单」形式给出外，其余步骤均含可直接落地的完整代码或明确到行的改动指令。上述两处已在步骤内写明「复用文件内既有范式、不引入新测试基建」，不属于 TBD。

**3. 类型一致性检查**

- `ResearchImage.id` 全链路统一为「内容哈希 sha256 前 16 位」：Task 4 `hashBuffer` 产出 → Task 5 用作落盘 id → Task 6 `normalizeVision(allowedIds)` 校验 → Task 12 前端 `adoptedImageIds` 匹配。
- `ResearchImagesConfig` 字段名（`enabled` / `max` / `pageFetch` / `searchFallback` / `vision` / `ttlDays`）在 Task 1、Task 5、Task 8、Task 9 一致。
- `AiTraceEvent.images` 与 `TraceImage` 结构同形（Task 7 已注明不 import 以免循环依赖）。
- 后端 `AiProviderConfigView.researchImages*` 与 admin `AiProviderConfigView.researchImages*` 命名一致（Task 9 / Task 12）。
- `traceStep` 第 5 参数 `attach` 由 Task 7 引入，Task 6 / Task 8 依赖它——**实施顺序必须先 Task 7 再 Task 6**。

**4. 已知实施顺序调整**：Task 6（`ResearchVisionService`）依赖 Task 7（`traceStep.attach`）。执行时按 **1 → 2 → 3 → 4 → 5 → 7 → 6 → 8 → 9 → 10 → 11 → 12 → 13** 顺序，其余依赖关系均满足。
