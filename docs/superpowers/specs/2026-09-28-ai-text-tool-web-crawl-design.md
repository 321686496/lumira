# AI 一键生成 · 文本模型通用工具循环 + 网页爬取工具 设计

> 日期：2026-09-28
> 范围：后端（`lumira-server/packages/backend/`）+ 后台 AI 设置（`lumira-server/packages/admin/src/components/ai-config-form.tsx`）
> Flutter 端：**零改动**

## 背景与目标

AI 一键生成模板当前把「趋势研究命中的检索条目」二次整理成结构化结论，再交给识别模型产出草稿。检索条目只有标题 + 短摘要（`snippet` 截断 240 字），大量有价值的信息（正文、穿搭逐件描述、姿势要点）无法进入提示词，导致模板的「真实度 / 热点度」受限于搜索引擎摘要质量。

同时 `llm-client.ts` 已在 Task 1 实现函数调用基建（`ToolDef` / `toolChat` / `extractToolCalls`），但**至今没有任何消费者**。

本设计的目标：

1. 建立**通用文本模型工具循环层**：任何「与文本模型对话」的环节，只要模型想调用工具就能调用，而不是在某一步硬编码；
2. 落地**第一个工具 `crawl_website`**：给定 URL 抓取网页正文并清洗为纯文本，供模型按需读取完整内容；
3. 提供**独立可开关、可限额、可降级**的运营控制（后台 AI 设置）。

### 非目标

- 不改视觉模型链路（`visionChat` / `visionChatJson` / `image-describe`）——那不是「文本模型」；
- 不做浏览器渲染（不引入 headless browser），只抓静态 HTML；
- 不做抖音/小红书专有反爬适配（沿用既有登记项，见 `docs/future-optimizations.md`）；
- 不引入新 npm 依赖（用正则与原生化字符串处理做 HTML→文本，与现有 web-search 适配器风格一致）。

## 现状（代码实证）

| 项 | 现状 | 文件 |
| --- | --- | --- |
| 工具调用基建 | `ToolDef` / `ToolCallMsg` / `ToolResultMsg` / `toolChat` / `extractToolCalls` 已实现，**无消费者**；`toolChat` 仅支持单轮、不接受历史消息 | `src/modules/ai/llm-client.ts` |
| 文本模型调用点 | `textChat`（reorganizeQuery / research-digest / prompt-polisher / image-prompt.composer / web-search-vendor）；`textChatJson`（style-profile / pose-ref-sheet / draft-refine / image-score / ai-analyze 文字路径） | 见「接线清单」 |
| JSON 容错封装 | `runJsonChat` / `visionChatJson` / `textChatJson`，`callChat(userText)` 单次调用语义 | `src/modules/ai/llm-json.ts` |
| 检索条目 | `ResearchItem { source,title,snippet,keywords,imgUrl?,url?,date?,popularity? }`，已带 `url` | `src/modules/ai/trend-research/research-item.ts` |
| LLM 配置 | `ai_provider_config` 单行表；已有 `search_*` / `llm_*` 列与后台表单 | `src/database/schema.ts`、`ai-config.service.ts`、`admin/src/components/ai-config-form.tsx` |
| 依赖 | 无 cheerio / jsdom；已有 `sharp` / `jimp` / `onnxruntime-node` | `backend/package.json` |

## 架构总览

```
文本模型调用点（style-profile / pose-ref-sheet / draft-refine / image-score
                / ai-analyze(文字) / research-digest / reorganizeQuery / …）
        │  传入 ctx = resolveTextTools(cfg)   ← cfg.crawl.enabled 决定是否下发
        ▼
chatWithTools(endpoint, input, ctx?)          ← tools/text-tool-loop.ts
        │  ctx 为空 → 直接等价 textChat（零行为变化）
        │  ctx 有值 → 多轮：决定 → tool_calls → 执行工具 → 回填 role:'tool' → 再决定
        ▼
工具注册表  tools/text-tools.ts
        │  crawl_website(url) → crawlUrl()    ← tools/crawl-url.ts
        ▼
fetch(http/https) → 体积/类型校验 → HTML 清洗 → 纯文本（≤6000 字）
```

## 一、通用工具循环层

新增 `src/modules/ai/tools/text-tool-loop.ts`：

