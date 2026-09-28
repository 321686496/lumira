# 后台图文博客（含 SEO 公开页 / AI 生成 / 底部推广开关）设计

日期：2026-09-28
状态：待评审
依赖：无（纯新增模块，不改动现有 App 端行为）

## 背景与目标

运营侧目前没有任何内容承载与长尾流量入口：后端 `public/index.html` 只有一张静态落地页，没有可持续产出内容的博客，也没有面向搜索引擎的内容页。

本设计目标：

1. 后台可**新增/编辑图文博客**，支持「保存草稿」「保存并发布」「取消发布」三态操作。
2. 发布后的文章生成一个**公开可访问链接**，任何人（含未安装 App 的搜索引擎爬虫）可直接打开。
3. 公开页**做好 SEO**：语义化 HTML、meta/canonical/OG、JSON-LD 结构化数据、`sitemap.xml`、`robots.txt`。
4. 后台提供 **AI 生成博客**：输入主题与要求，一次产出标题、摘要、SEO 描述、Markdown 正文、分类与英文 slug 建议。
5. 后台提供**博客底部默认推广内容开关**（默认开启），可在全局与单篇两个层级控制；推广文案本身（Lumira 官方信息 / APP 推广 / 公众号）在后台可编辑。

## 需求点

- 文章字段：标题、slug、摘要、SEO 标题（可空）、SEO 描述（可空）、封面图、Markdown 正文、分类（单选，可空）、状态、底部推广覆盖模式。
- 草稿仅后台可见；发布后公开可达；取消发布回到草稿且公开链接立即 404。
- 分享链接形态：`{BACKEND_PUBLIC_URL}/blog/{slug}`（生产即 `https://lumira.iwtle.top/blog/{slug}`），后台列表与编辑页展示完整链接 + 复制按钮。
- 底部推广内容三块，各自文案可空；`显示 = promo_mode==='on' ? true : promo_mode==='off' ? false : settings.promo_enabled`，`promo_mode` 默认 `inherit`，`settings.promo_enabled` 默认 `1`。
- 公开站点同时提供列表页与分类列表页，作为 SEO 内链枢纽。

## 现状勘察结论

**公开网页的托管现状（决定方案可行性的关键）**

- 后端 NestJS 使用 `app.setGlobalPrefix('api/v1')`，但 `main.ts#L77-L92` 的 `@fastify/static` 与随后显式注册的 `fastify.get('/')` 是**注册在裸 Fastify 实例上**的，不受全局前缀影响 —— 因此 `https://lumira.iwtle.top/` 直接返回 `public/index.html`。
- `deploy/nginx-lumira.conf.example#L92-L115` 中 `location /` 将 API 域名下的**全部**非健康检查路径反代到 `lumira-backend` 容器。→ 后端直接在现有域名上线公开博客页**无需任何 nginx / 域名 / Vercel 改动**。
- 已有可复用品牌样式：`backend/public/css/style.css`（12KB）、`public/js/main.js`、`public/assets/logos/lumira/logo-lumira-symbol.svg`。现有落地页已内置完整 SEO head（lang、title、description、字体、Phosphor 图标）。

**存储与图片（复用既有范式，避免硬编码 URL）**

- 图片一律在 DB 存**相对 storageKey**，出参时用 `buildAssetUrl(url)`（`common/storage/asset-url.ts#L37`）拼当前激活存储的公网地址；切换七牛/R2 后旧数据 URL 自动跟随（`isOwnBackendUrl` 会重建自建域名 URL）。
- 存储抽象：`StorageAdapter.write(category, id, filename, buffer) → storageKey`、`deleteByDir(category, id)`；`StorageCategory`（`storage-adapter.interface.ts#L6`）当前为 `'templates' | 'categories' | 'banners' | 'feedback' | 'users' | 'thumbs'`，**需新增 `'blog'`**。
- Admin 端 multipart 解析已有公用工具 `parseMultipart(req)`（`modules/templates/admin-templates.controller.ts#L119`），可直接复用其模式。

**后台（Next.js 14 App Router on Vercel）**

