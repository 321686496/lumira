# AI 一键生成模板：参考网站图片抓取 → 多模态转述 → 识别流程可视化

- 日期：2026-09-28
- 范围：`lumira-server/packages/backend`（主）+ `lumira-server/packages/admin`（识别流程 UI）+ `deploy/searxng`（图片引擎）
- 关联：
  - `2026-09-28-ai-template-multi-subject-photoreal-search-design.md`（**取代其「期 2」章节**）
  - `2026-09-21-ai-template-trend-orchestrator-design.md`（检索源 / `ResearchItem`）
  - `2026-09-24-ai-llm-raw-trace-design.md`、`2026-09-24-ai-create-process-trace-design.md`（识别流程时间线）
  - `2026-09-26-research-digest-and-timeline-design.md`（`ResearchBrief` / 资料整理）
- Flutter 端：不涉及
- 前置状态：多人物 / 去噪写实 / 搜索内容落地（上述 spec 的「期 1」）已落地；本文档对应其未实现的「期 2」，并做增强与取代

---

## 1. 背景与问题

后台「AI 一键生成模板」的趋势研究已能联网检索文本条目并二次整理成 `ResearchBrief`，但存在两个缺口：

1. **检索只拿文字，不拿图**。`ResearchItem` 早已预留 `imgUrl?` 字段（`research-item.ts` L15，注释「交给 T2 队列识别」），但：
   - `web-search-searxng.ts` 只取 `title/url/content`，**丢掉了 SearXNG 结果里可能带的 `img_src` / `thumbnail` / `thumbnail_src`**；
   - `qwen-shared.ts` 的 `toResearchItem` 只映射 `title/snippet/url`，不解析图片；
   - 唯一让模型输出 `imgUrl` 的 `web-search-vendor.ts`，其返回的图片链接基本是模型幻觉；
   - 该字段目前**无人消费**。
2. **识别流程看不到任何图片**。后台识别流程时间线对检索调用只渲染「检索词 / 命中摘要 / 上游原始响应 JSON」，结果弹窗的「参考来源」Tab 也只列 `title + url + snippet`（`AiResearchRef` 无图片字段）。运营无法核对「AI 到底参考了哪些图、用没用」。

同时，既有 spec 的「期 2」已规划过此事，但其取向为「**图片只落临时目录、识别完立即删除、只转文字**」。该取向与「识别流程里要能稳定显示参考图缩略图」冲突：图片一旦删除，时间线只能挂外链原图，而小红书 / 抖音等站点防盗链会导致缩略图大概率加载失败。

## 2. 目标与非目标

### 目标

- **抓图**：联网检索后，按三层递进抓取参考网站图片，落盘为可稳定访问的短 TTL 缓存。
- **看图**：把抓到的参考图交给多模态模型，产出结构化视觉结论（风格 / 色彩光影 / 构图 / 穿搭 / 场景），**转成文字注入生图提示词**，提升真实感与场景感。
- **看得见**：在后台识别流程时间线中新增独立阶段，展示「参考了哪些图（缩略图 + 来源 + 命中检索词）」，并给真正被多模态采纳的图标「已采用」徽标；结果弹窗「参考来源」Tab 同步展示。
- **可控可降级**：后台可开关、可限张数；任何一层失败静默降级，绝不阻断识别主流程。

### 非目标

- **不把参考图作为 img2img 底图**（沿用既有 spec 的版权取向）。只做「看图转述再注入提示词」，不改 `image-client.ts` 的 `referenceBase64` 通道。
- 不做图片的永久沉淀；不建立图片素材库、不做图片检索复用。
- 不改动 Flutter 端。
- 不重构 orchestrator 主流程骨架，不替换现有文本检索通道。

## 3. 总体链路

在「趋势研究」之后、注入识别提示词之前插入两个阶段，全部归属 `trend-research/` 模块：