```ts
export interface TextToolContext {
  tools: ToolDef[];
  execute(name: string, argsJson: string): Promise<string>;   // 返回回填给模型的字符串
  maxToolCalls: number;                                        // 单会话工具调用总次数上限
}

export interface ChatWithToolsInput {
  systemPrompt: string;
  userText: string;
  jsonMode?: boolean;
  temperature?: number;
  timeoutMs?: number;
  maxTokens?: number;
}

/** ctx 缺省或 tools 为空 → 完全等价 textChat；否则跑工具循环后返回最终内容 */
export async function chatWithTools(
  cfg: LlmEndpoint,
  input: ChatWithToolsInput,
  ctx?: TextToolContext,
): Promise<string>;
```

循环语义：

1. 轮次预算：最多 `TOOL_LOOP_MAX_ROUNDS = 3` 轮；工具调用累计不超过 `ctx.maxToolCalls`；
2. 每轮带 `tools` + `tool_choice:'auto'`（复用 `toolChat`）；
3. 该轮无 `tool_calls` → 该轮 `content` 即最终结果，返回；
4. 有 `tool_calls` → 逐条执行 `ctx.execute`，把结果作为 `role:'tool'` 消息（含 `tool_call_id`）追加进消息历史后进入下一轮；
5. **收尾轮强制去工具**：轮次用尽或工具预算用尽时，发起一次 `tool_choice:'none'` 的普通请求，逼模型输出最终 JSON/正文（避免「只调工具不给结果」）；
6. 任何工具执行抛错 → 回填 `{"error":"..."}` 文本，不中断循环（模型可换 URL 或放弃）。

配套扩展 `llm-client.ts`：

- `toolChat` 增加可选 `messages`（历史）入参，复用既有 `rawChatMessage` 的网络 / 错误映射 / jsonMode 降级逻辑，**签名向后兼容**（不传时行为与现状一致）；
- 新增 `toolChatOnce(cfg, { messages, tools, toolChoice, temperature, timeoutMs, maxTokens })` 供循环渐进追加消息使用（内部仍只走 `rawChatMessage`，不另写 fetch）。

> 说明：`tools` 与 `response_format: json_object` 不同厂商兼容性不一，因此**工具轮不带 jsonMode**，最终结果统一由调用方经 `extractJson` 解析（与现有 `runJsonChat` 语义一致）。

## 二、网页爬取工具 `crawl_website`

新增 `src/modules/ai/tools/crawl-url.ts`：

```ts
export interface CrawlResult { url: string; text: string; chars: number; truncated: boolean }
export async function crawlUrl(url: string): Promise<CrawlResult>;   // 失败抛可读 Error
```

规则（常量集中在文件顶部，便于调整）：