- 认证：`src/middleware.ts` 拦截除 `/login`、`/` 与静态资源外的全部路径；请求封装 `src/lib/api.ts#L53`（`adminFetch`，cookie 取 token → `Authorization: Bearer`）。
- 表单范式：server component 拉数据 → client 组件表单（react-hook-form + zod）→ `src/actions/*.ts` server action → `api.*` → `revalidatePath` + 跳转（参见 `actions/templates.ts`、`components/template-form.tsx`）。
- UI：Tailwind + shadcn 风格自研组件（`components/ui/`，含 `file-upload.tsx`）；图标统一 Phosphor React（`/dist/csr/*`）；侧边栏 `components/sidebar.tsx#L21-L38` 的 `navItems` 数组。
- **无任何 Markdown / 富文本编辑器依赖**（`packages/admin/package.json` 无 tiptap/quill/marked）。
- `next.config.js#L35-L53` 已把 `/uploads/*` 代理到资产源以规避 Mixed Content。

**AI 能力（可直接复用，无需新建调用栈）**

- 文本对话客户端 `modules/ai/llm-client.ts`：`TextChatInput` 类型 + `rawChatMessage`/`chatRequest`（含 jsonMode 降级、5xx 退避重试、鉴权错误处理）。
- 模型/key/开关来自 `modules/ai/ai-config.service.ts` 读取的单行配置表 `ai_provider_config`（`schema.ts#L352`）。

**数据库约定（`schema.ts`）**

- 内容表主键用 `text('id').primaryKey()` + nanoid（`templates`/`feedbacks`）；配置表用显式列（`ai_provider_config`）或多列（`storage_config`）。
- 时间戳为 **`int('created_at')` 秒级**，不是 datetime；布尔用 `int` 0/1；结构化数据用 `longtext('*_json')`。
- 迁移目录 `src/database/migrations/`，现有最大编号 `047`，命名 `<编号>_<snake_topic>.sql`。

## 架构设计

### 0. 公开页生成方式（已选定）

**后端 Fastify 动态 SSR**：在裸 Fastify 实例上注册 `/blog`、`/blog/category/:key`、`/blog/:slug`、`/sitemap.xml`、`/robots.txt`，直接拼 HTML 返回。理由：

- 与现有 `GET /` 完全同一手法，零新基础设施、零 nginx/Vercel 改动；
- 发布/取消发布**实时生效**，不存在「状态与落盘文件不一致」问题；
- 静态落盘方案（生成到容器内目录）会因容器重建丢失，除非额外挂卷，成本更高。

Markdown **请求时渲染**（单一数据源，日后调整渲染白名单无需回填历史数据），配 `Cache-Control: public, max-age=60`。

模板组织：`modules/blog/public/` 下 TypeScript 模板函数（返回 HTML 字符串），拆分为 `blog-layout.ts`（head/OG/JSON-LD/页头页脚）、`post-page.ts`、`list-page.ts`，样式新增 `public/css/blog.css`（沿用现有品牌变量与字体）。

### 1. 数据模型（迁移 `048_blog.sql`，新增 3 张表）

**`blog_categories`**

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | int PK autoincrement | |
| `key` | varchar(64) **unique** | 稳定标识，如 `shooting-tips`（用于 `/blog/category/:key`） |
| `name` | varchar(100) | 显示名，如 `拍摄技巧` |
| `description` | varchar(300) | 分类页 SEO 描述，默认 `''` |
| `sort_order` | int default 0 | |
| `created_at` / `updated_at` | int | 秒级 |

> `key` 用 `varchar` 而非 `text`：MySQL 的 TEXT 列无法直接建唯一索引（需前缀长度），slug/key 语义上本就定长。

**`blog_posts`**

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | text PK | nanoid（与 `templates` 一致） |
| `slug` | varchar(200) **unique** | URL 标识 |
| `title` | varchar(200) | |
| `summary` | varchar(300) | 列表页展示 + 作 SEO 描述回退 |
| `seo_title` | varchar(200) | 可空，空则回退 `title` |
| `seo_description` | varchar(300) | 可空，空则回退 `summary` |
| `cover_url` | varchar(512) | 存 storageKey，可空 |
| `content_md` | longtext | Markdown 原文（唯一数据源） |
| `category_id` | int | 可空（未分类） |
| `status` | varchar(16) | `'draft' \| 'published'`，默认 `draft` |
| `promo_mode` | varchar(16) | `'inherit' \| 'on' \| 'off'`，默认 `inherit` |
| `published_at` | int | 可空；首次发布写入，取消发布置空 |
| `created_at` / `updated_at` | int | 秒级 |