```
查询词重组 → 多源联网检索 → 二次整理(ResearchDigest)
                                  ↓
                       【新】参考图抓取 researchImages
                                  ↓
                       【新】参考图解读 researchVision（多模态）
                                  ↓
                        识别 analyze → 生图（注入 brief + vision）
```

- 新增服务 `ResearchImageService`（抓图 + 落盘 + 清理）与 `ResearchVisionService`（多模态解读）。
- 两个阶段都在 `TrendResearchService.research()` 内串接（`research()` 目前已在末尾调用 `researchDigest.summarize`），并在 `ResearchResult` 上回传。
- 两阶段都用 `traceStep` 包裹，成为时间线顶层阶段；`researchImages` 的 `parentStep` 为 `research`。

## 4. 数据模型

### 4.1 新增 `trend-research/research-image.ts`

```ts
/** 一张抓取落盘的参考图 */
export interface ResearchImage {
  /** 内容哈希（sha256 前 16 位）：去重键 + 落盘文件名 */
  id: string;
  /** 落盘后的公网可访问 URL（走现有 buildPublicUrl 体系） */
  url: string;
  /** 原图地址（外链，仅作溯源展示，不保证可访问） */
  sourceUrl: string;
  /** 来源页面 URL（若图片来自网页解析） */
  pageUrl?: string;
  /** 来源标识：引擎名（searxng / qwen-official / vendor / images）或页面域名 */
  source: string;
  /** 命中的检索词 */
  query?: string;
  /** 命中的哪一层：metadata | page | image-search */
  layer: 'metadata' | 'page' | 'image-search';
  width?: number;
  height?: number;
  bytes: number;
}

/** 参考图抓取整体结果（供 trace / 结果接口透传） */
export interface ResearchImagesResult {
  images: ResearchImage[];
  /** 单条抓取失败原因（不阻断主流程） */
  errors: { name: string; error: string }[];
}
```

### 4.2 `ResearchResult` 扩展

```ts
export interface ResearchResult {
  items: ResearchItem[];
  sourceErrors?: { name: string; error: string }[];
  brief?: ResearchBrief | null;
  /** 新增 */
  images?: ResearchImage[];
  imageErrors?: { name: string; error: string }[];
  /** 新增 */
  vision?: ResearchVision | null;
}
```

`ResearchItem` 结构不变；`imgUrl` 继续承载「第一层」的图片地址。

### 4.3 落盘与 URL

- 目录：`{UPLOAD_DIR}/research/{id}.{ext}`（生产 `UPLOAD_DIR=/app/data/uploads`，已挂载宿主机 `data/`，无需新增数据卷）。
- 出链：复用 `buildPublicUrl(category, id, filename)` 同款的 `BACKEND_PUBLIC_URL` 拼接逻辑（`admin-templates.service.ts` / `admin-categories.service.ts` 已有实现），生成 `{BACKEND_PUBLIC_URL}/uploads/research/{id}.{ext}`。
- 压缩：`sharp` 下采样长边 ≤1280、jpeg q80，再落盘（后台时间线要放缩略图，不能直接塞外链原图）。
- 去重：`id = sha256(归一化后原图 URL)[0:16]`，同时以 `sha256(内容)` 做二次去重（同图不同 URL 只保留一张）。

### 4.4 生命周期（短 TTL 缓存）

- TTL 由配置 `research_images_ttl_days` 控制，默认 **7 天**。
- 清理：定时任务（每小时）扫描 `{UPLOAD_DIR}/research/`，删除 `mtime` 超过 TTL 的文件；服务启动时同样执行一次兜底清扫。
- **不为参考图新增数据库表**：清理只依赖文件系统 `mtime`，避免为临时缓存引入持久化模型（配置项仍走既有 `ai_config` 表加列）。
- 时间线渲染所需的图片 URL 只存在于识别任务的 `events` 内存对象中，任务生命周期远短于 TTL，故 TTL 内一定可访问。

## 5. 参考图抓取（`ResearchImageService`）

### 5.1 三层递进

按顺序累计，达到 `research_images_max`（默认 6）即停止后续层：