| 项 | 规则 |
| --- | --- |
| 协议 | 仅 `http` / `https`，其余直接拒绝 |
| SSRF 防护 | 拒绝 `localhost` / `*.local` / 私有网段（`10.` `127.` `169.254.` `172.16-31.` `192.168.`）与裸 IP 直连 |
| 超时 | `AbortSignal.timeout(8000)` |
| 响应体 | `Content-Length` 或流式累计超过 `1MB` 即中止 |
| Content-Type | 仅接受 `text/html` / `text/plain` / `application/xhtml+xml`（其余拒绝，如 application/pdf、image/*） |
| 去噪 | 移除 `<script>` `<style>` `<noscript>` `<svg>` `<iframe>` `<template>` 与 HTML 注释 |
| 提正文 | 优先 `<article>` / `<main>` 区块，缺省回退 `<body>` |
| 转文本 | 块级标签 → 换行 → 去标签 → 解码常见实体（`&nbsp; &amp; &lt; &gt; &quot; &#39;`）→ 压缩连续空白 |
| 截断 | 保留前 `MAX_CHARS = 6000` 字，返回 `truncated` 标记 |
| 缓存 | 复用 `trend-research/lru-cache.ts` 的 `LruCache`（key=url，容量 100，仅缓存成功结果） |
| 请求头 | 带明确 `User-Agent`（标识爬虫身份）与 `Accept: text/html`，遵守限速与 ToS |

新增 `src/modules/ai/tools/text-tools.ts`：

```ts
function buildCrawlToolDef(): ToolDef;                   // name: 'crawl_website'
function createCrawlExecutor(budget: { maxToolCalls: number }): TextToolContext['execute'];
export function resolveTextTools(cfg: ActiveAiConfig): TextToolContext | undefined;
```

`crawl_website` 工具定义：

```jsonc
{
  "name": "crawl_website",
  "description": "抓取指定网页的正文纯文本（用于读取搜索结果或用户提供链接的完整内容）。只在摘要不足以支撑判断时调用；同一链接不要重复抓取。",
  "parameters": {
    "type": "object",
    "properties": { "url": { "type": "string", "description": "要抓取的网页绝对地址（http/https）" } },
    "required": ["url"]
  }
}
```

`resolveTextTools(cfg)` 行为：

- `cfg?.crawl?.enabled !== true` → 返回 `undefined`（**这就是默认零行为变化的保证**）；
- 否则返回 `{ tools: [buildCrawlToolDef()], execute: createCrawlExecutor({ maxToolCalls: cfg.crawl.maxPerSession }), maxToolCalls: cfg.crawl.maxPerSession }`。

## 三、开关与配置（独立开关）

### 3.1 数据库

新增 `src/database/migrations/048_ai_config_web_crawl.sql`（幂等，沿用既有风格）：

```sql
ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_enabled` INT NOT NULL DEFAULT 0 COMMENT '网页爬取工具开关：1=启用（文本模型可调用 crawl_website）；0=关闭',
  ADD COLUMN `crawl_max_per_session` INT NOT NULL DEFAULT 3 COMMENT '单次文本会话最多爬取次数（1~6）';
```

`schema.ts` 的 `aiProviderConfig` 同步补 `crawlEnabled` / `crawlMaxPerSession`。

### 3.2 后端服务与 DTO

- `ai-config.service.ts`：
  - `ActiveAiConfig` 新增 `crawl: { enabled: boolean; maxPerSession: number }`；
  - 读取映射（`crawl_enabled === 1`、`crawl_max_per_session` 兜底 3）；
  - 保存 upsert（`crawlEnabled` 缺省沿用原值；`crawlMaxPerSession` 缺省沿用原值）；
  - 校验：`crawlMaxPerSession` 越界（<1 或 >6）抛 `BadRequestException`。
- `dto/update-ai-config.dto.ts` 新增：

```ts
@IsOptional() @IsBoolean() crawlEnabled?: boolean;
@IsOptional() @IsInt() @Min(1) @Max(6) crawlMaxPerSession?: number;
```

### 3.3 后台 AI 设置页

`admin/src/components/ai-config-form.tsx`：在「研究管线 / 识别稳定性」分区旁新增「网页爬取」分区——开关（`crawlEnabled`）+ 次数上限输入（`crawlMaxPerSession`，1~6，缺省 3），保存走既有 PUT。

> **冲突规避**：本次只改 `ai-config-form.tsx` 与 `types/admin.ts`（如需补类型），**不触碰** `components/ai-create/**`（并行 WIP）。

## 四、接线清单

| 调用点 | 文件 | 改动 |
| --- | --- | --- |
| JSON 文本识别统一入口 | `llm-json.ts` | `JsonChatInput` 增可选 `ctx?: TextToolContext`；`textChatJson` 的 `callChat` 改为 `chatWithTools(endpoint, {...}, input.ctx)` |
| 风格定位 | `style-profile.service.ts` | `textChatJson(cfg.text, {...input, ctx: resolveTextTools(cfg)}, cfg.runtime)` |
| 姿势参考面片 | `pose-ref-sheet.service.ts` | 同上 |
| 草稿细化 | `draft-refine.service.ts` | 同上 |
| 质量评分 | `image-score.service.ts` | 同上 |
| 文字草稿生成 | `ai-analyze.service.ts` | 文字路径同上（带图路径 `visionChatJson` 不变） |
| 资料整理 | `trend-research/research-digest.service.ts` | `textChat` → `chatWithTools(cfg.text, {...jsonMode:true}, resolveTextTools(cfg))` |
| 查询词重组 | `trend-research/trend-research.service.ts` | 同上 |
| 生图 prompt 润色 | `image-prompt.composer.ts` | 同上 |
| 提示词润色 | `prompt-polisher.ts` | 同上 |
| 厂商联网检索 | `trend-research/web-search-vendor.ts` | 同上（该处本身即「文本模型回答检索」，工具可用） |

- 所有调用点均已持有 `cfg = await this.aiConfigService.getActiveConfig()`，接线只需传入 `resolveTextTools(cfg)`；
- `visionChatJson` / `image-describe` / `ai-config` 连通性测试**不改**；
- 不传 `ctx` 的全部存量调用与测试**行为完全不变**。

## 五、错误处理与降级

| 场景 | 行为 |
| --- | --- |
| 爬取开关关闭 / 配置缺失 | `resolveTextTools` 返回 `undefined` → 单次调用（旧行为） |
| 单次爬取失败（超时/拒绝/非 HTML） | 工具结果回填 `{"error":"..."}`，模型继续（可换 URL），不中断链路 |
| 工具轮整体异常 | `chatWithTools` 捕获后回退为一次无工具调用，保证仍能产出结果 |
| 模型只调工具不给结果 | 收尾轮 `tool_choice:'none'` 强制定稿 |
| 工具次数/轮次超限 | 立即进入收尾轮，回填提示「已达本次爬取上限」 |
| JSON 解析失败 | 仍由既有 `runJsonChat` 重试与 `LlmJsonError` 兜底，不受本次改动影响 |

## 六、可观测

- `toolChat` 已接 `traceLlmCall`：工具轮记一条「工具调用 · LLM」（含 `resultBrief: 调用工具：crawl_website`）；
- 新增爬取事件（仿 `traceSearchCall`）：标题 `网页爬取 · <host>`，`resultBrief` 为抓取字数 / 失败原因，供后台实时流程面板展示「抓了哪几个 URL、各多少字」；
- 不新增后台展示组件（复用现有时间线渲染）。

## 七、测试计划（TDD）

| 用例 | 断言 |
| --- | --- |
| `crawl-url.spec.ts` | mock fetch：正常 HTML → 纯文本且去除了 script/style；超 6000 字被截断并置 `truncated`；`file://`、`localhost`、私有 IP 被拒；非 `text/html` 被拒；超时抛可读错误；相同 URL 第二次命中缓存（fetch 调用次数不增） |
| `text-tool-loop.spec.ts` | mock fetch：首轮返回 `tool_calls`、次轮返回 JSON → 返回次轮内容且 `execute` 被调用一次、消息历史含 `role:'tool'`；`ctx` 缺省时与 `textChat` 请求体一致（无 `tools` 字段）；工具轮次/次数超限 → 进入 `tool_choice:'none'` 收尾轮；`execute` 抛错 → 回填 error 文本并继续 |
| `text-tools.spec.ts` | `resolveTextTools` 在 `crawl.enabled=false` 时返回 `undefined`；`true` 时工具定义 name/parameters 正确、`maxToolCalls` 取自配置 |
| `llm-json.spec.ts`（新增用例） | `textChatJson` 带 `ctx` 时走 `chatWithTools`（工具被调用）；不带 `ctx` 时请求体与既有断言一致 |
| `ai-config` 读写 | `crawlEnabled` / `crawlMaxPerSession` 存取；越界值 400 |
| 回归 | 既有 ai 模块全部测试保持全绿（默认不传 `ctx`） |

## 八、安全与合规

- 仅抓公开静态页；带明确 UA，遵守目标站 robots/ToS 与合理限速；
- SSRF 白名单式校验（协议 + 主机名 + 私有网段 + 裸 IP）；
- 严格体积 / 超时 / 长度上限，避免内存与带宽滥用；
- 全链路可开关、失败可降级，单点失败不影响主流程。

## 九、实施边界（与并行 WIP 隔离）

- **不改**：`lumira-server/packages/admin/src/components/ai-create/**`（`wizard.tsx` / `step-cover.tsx` 等，用户正在修「风格识别参考图被误用于姿势生图」）；
- **不改**：生图与剪影链路（`ai-generate-image.service.ts` / `image-client.ts` / `image-prompt.builder.ts` / `ai-generate-silhouette.service.ts` / `silhouette.pipeline.ts`）；
- **不改**：Flutter 端与废弃 uni-app。

## 十、后续优化登记项（写入 `docs/future-optimizations.md`）

1. 爬取正文抽取目前为启发式（`<article>/<main>` + 去标签），未做可读性算法；后续可评估引入 `@mozilla/readability` 类方案；
2. 仅支持静态 HTML，不渲染 JS 站点（小红书/抖音正文需另建适配器）；
3. 暂无跨进程爬取缓存（当前为进程内 LRU）。

## 十一、验收标准

1. 后台「网页爬取」开关默认关闭时，AI 一键生成全链路行为与改动前**逐字节一致**（既有测试全绿）；
2. 开启后，资料整理步骤的模型可在一次会话内调用 `crawl_website` 抓取检索命中的 URL 正文，并在实时流程面板看到「网页爬取 · host」事件；
3. 单会话爬取次数不超过后台配置上限，超限后模型仍能产出最终结果；
4. 关闭开关或爬取失败时，链路不中断、结果正常产出（降级路径可用）。