索引：`uq_blog_slug(slug)`、`idx_blog_status_pub(status, published_at)`、`idx_blog_category(category_id)`

**`blog_settings`**（单行配置，显式列，迁移内 seed `id=1`）

`id` int PK（固定 1）/ `promo_enabled` int default 1 / `blog_title` varchar(200)（列表页站点名）/ `blog_description` varchar(300)（列表页 description）/ 三块推广文案：
`promo_official_title` + `promo_official_body`、`promo_app_title` + `promo_app_body`、`promo_wechat_title` + `promo_wechat_body`（均 varchar(200)/varchar(500)）/ `promo_wechat_qr_url` varchar(512)（存 storageKey）/ `updated_at` int

### 2. 后端 Admin API（`/api/v1/admin/blog/*`，`AdminAuthGuard`）

模块目录 `modules/blog/`：`blog.module.ts`、`admin-blog.controller.ts`、`admin-blog.service.ts`、`blog-public.controller.ts`（仅承载 DTO/服务，不承载公开页路由）、`dto/*.dto.ts`、`ai-blog.service.ts`、`public/`（模板函数）、`markdown.ts`（渲染 + 净化）、`slug.ts`。

| 接口 | 说明 |
|---|---|
| `GET /posts` | 列表；入参 `status?`（`all\|draft\|published`）、`categoryId?`、`keyword?`、分页 |
| `GET /posts/:id` | 详情（含完整 `contentMd`） |
| `POST /posts` | 新建；multipart（`meta` JSON + 可选 `cover`）。`status` 由 meta 传入 |
| `PATCH /posts/:id` | 更新；同上 |
| `PATCH /posts/:id/status` | 单独切状态（列表页一键发布/取消发布），入参 `{ status }` |
| `DELETE /posts/:id` | 删除（同时 `deleteByDir('blog', id)` 清理该文章目录） |
| `GET /posts/:id/preview-html` | 返回完整 SSR HTML 字符串，供后台 `<iframe srcDoc>` 预览 |
| `GET/POST/PATCH/DELETE /categories` | 分类 CRUD |
| `GET /settings` · `PATCH /settings` | 博客设置（含推广开关、文案、二维码） |
| `POST /ai/generate` | AI 生成 |
| `POST /uploads` | 正文插图；`{ postId? }` + multipart `file`，返回 `{ storageKey }` |

**图片存储约定**：`StorageCategory` 新增 `'blog'`；上传目录为 `blog/{postId ?? 'drafts'}`；DB 列与正文 Markdown 中一律写 storageKey（`/uploads/blog/.../x.jpg`），出参与 SSR 渲染时统一经 `buildAssetUrl()` 拼公网地址。正文 Markdown 里的 `img[src]` 在渲染管道末端同样过一遍 `buildAssetUrl`，保证存储切换后历史文章图片不失效。

### 3. 后端公开站点（裸 Fastify，不带 `/api/v1` 前缀）

在 `blog.module.ts` 内提供 `registerBlogPublicRoutes(fastify, deps)`，由 `main.ts` 在注册 `public/` 静态目录**之后**调用（与现有 `fastify.get('/')` 同位置）。Fastify 的 find-my-way 路由优先级为「静态 > 参数 > 通配」，故显式路由不会被 `@fastify/static` 的 `/*` 吞掉——与现有 `/` 路由能生效同一机制。

| 路由 | 内容 |
|---|---|
| `GET /blog` | 列表页；`?page=N` 分页（每页 10 条）；页内提供分类导航链接（筛选通过跳转分类页实现，不在本页做 query 筛选） |
| `GET /blog/category/:key` | 分类列表页（路径式，利于 SEO 内链） |
| `GET /blog/:slug` | 文章页 |
| `GET /sitemap.xml` | 含 `/`、`/blog`、各分类页、全部已发布文章（`lastmod` = `updated_at`） |
| `GET /robots.txt` | `Allow: /`、`Disallow: /api/`、`Sitemap:` 绝对地址 |