| 层 | 来源 | 说明 |
|---|---|---|
| 1 `metadata` | 检索条目自带图字段 | SearXNG 补解析 `img_src` / `thumbnail` / `thumbnail_src` → `ResearchItem.imgUrl`；Qwen 官方补解析 `output.search_info.search_results[]` 中可能存在的图片字段；vendor 保留现提示词 |
| 2 `page` | 抓命中页面 HTML | `og:image` → `twitter:image` → JSON-LD `image` → 首个 ≥400px 的 `<img>`；单页 5s 超时、重定向 ≤3 跳 |
| 3 `image-search` | 图片搜索兜底 | 复用同一关键词走 SearXNG `categories=images`（**对应既有 spec 4.1**）；需在 `deploy/searxng/settings.yml` 启用 `sogou images` 引擎 |

### 5.2 改动点

- 检索适配器侧：`WebSearchQuery` 增加可选 `categories?: string`；`web-search-searxng.ts` 请求参数带 `categories`，`SearxngResult` 增加 `img_src` / `thumbnail` / `thumbnail_src` 并映射。
- `SearchSourceConfig` 增加可选 `categories?: string`，图片来源可单独配置（如 `site: xiaohongshu.com` + `categories: images`）。
- `web-search.provider.ts` 的工厂透传 `categories`。
- **不改动** 现有文本检索的解析契约与去重口径。

### 5.3 统一后处理管线

每张候选图依次通过：

1. **SSRF 拦截**：仅允许 `http` / `https`；解析 host，若为 IP 字面量或 DNS 结果为私网 / 环回 / 链路本地 / 保留段则拒绝；每次重定向后重新校验。
2. **下载**：`content-type` 必须匹配 `image/jpeg|image/png|image/webp`（白名单），单张 ≤5MB，5s 超时。
3. **尺寸门槛**：解析宽高，任一边 <400px 丢弃。
4. **去重**：URL 哈希 + 内容哈希双键。
5. **压缩 + 落盘**：sharp 压缩后写 `{UPLOAD_DIR}/research/`。

### 5.4 预算与并发

- 最多 `research_images_max` 张；并发上限 3；单图 5s、单页 5s 超时。
- 整体软预算 20s：超预算即停止抓取，使用已成功的结果（不视为失败）。

## 6. 多模态解读（`ResearchVisionService`）

### 6.1 产出结构（新增 `trend-research/research-vision.ts`）

```ts
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
```

- `normalizeVision(raw)`：宽松归一化（去空 / 去重 / 限长 / 限条目数），无有效内容 → `null`。
- `renderResearchVision(vision)`：渲染为带分节小标题的文本块，注入生图提示词。

### 6.2 调用

- 一次调用带入抓到的 N 张图（base64，`llm-client` 已支持 `image_url` 多模态消息），走 `cfg.text`。
- 系统提示词要求：只描述图中真实可见信息、不得编造；`adopted` 仅登记对本次模板构思确实有价值的图（可空）。
- 成功路径由 `traceStep('researchVision', '参考图解读', ...)` 包裹，`resultBrief` 输出采纳张数。
- 失败 / 超时 / 解析失败 / 无图 → `null`，**静默降级**（生图仅用文本 `brief`）。

### 6.3 注入生图

- 生图接口的 `research` JSON 扩展为 `{ items, brief, vision? }`（兼容旧形态：数组 / `{items, brief}`）。
- `ai-generate-image.service.ts` 解析后把 `renderResearchVision(vision)` 与 `renderResearchBrief(brief)` 并列注入 `composeImagePrompt` 的素材。
- 姿势图生成侧（`buildPromptMaterial`）同步新增【参考图视觉要点】区块（对应既有 spec 的【平台图片视觉参考】）。

## 7. 识别流程可视化

### 7.1 Trace 事件扩展

`llm-trace.ts` 与 admin `types/admin.ts` 的 `AiTraceEvent` 新增：

