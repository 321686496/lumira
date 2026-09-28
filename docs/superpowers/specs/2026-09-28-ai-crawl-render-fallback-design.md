# AI 一键生成 · 网页爬取「静态优先 + 无头渲染降级」与按域 Cookie 设计

> 本设计是 `docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md`（文本工具循环 + `crawl_website` 静态抓取）的**后续增强**，不改变前者的工具循环协议与开关语义。

## 背景与目标

上线后实测发现：`crawl_website` 对**普通静态站**可用（实测 `https://www.ithome.com/` 返回 200 / 112 KB HTML），但对**知乎**这类站点直接失败：

| 站点 | 当前实现（UA `LumiraBot/1.0`） | 换完整 Chrome UA |
| --- | --- | --- |
| ithome.com | ✅ 200，112 KB | — |
| zhihu.com question 页 | ❌ 403，584 B 反爬壳 | ❌ 仍 403，同一份反爬壳 |

换浏览器 UA 无效，说明知乎拦的是「非会话请求」——响应头 `zh-zse-ck` 是一段 JS 挑战，需要真实会话 cookie 才能过。而前一份设计把「不引入 headless browser」写成了非目标，导致这类站点（以及小红书/抖音等纯 JS 渲染站）正文取不到。

本次目标：

1. 在静态抓取失败时**自动降级到无头浏览器渲染**，覆盖纯 JS 渲染站；
2. 支持后台配置**按域名隔离的 cookie**，以访问登录态内容；
3. 失败时给出**模型可读的错误**，让模型能改道换来源，而不是拿到一句无法处理的 403；
4. 顺带把爬取链路的 **SSRF 守卫统一到一套做 DNS 解析的实现**（见第三节，这是本次新增渲染能力的必要前置）。

## 非目标

- 不接入第三方正文提取/reader 代理服务（`r.jina.ai` / Firecrawl 等）；
- 不做 stealth 指纹伪装、CAPTCHA 绕过、住宅代理（开源方案不含这些能力，见第九节「诚实声明」）；
- 不改工具循环协议（`chatWithTools` / `TOOL_LOOP_MAX_ROUNDS` / `toolChatOnce`）与工具定义（`crawl_website` 的参数不变）；
- 不改视觉模型链路、生图与剪影链路；
- 不新增 npm 侧的浏览器二进制下载（后端只加纯 JS 的 `puppeteer-core`）。

## 现状（代码实证）

- `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts`
  - 常量：`CRAWL_TIMEOUT_MS = 8_000`（L17）、`MAX_BYTES = 1_048_576`（L18）、`MAX_CHARS = 6_000`（L19）、`USER_AGENT = 'LumiraBot/1.0 (...)'`（L20）、`ALLOWED_MIME`（L21）
  - `assertCrawlableUrl`（L44-64）：仅做 **hostname 正则**判定（`IP_LITERAL` L27、`BLOCKED_HOST_PATTERNS` L30-41），**不做 DNS 解析**
  - `htmlToText`（L71-92）、`readBodyWithinLimit`（L95-113，流式 1MB 截断）
  - `crawlUrl`（L116-163）：`fetch` 带 `redirect: 'follow'`（L127），**响应回来后才**校验 `res.url`（L139）
  - 进程内 LRU 缓存（L24）、`clearCrawlCache`（L166-167）
- `lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts`
  - `CrawlToolConfig { enabled, maxPerSession }`（L12-15）、`buildCrawlToolDef`（L23-36）、`createToolExecutor`（L49-68）、`resolveTextTools`（L74-80，`maxPerSession` 夹紧 1~6）
- `lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts`
  - `TextToolContext`（L10-16）、`TOOL_LOOP_MAX_ROUNDS = 3`（L28）