**草稿隔离**：`status !== 'published'` 的 slug 一律返回 **404**，且不出现在列表页、分类页与 sitemap 中。本设计**不提供任何公开预览路由**（草稿 HTML 仅通过受 `AdminAuthGuard` 保护的 `preview-html` 接口下发）。

**SEO 输出**

- 文章页 `<head>`：`<title>{seoTitle||title} · 如画 Lumira 博客</title>`、`<meta name="description">`、`<link rel="canonical" href="{BACKEND_PUBLIC_URL}/blog/{slug}">`、`og:type=article` + `og:title/og:description/og:image/og:url`、`twitter:card=summary_large_image`、`<html lang="zh-CN">`。
- JSON-LD `BlogPosting`：`headline`、`description`、`image`（`buildAssetUrl(cover)`）、`datePublished`、`dateModified`、`author`/`publisher` = `Organization "如画 Lumira"`、`mainEntityOfPage`。
- 列表页/分类页：canonical + description + 简版 `ItemList`。
- `og:image` 回退：文章无封面时使用站点默认图（复用 `logo-lumira-symbol.svg`）。

**Markdown 渲染与安全**：新增后端依赖 `marked` + `sanitize-html`。白名单放行 `p/h2/h3/h4/ul/ol/li/blockquote/pre/code/a/img/strong/em/hr/table/thead/tbody/tr/th/td/figure/figcaption`；仅允许属性 `a[href,target,rel]`、`img[src,alt,title,loading]`；禁止 `script/iframe/style/object/embed` 及一切 `on*` 事件属性；`a` 强制补 `rel="noopener"`、`img` 强制 `loading="lazy"`。

### 4. 后台 UI（`admin/src/app/dashboard/blog/*`）

| 页面 | 说明 |
|---|---|
| `/dashboard/blog` | 文章表格列表：状态 Tab（全部/草稿/已发布）、分类与关键词筛选、一键发布/取消发布、复制公开链接、删除 |
| `/dashboard/blog/new` | 新建：顶部「AI 生成」入口 + 标题/slug/摘要/SEO 字段/分类/封面/Markdown 正文；底部「保存草稿」与「保存并发布」 |
| `/dashboard/blog/[id]` | 编辑：同上 + 当前状态、公开链接、预览按钮（`iframe srcDoc`）、底部推广覆盖三选一、删除 |
| `/dashboard/blog/categories` | 分类管理（列表 + 新增/编辑/删除 + 排序） |
| `/dashboard/blog/settings` | 博客设置：推广总开关 + 三块文案 + 公众号二维码上传 + 列表页站点标题/描述 |

- `components/sidebar.tsx#L21-L38` 的 `navItems` 追加一项「博客」（`/dashboard/blog`，Phosphor 图标）。
- **Markdown 编辑器自建轻量组件** `components/blog/markdown-editor.tsx`：textarea + 工具栏（标题/粗体/斜体/引用/有序无序列表/链接/图片/代码/分隔线）+ 客户端 `marked` 实时预览。不引入 tiptap/quill 等重型依赖，避免与现有 Tailwind 主题冲突。
- 图片按钮 → 调 `api.uploadBlogImage()`（`POST /admin/blog/uploads`）→ 插入 `![alt](storageKey)`。
- 数据层沿用现有范式：`src/lib/api.ts` 增 `blog*` 方法、`src/actions/blog.ts` 承载 server action、`src/types/admin.ts` 增博客类型。
- 复用 `components/ui/`（`file-upload.tsx`、`switch.tsx`、`select.tsx`、`dialog.tsx`、`toast`）与 `lib/asset-url.ts`。

### 5. AI 生成博客（`POST /admin/blog/ai/generate`）