```ts
/** 参考图抓取：该阶段产出的图片（只存 URL，不存 base64） */
images?: {
  id: string;
  url: string;
  sourceUrl?: string;
  pageUrl?: string;
  source: string;
  query?: string;
}[];
/** 参考图解读：被采纳的图片 id */
adoptedImageIds?: string[];
```

- 新增阶段 `researchImages`「参考图抓取」（`parentStep = research`）：其下每个来源一次检索调用事件（复用 `traceSearchCall`，`userPrompt` = 检索词），阶段 `done` 事件携带 `images`。
- 新增阶段 `researchVision`「参考图解读」：阶段 `done` 事件携带 `adoptedImageIds`，`resultBrief` 形如「采纳 N 张 / 未采纳」。
- 已确认 `researchImages` / `researchVision` 会出现在 [analyze-trace-stream.tsx](file:///e:/Project/photo_post/lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx) 的阶段轨道上（该组件按事件自动建树，无需改结构）。

### 7.2 后台 UI 改动

- 新增组件 `admin/src/components/ai-create/trace-image-grid.tsx`：缩略图网格（图片 + 来源域名 + 命中检索词 + 「已采用」徽标 + 点击看大图 + 加载失败占位）。
- 阶段详情渲染：当选中阶段的事件带 `images` 时渲染图片网格；`adoptedImageIds` 来自同一次识别的 `researchVision` 事件，前端做跨事件关联后打徽标。
- 结果弹窗 [analyze-result-dialog.tsx](file:///e:/Project/photo_post/lumira-server/packages/admin/src/components/ai-create/analyze-result-dialog.tsx)：`AiAnalyzeStatusResult` 新增 `researchImages?: AiResearchImage[]`（含 `adopted: boolean`）与 `researchVision?: AiResearchVision | null`；「参考来源」Tab 增加图片网格，并可显示视觉结论。

## 8. 配置（后台「研究管线」）

新增迁移 `043_ai_config_research_images.sql`（`042_ai_config_search_site.sql` 之后），并在 [ai-config-form.tsx](file:///e:/Project/photo_post/lumira-server/packages/admin/src/components/ai-config-form.tsx) 增加表单项：

| 配置键 | 默认 | 说明 |
|---|---|---|
| `research_images_enabled` | `false` | 参考图抓取总开关 |
| `research_images_max` | `6` | 每主题最多保留张数 |
| `research_images_page_fetch` | `true` | 是否启用第二层（抓页面 `og:image`） |
| `research_images_search_fallback` | `true` | 是否启用第三层（图片搜索兜底） |
| `research_images_vision` | `true` | 是否启用多模态解读 |
| `research_images_ttl_days` | `7` | 落盘图片保留天数 |

## 9. 错误处理与降级

| 场景 | 行为 |
|---|---|
| 总开关关闭 | 整条支路跳过，不产生 `researchImages` / `researchVision` 阶段 |
| 第一层无图 | 进入第二层 |
| 第二层抓页失败（反爬 / 超时 / 无 `og:image`） | 记 `imageErrors`，继续下一候选；全部失败进入第三层 |
| 第三层图片搜索不可用 | 记 `imageErrors`，返回已抓到的图（可能为空） |
| SSRF / MIME / 体积 / 尺寸拦截 | 丢弃该候选，静默继续 |
| 超出整体 20s 软预算 | 停止抓取，使用已得结果 |
| 多模态解读失败 / 超时 / 解析失败 | `vision = null`，生图仅注入 `brief` |
| 无图可解读 | 跳过 `researchVision` 阶段 |
| 落盘失败（磁盘满 / 权限） | 丢弃该图并记 `imageErrors`，不阻断 |
| **所有图片相关失败** | **一律不阻断识别主流程**（与现有 `sourceErrors` 取向一致） |

## 10. 测试策略

后端 spec 与实现同目录（`*.spec.ts`）：

- `research-image.service.spec.ts`：
  - 三层来源各自命中路径；层间递进与 `research_images_max` 截断
  - SSRF 拦截（私网 / 环回 / 非法 scheme / 重定向到内网）
  - MIME 白名单、体积上限、尺寸门槛、超时拦截
  - URL 哈希与内容哈希双去重
  - 落盘文件名与 URL 拼接正确；落盘失败降级
  - 软预算耗尽后使用已得结果
- `research-image-cleanup.spec.ts`（或并入上者）：TTL 过期文件被删除、未过期文件保留
- `research-vision.service.spec.ts`：正常解析 / 无图跳过 / 解析失败降级 / `adopted` 归一化
- `research-brief` 同类：`normalizeVision` 边界（全空 → null、超长截断、去重）
- `web-search-searxng.spec.ts`：`categories=images` 参数透传、`img_src` / `thumbnail_src` 映射
- `trend-research.service.spec.ts`：`ResearchResult` 含 `images` / `vision`；抓图失败时识别照常返回
- `llm-trace.spec.ts`：`images` / `adoptedImageIds` 字段记录
- `ai-generate-image.service.spec.ts`：`research` 支持 `{items, brief, vision}`；`vision` 渲染文本注入素材；`vision` 为空时不注入

admin：

- `trace-image-grid` 渲染：正常 / 加载失败占位 / 「已采用」徽标
- `pnpm --filter @lumira/admin build` 类型校验通过

backend：`pnpm --filter @lumira/backend test` + typecheck 通过

## 11. 实施顺序

1. 数据层：`research-image.ts` / `research-vision.ts` 类型与归一化函数 + 单测
2. 检索层：SearXNG `categories` 与图片字段映射、`SearchSourceConfig.categories` 透传 + 单测
3. 抓取层：`ResearchImageService`（三层 + 后处理管线 + 落盘）+ 单测
4. 清理：TTL 定时任务 + 启动兜底清扫 + 单测
5. 解读层：`ResearchVisionService` + 单测
6. 编排：`TrendResearchService.research()` 串接两阶段，`ResearchResult` 扩展 + 单测
7. Trace：`llm-trace.ts` 新字段与事件记录 + 单测
8. 生图注入：`ai-generate-image.service.ts` / 姿势图 `buildPromptMaterial` 支持 `vision` + 单测
9. 接口与后台：`ai-templates.controller.ts` 状态接口回传 `researchImages` / `researchVision`；admin 类型、`trace-image-grid.tsx`、结果弹窗、配置表单项与迁移 043
10. 部署配置：`deploy/searxng/settings.yml` 启用 `sogou images`
11. 全量 `test` + `typecheck` + admin build；提交并双远程推送

## 12. 风险与登记

| 风险 | 处理 |
|---|---|
| 版权 | 参考图仅用于后台内部核查与多模态转述；**不作 img2img 底图、不对外发布**；短 TTL（默认 7 天）自动清理 |
| 反爬 / 防盗链 | 小红书 / 抖音等直爬失败属预期，靠第一层与第三层兜底；缩略图统一走本地落盘 URL，不依赖外链 |
| SSRF | 白名单 scheme + DNS 解析后私网/环回拦截 + 每次重定向重新校验 |
| 成本 | 每主题 ≤`research_images_max` 张；多模态仅 1 次调用；同一主题结果走进程内 LRU 缓存 |
| 存储 | 落盘 `data/uploads/research/`，计入现有数据卷；TTL 自动回收 |
| 时效 | 抓图与解读为**新增串行阶段**，整体软预算 20s；超预算即降级用已得结果 |
| 与既有「期 2」取向冲突 | 本文档**取代**该 spec 第 4 章；其「不落地图片 / 用后即删」改为「短 TTL 缓存」，其余取向（不作 img2img 底图、只转文字反哺）保持 |

### 后续优化登记

以下不在本期实现，实施时若仍需要，追加到 `docs/future-optimizations.md`：

- 图片语义去重（感知哈希 / 视觉相似度），避免同题材重复图占用额度
- 参考图按风格档案分档筛选（提升「注入提示词」的针对性）
- 抓取成功率看板（按来源统计反爬失败率，指导引擎与站点白名单调整）