- `lumira-server/packages/backend/src/modules/ai/llm-trace.ts`：`traceCrawlCall`（L271）产出现有「网页爬取 · host」流程事件
- `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
  - `AiConfigView.crawlEnabled / crawlMaxPerSession`（L70-73）
  - `ActiveAiConfig.crawl { enabled, maxPerSession }`（L121-125）
  - `DEFAULT_CRAWL_MAX_PER_SESSION = 3`（L165）、`get()` 映射（L246-247）、`save()` 校验与归一（L332-336、L404-405、L451-452）、`getActiveConfig()`（L675-677）
- `lumira-server/packages/backend/src/database/`：`schema.ts` 的 `crawlEnabled`（L395-396）/ `crawlMaxPerSession`（L398）；迁移最新为 `049_ai_config_web_crawl.sql` → **本次用 050**
- `lumira-server/packages/backend/src/modules/ai/trend-research/research-image-fetch.ts`
  - `assertPublicHttpUrl`（L73-97）：**DNS 全量解析** + 私网判定（比 `assertCrawlableUrl` 强）
  - `fetchGuarded`（L103-129）：`redirect: 'manual'` 手动逐跳跟随，**每跳重新校验**
  - 伪装头先例：`'User-Agent': 'Mozilla/5.0 (compatible; LumiraBot/1.0)'`（L110）
- 工具开关的唯一入口是 `resolveTextTools(cfg)`，调用点：`ai-analyze.service.ts:219`、`draft-refine.service.ts:95`、`image-score.service.ts:203`、`pose-ref-sheet.service.ts:169`、`style-profile.service.ts:97`、`trend-research.service.ts:140`、`research-digest.service.ts:107`
- `deploy/docker-compose.prod.yml`：`lumira-backend`（L55-98，未设 `shm_size`）与既有附加服务先例 `lumira-searxng`（L112-125）；网络 `lumira-net`（L127-134，external）
- `lumira-server/packages/backend/Dockerfile`：`node:20-slim`（L6）、apt 走阿里云镜像源（L14-18）、runner 仅 COPY `node_modules`/`dist`/模型资产（L83-102）
- 后台：`lumira-server/packages/admin/src/types/admin.ts`（L454-457 视图 / L528-531 载荷）、`src/components/ai-config-form.tsx`（L96-98 `FormState`、L225-226/L258 初始化、L524-525 载荷、L1160-1195 「网页爬取」卡片）

## 架构总览

```
toolChatOnce 工具循环（不变）
   └─ execute('crawl_website', {url})
        └─ crawlUrl(url, opts)                       ← 新增 opts（渲染配置 + 按域 cookie）
             ├─ assertPublicHttpUrl(url)             ← 统一 SSRF 守卫（DNS 解析，见第三节）
             ├─ LRU 缓存命中？ → 直接返回
             ├─ 静态 fetchGuarded（伪装头 + 按域 cookie，逐跳校验）
             │    ├─ 成功且正文 ≥ 300 字 → htmlToText → 裁剪 → 缓存 → 返回   （与现状一致）
             │    └─ 403/429 或正文 < 300 字 ↓
             └─ 渲染降级（仅 crawl_render_enabled=1 且本会话渲染次数未超 2）
                  └─ renderUrl(url, opts)           ← 新增 tools/render-fetch.ts
                       └─ puppeteer-core.connect(ws://lumira-renderer:9222)
                            ├─ setRequestInterception → 每请求 assertPublicHttpUrl，私网 abort
                            ├─ setCookie（仅域名后缀匹配项）
                            ├─ goto(waitUntil: 'networkidle2', timeout)
                            └─ page.content() → htmlToText → 裁剪 → 缓存 → 返回
```

关键性质：**渲染是纯追加分支**。静态成功路径与本次改动前逐字节一致；`crawl_render_enabled` 默认 0，关闭时链路等价于现状。

## 一、渲染容器（`deploy/renderer/`）

新增 `deploy/renderer/Dockerfile`：

- 基础镜像 `debian:bookworm-slim`（与后端 `node:20-slim` 同为 bookworm，glibc 版本一致）
- apt 源改阿里云（照抄后端 `Dockerfile` L14-18 的 `sed` 写法，适配 deb822 与旧格式）
- 安装：`chromium`、`fonts-noto-cjk`、`fonts-wqy-zenhei`、`fontconfig`、`ca-certificates`、`curl`（仅给 healthcheck 用）
- ENTRYPOINT 只做一件事：

  ```
  chromium --headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu \
           --no-first-run --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222 \
           --user-data-dir=/tmp/chrome
  ```

- **不含任何业务代码**；不映射端口到宿主机；预计体积约 400 MB（对比 browserless 镜像 3.62 GB）
- `--no-sandbox` 为容器内必需的取舍（否则需 `SYS_ADMIN`），作为残余风险记录
- healthcheck：`curl -f http://127.0.0.1:9222/json/version`（该端点返回 JSON，无需额外依赖）
- 不依赖 `ghcr.io`：全部来自可配置的 Debian 镜像源，规避国内服务器拉取风险

`deploy/docker-compose.prod.yml` 变更：

- 新增 service `lumira-renderer`：`build` 指向 `./repo` + `deploy/renderer/Dockerfile`，`image: lumira-renderer:latest`，`restart: always`，`shm_size: "1g"`，只加入 `renderer-net`
- `lumira-backend` 增加 `renderer-net` 网络与环境变量 `RENDERER_WS_ENDPOINT=ws://lumira-renderer:9222`
- 新增 network `renderer-net`（普通 bridge，`internal: false`，需外网出口）
- **网络隔离意图**：renderer 不在 `lumira-net` 上，因而访问不到 `lumira-mysql`；backend 同时接入两网
- 残余风险：backend 也在 `renderer-net` 上，renderer 理论上可达 `lumira-backend:3000`。缓解手段是渲染时的请求拦截——`lumira-backend` 解析到 Docker 私网地址，会被第三节的 DNS 私网判定拦下（记为后续优化项 1）

## 二、静态优先降级

`crawlUrl` 增加可选第二参 `opts?: CrawlOptions`：

```ts
export interface CrawlOptions {
  renderEnabled?: boolean;          // 缺省 false → 纯静态
  renderTimeoutMs?: number;         // 缺省 20000
  cookies?: Record<string, string>; // 域名 → cookie 原始串，仅内存中传递
  /** 会话级渲染预算（同一 tool 会话内共享同一对象，跨多次 crawl 调用累计） */
  renderBudget?: { used: number; max: number };
  /**
   * 渲染实现注入点：缺省使用 `tools/render-fetch.ts` 的真实实现。
   * 存在的唯一目的是让 crawl-url 的降级判定可以单测，而不必启动 Chromium。
   */
  render?: RenderFn;                // (url: string, o: { timeoutMs: number; cookies: Record<string,string> }) => Promise<string>
}
```

同理，`render-fetch.ts` 导出的 `renderUrl(url, opts, deps?)` 接受可选 `deps.connect`（缺省为真实的 `puppeteer.connect`），使 `render-fetch.spec.ts` 能注入假浏览器对象验证拦截与 cookie 逻辑。

`CrawlResult` 增加一个字段，用于渲染预算记账与 trace 文案：

```ts
export interface CrawlResult {
  url: string;
  text: string;
  chars: number;
  truncated: boolean;
  usedRender: boolean;   // 本次结果是否来自无头渲染
}
```

**渲染预算归属**：计数留在 `crawlUrl` 内（`renderBudget.used += 1`），`text-tools.ts` 的 `createToolExecutor` 只负责**为每个工具会话创建一个 `renderBudget` 对象**并在每次调用时透传。这样判定、记账、结果标记全在同一处，可单测；执行器保持薄。

流程调整为：

1. `assertPublicHttpUrl(raw)`（统一守卫，见第三节）
2. 查 LRU 缓存（key = 归一化 URL）
3. 静态抓取：`fetchGuarded(key, { timeoutMs: 8_000, accept: 'text/html,application/xhtml+xml,text/plain;q=0.9', headers: 伪装头 + 按域 cookie })`
4. 转文本：`text/plain` → 压空白；否则 `htmlToText`
5. **降级判定** `shouldRenderFallback(status, text)`：`status ∈ {403, 429}` **或** `text.length < STATIC_MIN_CHARS`
6. 不需要降级 → 裁剪、缓存（`usedRender: false`）、返回
7. 需要降级但**不满足**任一前提（`opts.renderEnabled !== true`，或 `renderBudget` 已达上限，或 `RENDERER_WS_ENDPOINT` 未配置）→ 按第七节抛对应可读错误
8. 需要降级且前提满足 → `renderBudget.used += 1` → `renderUrl` → `htmlToText` → 裁剪 → 缓存（`usedRender: true`）→ 返回
9. 渲染不可用/失败 → 按第七节降级（此时不改动 `renderBudget.used` 之外的任何计数语义：**已尝试的渲染仍计入预算**，避免同一会话反复重试同一渲染）

新增常量（`crawl-url.ts`）：`STATIC_MIN_CHARS = 300`、`CRAWL_RENDER_MAX_PER_SESSION = 2`。

> 关于"零回归"的准确含义：静态**成功**路径（第 6 步）与改动前逐字节一致；错误文案属本次有意优化（见第七节），因此关闭渲染开关时 403/429 的**文案会变化**，这是设计目标之一，不是回归。

伪装头（静态与渲染共用）：浏览器 UA（替换现有 `LumiraBot/1.0`）+ `Accept` + `Accept-Language: zh-CN,zh;q=0.9`。不使用 `Sec-Fetch-*` / `Referer` 伪造——服务端发起时语义不成立，且收益未经证伪。

**为什么渲染次数上限是常量而非配置列**：`maxPerSession`（默认 3）配合 20s 渲染超时，最坏会把单次会话拖到 60s+；先固定为 2 以避免新增配置面，调优入口登记为后续优化项。

## 三、SSRF 守卫统一（针对性加固）

现状问题（均已在代码中确认）：

1. `assertCrawlableUrl`（`crawl-url.ts` L44-64）**只查 hostname 正则**，不做 DNS 解析。因此任何"域名解析到内网"的地址都能绕过，例如自有域名 A 记录指向 `172.16.x.x`。
2. `crawlUrl` 用 `redirect: 'follow'`（L127）——重定向目标在 `res.url` 校验（L139）**之前**就已被请求发出，属于盲 SSRF（虽然响应体在校验前不会被读）。
3. 同一个安全面上，`trend-research/research-image-fetch.ts` 已有更强的 `assertPublicHttpUrl`（L73-97，`lookup` 全量解析 + 任一私网即拒）与 `fetchGuarded`（L103-129，逐跳校验）。

决定（**行为保持的最小搬迁**，不是重构）：

- 新增共享模块 `lumira-server/packages/backend/src/common/net/guarded-fetch.ts`，把 `assertPublicHttpUrl`、`fetchGuarded` 及其私有辅助（`isPrivateAddress` / `isPrivateV4` / `IPV4_LITERAL` 等）从 `research-image-fetch.ts` **原样搬入**；`fetchGuarded` 仅新增一个可选入参 `headers?: Record<string, string>`（缺省 `undefined` → 既有调用行为完全不变），用于让爬取链路传入伪装头与按域 cookie
- `research-image-fetch.ts` 改为从该模块导入并**继续原样导出**同名符号，其对外 API 与行为不变（既有 `research-image*.spec.ts` 必须全绿）
- `crawl-url.ts` 改用共享实现，删除 `IP_LITERAL` / `BLOCKED_HOST_PATTERNS` / `assertCrawlableUrl`；`crawlUrl` 改用 `fetchGuarded` 手动逐跳（超时映射文案保持现有「抓取超时（8 秒），请换其他链接」）
- 渲染侧：CDP `page.setRequestInterception(true)`，对**每个**请求 `await assertPublicHttpUrl(req.url())`，不通过即 `req.abort()`。这是方案选型中"薄容器 + 后端驱动"的核心收益——守卫只有一份，且能拦住页面自身发起的跳转

注意：`crawl-url.spec.ts` 现有针对 `assertCrawlableUrl` 的用例（L27-53，含尾点归一化）需改写为针对 `assertPublicHttpUrl` 的等价用例；DNS 解析在单测中需可注入（`lookup` 通过参数或模块 mock 控制），以保持测试不触网。

## 四、开关与配置（迁移 050）

`lumira-server/packages/backend/src/database/migrations/050_ai_config_crawl_render.sql`：

```sql
ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_render_enabled` INT NOT NULL DEFAULT 0
    COMMENT '爬取静态失败时是否降级到无头渲染：1=启用；0=关闭',
  ADD COLUMN `crawl_render_timeout_ms` INT NOT NULL DEFAULT 20000
    COMMENT '单次无头渲染超时（毫秒，5000~60000）',
  ADD COLUMN `crawl_cookies` TEXT NULL
    COMMENT '按域名隔离的 cookie（JSON：{domain: cookieString}），AES-256-GCM 加密存储';
```

后端改动：

- `schema.ts`（L395-398 附近）新增 `crawlRenderEnabled` / `crawlRenderTimeoutMs` / `crawlCookies` 三列，默认值与迁移一致
- `AiConfigView`（L70-73）新增：`crawlRenderEnabled: boolean`、`crawlRenderTimeoutMs: number`、`crawlCookieDomains: string[]`（**只回显域名列表，绝不回传 cookie 值**）
- `ActiveAiConfig.crawl`（L121-125）扩展为 `{ enabled, maxPerSession, renderEnabled, renderTimeoutMs, cookies: Record<string, string> }`，其中 `cookies` 在此处解密（仅存在于内存）
- `get()` 映射（L246-247 附近）、`getActiveConfig()`（L675-677）同步补三字段
- `save()`（L332-336 归一 / L404-405 更新 / L451-452 插入）：`crawlRenderTimeoutMs` 夹紧到 `5000~60000`（越界抛可读错误，与现有 `crawlMaxPerSession` 1~6 的处理同风格）；`crawlCookies` **仅在显式传入时重写**，加密后落库；未传则保留存量值
- 常量：`DEFAULT_CRAWL_RENDER_TIMEOUT_MS = 20000`
- DTO（`update-ai-config.dto.ts` L228-240 之后）新增：
  - `crawlRenderEnabled?: boolean`（`@IsOptional @IsBoolean`）
  - `crawlRenderTimeoutMs?: number`（`@IsOptional @IsInt @Min(5000) @Max(60000)`）
  - `crawlCookies?: Record<string, string>`（`@IsOptional @IsObject`；值长度上限 4096，域名需为合法 hostname）。**语义**：字段缺省 = 保留存量 cookie；传入对象 = 以该对象**整体覆盖**（传 `{}` 即清空全部域名 cookie）

后台（`ai-config-form.tsx` L1160-1195 现有「网页爬取」卡片内扩展，**该文件不在被冻结的 `ai-create/**` 目录内**）：

- `FormState`（L96-98 附近）新增 `crawlRenderEnabled: boolean`、`crawlRenderTimeoutMs: number`、`crawlCookies: Array<{ domain: string; value: string }>`
- 两条初始化路径（L225-226 configured / L258 非 configured）与载荷组装（L524-525）同步补字段
- UI 元素：渲染降级开关 + 超时数字输入 + 「域名 / cookie」增删行列表（值用 `type="password"`，保存后仅回显域名，值留空表示沿用）
- `packages/admin/src/types/admin.ts`（L454-457 / L528-531）补对应字段

## 五、Cookie 凭据的存储与作用域

**加密**（新增 `lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts`）：

- 算法 `AES-256-GCM`，`node:crypto`
- 密钥来源：环境变量 `CRAWL_COOKIE_SECRET`（64 位 hex，即 32 字节；生成方式 `openssl rand -hex 32`）
- 存储格式：`v1:<ivHex>:<tagHex>:<cipherHex>`（iv 12 字节随机）
- 密钥缺失：`save()` 收到 `crawlCookies` 时抛 400「未配置 CRAWL_COOKIE_SECRET，无法保存 cookie」——**绝不落明文**；`getActiveConfig()` 把 `cookies` 视为空对象（渲染照常可用，只是不带登录态）
- 解密失败（密文被篡改/格式非法）：视为无 cookie，记 warn 日志，不中断链路

**作用域（本设计最重要的一条安全约束）**：

- 明文结构为 `{ "<domain>": "<cookie 原始串>" }`
- 使用时按目标 URL 的 hostname 做**域名后缀匹配**：`host === domain || host.endsWith('.' + domain)`
- **只附加匹配项的 cookie；无匹配则不发送任何 cookie**。禁止"把最像的 cookie 发过去"这类模糊匹配——全局单份 cookie 会把知乎的会话泄露给任意被抓站点
- 静态请求与渲染 `setCookie` 走同一匹配函数（`selectCookiesForHost(host, cookies)`），保证两侧语义一致

**保密**：cookie 值不得进入 trace 事件、日志或错误信息；错误文案中若需提示登录态问题，只说"未配置该域名的 cookie"。

## 六、接线清单

| 文件 | 改动 |
| --- | --- |
| `common/net/guarded-fetch.ts` | 新增：`assertPublicHttpUrl` / `fetchGuarded` 从 `research-image-fetch.ts` 原样搬入 |
| `trend-research/research-image-fetch.ts` | 改为从共享模块导入并原样 re-export；对外行为不变 |
| `tools/crawl-url.ts` | 新增 `CrawlOptions`、`CrawlResult.usedRender`、`STATIC_MIN_CHARS`、`CRAWL_RENDER_MAX_PER_SESSION`、`shouldRenderFallback`、`selectCookiesForHost`、伪装头；删除本地的 SSRF 常量与 `assertCrawlableUrl`；接入渲染降级与渲染预算记账 |
| `tools/render-fetch.ts` | **新增**：`renderUrl(url, opts)` = puppeteer-core 连接（端点取 `process.env.RENDERER_WS_ENDPOINT`，未配置即视为不可用）+ 请求拦截 + 按域 setCookie + goto + `page.content()` |
| `tools/text-tools.ts` | `CrawlToolConfig` 扩展 `renderEnabled` / `renderTimeoutMs` / `cookies`；`resolveTextTools` 透传配置并创建会话级 `renderBudget = { used: 0, max: CRAWL_RENDER_MAX_PER_SESSION }`；`createToolExecutor` 每次调用透传该同一对象 |
| `modules/ai/cookie-crypto.ts` | **新增**：`encryptCookies` / `decryptCookies` / `selectCookiesForHost` |
| `ai-config.service.ts` | 三字段读写、夹紧、加解密接线（见第四节） |
| `dto/update-ai-config.dto.ts` | 三个新可选字段 + 校验 |
| `database/schema.ts` | 三列 |
| `database/migrations/050_ai_config_crawl_render.sql` | **新增** |
| `packages/backend/package.json` | 新增依赖 `puppeteer-core`（纯 JS，**不下载浏览器二进制**） |
| `packages/backend/.env.example` | 新增 `CRAWL_COOKIE_SECRET`、`RENDERER_WS_ENDPOINT` |
| `deploy/renderer/Dockerfile` | **新增** |
| `deploy/docker-compose.prod.yml` | 新增 `lumira-renderer` service、`renderer-net` 网络、backend 的 env 与网络 |
| `packages/admin/src/types/admin.ts` + `components/ai-config-form.tsx` | 渲染开关 / 超时 / 域名-cookie 列表 |
| `AGENTS.md` | 部署章节的服务器 `.env` 表补 `CRAWL_COOKIE_SECRET`（并注明需重启或重新部署生效） |

**无需改动**：`text-tool-loop.ts`、`llm-client.ts`、`llm-json.ts` 以及 7 个 `resolveTextTools(cfg)` 调用点（配置经 `getActiveConfig()` 自动流入）。

## 七、错误处理与降级

文案集中为 `crawl-url.ts` 内的常量，并逐条单测断言（让模型能读到"该换来源了"）。

判定**按此优先级自上而下取第一条命中**（顺序即语义，避免"403 且渲染不可达"这类组合落到错误文案）：

| 优先级 | 条件 | 返回 |
| --- | --- | --- |
| 1 | 静态正文非空（含不足 300 字的短正文） | **静默降级**：返回该静态正文，不报错 |
| 2 | 静态状态 ∈ {403, 429}，且渲染未成功产出正文 | `目标站点拒绝自动抓取（HTTP 403），请改用搜索摘要或换其他来源`；若本次**确实尝试过渲染**则追加 `，已尝试浏览器渲染仍未取到正文` |
| 3 | 渲染成功但渲染正文为空 | `该站内容由脚本动态加载或需登录，未取到正文，请换来源` |
| 4 | 其余（静态无正文、非 403/429、渲染不可达或失败、渲染超时） | `网站响应异常，请换其他来源` |
| — | 静态请求本身超时 | 保持现有 `抓取超时（8 秒），请换其他链接`（独立于上述顺序，在静态阶段直接抛出） |

原则：**渲染是可选增强，其失败不得让工具整体失败**（与既有设计"可开关、可降级、单点失败不阻断"一致）。第 1 条正是"不阻断"的落点：静态已经拿到一点内容时，宁可给模型短内容，也不给一句错误。

## 八、可观测

- **不新增 trace 事件类型**（避免改动 admin 流程面板渲染层）。渲染信息写入既有 `traceCrawlCall`（`llm-trace.ts` L271）的 `resultBrief`：
  - 静态命中：`抓取 1234 字`
  - 渲染命中：`抓取 1234 字（渲染）`
  - 截断时沿用现有 `（已截断）` 后缀
- 渲染失败经 `handle.fail(err)` 记录，与现有静态失败一致
- 后端启动时若 `RENDERER_WS_ENDPOINT` 未配置，打印一条 warn：渲染降级能力自动关闭——避免运营在后台开了开关却因为缺环境变量而"以为开了"

## 九、测试计划（TDD）

1. `common/net/guarded-fetch.spec.ts`（新）：私网 IPv4 / IPv6 字面量拒绝；协议非 http(s) 拒绝；DNS 解析到私网拒绝（注入 `lookup`）；`fetchGuarded` 逐跳校验、超跳数上限、超时映射
2. `tools/crawl-url.spec.ts`（扩展）：
   - 静态成功 → **不调用渲染**（注入假 renderer，断言调用 0 次）
   - 403 → 调用渲染；渲染成功 → 返回渲染正文
   - 静态正文 < 300 字 → 调用渲染
   - 渲染开关关闭 → 不调用渲染，抛既有错误
   - 渲染抛错 + 静态有正文 → 返回静态正文（静默降级）
   - 渲染抛错 + 静态无正文 → 抛第七节对应文案
   - `selectCookiesForHost`：精确匹配带、子域匹配带、`evil-zhihu.com` **不**匹配 `zhihu.com`、无匹配则不带
   - 既有 `assertCrawlableUrl` 用例改写为 `assertPublicHttpUrl` 等价用例（含尾点归一化语义）
3. `tools/render-fetch.spec.ts`（新）：以注入的假 puppeteer 实现验证——拦截回调对私网 URL 调 `abort`、对正常 URL 调 `continue`；cookie 仅在域匹配时 `setCookie`；`goto` 超时映射为可读错误；`page.content()` 结果被返回。**测试不启动真实 Chromium**
4. `modules/ai/cookie-crypto.spec.ts`（新）：加解密往返；篡改密文报错；格式非法报错；密钥长度非法报错；密钥缺失时 `encryptCookies` 抛错
5. `ai-config.crawl.spec.ts`（扩展）：三字段读取映射与默认值；`crawlRenderTimeoutMs` 越界夹紧；`crawlCookies` 落库值**不是明文**；密钥缺失时保存 cookie 抛错；`get()` 只回显域名列表
6. `tools/text-tools.spec.ts`（扩展）：渲染次数上限 2 在本会话内生效（第 3 次不再调用渲染）
7. 全量回归：`pnpm --filter @lumira/backend test`（基线 635 passed / 3 skipped）+ `tsc --noEmit`（基线恰 3 处既有错误：`golden-set.service.spec.ts:30`、`image-prompt.composer.spec.ts:119`、`image-score.service.spec.ts:69`，零新增）+ `pnpm --filter @lumira/admin build`
8. 人工验收（需真实运行环境与密钥）：见第十二节第 2、3 条

## 十、实施边界（与并行 WIP 隔离）

- **不改**：`lumira-server/packages/admin/src/components/ai-create/**`（用户正在修「风格识别参考图被误用于姿势生图」）；生图与剪影链路（`ai-generate-image.service.ts` / `image-client.ts` / `image-prompt.builder.ts` / `ai-generate-silhouette.service.ts` / `silhouette.pipeline.ts`）；视觉模型链路
- **不改** `lumira-app/`（已废弃原型）
- 迁移编号 **050**（049 已占用，已核对）
- 本仓库并行工作流共用同一分支与工作树：禁用无过滤 diff 评审、禁 `git add -A`、禁 `reset` / `stash` / `rebase`
- 新增依赖仅 `puppeteer-core`（后端）；renderer 容器不引入 npm 概念

## 十一、后续优化登记项（写入 `docs/future-optimizations.md`）

1. CDP 端口 9222 无鉴权，仅靠 `renderer-net` 隔离与请求拦截保护；后续可加反代 + token 或 mTLS
2. 渲染无并发闸门：当前靠"单会话串行 + 每会话上限 2"天然限流；多会话并发时需队列/信号量
3. 无 stealth 指纹伪装与代理池：若知乎类站点实测仍被拦，需评估付费能力或专用适配器
4. 渲染结果与静态结果共用同一个 LRU（无独立 TTL），长文本渲染页可能较快挤掉静态缓存
5. 降级触发条件（403/429 + 300 字阈值）为启发式，未按站点统计调优
6. `renderer-net` 上 backend 仍对 renderer 可见，属纵深防御的剩余面

## 十二、验收标准

1. **零回归（限定范围）**：`crawl_render_enabled` 默认 0，关闭时**静态成功路径**（正文抓取、清洗、裁剪、缓存、`chars`/`truncated` 语义）与改动前一致，且**不会发起任何渲染**；3 个新增配置列对既有 `crawlEnabled` / `crawlMaxPerSession` 语义无影响。全量测试无新增失败、`tsc` 无新增错误。**例外（有意变更，非回归）**：403/429 与"未取到正文"的错误文案按第七节优化
2. **JS 站覆盖**：开启渲染后，一个正文由前端 JS 渲染的站点能取到正文（人工验收，需真实运行环境 + 渲染容器）
3. **知乎**：后台为该域名配置 cookie 后能取到正文；不配 cookie 时返回第七节可读错误且链路正常结束（人工验收，**不保证成功**，见下节）
4. **cookie 不外泄**：域名不匹配时绝不外发（单测断言）；`crawl_cookies` 在库中非明文（可直接查库验证）
5. **降级不阻断**：渲染容器不可达时链路按第七节正常降级（单测断言）
6. **部署就绪**：`RENDERER_WS_ENDPOINT` 未配置时渲染能力自动关闭且有 warn 日志；服务器 `.env` 补 `CRAWL_COOKIE_SECRET` 的步骤写入 `AGENTS.md`

## 诚实声明

即使本设计全部落地，**知乎仍不保证 100% 成功**。开源渲染方案（自建 Chromium）不含 stealth 指纹伪装、住宅代理与 CAPTCHA 绕过——那些能力在 browserless 等产品的付费版本中。能否过知乎取决于：运营粘贴的 cookie 是否有效、以及目标站点当期策略。

设计能保证的是：**能过就取到正文；过不去就给出模型可读的错误让链路改道，绝不让工具调用卡死或返回一句无法处理的 403。**