- 入参：`{ topic: string; requirements?: string; wordCount?: number; categoryId?: number }`。
- 复用 `llm-client.ts` 文本对话 + `ai-config.service` 的模型/key；请求走 jsonMode。
- 输出 JSON：`{ title, slugSuggestion, summary, seoDescription, contentMd, categoryKey }`，直接回填表单供运营继续手改（不直接落库）。
- **防编造约束（与「设计不得包含不存在的功能」原则一致）**：system prompt 内置产品事实摘要（取自 `blog_settings.promo_official_body`）并显式约束「不得虚构 Lumira 不具备的功能、不得承诺未上线能力」；若运营填了 `categoryId`，则把现有分类清单注入 prompt 让其从中选一个。
- 字数与结构约束：按 `wordCount`（默认 800）生成，要求含 H2/H3 小标题、每节 2-3 段、不输出 Markdown 代码围栏包裹全文。
- 失败处理：JSON 解析失败 / 超时 / 5xx 均抛错，后台 toast 提示并保留表单内容，运营可重试；沿用 `llm-client` 既有的 800ms 退避重试与 300s 超时。

### 6. 底部推广内容渲染

解析优先级：`promo_mode === 'on'` → 显示；`'off'` → 不显示；`'inherit'` → 跟随 `blog_settings.promo_enabled`（默认开启）。

渲染为正文末尾 `<aside class="blog-promo">`，含三块：

1. **Lumira 官方信息** — 品牌介绍文案 + 落地页链接 `/`
2. **APP 推广** — 推广文案 + 下载按钮，指向落地页 `/#download`
3. **公众号** — 引导语「关注微信公众号获取更多相关资讯」+ 二维码图片（`buildAssetUrl(promo_wechat_qr_url)`）

**某块文案为空则不渲染该块**；三块均空则不渲染整个 `<aside>`。

## 数据流

```
运营后台 /dashboard/blog/new
  ├─(可选) POST /api/v1/admin/blog/ai/generate {topic, requirements, wordCount}
  │     └─ llm-client(ai_provider_config) → {title, slugSuggestion, summary, seoDescription, contentMd}
  │        → 回填表单
  ├─ 正文插图 POST /api/v1/admin/blog/uploads {postId?} → storageKey → 插入 ![alt](storageKey)
  └─ 保存 POST/PATCH /api/v1/admin/blog/posts (multipart: meta JSON + cover)
        └─ DB blog_posts（status=draft|published；published 时写 published_at）

公开访问
  浏览器/爬虫 → https://lumira.iwtle.top/blog/{slug}
    → nginx location / → lumira-backend:3000
    → Fastify 裸路由 /blog/:slug
        ├─ 查 blog_posts（WHERE slug=? AND status='published'），未命中 → 404
        ├─ marked(content_md) → sanitize-html(白名单) → img[src] 过 buildAssetUrl
        ├─ 解析 promo_mode × blog_settings.promo_enabled → 追加 <aside class="blog-promo">
        └─ 拼 <head>(title/description/canonical/OG) + JSON-LD BlogPosting → 返回 HTML
  爬虫 → /sitemap.xml → 全部已发布文章 + 列表页 + 分类页
```

## 边界与容错

- **slug 冲突**：自动生成时若冲突追加 `-2`/`-3`；运营手填且冲突时返回 **409** 并在后台表单内提示。
- **slug 保留字**：`category` 为路由保留段（`/blog/category/:key`），校验层禁止使用该 slug，返回 400 并提示。
- **分页**：列表页与分类页每页固定 10 条；`?page` 非正整数或越界时钳制到合法范围（默认第 1 页），不报错。
- **slug 生成规则**：由标题派生 —— 先 ASCII 化（去标点、空格转 `-`、小写）；结果为空或无 ASCII 字符（纯中文标题）时回退 `post-<6位nanoid>`，同时表单提示可手填英文 slug。AI 生成路径会额外给出 `slugSuggestion`，故 AI 文章天然有可读 slug。
- **发布校验**：`title`、`slug`、`content_md` 必填；封面建议填写（用于 `og:image`），缺失时回退站点默认图。
- **取消发布**：`status → draft` 且 `published_at` 置空；公开链接立即 404，sitemap 自动移除。
- **删除文章**：需二次确认；删除后调用 `deleteByDir('blog', id)` 清理该文章目录（正文插图若上传于 `blog/drafts/` 目录则不随文章删除，作为独立优化项登记）。
- **XSS**：正文经 `sanitize-html` 白名单净化后才输出；分类名、标题等文本字段在模板中转义 HTML 实体。
- **大正文**：`content_md` 为 longtext；模板函数不做长度截断（列表页只渲染 `summary`，不渲染正文）。
- **AI 失败**：见 5 节；不写库、不改动已有内容。

## 明确不实现（YAGNI）

登记进 `docs/future-optimizations.md`：

- RSS 订阅输出（`/blog/rss.xml`）
- 发布后主动向百度/Bing 站长平台推送 URL
- 评论 / 点赞 / 阅读量统计
- 多作者与署名体系
- 定时发布（预约发布时间）
- 草稿版本历史与回滚
- 未使用插图（`blog/drafts/` 下的孤儿文件）自动清理
- 博客站内搜索

## 改动文件清单

**后端（`lumira-server/packages/backend/`）**

- `package.json`（新增 `marked`、`sanitize-html` 依赖）
- `src/database/migrations/048_blog.sql`（新增）
- `src/database/schema.ts`（新增 `blogCategories` / `blogPosts` / `blogSettings`）
- `src/common/storage/storage-adapter.interface.ts`（`StorageCategory` 增 `'blog'`）
- `src/modules/blog/blog.module.ts`（新增）
- `src/modules/blog/admin-blog.controller.ts`（新增）
- `src/modules/blog/admin-blog.service.ts`（新增）
- `src/modules/blog/ai-blog.service.ts`（新增）
- `src/modules/blog/markdown.ts`（新增：渲染 + 净化 + `buildAssetUrl` 后处理）
- `src/modules/blog/slug.ts`（新增）
- `src/modules/blog/dto/*.dto.ts`（新增：create/update/status/category/settings/ai-generate/list-query）
- `src/modules/blog/public/blog-layout.ts` / `post-page.ts` / `list-page.ts`（新增）
- `src/modules/blog/public/register-public-routes.ts`（新增：`/blog*`、`/sitemap.xml`、`/robots.txt`）
- `src/main.ts`（调用 `registerBlogPublicRoutes`）
- `src/app.module.ts`（注册 `BlogModule`）
- `public/css/blog.css`（新增）
- 测试：`src/modules/blog/*.spec.ts`（新增）

**后台（`lumira-server/packages/admin/`）**

- `src/types/admin.ts`（新增博客类型）
- `src/lib/api.ts`（新增 `blog*` 方法）
- `src/actions/blog.ts`（新增）
- `src/components/blog/markdown-editor.tsx`（新增）
- `src/components/blog/post-form.tsx`（新增）
- `src/components/blog/ai-generate-dialog.tsx`（新增）
- `src/components/blog/category-manager.tsx`（新增）
- `src/components/blog/settings-form.tsx`（新增）
- `src/app/dashboard/blog/page.tsx`（新增，列表）
- `src/app/dashboard/blog/new/page.tsx`（新增）
- `src/app/dashboard/blog/[id]/page.tsx`（新增）
- `src/app/dashboard/blog/categories/page.tsx`（新增）
- `src/app/dashboard/blog/settings/page.tsx`（新增）
- `src/components/sidebar.tsx`（`navItems` 追加「博客」）

**文档**

- `docs/future-optimizations.md`（追加 YAGNI 项）

## 验证方式

- 后端：`pnpm --filter @lumira/backend test`（单测覆盖：slug 生成与冲突回退、Markdown XSS 净化用例、promo 三态 × 全局开关的解析矩阵、sitemap 仅含已发布、草稿 slug 返回 404、AI JSON 解析失败降级为抛错）、`typecheck`、`test:e2e`。
- 后台：`pnpm --filter @lumira/admin build`（exit 0）、`pnpm --filter @lumira/admin test`。
- 部署后手工验证（生产 `https://lumira.iwtle.top`）：
  1. 发布一篇测试文章，`curl -s https://lumira.iwtle.top/blog/{slug} | head -50` 确认 HTML 中已含 `<title>`、canonical、`og:image`、`ld+json`。
  2. `curl -s https://lumira.iwtle.top/sitemap.xml` 确认含该 slug。
  3. 取消发布后再次 `curl`，确认返回 404 且 sitemap 已移除。
  4. 关闭全局推广开关后刷新文章页，确认 `<aside class="blog-promo">` 消失；打开且单篇 `promo_mode=off` 时同样消失。
  5. 后台侧栏「博客」入口可进入，AI 生成能回填表单，插图上传后公开页图片可正常显示（非 Mixed Content）。