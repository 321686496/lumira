# 后台图文博客（SEO 公开页 / AI 生成 / 底部推广开关）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在运营后台新增图文博客模块（草稿 / 发布 / 取消发布三态、AI 生成、底部推广开关），并由后端 Fastify 动态 SSR 出公开的 SEO 页面（列表页 / 分类页 / 文章页 / sitemap / robots），发布后任何人可访问 `https://lumira.iwtle.top/blog/{slug}`。

**Architecture:** 后端新增独立 `modules/blog/` 模块：Drizzle 三张新表（`blog_categories` / `blog_posts` / `blog_settings`）+ `BlogService`（Admin 与管理端共用的唯一数据层）+ `AdminBlogController`（`/api/v1/admin/blog/*`，走 `AdminAuthGuard`）+ `AiBlogService`（复用 `llm-client` 文本对话）+ `public/` 下的 HTML 模板函数与 `registerBlogPublicRoutes(fastify, deps)`（在 `main.ts` 注册静态目录**之后**挂到裸 Fastify 实例，与现有 `fastify.get('/')` 同一手法）。正文 Markdown 请求时渲染（`marked` → `sanitize-html` 白名单 → `img[src]` 过 `buildAssetUrl`），配 `Cache-Control: public, max-age=60`。后台新增 `dashboard/blog/*` 五个页面 + 自建轻量 Markdown 编辑器，沿用既有 `adminFetch` + server action + shadcn 风格自研组件范式。

**Tech Stack:** NestJS 10 + Fastify 4 + Drizzle ORM 0.38 + MySQL 8（mysql2）+ `marked` + `sanitize-html` + Jest；Admin：Next.js 14 App Router + react-hook-form + zod + Phosphor React + Tailwind；pnpm workspace。

## Global Constraints

- 改动范围仅 `lumira-server/packages/backend/**` 与 `lumira-server/packages/admin/**`；**不触碰** `lumira_app_flutter/**` 与 `lumira-app/**`。
- 新增依赖**仅**：后端 `marked`、`sanitize-html`（+ devDependency `@types/sanitize-html`）、Admin `marked`。禁止引入 tiptap / quill / DOMPurify 等重型或额外依赖。
- 数据库约定：内容表主键 `VARCHAR(64)` + `nanoid`；时间戳一律 `INT` **秒级**（`Math.floor(Date.now() / 1000)`）；布尔用 `INT` 0/1；结构化/长文本用 `LONGTEXT`；列名为保留字（`key`）时迁移 SQL 用反引号包裹。
- 迁移文件命名 `<编号>_<snake_topic>.sql`，本次编号 **048**；迁移器按 `_migrations` 表幂等执行，SQL 必须自身幂等（`CREATE TABLE IF NOT EXISTS` / `INSERT ... ON DUPLICATE KEY UPDATE`）。
- 图片一律在 DB 存**相对 storageKey**（`/uploads/blog/...`）；出参与 HTML 渲染时**统一**经 `buildAssetUrl()` 拼当前激活存储的公网地址。
- 公开页**实时**反映发布状态：`status !== 'published'` 的 slug 一律 404，且不出现在列表页 / 分类页 / sitemap。
- 渲染出的 HTML **必须**先过 `sanitize-html` 白名单；所有来自 DB 的纯文本字段（标题、分类名、摘要、推广文案）在模板中必须经 `escapeHtml()` 转义。
- 后端单测文件与实现同目录（`*.spec.ts`），运行器 Jest。
- Admin 侧所有后端调用**必须**经 `src/lib/api.ts#adminFetch`（自带 cookie token、401 → `UnauthenticatedError`、错误文案透传）；写操作经 `src/actions/*.ts` server action + `revalidatePath`。
- 每个 Task 结束必须 commit，并按 `AGENTS.md` 硬规则**同时 push 两个远程**：`git push origin master` 与 `git push github master`。
- 设计文档为唯一权威源：[2026-09-28-admin-blog-design.md](file:///d:/app/projects/photo_post/docs/specs/2026-09-28-admin-blog-design.md)。命名偏差说明：设计稿「改动文件清单」中的 `admin-blog.service.ts` 在本计划中命名为 `blog.service.ts`（该类同时服务 Admin 与公开页，命名中性更贴切），职责与内容不变。

---

## 文件结构（改动映射）

| 文件 | 责任 | 涉及 Task |
|------|------|-----------|
| `backend/src/database/migrations/048_blog.sql` | 新增 3 张表 + 设置行 seed | 1 |
| `backend/src/database/schema.ts` | `blogCategories` / `blogPosts` / `blogSettings` Drizzle 表 | 1 |
| `backend/src/common/storage/storage-adapter.interface.ts` | `StorageCategory` 增 `'blog'` | 1 |
| `backend/src/modules/storage-migration/storage-migration.agent.ts` | 迁移类别白名单增 `'blog'` | 1 |
| `backend/src/modules/blog/slug.ts` | slug 生成 / 校验 / 冲突消解 | 2 |
| `backend/src/modules/blog/slug.spec.ts` | slug 单测 | 2 |
| `backend/src/modules/blog/markdown.ts` | Markdown → 安全 HTML + 图片 URL 规整 | 3 |
| `backend/src/modules/blog/markdown.spec.ts` | XSS 净化 / 图片规整单测 | 3 |
| `backend/package.json` | 新增 `marked`、`sanitize-html` 依赖 + dev `@types/sanitize-html` | 3 |
| `backend/src/modules/blog/blog.service.ts` | 唯一数据层：分类 / 设置 / 文章 CRUD / 公开只读 / 推广解析 | 4 |
| `backend/src/modules/blog/blog.service.spec.ts` | promo 解析矩阵 + 分页钳制单测 | 4 |
| `backend/src/modules/blog/multipart.ts` | 博客 multipart 解析（`meta` + `cover` + `file`） | 5 |
| `backend/src/modules/blog/dto/*.dto.ts` | create / update / status / category / settings / ai-generate / list-query DTO | 5 |
| `backend/src/modules/blog/admin-blog.controller.ts` | `/api/v1/admin/blog/*` 全部管理端点 | 5 |
| `backend/src/modules/blog/blog.module.ts` | Blog 模块装配 + `registerBlogPublicRoutes` 装配函数 | 5 / 8 |
| `backend/src/app.module.ts` | 注册 `BlogModule` | 5 |
| `backend/src/modules/blog/ai-blog.service.ts` | AI 生成博客（复用 `llm-client`） | 6 |
| `backend/src/modules/blog/ai-blog.service.spec.ts` | AI JSON 解析 / 失败抛错单测 | 6 |
| `backend/src/modules/blog/public/blog-layout.ts` | head/OG/JSON-LD/页头页脚 + `escapeHtml` + 推广 `<aside>` | 7 |
| `backend/src/modules/blog/public/post-page.ts` | 文章页 HTML | 7 |
| `backend/src/modules/blog/public/list-page.ts` | 列表页 / 分类页 HTML | 7 |
| `backend/src/modules/blog/public/blog-layout.spec.ts` | 布局转义 / promo 渲染单测 | 7 |
| `backend/src/modules/blog/public/register-public-routes.ts` | `/blog*`、`/sitemap.xml`、`/robots.txt` 裸路由 | 8 |
| `backend/src/main.ts` | 静态目录注册后调用 `registerBlogPublicRoutes` | 8 |
| `backend/public/css/blog.css` | 博客公开页样式（复用品牌变量） | 8 |
| `admin/src/types/admin.ts` | 博客类型定义 | 9 |
| `admin/src/lib/api.ts` | `api.blog*` 方法 | 9 |
| `admin/src/actions/blog.ts` | 博客 server actions | 9 |
| `admin/src/lib/blog-markdown.ts` | Markdown 工具栏纯函数变换 | 10 |
| `admin/src/lib/__tests__/blog-markdown.test.ts` | 工具栏变换 vitest 单测 | 10 |
| `admin/package.json` | 新增 `marked` 依赖 | 10 |
| `admin/src/components/blog/markdown-editor.tsx` | 轻量 Markdown 编辑器（工具栏 + 客户端预览 + 插图） | 10 |
| `admin/src/components/blog/post-form.tsx` | 文章表单（新建 / 编辑共用） | 11 |
| `admin/src/components/blog/ai-generate-dialog.tsx` | AI 生成弹窗 | 11 |
| `admin/src/app/dashboard/blog/new/page.tsx` | 新建页 | 11 |
| `admin/src/app/dashboard/blog/[id]/page.tsx` | 编辑页 | 11 |
| `admin/src/components/blog/post-table.tsx` | 列表行操作（发布 / 取消发布、复制链接、编辑、删除） | 12 |
| `admin/src/app/dashboard/blog/page.tsx` | 文章列表（状态 Tab / 一键发布 / 复制链接 / 删除） | 12 |
| `admin/src/components/blog/category-manager.tsx` | 分类管理组件 | 13 |
| `admin/src/components/blog/settings-form.tsx` | 设置表单组件 | 13 |
| `admin/src/app/dashboard/blog/categories/page.tsx` | 分类管理页 | 13 |
| `admin/src/app/dashboard/blog/settings/page.tsx` | 博客设置页 | 13 |
| `admin/src/components/sidebar.tsx` | `navItems` 追加「博客」 | 14 |
| `admin/src/components/dashboard-shell.tsx` | `titleMap` 补博客页标题 | 14 |
| `docs/future-optimizations.md` | 追加 YAGNI 优化项 | 15 |

**执行顺序提示**：Task 4 定义 `BlogService` 的全部公开签名，Task 5 / 6 / 7 / 8 都依赖它，必须按编号顺序执行。Task 9 定义 Admin 类型与方法名，Task 10~14 依赖它。

---

## Task 1: 数据落库（迁移 048 + Drizzle 表 + 存储类别 + 迁移器白名单）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/048_blog.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（文件末尾追加）
- Modify: `lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts:6`
- Modify: `lumira-server/packages/backend/src/modules/storage-migration/storage-migration.agent.ts:186,346`

**Interfaces:**
- Consumes: 无
- Produces: Drizzle 表对象 `blogCategories` / `blogPosts` / `blogSettings`（供 Task 4 的 `BlogService` 使用）；`StorageCategory` 联合类型新增 `'blog'`

- [ ] **Step 1: 写迁移 SQL**

新建 `lumira-server/packages/backend/src/database/migrations/048_blog.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/048_blog.sql
-- 后台图文博客（spec 2026-09-28-admin-blog-design）：blog_categories / blog_posts / blog_settings 三张表。
-- 幂等说明：迁移由 _migrations 表记录只执行一次；建表用 CREATE TABLE IF NOT EXISTS，
--          设置行用 INSERT ... ON DUPLICATE KEY UPDATE 保证重跑安全。
-- 约定：时间戳 INT 秒级；布尔 INT 0/1；`key` 为 MySQL 保留字，需反引号包裹。

CREATE TABLE IF NOT EXISTS `blog_categories` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `key`         VARCHAR(64) NOT NULL COMMENT '稳定标识，用于 /blog/category/:key',
  `name`        VARCHAR(100) NOT NULL,
  `description` VARCHAR(300) NOT NULL DEFAULT '' COMMENT '分类页 SEO 描述',
  `sort_order`  INT NOT NULL DEFAULT 0,
  `created_at`  INT NOT NULL,
  `updated_at`  INT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_blog_category_key` (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `blog_posts` (
  `id`              VARCHAR(64) NOT NULL COMMENT 'nanoid',
  `slug`            VARCHAR(200) NOT NULL,
  `title`           VARCHAR(200) NOT NULL,
  `summary`         VARCHAR(300) NOT NULL DEFAULT '' COMMENT '列表页展示 + SEO 描述回退',
  `seo_title`       VARCHAR(200) NOT NULL DEFAULT '' COMMENT '空则回退 title',
  `seo_description` VARCHAR(300) NOT NULL DEFAULT '' COMMENT '空则回退 summary',
  `cover_url`       VARCHAR(512) NOT NULL DEFAULT '' COMMENT '相对 storageKey',
  `content_md`      LONGTEXT NOT NULL COMMENT 'Markdown 原文（唯一数据源）',
  `category_id`     INT NULL COMMENT '可空=未分类',
  `status`          VARCHAR(16) NOT NULL DEFAULT 'draft' COMMENT 'draft | published',
  `promo_mode`      VARCHAR(16) NOT NULL DEFAULT 'inherit' COMMENT 'inherit | on | off',
  `published_at`    INT NULL COMMENT '首次发布写入，取消发布置空',
  `created_at`      INT NOT NULL,
  `updated_at`      INT NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_blog_slug` (`slug`),
  KEY `idx_blog_status_pub` (`status`, `published_at`),
  KEY `idx_blog_category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `blog_settings` (
  `id`                  INT NOT NULL,
  `promo_enabled`       INT NOT NULL DEFAULT 1 COMMENT '推广总开关，默认开启',
  `blog_title`          VARCHAR(200) NOT NULL DEFAULT '如画 Lumira 博客',
  `blog_description`    VARCHAR(300) NOT NULL DEFAULT '',
  `promo_official_title` VARCHAR(200) NOT NULL DEFAULT '',
  `promo_official_body`  VARCHAR(500) NOT NULL DEFAULT '',
  `promo_app_title`      VARCHAR(200) NOT NULL DEFAULT '',
  `promo_app_body`       VARCHAR(500) NOT NULL DEFAULT '',
  `promo_wechat_title`   VARCHAR(200) NOT NULL DEFAULT '',
  `promo_wechat_body`    VARCHAR(500) NOT NULL DEFAULT '',
  `promo_wechat_qr_url`  VARCHAR(512) NOT NULL DEFAULT '' COMMENT '相对 storageKey',
  `updated_at`          INT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `blog_settings` (
  `id`, `promo_enabled`, `blog_title`, `blog_description`,
  `promo_official_title`, `promo_official_body`,
  `promo_app_title`, `promo_app_body`,
  `promo_wechat_title`, `promo_wechat_body`, `promo_wechat_qr_url`, `updated_at`
) VALUES (
  1, 1, '如画 Lumira 博客', '摄影灵感、拍摄技巧与出片思路，帮助你用最简单的方式拍出好照片。',
  '关于如画 Lumira', '如画 Lumira 是一款帮助普通人拍出好照片的摄影辅助应用：挑一个模板、按快门、直接出片。',
  '用如画 Lumira 拍照', '打开 App 挑选喜欢的模板，跟着构图提示拍，人人都能轻松拍出好照片。',
  '关注微信公众号', '关注微信公众号获取更多相关资讯', '', 0
) ON DUPLICATE KEY UPDATE `id` = `id`;
```

- [ ] **Step 2: 在 schema.ts 末尾追加三张表**

在 `lumira-server/packages/backend/src/database/schema.ts` 文件**末尾**（`storageConfigs` 之后）追加：

```ts
// ===== 后台图文博客（spec 2026-09-28-admin-blog-design）=====
export const blogCategories = mysqlTable('blog_categories', {
  id: int('id').primaryKey().autoincrement(),
  key: varchar('key', { length: 64 }).notNull(),
  name: varchar('name', { length: 100 }).notNull(),
  description: varchar('description', { length: 300 }).notNull().default(''),
  sortOrder: int('sort_order').notNull().default(0),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  keyIdx: uniqueIndex('uq_blog_category_key').on(table.key),
}));

export const blogPosts = mysqlTable('blog_posts', {
  id: varchar('id', { length: 64 }).primaryKey(),
  slug: varchar('slug', { length: 200 }).notNull(),
  title: varchar('title', { length: 200 }).notNull(),
  summary: varchar('summary', { length: 300 }).notNull().default(''),
  seoTitle: varchar('seo_title', { length: 200 }).notNull().default(''),
  seoDescription: varchar('seo_description', { length: 300 }).notNull().default(''),
  coverUrl: varchar('cover_url', { length: 512 }).notNull().default(''),
  contentMd: longtext('content_md').notNull(),
  categoryId: int('category_id'),
  status: varchar('status', { length: 16 }).notNull().default('draft'),
  promoMode: varchar('promo_mode', { length: 16 }).notNull().default('inherit'),
  publishedAt: int('published_at'),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  slugIdx: uniqueIndex('uq_blog_slug').on(table.slug),
  statusPubIdx: index('idx_blog_status_pub').on(table.status, table.publishedAt),
  categoryIdx: index('idx_blog_category').on(table.categoryId),
}));

export const blogSettings = mysqlTable('blog_settings', {
  id: int('id').primaryKey(),
  promoEnabled: int('promo_enabled').notNull().default(1),
  blogTitle: varchar('blog_title', { length: 200 }).notNull().default('如画 Lumira 博客'),
  blogDescription: varchar('blog_description', { length: 300 }).notNull().default(''),
  promoOfficialTitle: varchar('promo_official_title', { length: 200 }).notNull().default(''),
  promoOfficialBody: varchar('promo_official_body', { length: 500 }).notNull().default(''),
  promoAppTitle: varchar('promo_app_title', { length: 200 }).notNull().default(''),
  promoAppBody: varchar('promo_app_body', { length: 500 }).notNull().default(''),
  promoWechatTitle: varchar('promo_wechat_title', { length: 200 }).notNull().default(''),
  promoWechatBody: varchar('promo_wechat_body', { length: 500 }).notNull().default(''),
  promoWechatQrUrl: varchar('promo_wechat_qr_url', { length: 512 }).notNull().default(''),
  updatedAt: int('updated_at').notNull(),
});
```

- [ ] **Step 3: 存储类别新增 'blog'**

把 `lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts:4-6` 改为：

```ts
// 'thumbs' 为缩略图派生目录（/uploads/thumbs/{templates|categories}/...），
// 由 ThumbsService 预生成/按需生成后写入激活存储，供客户端直连存储域名取图。
// 'blog' 为后台博客图片（封面 blog/{postId}、正文插图 blog/{postId}|drafts、公众号二维码 blog/settings）。
export type StorageCategory =
  | 'templates'
  | 'categories'
  | 'banners'
  | 'feedback'
  | 'users'
  | 'thumbs'
  | 'blog';
```

- [ ] **Step 4: 存储迁移器类别白名单新增 'blog'**

先打开 `lumira-server/packages/backend/src/modules/storage-migration/storage-migration.agent.ts`，对 `:186` 与 `:346` 两处硬编码的类别数组（形如 `['templates', 'categories', 'banners', 'feedback', 'users']`）各追加一个 `'blog'`，即两处都变成：

```ts
const CATEGORIES = ['templates', 'categories', 'banners', 'feedback', 'users', 'blog'] as const;
```

（两处原本是内联字面量数组；若为内联写法，直接在每个数组末尾补 `, 'blog'` 即可，变量名保持文件原有命名。）

- [ ] **Step 5: 编译与既有测试回归**

Run: `pnpm --filter @lumira/backend build`
Expected: 退出码 0，无 TS 报错。

Run: `pnpm --filter @lumira/backend test`
Expected: 全部既有用例 PASS（新增表定义不影响任何既有测试）。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/src/database/migrations/048_blog.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts lumira-server/packages/backend/src/modules/storage-migration/storage-migration.agent.ts
git commit -m "feat(backend): 新增博客三张表、blog 存储类别与迁移器白名单"
git push origin master
git push github master
```

---

## Task 2: slug 工具（生成 / 校验 / 冲突消解）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/slug.ts`
- Test: `lumira-server/packages/backend/src/modules/blog/slug.spec.ts`

**Interfaces:**
- Consumes: 无（仅依赖 `nanoid`）
- Produces:
  - `RESERVED_SLUGS: Set<string>`
  - `slugify(input: string): string`
  - `suggestSlug(title: string): string`
  - `validateSlug(slug: string): { ok: true } | { ok: false; reason: string }`
  - `resolveUniqueSlug(base: string, exists: (candidate: string) => Promise<boolean>): Promise<string>`

- [ ] **Step 1: 写失败测试**

新建 `lumira-server/packages/backend/src/modules/blog/slug.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/slug.spec.ts
import { RESERVED_SLUGS, resolveUniqueSlug, slugify, suggestSlug, validateSlug } from './slug';

describe('slugify', () => {
  it('英文标题转为小写连字符', () => {
    expect(slugify('Hello World!')).toBe('hello-world');
  });

  it('中英混排只保留 ASCII 片段', () => {
    expect(slugify('2026 夏日 Portrait 拍摄 技巧')).toBe('2026-portrait');
  });

  it('纯中文标题产出空串', () => {
    expect(slugify('夏日人像拍摄技巧')).toBe('');
  });

  it('首尾与连续的标点不会留下连字符', () => {
    expect(slugify('  --A  B--  ')).toBe('a-b');
  });
});

describe('suggestSlug', () => {
  it('有 ASCII 时直接使用 slugify 结果', () => {
    expect(suggestSlug('Shooting Tips')).toBe('shooting-tips');
  });

  it('纯中文标题回退 post-<6位 nanoid>', () => {
    expect(suggestSlug('夏日人像拍摄技巧')).toMatch(/^post-[0-9a-z]{6}$/);
  });
});

describe('validateSlug', () => {
  it('合法 slug 通过', () => {
    expect(validateSlug('shooting-tips')).toEqual({ ok: true });
  });

  it('空值不通过', () => {
    expect(validateSlug('').ok).toBe(false);
  });

  it('大写 / 下划线 / 前后连字符不通过', () => {
    expect(validateSlug('Shooting_Tips').ok).toBe(false);
    expect(validateSlug('-tips').ok).toBe(false);
    expect(validateSlug('tips-').ok).toBe(false);
  });

  it('保留字 category 不通过', () => {
    const r = validateSlug('category');
    expect(r.ok).toBe(false);
    expect(RESERVED_SLUGS.has('category')).toBe(true);
  });

  it('超长不通过', () => {
    expect(validateSlug('a'.repeat(201)).ok).toBe(false);
  });
});

describe('resolveUniqueSlug', () => {
  it('无冲突时原样返回', async () => {
    await expect(resolveUniqueSlug('tips', async () => false)).resolves.toBe('tips');
  });

  it('冲突时依次追加 -2 / -3', async () => {
    const taken = new Set(['tips', 'tips-2']);
    await expect(resolveUniqueSlug('tips', async (c) => taken.has(c))).resolves.toBe('tips-3');
  });

  it('空 base 时回退 post-<6位>', async () => {
    await expect(resolveUniqueSlug('', async () => false)).resolves.toMatch(/^post-[0-9a-z]{6}$/);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- slug.spec`
Expected: FAIL —— `Cannot find module './slug'`

- [ ] **Step 3: 实现 slug.ts**

新建 `lumira-server/packages/backend/src/modules/blog/slug.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/slug.ts
// 博客 slug 工具：标题 → URL 友好标识；纯中文标题回退 `post-<6位 nanoid>`。
import { customAlphabet } from 'nanoid';

/** 路由保留段：/blog/category/:key 已占用 `category`，禁止文章 slug 使用 */
export const RESERVED_SLUGS = new Set(['category']);

const SLUG_MAX = 200;
const nanoSuffix = customAlphabet('0123456789abcdefghijklmnopqrstuvwxyz', 6);

/**
 * ASCII 化：去音标 → 小写 → 非 [a-z0-9] 一律折叠为 `-` → 去首尾连字符 → 截断。
 * 无 ASCII 产出（如纯中文标题）时返回空串，由调用方决定回退策略。
 */
export function slugify(input: string): string {
  return (input || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, SLUG_MAX)
    .replace(/-+$/g, '');
}

/** 由标题派生候选 slug；纯中文 / 无 ASCII 时回退 `post-<6位>` */
export function suggestSlug(title: string): string {
  const base = slugify(title);
  return base || `post-${nanoSuffix()}`;
}

/** 手填校验：1~200 位小写字母/数字/连字符，非保留字 */
export function validateSlug(slug: string): { ok: true } | { ok: false; reason: string } {
  const s = (slug || '').trim();
  if (!s) return { ok: false, reason: 'slug 不能为空' };
  if (s.length > SLUG_MAX) return { ok: false, reason: `slug 不能超过 ${SLUG_MAX} 个字符` };
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(s)) {
    return { ok: false, reason: 'slug 只能包含小写字母、数字与连字符（-），且不能以连字符开头或结尾' };
  }
  if (RESERVED_SLUGS.has(s)) return { ok: false, reason: `slug "${s}" 为系统保留字，请更换` };
  return { ok: true };
}

/** 冲突时依次追加 -2 / -3…；`exists` 由调用方查库提供（更新场景需排除自身 id） */
export async function resolveUniqueSlug(
  base: string,
  exists: (candidate: string) => Promise<boolean>,
): Promise<string> {
  const root = base || `post-${nanoSuffix()}`;
  for (let n = 1; n <= 200; n += 1) {
    const candidate = n === 1 ? root : `${root}-${n}`;
    if (!(await exists(candidate))) return candidate;
  }
  // 极端兜底：200 次都冲突时加随机后缀，避免死循环
  return `${root}-${nanoSuffix()}`;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- slug.spec`
Expected: PASS（14 个用例）

- [ ] **Step 5: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/slug.ts lumira-server/packages/backend/src/modules/blog/slug.spec.ts
git commit -m "feat(backend): 博客 slug 生成/校验/冲突消解工具"
git push origin master
git push github master
```

---

## Task 3: Markdown 渲染与净化（含依赖安装）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/markdown.ts`
- Test: `lumira-server/packages/backend/src/modules/blog/markdown.spec.ts`
- Modify: `lumira-server/packages/backend/package.json`（依赖）

**Interfaces:**
- Consumes: `buildAssetUrl(url: string | null | undefined): string`（`common/storage/asset-url.ts`，已存在）
- Produces: `renderMarkdown(md: string): string`（返回已净化的 HTML 片段）

- [ ] **Step 1: 安装依赖**

Run: `pnpm --filter @lumira/backend add marked sanitize-html`
Expected: `lumira-server/packages/backend/package.json` 的 `dependencies` 新增 `marked`、`sanitize-html`。

Run: `pnpm --filter @lumira/backend add -D @types/sanitize-html`
Expected: `devDependencies` 新增 `@types/sanitize-html`。

- [ ] **Step 2: 写失败测试**

新建 `lumira-server/packages/backend/src/modules/blog/markdown.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/markdown.spec.ts
import { renderMarkdown } from './markdown';

describe('renderMarkdown', () => {
  it('渲染标题与段落', () => {
    const html = renderMarkdown('## 小标题\n\n正文一段。');
    expect(html).toContain('<h2>小标题</h2>');
    expect(html).toContain('<p>正文一段。</p>');
  });

  it('剥除 script 标签与内容', () => {
    const html = renderMarkdown('正常文字\n\n<script>alert(1)</script>');
    expect(html).not.toContain('<script');
    expect(html).not.toContain('alert(1)');
  });

  it('剥除 on* 事件属性与 javascript: 链接', () => {
    const html = renderMarkdown('<img src="/uploads/blog/x/a.jpg" onerror="alert(1)">\n\n[点我](javascript:alert(1))');
    expect(html).not.toContain('onerror');
    expect(html).not.toContain('javascript:');
  });

  it('禁止 iframe / style 标签', () => {
    const html = renderMarkdown('<iframe src="//evil"></iframe>\n\n<style>body{display:none}</style>');
    expect(html).not.toContain('<iframe');
    expect(html).not.toContain('<style');
  });

  it('外链强制补 rel=noopener noreferrer', () => {
    const html = renderMarkdown('[外链](https://example.com/a)');
    expect(html).toContain('rel="noopener noreferrer"');
  });

  it('img 补 loading=lazy 且 storageKey 相对路径被规整为绝对 URL', () => {
    const html = renderMarkdown('![图](/uploads/blog/drafts/abc.jpg)');
    expect(html).toContain('loading="lazy"');
    expect(html).toContain('/uploads/blog/drafts/abc.jpg');
    expect(html).not.toContain('src="/uploads');
  });

  it('外部绝对图片 URL 原样保留', () => {
    const html = renderMarkdown('![图](https://cdn.example.com/a.jpg)');
    expect(html).toContain('src="https://cdn.example.com/a.jpg"');
  });

  it('空输入返回空串', () => {
    expect(renderMarkdown('')).toBe('');
  });
});
```

- [ ] **Step 3: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- markdown.spec`
Expected: FAIL —— `Cannot find module './markdown'`

- [ ] **Step 4: 实现 markdown.ts**

新建 `lumira-server/packages/backend/src/modules/blog/markdown.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/markdown.ts
// 博客正文渲染：Markdown → HTML → sanitize-html 白名单净化 → img[src] 经 buildAssetUrl 规整。
// 净化在渲染管道末端完成，故调整白名单无需回填历史数据。
import { marked } from 'marked';
import sanitizeHtml from 'sanitize-html';
import { buildAssetUrl } from '../../common/storage/asset-url';

/** 白名单标签：文章语义化结构 + 表格 + 图片说明 */
const ALLOWED_TAGS = [
  'p', 'h2', 'h3', 'h4', 'ul', 'ol', 'li', 'blockquote', 'pre', 'code',
  'a', 'img', 'strong', 'em', 'hr', 'br',
  'table', 'thead', 'tbody', 'tr', 'th', 'td',
  'figure', 'figcaption',
];

export function renderMarkdown(md: string): string {
  if (!md || !md.trim()) return '';
  const rawHtml = marked.parse(md, { async: false }) as string;
  return sanitizeHtml(rawHtml, {
    allowedTags: ALLOWED_TAGS,
    allowedAttributes: {
      a: ['href', 'target', 'rel', 'title'],
      img: ['src', 'alt', 'title', 'loading'],
      th: ['align'],
      td: ['align'],
    },
    allowedSchemes: ['http', 'https', 'mailto'],
    // 显式禁止危险标签（白名单已排除，此处再声明一次以防配置漂移）
    disallowedTagsMode: 'discard',
    transformTags: {
      a: sanitizeHtml.simpleTransform('a', { rel: 'noopener noreferrer' }, true),
      img: (tagName, attribs) => ({
        tagName,
        attribs: { ...attribs, src: buildAssetUrl(attribs.src), loading: 'lazy' },
      }),
    },
  });
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- markdown.spec`
Expected: PASS（8 个用例）

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/package.json lumira-server/pnpm-lock.yaml lumira-server/packages/backend/src/modules/blog/markdown.ts lumira-server/packages/backend/src/modules/blog/markdown.spec.ts
git commit -m "feat(backend): 博客 Markdown 渲染与 XSS 净化"
git push origin master
git push github master
```

---

## Task 4: `BlogService` 唯一数据层（分类 / 设置 / 文章 / 公开只读 / 推广解析）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/blog.service.ts`
- Test: `lumira-server/packages/backend/src/modules/blog/blog.service.spec.ts`

**Interfaces:**
- Consumes: `blogCategories` / `blogPosts` / `blogSettings`（Task 1）、`slug.ts`（Task 2）、`STORAGE_ADAPTER`（现有）、`buildAssetUrl`（现有）
- Produces（Task 5 / 6 / 7 / 8 全部依赖以下签名）：

```ts
export type BlogStatus = 'draft' | 'published';
export type PromoMode = 'inherit' | 'on' | 'off';
export interface UploadFile { buffer: Buffer; filename: string; mimetype: string }
export interface BlogCategoryView { id: number; key: string; name: string; description: string; sortOrder: number }
export interface BlogPostListItem {
  id: string; slug: string; title: string; summary: string; coverUrl: string;
  status: BlogStatus; promoMode: PromoMode;
  categoryId: number | null; categoryName: string | null; categoryKey: string | null;
  publishedAt: number | null; createdAt: number; updatedAt: number;
}
export interface BlogPostDetail extends BlogPostListItem { seoTitle: string; seoDescription: string; contentMd: string }
export interface BlogSettingsView {
  promoEnabled: boolean; blogTitle: string; blogDescription: string;
  promoOfficialTitle: string; promoOfficialBody: string;
  promoAppTitle: string; promoAppBody: string;
  promoWechatTitle: string; promoWechatBody: string; promoWechatQrUrl: string;
}
export interface PromoBlock { title: string; body: string; qrUrl?: string }
export interface PromoContent { official: PromoBlock | null; app: PromoBlock | null; wechat: PromoBlock | null }
export interface PostInput {
  title: string; slug?: string; summary?: string; seoTitle?: string; seoDescription?: string;
  contentMd?: string; categoryId?: number | null; status?: BlogStatus; promoMode?: PromoMode;
}
export interface CategoryInput { key: string; name: string; description?: string; sortOrder?: number }
export interface SettingsInput {
  promoEnabled?: boolean; blogTitle?: string; blogDescription?: string;
  promoOfficialTitle?: string; promoOfficialBody?: string;
  promoAppTitle?: string; promoAppBody?: string;
  promoWechatTitle?: string; promoWechatBody?: string;
}
export class BlogService {
  listCategories(): Promise<BlogCategoryView[]>;
  getCategoryByKey(key: string): Promise<BlogCategoryView | null>;
  createCategory(input: CategoryInput): Promise<BlogCategoryView>;
  updateCategory(id: number, input: Omit<CategoryInput, 'key'>): Promise<BlogCategoryView>;
  deleteCategory(id: number): Promise<void>;
  getSettings(): Promise<BlogSettingsView>;
  updateSettings(input: SettingsInput, qr?: UploadFile): Promise<BlogSettingsView>;
  listPosts(query: { status?: string; categoryId?: number; keyword?: string; page?: number; pageSize?: number }):
    Promise<{ items: BlogPostListItem[]; total: number; page: number; pageSize: number }>;
  getPost(id: string): Promise<BlogPostDetail | null>;
  createPost(input: PostInput, cover?: UploadFile): Promise<BlogPostDetail>;
  updatePost(id: string, input: PostInput, cover?: UploadFile): Promise<BlogPostDetail>;
  updatePostStatus(id: string, status: BlogStatus): Promise<BlogPostListItem>;
  deletePost(id: string): Promise<void>;
  uploadImage(file: UploadFile, postId?: string): Promise<{ storageKey: string; url: string }>;
  getPublishedBySlug(slug: string): Promise<BlogPostDetail | null>;
  listPublishedPosts(opts: { page?: number; categoryKey?: string }):
    Promise<{ items: BlogPostListItem[]; total: number; page: number; pageSize: number; category: BlogCategoryView | null }>;
  listPublishedForSitemap(): Promise<{ slug: string; updatedAt: number }[]>;
}
export function resolvePromoContent(mode: PromoMode, settings: BlogSettingsView): PromoContent | null;
export function resolvePage(requested: unknown, total: number, pageSize: number): number;
```

- [ ] **Step 1: 写失败测试（只测两个纯函数，保持 DB 无关）**

新建 `lumira-server/packages/backend/src/modules/blog/blog.service.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/blog.service.spec.ts
import { BlogSettingsView, resolvePage, resolvePromoContent } from './blog.service';

function settings(over: Partial<BlogSettingsView> = {}): BlogSettingsView {
  return {
    promoEnabled: true,
    blogTitle: '如画 Lumira 博客',
    blogDescription: '',
    promoOfficialTitle: '关于如画 Lumira',
    promoOfficialBody: '官方介绍文案',
    promoAppTitle: '用如画 Lumira 拍照',
    promoAppBody: 'App 推广文案',
    promoWechatTitle: '关注微信公众号',
    promoWechatBody: '关注微信公众号获取更多相关资讯',
    promoWechatQrUrl: '/uploads/blog/settings/wechat-qr.png',
    ...over,
  };
}

describe('resolvePromoContent', () => {
  it('promo_mode=on 时无视全局开关，始终渲染', () => {
    const promo = resolvePromoContent('on', settings({ promoEnabled: false }));
    expect(promo).not.toBeNull();
    expect(promo?.official?.body).toBe('官方介绍文案');
  });

  it('promo_mode=off 时无视全局开关，始终不渲染', () => {
    expect(resolvePromoContent('off', settings({ promoEnabled: true }))).toBeNull();
  });

  it('promo_mode=inherit 跟随全局开关：开启则渲染', () => {
    expect(resolvePromoContent('inherit', settings({ promoEnabled: true }))).not.toBeNull();
  });

  it('promo_mode=inherit 跟随全局开关：关闭则不渲染', () => {
    expect(resolvePromoContent('inherit', settings({ promoEnabled: false }))).toBeNull();
  });

  it('某块文案为空则该块不渲染', () => {
    const promo = resolvePromoContent('inherit', settings({ promoOfficialBody: '', promoAppBody: '' }));
    expect(promo?.official).toBeNull();
    expect(promo?.app).toBeNull();
    expect(promo?.wechat).not.toBeNull();
  });

  it('三块文案全空则整体返回 null', () => {
    const promo = resolvePromoContent('inherit', settings({
      promoOfficialBody: '', promoAppBody: '', promoWechatBody: '',
    }));
    expect(promo).toBeNull();
  });

  it('公众号块携带二维码 storageKey', () => {
    const promo = resolvePromoContent('inherit', settings());
    expect(promo?.wechat?.qrUrl).toBe('/uploads/blog/settings/wechat-qr.png');
  });
});

describe('resolvePage', () => {
  it('非数字 / 非正整数 / 小数一律回落第 1 页', () => {
    expect(resolvePage('abc', 25, 10)).toBe(1);
    expect(resolvePage(0, 25, 10)).toBe(1);
    expect(resolvePage(-3, 25, 10)).toBe(1);
    expect(resolvePage(1.5, 25, 10)).toBe(1);
  });

  it('合法页码原样返回', () => {
    expect(resolvePage(2, 25, 10)).toBe(2);
  });

  it('越界页码钳制到最后一页', () => {
    expect(resolvePage(99, 25, 10)).toBe(3);
  });

  it('总数 0 时不越界，返回第 1 页', () => {
    expect(resolvePage(5, 0, 10)).toBe(1);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- blog.service.spec`
Expected: FAIL —— `Cannot find module './blog.service'`

- [ ] **Step 3: 实现 blog.service.ts**

新建 `lumira-server/packages/backend/src/modules/blog/blog.service.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/blog.service.ts
// 博客唯一数据层：同时服务 Admin 管理端点与公开页 SSR（分类 / 设置 / 文章 CRUD / 公开只读 / 推广解析）。
import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, asc, desc, eq, like, ne, or, sql } from 'drizzle-orm';
import type { SQL } from 'drizzle-orm';
import { nanoid } from 'nanoid';
import { DatabaseService } from '../../database/database.service';
import { blogCategories, blogPosts, blogSettings } from '../../database/schema';
import { STORAGE_ADAPTER } from '../../common/storage/storage.provider';
import { buildAssetUrl } from '../../common/storage/asset-url';
import type { StorageAdapter } from '../../common/storage/storage-adapter.interface';
import { resolveUniqueSlug, suggestSlug, validateSlug } from './slug';

export type BlogStatus = 'draft' | 'published';
export type PromoMode = 'inherit' | 'on' | 'off';

export interface UploadFile { buffer: Buffer; filename: string; mimetype: string }
export interface BlogCategoryView { id: number; key: string; name: string; description: string; sortOrder: number }
export interface BlogPostListItem {
  id: string; slug: string; title: string; summary: string; coverUrl: string;
  status: BlogStatus; promoMode: PromoMode;
  categoryId: number | null; categoryName: string | null; categoryKey: string | null;
  publishedAt: number | null; createdAt: number; updatedAt: number;
}
export interface BlogPostDetail extends BlogPostListItem {
  seoTitle: string; seoDescription: string; contentMd: string;
}
export interface BlogSettingsView {
  promoEnabled: boolean; blogTitle: string; blogDescription: string;
  promoOfficialTitle: string; promoOfficialBody: string;
  promoAppTitle: string; promoAppBody: string;
  promoWechatTitle: string; promoWechatBody: string; promoWechatQrUrl: string;
}
export interface PromoBlock { title: string; body: string; qrUrl?: string }
export interface PromoContent { official: PromoBlock | null; app: PromoBlock | null; wechat: PromoBlock | null }
export interface PostInput {
  title: string; slug?: string; summary?: string; seoTitle?: string; seoDescription?: string;
  contentMd?: string; categoryId?: number | null; status?: BlogStatus; promoMode?: PromoMode;
}
export interface CategoryInput { key: string; name: string; description?: string; sortOrder?: number }
export interface SettingsInput {
  promoEnabled?: boolean; blogTitle?: string; blogDescription?: string;
  promoOfficialTitle?: string; promoOfficialBody?: string;
  promoAppTitle?: string; promoAppBody?: string;
  promoWechatTitle?: string; promoWechatBody?: string;
}

const SETTINGS_ID = 1;
const DEFAULT_PAGE_SIZE = 10;
const MAX_PAGE_SIZE = 50;
const CATEGORY_KEY_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const DEFAULT_SETTINGS: BlogSettingsView = {
  promoEnabled: true, blogTitle: '如画 Lumira 博客', blogDescription: '',
  promoOfficialTitle: '', promoOfficialBody: '',
  promoAppTitle: '', promoAppBody: '',
  promoWechatTitle: '', promoWechatBody: '', promoWechatQrUrl: '',
};

function nowSec(): number { return Math.floor(Date.now() / 1000); }

/** 由上传文件名推导扩展名（无扩展名回退 jpg） */
function extOf(filename: string): string {
  const m = /\.([a-z0-9]{1,8})$/i.exec(filename || '');
  return m ? m[1].toLowerCase() : 'jpg';
}

/** 页码钳制：非正整数 / 非整数 / 越界一律收敛到合法范围（默认第 1 页），不报错 */
export function resolvePage(requested: unknown, total: number, pageSize: number): number {
  const n = Number(requested);
  const maxPage = Math.max(1, Math.ceil(total / Math.max(1, pageSize)));
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 1) return 1;
  return Math.min(n, maxPage);
}

/** 推广显示规则：on → 显示；off → 不显示；inherit → 跟随全局开关；某块文案为空则该块省略 */
export function resolvePromoContent(mode: PromoMode, settings: BlogSettingsView): PromoContent | null {
  const show = mode === 'on' ? true : mode === 'off' ? false : settings.promoEnabled;
  if (!show) return null;
  const official: PromoBlock | null = settings.promoOfficialBody.trim()
    ? { title: settings.promoOfficialTitle, body: settings.promoOfficialBody }
    : null;
  const app: PromoBlock | null = settings.promoAppBody.trim()
    ? { title: settings.promoAppTitle, body: settings.promoAppBody }
    : null;
  const wechat: PromoBlock | null = settings.promoWechatBody.trim()
    ? { title: settings.promoWechatTitle, body: settings.promoWechatBody, qrUrl: settings.promoWechatQrUrl || undefined }
    : null;
  if (!official && !app && !wechat) return null;
  return { official, app, wechat };
}

type PostRow = typeof blogPosts.$inferSelect;
type CategoryRow = typeof blogCategories.$inferSelect;

function toCategoryView(row: CategoryRow): BlogCategoryView {
  return { id: row.id, key: row.key, name: row.name, description: row.description, sortOrder: row.sortOrder };
}

function toListItem(row: PostRow, categoryName: string | null, categoryKey: string | null): BlogPostListItem {
  return {
    id: row.id, slug: row.slug, title: row.title, summary: row.summary,
    coverUrl: buildAssetUrl(row.coverUrl),
    status: row.status as BlogStatus, promoMode: row.promoMode as PromoMode,
    categoryId: row.categoryId, categoryName, categoryKey,
    publishedAt: row.publishedAt, createdAt: row.createdAt, updatedAt: row.updatedAt,
  };
}

function toDetail(row: PostRow, categoryName: string | null, categoryKey: string | null): BlogPostDetail {
  return {
    ...toListItem(row, categoryName, categoryKey),
    seoTitle: row.seoTitle, seoDescription: row.seoDescription, contentMd: row.contentMd,
  };
}

function toSettingsView(row: typeof blogSettings.$inferSelect): BlogSettingsView {
  return {
    promoEnabled: row.promoEnabled === 1,
    blogTitle: row.blogTitle, blogDescription: row.blogDescription,
    promoOfficialTitle: row.promoOfficialTitle, promoOfficialBody: row.promoOfficialBody,
    promoAppTitle: row.promoAppTitle, promoAppBody: row.promoAppBody,
    promoWechatTitle: row.promoWechatTitle, promoWechatBody: row.promoWechatBody,
    promoWechatQrUrl: row.promoWechatQrUrl,
  };
}

@Injectable()
export class BlogService {
  constructor(
    private readonly dbService: DatabaseService,
    @Inject(STORAGE_ADAPTER) private readonly storage: StorageAdapter,
  ) {}

  private get db() { return this.dbService.getDb(); }

  // ===== 分类 =====

  async listCategories(): Promise<BlogCategoryView[]> {
    const rows = await this.db.select().from(blogCategories)
      .orderBy(asc(blogCategories.sortOrder), asc(blogCategories.id));
    return rows.map(toCategoryView);
  }

  async getCategoryByKey(key: string): Promise<BlogCategoryView | null> {
    const rows = await this.db.select().from(blogCategories)
      .where(eq(blogCategories.key, key)).limit(1);
    return rows[0] ? toCategoryView(rows[0]) : null;
  }

  async createCategory(input: CategoryInput): Promise<BlogCategoryView> {
    const key = (input.key || '').trim();
    const name = (input.name || '').trim();
    if (!name) throw new BadRequestException('分类名称不能为空');
    if (!CATEGORY_KEY_RE.test(key)) {
      throw new BadRequestException('分类 key 只能包含小写字母、数字与连字符（-）');
    }
    const dup = await this.db.select({ id: blogCategories.id }).from(blogCategories)
      .where(eq(blogCategories.key, key)).limit(1);
    if (dup.length) throw new ConflictException(`分类 key "${key}" 已存在`);

    const now = nowSec();
    await this.db.insert(blogCategories).values({
      key, name, description: input.description ?? '', sortOrder: input.sortOrder ?? 0,
      createdAt: now, updatedAt: now,
    });
    return (await this.getCategoryByKey(key))!;
  }

  /** key 为公开链接标识，创建后不可修改；仅允许改名称 / 描述 / 排序 */
  async updateCategory(id: number, input: Omit<CategoryInput, 'key'>): Promise<BlogCategoryView> {
    const rows = await this.db.select().from(blogCategories).where(eq(blogCategories.id, id)).limit(1);
    if (!rows[0]) throw new NotFoundException('分类不存在');
    const name = (input.name ?? '').trim();
    if (!name) throw new BadRequestException('分类名称不能为空');
    await this.db.update(blogCategories).set({
      name,
      description: input.description ?? rows[0].description,
      sortOrder: input.sortOrder ?? rows[0].sortOrder,
      updatedAt: nowSec(),
    }).where(eq(blogCategories.id, id));
    return toCategoryView({ ...rows[0], name, description: input.description ?? rows[0].description, sortOrder: input.sortOrder ?? rows[0].sortOrder });
  }

  /** 删除分类：先解除文章归属（置 null），再删分类 */
  async deleteCategory(id: number): Promise<void> {
    const rows = await this.db.select({ id: blogCategories.id }).from(blogCategories)
      .where(eq(blogCategories.id, id)).limit(1);
    if (!rows[0]) throw new NotFoundException('分类不存在');
    await this.db.update(blogPosts).set({ categoryId: null, updatedAt: nowSec() })
      .where(eq(blogPosts.categoryId, id));
    await this.db.delete(blogCategories).where(eq(blogCategories.id, id));
  }

  // ===== 设置 =====

  async getSettings(): Promise<BlogSettingsView> {
    const rows = await this.db.select().from(blogSettings).where(eq(blogSettings.id, SETTINGS_ID)).limit(1);
    return rows[0] ? toSettingsView(rows[0]) : { ...DEFAULT_SETTINGS };
  }

  async updateSettings(input: SettingsInput, qr?: UploadFile): Promise<BlogSettingsView> {
    const current = await this.getSettings();
    let promoWechatQrUrl = current.promoWechatQrUrl;
    if (qr) {
      promoWechatQrUrl = await this.storage.write('blog', 'settings', `wechat-qr.${extOf(qr.filename)}`, qr.buffer);
    }
    const next: BlogSettingsView = {
      promoEnabled: input.promoEnabled ?? current.promoEnabled,
      blogTitle: input.blogTitle ?? current.blogTitle,
      blogDescription: input.blogDescription ?? current.blogDescription,
      promoOfficialTitle: input.promoOfficialTitle ?? current.promoOfficialTitle,
      promoOfficialBody: input.promoOfficialBody ?? current.promoOfficialBody,
      promoAppTitle: input.promoAppTitle ?? current.promoAppTitle,
      promoAppBody: input.promoAppBody ?? current.promoAppBody,
      promoWechatTitle: input.promoWechatTitle ?? current.promoWechatTitle,
      promoWechatBody: input.promoWechatBody ?? current.promoWechatBody,
      promoWechatQrUrl,
    };
    await this.db.insert(blogSettings).values({
      id: SETTINGS_ID,
      promoEnabled: next.promoEnabled ? 1 : 0,
      blogTitle: next.blogTitle, blogDescription: next.blogDescription,
      promoOfficialTitle: next.promoOfficialTitle, promoOfficialBody: next.promoOfficialBody,
      promoAppTitle: next.promoAppTitle, promoAppBody: next.promoAppBody,
      promoWechatTitle: next.promoWechatTitle, promoWechatBody: next.promoWechatBody,
      promoWechatQrUrl: next.promoWechatQrUrl,
      updatedAt: nowSec(),
    }).onDuplicateKeyUpdate({
      set: {
        promoEnabled: next.promoEnabled ? 1 : 0,
        blogTitle: next.blogTitle, blogDescription: next.blogDescription,
        promoOfficialTitle: next.promoOfficialTitle, promoOfficialBody: next.promoOfficialBody,
        promoAppTitle: next.promoAppTitle, promoAppBody: next.promoAppBody,
        promoWechatTitle: next.promoWechatTitle, promoWechatBody: next.promoWechatBody,
        promoWechatQrUrl: next.promoWechatQrUrl,
        updatedAt: nowSec(),
      },
    });
    return next;
  }

  // ===== 文章（Admin）=====

  async listPosts(query: {
    status?: string; categoryId?: number; keyword?: string; page?: number; pageSize?: number;
  }): Promise<{ items: BlogPostListItem[]; total: number; page: number; pageSize: number }> {
    const pageSize = query.pageSize && query.pageSize > 0
      ? Math.min(query.pageSize, MAX_PAGE_SIZE)
      : DEFAULT_PAGE_SIZE;
    const conds: SQL[] = [];
    if (query.status && query.status !== 'all') conds.push(eq(blogPosts.status, query.status));
    if (query.categoryId) conds.push(eq(blogPosts.categoryId, query.categoryId));
    const kw = (query.keyword || '').trim();
    if (kw) {
      const pattern = `%${kw}%`;
      const likeCond = or(like(blogPosts.title, pattern), like(blogPosts.slug, pattern));
      if (likeCond) conds.push(likeCond);
    }
    const where = conds.length ? and(...conds) : undefined;

    const countRows = await this.db.select({ count: sql<number>`count(*)` })
      .from(blogPosts).where(where);
    const total = Number(countRows[0]?.count || 0);
    const page = resolvePage(query.page, total, pageSize);

    const rows = await this.db
      .select({ post: blogPosts, categoryName: blogCategories.name, categoryKey: blogCategories.key })
      .from(blogPosts)
      .leftJoin(blogCategories, eq(blogPosts.categoryId, blogCategories.id))
      .where(where)
      .orderBy(desc(blogPosts.updatedAt))
      .limit(pageSize)
      .offset((page - 1) * pageSize);

    return { items: rows.map((r) => toListItem(r.post, r.categoryName ?? null, r.categoryKey ?? null)), total, page, pageSize };
  }

  async getPost(id: string): Promise<BlogPostDetail | null> {
    const rows = await this.db
      .select({ post: blogPosts, categoryName: blogCategories.name, categoryKey: blogCategories.key })
      .from(blogPosts)
      .leftJoin(blogCategories, eq(blogPosts.categoryId, blogCategories.id))
      .where(eq(blogPosts.id, id)).limit(1);
    return rows[0] ? toDetail(rows[0].post, rows[0].categoryName ?? null, rows[0].categoryKey ?? null) : null;
  }

  private async slugTaken(slug: string, exceptId?: string): Promise<boolean> {
    const conds: SQL[] = [eq(blogPosts.slug, slug)];
    if (exceptId) conds.push(ne(blogPosts.id, exceptId));
    const rows = await this.db.select({ id: blogPosts.id }).from(blogPosts)
      .where(and(...conds)).limit(1);
    return rows.length > 0;
  }

  private validatePublishable(input: PostInput): { title: string; contentMd: string } {
    const title = (input.title || '').trim();
    if (!title) throw new BadRequestException('标题不能为空');
    const contentMd = input.contentMd ?? '';
    if (!contentMd.trim()) throw new BadRequestException('正文不能为空');
    return { title, contentMd };
  }

  async createPost(input: PostInput, cover?: UploadFile): Promise<BlogPostDetail> {
    const { title, contentMd } = this.validatePublishable(input);
    const status: BlogStatus = input.status === 'published' ? 'published' : 'draft';

    // 手填 slug：格式非法 400；与既有冲突 409（不自动改写成 -2）
    // 未填 / AI 建议：由标题派生 + 冲突自动追加 -2 / -3
    let slug: string;
    const manual = (input.slug || '').trim();
    if (manual) {
      const v = validateSlug(manual);
      if (!v.ok) throw new BadRequestException(v.reason);
      if (await this.slugTaken(manual)) throw new ConflictException(`slug "${manual}" 已被其它文章占用`);
      slug = manual;
    } else {
      slug = await resolveUniqueSlug(suggestSlug(title), (c) => this.slugTaken(c));
    }

    const id = nanoid();
    const now = nowSec();
    let coverUrl = '';
    if (cover) coverUrl = await this.storage.write('blog', id, `cover.${extOf(cover.filename)}`, cover.buffer);

    await this.db.insert(blogPosts).values({
      id, slug, title,
      summary: input.summary ?? '', seoTitle: input.seoTitle ?? '', seoDescription: input.seoDescription ?? '',
      coverUrl, contentMd,
      categoryId: input.categoryId ?? null,
      status, promoMode: input.promoMode ?? 'inherit',
      publishedAt: status === 'published' ? now : null,
      createdAt: now, updatedAt: now,
    });
    return (await this.getPost(id))!;
  }

  async updatePost(id: string, input: PostInput, cover?: UploadFile): Promise<BlogPostDetail> {
    const rows = await this.db.select().from(blogPosts).where(eq(blogPosts.id, id)).limit(1);
    const existing = rows[0];
    if (!existing) throw new NotFoundException('文章不存在');
    const { title, contentMd } = this.validatePublishable(input);

    let slug = existing.slug;
    const manual = (input.slug || '').trim();
    if (manual && manual !== existing.slug) {
      const v = validateSlug(manual);
      if (!v.ok) throw new BadRequestException(v.reason);
      if (await this.slugTaken(manual, id)) throw new ConflictException(`slug "${manual}" 已被其它文章占用`);
      slug = manual;
    }

    const status: BlogStatus = input.status === 'published' ? 'published'
      : input.status === 'draft' ? 'draft' : (existing.status as BlogStatus);
    // 首次发布写入 published_at；取消发布置空
    let publishedAt = existing.publishedAt;
    if (status === 'published' && publishedAt == null) publishedAt = nowSec();
    if (status === 'draft') publishedAt = null;

    let coverUrl = existing.coverUrl;
    if (cover) coverUrl = await this.storage.write('blog', id, `cover.${extOf(cover.filename)}`, cover.buffer);

    await this.db.update(blogPosts).set({
      slug, title,
      summary: input.summary ?? existing.summary,
      seoTitle: input.seoTitle ?? existing.seoTitle,
      seoDescription: input.seoDescription ?? existing.seoDescription,
      coverUrl, contentMd,
      categoryId: input.categoryId === undefined ? existing.categoryId : input.categoryId,
      status, promoMode: input.promoMode ?? (existing.promoMode as PromoMode),
      publishedAt, updatedAt: nowSec(),
    }).where(eq(blogPosts.id, id));
    return (await this.getPost(id))!;
  }

  async updatePostStatus(id: string, status: BlogStatus): Promise<BlogPostListItem> {
    const rows = await this.db.select().from(blogPosts).where(eq(blogPosts.id, id)).limit(1);
    const existing = rows[0];
    if (!existing) throw new NotFoundException('文章不存在');
    const publishedAt = status === 'published'
      ? (existing.publishedAt ?? nowSec())
      : null;
    await this.db.update(blogPosts).set({ status, publishedAt, updatedAt: nowSec() })
      .where(eq(blogPosts.id, id));
    const detail = await this.getPost(id);
    return detail!;
  }

  async deletePost(id: string): Promise<void> {
    const rows = await this.db.select({ id: blogPosts.id }).from(blogPosts).where(eq(blogPosts.id, id)).limit(1);
    if (!rows[0]) throw new NotFoundException('文章不存在');
    await this.db.delete(blogPosts).where(eq(blogPosts.id, id));
    try {
      // 清理该文章目录（封面 + 该文章目录下的正文插图）
      await this.storage.deleteByDir('blog', id);
    } catch {
      // 存储清理失败不影响删除结果（残留文件由后续优化项统一清理）
    }
  }

  /** 正文插图上传：有 postId 落 blog/{postId}/，否则落 blog/drafts/ */
  async uploadImage(file: UploadFile, postId?: string): Promise<{ storageKey: string; url: string }> {
    const dirId = postId && /^[A-Za-z0-9_-]{1,64}$/.test(postId) ? postId : 'drafts';
    const storageKey = await this.storage.write('blog', dirId, `${nanoid(10)}.${extOf(file.filename)}`, file.buffer);
    return { storageKey, url: buildAssetUrl(storageKey) };
  }

  // ===== 公开只读 =====

  async getPublishedBySlug(slug: string): Promise<BlogPostDetail | null> {
    const rows = await this.db
      .select({ post: blogPosts, categoryName: blogCategories.name, categoryKey: blogCategories.key })
      .from(blogPosts)
      .leftJoin(blogCategories, eq(blogPosts.categoryId, blogCategories.id))
      .where(and(eq(blogPosts.slug, slug), eq(blogPosts.status, 'published')))
      .limit(1);
    return rows[0] ? toDetail(rows[0].post, rows[0].categoryName ?? null, rows[0].categoryKey ?? null) : null;
  }

  async listPublishedPosts(opts: { page?: number; categoryKey?: string }): Promise<{
    items: BlogPostListItem[]; total: number; page: number; pageSize: number; category: BlogCategoryView | null;
  }> {
    const pageSize = DEFAULT_PAGE_SIZE;
    let category: BlogCategoryView | null = null;
    const conds: SQL[] = [eq(blogPosts.status, 'published')];
    if (opts.categoryKey) {
      category = await this.getCategoryByKey(opts.categoryKey);
      if (!category) {
        return { items: [], total: 0, page: 1, pageSize, category: null };
      }
      conds.push(eq(blogPosts.categoryId, category.id));
    }
    const where = and(...conds);

    const countRows = await this.db.select({ count: sql<number>`count(*)` }).from(blogPosts).where(where);
    const total = Number(countRows[0]?.count || 0);
    const page = resolvePage(opts.page, total, pageSize);

    const rows = await this.db
      .select({ post: blogPosts, categoryName: blogCategories.name, categoryKey: blogCategories.key })
      .from(blogPosts)
      .leftJoin(blogCategories, eq(blogPosts.categoryId, blogCategories.id))
      .where(where)
      .orderBy(desc(blogPosts.publishedAt), desc(blogPosts.createdAt))
      .limit(pageSize)
      .offset((page - 1) * pageSize);

    return { items: rows.map((r) => toListItem(r.post, r.categoryName ?? null, r.categoryKey ?? null)), total, page, pageSize, category };
  }

  async listPublishedForSitemap(): Promise<{ slug: string; updatedAt: number }[]> {
    const rows = await this.db
      .select({ slug: blogPosts.slug, updatedAt: blogPosts.updatedAt })
      .from(blogPosts)
      .where(eq(blogPosts.status, 'published'))
      .orderBy(desc(blogPosts.publishedAt));
    return rows;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- blog.service.spec`
Expected: PASS（11 个用例）

- [ ] **Step 5: 类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 退出码 0。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/blog.service.ts lumira-server/packages/backend/src/modules/blog/blog.service.spec.ts
git commit -m "feat(backend): 博客数据层 BlogService（分类/设置/文章/公开只读/推广解析）"
git push origin master
git push github master
```

---

## Task 5: Admin API（DTO + multipart + 控制器 + 模块装配）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/dto/upsert-post.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/dto/list-posts.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/dto/update-status.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/dto/category.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/dto/settings.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/dto/ai-generate.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/multipart.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/admin-blog.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/blog.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts:25,31`

**Interfaces:**
- Consumes: `BlogService` / `UploadFile` / `PostInput` / `CategoryInput` / `SettingsInput`（Task 4）、`AiBlogService.generate(dto)`（Task 6，本 Task 先按签名接线，Task 6 实现）
- Produces:
  - `AdminBlogController`（`@Controller('admin/blog')`，全部端点）
  - `BlogModule`（导出 `BlogService`，供 `main.ts` 取用）
  - `parseBlogMultipart(req): Promise<{ meta: string | null; postId: string | null; cover?: UploadFile; file?: UploadFile; qr?: UploadFile }>`

- [ ] **Step 1: 写 DTO**

新建 `lumira-server/packages/backend/src/modules/blog/dto/upsert-post.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/upsert-post.dto.ts
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, ValidateIf } from 'class-validator';

export class UpsertPostDto {
  @IsString() @IsNotEmpty() @MaxLength(200) title!: string;
  @IsOptional() @IsString() @MaxLength(200) slug?: string;
  @IsOptional() @IsString() @MaxLength(300) summary?: string;
  @IsOptional() @IsString() @MaxLength(200) seoTitle?: string;
  @IsOptional() @IsString() @MaxLength(300) seoDescription?: string;
  @IsOptional() @IsString() contentMd?: string;
  @IsOptional() @ValidateIf((_o, v) => v !== null) @Type(() => Number) @IsInt() categoryId?: number | null;
  @IsOptional() @IsIn(['draft', 'published']) status?: 'draft' | 'published';
  @IsOptional() @IsIn(['inherit', 'on', 'off']) promoMode?: 'inherit' | 'on' | 'off';
}
```

新建 `lumira-server/packages/backend/src/modules/blog/dto/list-posts.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/list-posts.dto.ts
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString } from 'class-validator';

export class ListPostsQueryDto {
  @IsOptional() @IsIn(['all', 'draft', 'published']) status?: 'all' | 'draft' | 'published';
  @IsOptional() @Type(() => Number) @IsInt() categoryId?: number;
  @IsOptional() @IsString() keyword?: string;
  @IsOptional() @Type(() => Number) @IsInt() page?: number;
  @IsOptional() @Type(() => Number) @IsInt() pageSize?: number;
}
```

新建 `lumira-server/packages/backend/src/modules/blog/dto/update-status.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/update-status.dto.ts
import { IsIn } from 'class-validator';

export class UpdateStatusDto {
  @IsIn(['draft', 'published']) status!: 'draft' | 'published';
}
```

新建 `lumira-server/packages/backend/src/modules/blog/dto/category.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/category.dto.ts
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateCategoryDto {
  @IsString() @IsNotEmpty() @MaxLength(64) key!: string;
  @IsString() @IsNotEmpty() @MaxLength(100) name!: string;
  @IsOptional() @IsString() @MaxLength(300) description?: string;
  @IsOptional() @Type(() => Number) @IsInt() sortOrder?: number;
}

export class UpdateCategoryDto {
  @IsString() @IsNotEmpty() @MaxLength(100) name!: string;
  @IsOptional() @IsString() @MaxLength(300) description?: string;
  @IsOptional() @Type(() => Number) @IsInt() sortOrder?: number;
}
```

新建 `lumira-server/packages/backend/src/modules/blog/dto/settings.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/settings.dto.ts
import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional() @IsBoolean() promoEnabled?: boolean;
  @IsOptional() @IsString() @MaxLength(200) blogTitle?: string;
  @IsOptional() @IsString() @MaxLength(300) blogDescription?: string;
  @IsOptional() @IsString() @MaxLength(200) promoOfficialTitle?: string;
  @IsOptional() @IsString() @MaxLength(500) promoOfficialBody?: string;
  @IsOptional() @IsString() @MaxLength(200) promoAppTitle?: string;
  @IsOptional() @IsString() @MaxLength(500) promoAppBody?: string;
  @IsOptional() @IsString() @MaxLength(200) promoWechatTitle?: string;
  @IsOptional() @IsString() @MaxLength(500) promoWechatBody?: string;
}
```

新建 `lumira-server/packages/backend/src/modules/blog/dto/ai-generate.dto.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/dto/ai-generate.dto.ts
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class AiGenerateDto {
  @IsString() @IsNotEmpty() @MaxLength(200) topic!: string;
  @IsOptional() @IsString() @MaxLength(1000) requirements?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(200) @Max(3000) wordCount?: number;
  @IsOptional() @Type(() => Number) @IsInt() categoryId?: number;
}
```

- [ ] **Step 2: 写 multipart 解析器**

新建 `lumira-server/packages/backend/src/modules/blog/multipart.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/multipart.ts
// 博客 multipart 解析：文本字段 meta / postId + 文件字段 cover / file / qr。
import { BadRequestException } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import type { UploadFile } from './blog.service';

export interface BlogMultipart {
  meta: string | null;
  postId: string | null;
  cover?: UploadFile;
  file?: UploadFile;
  qr?: UploadFile;
}

export async function parseBlogMultipart(req: FastifyRequest): Promise<BlogMultipart> {
  const result: BlogMultipart = { meta: null, postId: null };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const reqAny = req as any;
  if (typeof reqAny.parts !== 'function') {
    throw new BadRequestException('Multipart not enabled on this request');
  }

  for await (const part of reqAny.parts()) {
    if (part.type === 'field') {
      if (part.fieldname === 'meta') result.meta = part.value as string;
      else if (part.fieldname === 'postId') result.postId = String(part.value ?? '');
    } else if (part.type === 'file') {
      const file: UploadFile = {
        buffer: await part.toBuffer(),
        filename: part.filename || '',
        mimetype: part.mimetype || '',
      };
      if (part.fieldname === 'cover') result.cover = file;
      else if (part.fieldname === 'file') result.file = file;
      else if (part.fieldname === 'qr') result.qr = file;
    }
  }
  return result;
}
```

- [ ] **Step 3: 写控制器**

新建 `lumira-server/packages/backend/src/modules/blog/admin-blog.controller.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/admin-blog.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import type { ValidationError } from 'class-validator';
import type { FastifyRequest } from 'fastify';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { BlogService, resolvePromoContent } from './blog.service';
import { AiBlogService } from './ai-blog.service';
import { renderPostPage } from './public/post-page';
import { parseBlogMultipart } from './multipart';
import { UpsertPostDto } from './dto/upsert-post.dto';
import { ListPostsQueryDto } from './dto/list-posts.dto';
import { UpdateStatusDto } from './dto/update-status.dto';
import { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto';
import { UpdateSettingsDto } from './dto/settings.dto';
import { AiGenerateDto } from './dto/ai-generate.dto';

function formatErrors(errors: ValidationError[]): string {
  const messages: string[] = [];
  const walk = (list: ValidationError[], parent = '') => {
    for (const err of list) {
      const path = parent ? `${parent}.${err.property}` : err.property;
      if (err.constraints) messages.push(...Object.values(err.constraints).map((m) => `${path}: ${m}`));
      if (err.children?.length) walk(err.children, path);
    }
  };
  walk(errors);
  return messages.join('; ') || '参数校验失败';
}

/** multipart 的 meta JSON → DTO 并做 class-validator 校验 */
async function parseMetaDto<T extends object>(cls: new () => T, meta: string | null): Promise<T> {
  if (!meta) throw new BadRequestException('缺少 meta 字段');
  let raw: unknown;
  try {
    raw = JSON.parse(meta);
  } catch {
    throw new BadRequestException('meta 不是合法 JSON');
  }
  const dto = plainToInstance(cls, raw as object);
  const errors = await validate(dto, { whitelist: true });
  if (errors.length) throw new BadRequestException(formatErrors(errors));
  return dto;
}

@Controller('admin/blog')
@UseGuards(AdminAuthGuard)
export class AdminBlogController {
  constructor(
    private readonly blog: BlogService,
    private readonly ai: AiBlogService,
  ) {}

  // ===== 文章 =====

  @Get('posts')
  listPosts(@Query() query: ListPostsQueryDto) {
    return this.blog.listPosts(query);
  }

  @Get('posts/:id')
  async getPost(@Param('id') id: string) {
    const post = await this.blog.getPost(id);
    if (!post) throw new NotFoundException('文章不存在');
    return post;
  }

  @Post('posts')
  async createPost(@Req() req: FastifyRequest) {
    const parsed = await parseBlogMultipart(req);
    const dto = await parseMetaDto(UpsertPostDto, parsed.meta);
    return this.blog.createPost(dto, parsed.cover);
  }

  @Patch('posts/:id')
  async updatePost(@Param('id') id: string, @Req() req: FastifyRequest) {
    const parsed = await parseBlogMultipart(req);
    const dto = await parseMetaDto(UpsertPostDto, parsed.meta);
    return this.blog.updatePost(id, dto, parsed.cover);
  }

  @Patch('posts/:id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateStatusDto) {
    return this.blog.updatePostStatus(id, dto.status);
  }

  @Delete('posts/:id')
  async deletePost(@Param('id') id: string) {
    await this.blog.deletePost(id);
    return { success: true };
  }

  /** 后台 iframe srcDoc 预览：返回完整文章页 HTML（草稿也可预览，仅受 AdminAuthGuard 保护） */
  @Get('posts/:id/preview-html')
  async previewHtml(@Param('id') id: string) {
    const post = await this.blog.getPost(id);
    if (!post) throw new NotFoundException('文章不存在');
    const settings = await this.blog.getSettings();
    const promo = resolvePromoContent(post.promoMode, settings);
    const html = renderPostPage({ post, promo, settings, preview: true });
    return { html };
  }

  // ===== 分类 =====

  @Get('categories')
  listCategories() {
    return this.blog.listCategories();
  }

  @Post('categories')
  createCategory(@Body() dto: CreateCategoryDto) {
    return this.blog.createCategory(dto);
  }

  @Patch('categories/:id')
  updateCategory(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateCategoryDto) {
    return this.blog.updateCategory(id, dto);
  }

  @Delete('categories/:id')
  async deleteCategory(@Param('id', ParseIntPipe) id: number) {
    await this.blog.deleteCategory(id);
    return { success: true };
  }

  // ===== 设置 =====

  @Get('settings')
  getSettings() {
    return this.blog.getSettings();
  }

  @Patch('settings')
  async updateSettings(@Req() req: FastifyRequest) {
    const parsed = await parseBlogMultipart(req);
    const dto = await parseMetaDto(UpdateSettingsDto, parsed.meta);
    return this.blog.updateSettings(dto, parsed.qr);
  }

  // ===== 图片 / AI =====

  @Post('uploads')
  async upload(@Req() req: FastifyRequest) {
    const parsed = await parseBlogMultipart(req);
    if (!parsed.file || parsed.file.buffer.length === 0) {
      throw new BadRequestException('缺少 file 字段');
    }
    return this.blog.uploadImage(parsed.file, parsed.postId || undefined);
  }

  @Post('ai/generate')
  generate(@Body() dto: AiGenerateDto) {
    return this.ai.generate(dto);
  }
}
```

**说明**：`previewHtml` 复用 Task 7 的 `renderPostPage`，草稿也能预览（该端点受 `AdminAuthGuard` 保护，公开站**不提供**任何预览路由）。

- [ ] **Step 4: 写模块装配并注册进 AppModule**

新建 `lumira-server/packages/backend/src/modules/blog/blog.module.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/blog.module.ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { AdminBlogController } from './admin-blog.controller';
import { BlogService } from './blog.service';
import { AiBlogService } from './ai-blog.service';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [DatabaseModule, AiModule],
  controllers: [AdminBlogController],
  providers: [BlogService, AiBlogService],
  exports: [BlogService],
})
export class BlogModule {}
```

在 `lumira-server/packages/backend/src/app.module.ts` 中：
1. 第 25 行 `import { StorageMigrationModule } from './modules/storage-migration/storage-migration.module';` 之后追加：

```ts
import { BlogModule } from './modules/blog/blog.module';
```

2. 第 31 行 `imports: [...]` 数组末尾（`StorageMigrationModule` 之后）追加 `BlogModule`：

```ts
  imports: [RedisModule, StorageModule, DatabaseModule, DeviceModule, ProfileModule, InviteModule, RedeemModule, RewardsModule, AdminModule, WeatherModule, QuestionnaireModule, TemplatesModule, UsageModule, ScenesModule, SignInModule, FeedbackModule, AccountModule, NotificationsModule, BannersModule, AiModule, StorageMigrationModule, BlogModule],
```

**前置核对**：打开 `lumira-server/packages/backend/src/modules/ai/ai.module.ts`，确认它 `exports` 了 `AiConfigService`（Task 6 的 `AiBlogService` 需要注入它）。若未导出，则在该模块的 `exports` 数组末尾补上 `AiConfigService`。

- [ ] **Step 5: 编译验证**

Run: `pnpm --filter @lumira/backend build`
Expected: 退出码 0。若报 `Cannot find module './ai-blog.service'` 或 `'./public/post-page'`，说明 Task 6 / Task 7 尚未执行——这两个文件在本 Task 中只做「按签名接线」，实现放在 Task 6 / 7；若希望本 Task 独立编译通过，可先在 Task 6 / 7 完成后统一回跑本步（推荐执行顺序仍是 5 → 6 → 7 → 8，最后回到本步补验）。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/dto lumira-server/packages/backend/src/modules/blog/multipart.ts lumira-server/packages/backend/src/modules/blog/admin-blog.controller.ts lumira-server/packages/backend/src/modules/blog/blog.module.ts lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): 博客 Admin API 控制器、DTO 与模块装配"
git push origin master
git push github master
```

---

## Task 6: AI 生成博客

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/ai-blog.service.ts`
- Test: `lumira-server/packages/backend/src/modules/blog/ai-blog.service.spec.ts`

**Interfaces:**
- Consumes: `AiConfigService.getActiveConfig()`（现有，`modules/ai/ai-config.service.ts`）、`textChat(cfg, input)`（现有，`modules/ai/llm-client.ts`）、`BlogService.getSettings()` / `BlogService.listCategories()`（Task 4）、`validateSlug` / `suggestSlug`（Task 2）
- Produces:
  - `interface AiBlogDraft { title: string; slugSuggestion: string; summary: string; seoDescription: string; contentMd: string; categoryKey: string }`
  - `interface AiBlogGenerateInput { topic: string; requirements?: string; wordCount?: number; categoryId?: number }`
  - `class AiBlogService { generate(input: AiBlogGenerateInput): Promise<AiBlogDraft> }`
  - `function parseAiBlogJson(raw: string): AiBlogDraft`（纯函数，可单测）

- [ ] **Step 1: 写失败测试**

新建 `lumira-server/packages/backend/src/modules/blog/ai-blog.service.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/ai-blog.service.spec.ts
import { parseAiBlogJson } from './ai-blog.service';

describe('parseAiBlogJson', () => {
  it('解析纯净 JSON', () => {
    const raw = JSON.stringify({
      title: '逆光人像怎么拍',
      slugSuggestion: 'backlight-portrait',
      summary: '三招拍好逆光人像。',
      seoDescription: '逆光人像总拍不好？本文用三个可复制的步骤讲清楚测光、补光与后期思路。',
      contentMd: '## 测光\n\n先对人脸测光。',
      categoryKey: 'shooting-tips',
    });
    const draft = parseAiBlogJson(raw);
    expect(draft.title).toBe('逆光人像怎么拍');
    expect(draft.slugSuggestion).toBe('backlight-portrait');
    expect(draft.categoryKey).toBe('shooting-tips');
  });

  it('剥离 ```json 代码围栏', () => {
    const raw = '```json\n{"title":"标题","summary":"","seoDescription":"","contentMd":"## 段落","slugSuggestion":"a-b","categoryKey":""}\n```';
    expect(parseAiBlogJson(raw).title).toBe('标题');
  });

  it('slug 非法时回退由标题派生（纯中文标题 → post-<6位>）', () => {
    const raw = JSON.stringify({
      title: '夏日人像拍摄技巧', slugSuggestion: 'Bad_Slug', summary: '', seoDescription: '', contentMd: '## x', categoryKey: '',
    });
    expect(parseAiBlogJson(raw).slugSuggestion).toMatch(/^post-[0-9a-z]{6}$/);
  });

  it('非法 JSON 抛错', () => {
    expect(() => parseAiBlogJson('这不是 JSON')).toThrow();
  });

  it('缺少标题抛错', () => {
    const raw = JSON.stringify({ title: '', contentMd: '## x' });
    expect(() => parseAiBlogJson(raw)).toThrow();
  });

  it('缺少正文抛错', () => {
    const raw = JSON.stringify({ title: '标题', contentMd: '' });
    expect(() => parseAiBlogJson(raw)).toThrow();
  });

  it('数组结构抛错', () => {
    expect(() => parseAiBlogJson('[1,2,3]')).toThrow();
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- ai-blog.service.spec`
Expected: FAIL —— `Cannot find module './ai-blog.service'`

- [ ] **Step 3: 实现 ai-blog.service.ts**

新建 `lumira-server/packages/backend/src/modules/blog/ai-blog.service.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/ai-blog.service.ts
// AI 生成博客草稿：复用 ai_provider_config 的文本模型，产出结构化 JSON 回填后台表单（不落库）。
import { BadGatewayException, Injectable } from '@nestjs/common';
import { AiConfigService } from '../ai/ai-config.service';
import { textChat } from '../ai/llm-client';
import { BlogService } from './blog.service';
import type { BlogCategoryView } from './blog.service';
import { suggestSlug, validateSlug } from './slug';

const AI_TIMEOUT_MS = 300_000;
const AI_MAX_TOKENS = 4096;
const DEFAULT_WORD_COUNT = 800;

export interface AiBlogDraft {
  title: string;
  slugSuggestion: string;
  summary: string;
  seoDescription: string;
  contentMd: string;
  categoryKey: string;
}

export interface AiBlogGenerateInput {
  topic: string;
  requirements?: string;
  wordCount?: number;
  categoryId?: number;
}

/** 解析模型返回的 JSON：剥离代码围栏、校验必填、slug 非法时回退派生 */
export function parseAiBlogJson(raw: string): AiBlogDraft {
  const cleaned = (raw || '')
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```\s*$/, '')
    .trim();

  let obj: unknown;
  try {
    obj = JSON.parse(cleaned);
  } catch {
    throw new BadGatewayException('AI 返回内容不是合法 JSON，请重试');
  }
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
    throw new BadGatewayException('AI 返回结构不符合预期，请重试');
  }

  const rec = obj as Record<string, unknown>;
  const title = String(rec.title ?? '').trim();
  const contentMd = String(rec.contentMd ?? rec.content ?? '').trim();
  if (!title) throw new BadGatewayException('AI 未返回标题，请重试');
  if (!contentMd) throw new BadGatewayException('AI 未返回正文，请重试');

  const slugRaw = String(rec.slugSuggestion ?? '').trim();
  const slugSuggestion = slugRaw && validateSlug(slugRaw).ok ? slugRaw : suggestSlug(title);

  return {
    title,
    slugSuggestion,
    summary: String(rec.summary ?? '').trim(),
    seoDescription: String(rec.seoDescription ?? '').trim(),
    contentMd,
    categoryKey: String(rec.categoryKey ?? '').trim(),
  };
}

@Injectable()
export class AiBlogService {
  constructor(
    private readonly config: AiConfigService,
    private readonly blog: BlogService,
  ) {}

  private buildSystemPrompt(officialIntro: string, categories: BlogCategoryView[]): string {
    const catList = categories.length
      ? categories.map((c) => `${c.key}（${c.name}）`).join('、')
      : '（暂无分类，categoryKey 一律返回空字符串）';
    return [
      '你是「如画 Lumira」品牌的资深内容编辑，负责撰写中文图文博客。',
      '',
      '【产品事实】',
      officialIntro || '如画 Lumira 是一款摄影辅助 App：挑选模板、按快门、直接出片。',
      '',
      '【硬性约束】',
      '1. 不得虚构 Lumira 不具备的功能，不得承诺未上线的能力、价格、活动或合作；不确定的信息一律不写。',
      '2. 只围绕摄影/拍照/出片方法、审美与生活方式展开，不提供医疗、投资、法律等专业建议。',
      '3. 只输出单个 JSON 对象，不要输出 Markdown 代码围栏，不要输出 JSON 以外的任何文字。',
      '',
      '【JSON 字段】',
      '- title：文章标题，≤30 字，具体有吸引力，避免“浅谈/漫谈”类空泛词。',
      '- slugSuggestion：英文小写 slug，仅含小写字母/数字/连字符，≤60 字符。',
      '- summary：一句话摘要，≤60 字，用于列表页展示。',
      '- seoDescription：SEO 描述，60~120 字，自然包含关键词，不堆砌。',
      '- contentMd：Markdown 正文，用 ## / ### 分节，每节 2~3 段；不要用代码围栏包裹全文。',
      `- categoryKey：从以下分类 key 中选一个最贴切的；都不合适则返回空字符串。可选：${catList}`,
    ].join('\n');
  }

  async generate(input: AiBlogGenerateInput): Promise<AiBlogDraft> {
    const cfg = await this.config.getActiveConfig();
    const [settings, categories] = await Promise.all([
      this.blog.getSettings(),
      this.blog.listCategories(),
    ]);
    const wordCount = input.wordCount && input.wordCount > 0 ? input.wordCount : DEFAULT_WORD_COUNT;
    const preferred = input.categoryId
      ? categories.find((c) => c.id === input.categoryId)
      : undefined;

    const userText = [
      `主题：${input.topic}`,
      input.requirements ? `补充要求：${input.requirements}` : '',
      `目标字数：约 ${wordCount} 字`,
      preferred ? `优先归入分类：${preferred.key}（${preferred.name}）` : '',
    ].filter(Boolean).join('\n');

    const raw = await textChat(
      {
        provider: cfg.text.provider,
        baseUrl: cfg.text.baseUrl,
        apiKey: cfg.text.apiKey,
        model: cfg.text.model,
      },
      {
        systemPrompt: this.buildSystemPrompt(settings.promoOfficialBody, categories),
        userText,
        jsonMode: true,
        temperature: 0.6,
        timeoutMs: AI_TIMEOUT_MS,
        maxTokens: AI_MAX_TOKENS,
      },
    );

    const draft = parseAiBlogJson(raw);
    // categoryKey 必须命中现有分类，否则清空（避免回填不存在的分类）
    if (draft.categoryKey && !categories.some((c) => c.key === draft.categoryKey)) {
      draft.categoryKey = '';
    }
    return draft;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- ai-blog.service.spec`
Expected: PASS（7 个用例）

- [ ] **Step 5: 编译验证（此时 Task 5 的控制器也应能编译通过）**

Run: `pnpm --filter @lumira/backend build`
Expected: 退出码 0。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/ai-blog.service.ts lumira-server/packages/backend/src/modules/blog/ai-blog.service.spec.ts
git commit -m "feat(backend): AI 生成博客服务（复用文本模型，JSON 契约 + 防编造约束）"
git push origin master
git push github master
```

---

## Task 7: 公开页 HTML 模板（布局 / 文章页 / 列表页）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/public/blog-layout.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/public/post-page.ts`
- Create: `lumira-server/packages/backend/src/modules/blog/public/list-page.ts`
- Test: `lumira-server/packages/backend/src/modules/blog/public/blog-layout.spec.ts`

**Interfaces:**
- Consumes: `renderMarkdown(md)`（Task 3）、`buildAssetUrl`（现有）、`BlogPostDetail` / `BlogPostListItem` / `BlogCategoryView` / `BlogSettingsView` / `PromoContent`（Task 4）
- Produces:
  - `siteBaseUrl(): string`
  - `escapeHtml(input: string): string`
  - `renderBlogLayout(o: LayoutOptions): string`
  - `renderPromoAside(promo: PromoContent | null): string`
  - `SITE_DEFAULT_OG_IMAGE: string`
  - `renderPostPage(o: { post: BlogPostDetail; promo: PromoContent | null; settings: BlogSettingsView; preview?: boolean }): string`
  - `renderListPage(o: { settings: BlogSettingsView; categories: BlogCategoryView[]; items: BlogPostListItem[]; page: number; total: number; pageSize: number; category: BlogCategoryView | null }): string`

- [ ] **Step 1: 写失败测试**

新建 `lumira-server/packages/backend/src/modules/blog/public/blog-layout.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/public/blog-layout.spec.ts
import { escapeHtml, renderPromoAside, siteBaseUrl } from './blog-layout';

describe('escapeHtml', () => {
  it('转义五个危险字符', () => {
    expect(escapeHtml(`<a href="x" onclick='y'>&</a>`))
      .toBe('&lt;a href=&quot;x&quot; onclick=&#39;y&#39;&gt;&amp;&lt;/a&gt;');
  });

  it('空值返回空串', () => {
    expect(escapeHtml('')).toBe('');
  });
});

describe('siteBaseUrl', () => {
  it('去掉结尾斜杠且不返回空串', () => {
    const base = siteBaseUrl();
    expect(base.length).toBeGreaterThan(0);
    expect(base.endsWith('/')).toBe(false);
  });
});

describe('renderPromoAside', () => {
  it('null 时返回空串', () => {
    expect(renderPromoAside(null)).toBe('');
  });

  it('渲染官方信息块并含首页链接', () => {
    const html = renderPromoAside({
      official: { title: '关于如画 Lumira', body: '官方介绍' },
      app: null,
      wechat: null,
    });
    expect(html).toContain('<aside class="blog-promo">');
    expect(html).toContain('官方介绍');
    expect(html).toContain('href="/"');
  });

  it('渲染 App 块并指向 /#download', () => {
    const html = renderPromoAside({ official: null, app: { title: '下载', body: '推广文案' }, wechat: null });
    expect(html).toContain('href="/#download"');
  });

  it('公众号块渲染二维码图片，且文案被转义', () => {
    const html = renderPromoAside({
      official: null,
      app: null,
      wechat: { title: '关注', body: '<b>关注微信公众号获取更多相关资讯</b>', qrUrl: '/uploads/blog/settings/q.png' },
    });
    expect(html).toContain('blog-promo-qr');
    expect(html).toContain('/uploads/blog/settings/q.png');
    expect(html).not.toContain('<b>关注');
  });

  it('二维码为空时公众号块不渲染 img', () => {
    const html = renderPromoAside({ official: null, app: null, wechat: { title: '关注', body: '文案' } });
    expect(html).not.toContain('blog-promo-qr');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- blog-layout.spec`
Expected: FAIL —— `Cannot find module './blog-layout'`

- [ ] **Step 3: 实现 blog-layout.ts**

新建 `lumira-server/packages/backend/src/modules/blog/public/blog-layout.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/public/blog-layout.ts
// 公开博客页的 HTML 外壳：head（SEO/OG/JSON-LD）、页头页脚、底部推广 <aside>。
// 所有来自 DB 的纯文本字段必须经 escapeHtml 转义；正文 HTML 由 renderMarkdown 负责净化。
import { buildAssetUrl } from '../../../common/storage/asset-url';
import type { PromoContent } from '../blog.service';

export const SITE_DEFAULT_OG_IMAGE = '/assets/logos/lumira/logo-lumira-symbol.svg';

export function siteBaseUrl(): string {
  return (process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000').replace(/\/+$/, '');
}

export function escapeHtml(input: string): string {
  return (input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export interface LayoutOptions {
  title: string;
  description: string;
  canonicalUrl: string;
  ogImage: string;
  ogType: 'website' | 'article';
  publishedTime?: string;
  modifiedTime?: string;
  jsonLd?: Record<string, unknown>;
  noIndex?: boolean;
  body: string;
}

/** 公共 HTML 外壳；`noIndex` 仅用于后台预览 */
export function renderBlogLayout(o: LayoutOptions): string {
  const jsonLd = o.jsonLd
    ? `<script type="application/ld+json">${JSON.stringify(o.jsonLd)}</script>`
    : '';
  const robots = o.noIndex ? '<meta name="robots" content="noindex,nofollow" />' : '';
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(o.title)}</title>
  <meta name="description" content="${escapeHtml(o.description)}" />
  <link rel="canonical" href="${escapeHtml(o.canonicalUrl)}" />
  ${robots}
  <meta property="og:type" content="${o.ogType}" />
  <meta property="og:title" content="${escapeHtml(o.title)}" />
  <meta property="og:description" content="${escapeHtml(o.description)}" />
  <meta property="og:url" content="${escapeHtml(o.canonicalUrl)}" />
  <meta property="og:image" content="${escapeHtml(o.ogImage)}" />
  <meta property="og:site_name" content="如画 Lumira" />
  ${o.publishedTime ? `<meta property="article:published_time" content="${escapeHtml(o.publishedTime)}" />` : ''}
  ${o.modifiedTime ? `<meta property="article:modified_time" content="${escapeHtml(o.modifiedTime)}" />` : ''}
  <meta name="twitter:card" content="summary_large_image" />
  <link rel="icon" href="/assets/logos/lumira/logo-lumira-symbol.svg" type="image/svg+xml" />
  <link rel="stylesheet" href="/css/style.css" />
  <link rel="stylesheet" href="/css/blog.css" />
  ${jsonLd}
</head>
<body class="blog-body">
  <header class="blog-header">
    <a class="blog-brand" href="/">
      <img src="/assets/logos/lumira/logo-lumira-symbol.svg" alt="如画 Lumira" width="28" height="28" />
      <span>如画 Lumira</span>
    </a>
    <nav class="blog-nav">
      <a href="/">首页</a>
      <a href="/blog">博客</a>
    </nav>
  </header>
  <main class="blog-main">
${o.body}
  </main>
  <footer class="blog-footer">
    <p>© ${new Date().getFullYear()} 如画 Lumira · <a href="/">返回首页</a></p>
  </footer>
</body>
</html>`;
}

/** 底部推广：三块各自可选；全空时返回空串 */
export function renderPromoAside(promo: PromoContent | null): string {
  if (!promo) return '';
  const blocks: string[] = [];

  if (promo.official) {
    blocks.push(`    <section class="blog-promo-block">
      <h3>${escapeHtml(promo.official.title || '关于如画 Lumira')}</h3>
      <p>${escapeHtml(promo.official.body)}</p>
      <p><a class="blog-promo-link" href="/">了解如画 Lumira</a></p>
    </section>`);
  }
  if (promo.app) {
    blocks.push(`    <section class="blog-promo-block">
      <h3>${escapeHtml(promo.app.title || '用如画 Lumira 拍照')}</h3>
      <p>${escapeHtml(promo.app.body)}</p>
      <p><a class="blog-promo-link" href="/#download">下载 App</a></p>
    </section>`);
  }
  if (promo.wechat) {
    const qr = promo.wechat.qrUrl
      ? `<img class="blog-promo-qr" src="${escapeHtml(buildAssetUrl(promo.wechat.qrUrl))}" alt="微信公众号二维码" loading="lazy" />`
      : '';
    blocks.push(`    <section class="blog-promo-block">
      <h3>${escapeHtml(promo.wechat.title || '关注微信公众号')}</h3>
      <p>${escapeHtml(promo.wechat.body)}</p>
      ${qr}
    </section>`);
  }

  if (!blocks.length) return '';
  return `  <aside class="blog-promo">
${blocks.join('\n')}
  </aside>`;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- blog-layout.spec`
Expected: PASS（9 个用例）

- [ ] **Step 5: 实现 post-page.ts**

新建 `lumira-server/packages/backend/src/modules/blog/public/post-page.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/public/post-page.ts
// 文章页 SSR：语义化 <article> + JSON-LD BlogPosting + 底部推广。
import { buildAssetUrl } from '../../../common/storage/asset-url';
import { renderMarkdown } from '../markdown';
import type { BlogPostDetail, BlogSettingsView, PromoContent } from '../blog.service';
import { SITE_DEFAULT_OG_IMAGE, escapeHtml, renderBlogLayout, renderPromoAside, siteBaseUrl } from './blog-layout';

export interface RenderPostPageOptions {
  post: BlogPostDetail;
  promo: PromoContent | null;
  settings: BlogSettingsView;
  /** 后台预览：打 noindex,nofollow（该 HTML 只经受保护的 preview-html 接口下发） */
  preview?: boolean;
}

function iso(sec: number | null): string | undefined {
  return sec ? new Date(sec * 1000).toISOString() : undefined;
}

function formatDate(sec: number): string {
  const d = new Date(sec * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function renderPostPage(o: RenderPostPageOptions): string {
  const { post, settings } = o;
  const base = siteBaseUrl();
  const canonicalUrl = `${base}/blog/${post.slug}`;
  const seoTitle = post.seoTitle || post.title;
  const description = post.seoDescription || post.summary || settings.blogDescription || post.title;
  const ogImage = post.coverUrl ? buildAssetUrl(post.coverUrl) : `${base}${SITE_DEFAULT_OG_IMAGE}`;

  const jsonLd: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    headline: post.title,
    description,
    image: [ogImage],
    datePublished: iso(post.publishedAt),
    dateModified: iso(post.updatedAt),
    author: { '@type': 'Organization', name: '如画 Lumira' },
    publisher: { '@type': 'Organization', name: '如画 Lumira' },
    mainEntityOfPage: canonicalUrl,
  };

  const categoryLink = post.categoryKey && post.categoryName
    ? ` · <a class="blog-post-category" href="/blog/category/${escapeHtml(post.categoryKey)}">${escapeHtml(post.categoryName)}</a>`
    : '';
  const timeHtml = post.publishedAt
    ? `<time datetime="${escapeHtml(iso(post.publishedAt) || '')}">${formatDate(post.publishedAt)}</time>`
    : '';

  const body = `    <article class="blog-post">
      <h1 class="blog-post-title">${escapeHtml(post.title)}</h1>
      <p class="blog-post-meta">${timeHtml}${categoryLink}</p>
      ${post.coverUrl ? `<img class="blog-post-cover" src="${escapeHtml(ogImage)}" alt="${escapeHtml(post.title)}" />` : ''}
      <div class="blog-content">${renderMarkdown(post.contentMd)}</div>
${renderPromoAside(o.promo)}
    </article>`;

  return renderBlogLayout({
    title: `${seoTitle} · 如画 Lumira 博客`,
    description,
    canonicalUrl,
    ogImage,
    ogType: 'article',
    publishedTime: iso(post.publishedAt),
    modifiedTime: iso(post.updatedAt),
    jsonLd,
    noIndex: o.preview === true,
    body,
  });
}
```

- [ ] **Step 6: 实现 list-page.ts**

新建 `lumira-server/packages/backend/src/modules/blog/public/list-page.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/public/list-page.ts
// 列表页 / 分类列表页 SSR：作为 SEO 内链枢纽，含 canonical、description 与简版 ItemList。
import type { BlogCategoryView, BlogPostListItem, BlogSettingsView } from '../blog.service';
import { SITE_DEFAULT_OG_IMAGE, escapeHtml, renderBlogLayout, siteBaseUrl } from './blog-layout';

export interface RenderListPageOptions {
  settings: BlogSettingsView;
  categories: BlogCategoryView[];
  items: BlogPostListItem[];
  page: number;
  total: number;
  pageSize: number;
  /** null = 全站列表页 /blog；非 null = 分类页 /blog/category/:key */
  category: BlogCategoryView | null;
}

export function renderListPage(o: RenderListPageOptions): string {
  const base = siteBaseUrl();
  const isCategory = o.category !== null;
  const path = isCategory ? `/blog/category/${o.category!.key}` : '/blog';
  const canonicalUrl = `${base}${path}${o.page > 1 ? `?page=${o.page}` : ''}`;
  const titleText = isCategory ? `${o.category!.name} · 如画 Lumira 博客` : '如画 Lumira 博客';
  const description = isCategory
    ? (o.category!.description || `${o.category!.name}相关文章合集。`)
    : (o.settings.blogDescription || '摄影灵感、拍摄技巧与出片思路。');

  const navLinks = o.categories
    .map((c) => `<a class="blog-chip${isCategory && c.key === o.category!.key ? ' is-active' : ''}" href="/blog/category/${escapeHtml(c.key)}">${escapeHtml(c.name)}</a>`)
    .join('\n      ');

  const cards = o.items.length
    ? o.items.map((it) => `      <article class="blog-card">
        ${it.coverUrl ? `<a class="blog-card-cover" href="/blog/${escapeHtml(it.slug)}"><img src="${escapeHtml(it.coverUrl)}" alt="${escapeHtml(it.title)}" loading="lazy" /></a>` : ''}
        <h2 class="blog-card-title"><a href="/blog/${escapeHtml(it.slug)}">${escapeHtml(it.title)}</a></h2>
        ${it.summary ? `<p class="blog-card-summary">${escapeHtml(it.summary)}</p>` : ''}
        <p class="blog-card-meta">${it.categoryKey && it.categoryName ? `<a href="/blog/category/${escapeHtml(it.categoryKey)}">${escapeHtml(it.categoryName)}</a>` : ''}</p>
      </article>`).join('\n')
    : '      <p class="blog-empty">暂无文章。</p>';

  const totalPages = Math.max(1, Math.ceil(o.total / o.pageSize));
  const pageLink = (n: number) => `${path}${n > 1 ? `?page=${n}` : ''}`;
  const pagination = totalPages > 1
    ? `      <nav class="blog-pagination">
        ${o.page > 1 ? `<a href="${escapeHtml(pageLink(o.page - 1))}">上一页</a>` : ''}
        <span>第 ${o.page} / ${totalPages} 页</span>
        ${o.page < totalPages ? `<a href="${escapeHtml(pageLink(o.page + 1))}">下一页</a>` : ''}
      </nav>`
    : '';

  const jsonLd: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    itemListElement: o.items.map((it, idx) => ({
      '@type': 'ListItem',
      position: idx + 1,
      url: `${base}/blog/${it.slug}`,
      name: it.title,
    })),
  };

  const body = `    <div class="blog-list-head">
      <h1>${escapeHtml(isCategory ? o.category!.name : '如画 Lumira 博客')}</h1>
      <p class="blog-list-desc">${escapeHtml(description)}</p>
      ${o.categories.length ? `<nav class="blog-chips">
      <a class="blog-chip${isCategory ? '' : ' is-active'}" href="/blog">全部</a>
      ${navLinks}
      </nav>` : ''}
    </div>
    <section class="blog-cards">
${cards}
    </section>
${pagination}`;

  return renderBlogLayout({
    title: titleText,
    description,
    canonicalUrl,
    ogImage: `${base}${SITE_DEFAULT_OG_IMAGE}`,
    ogType: 'website',
    jsonLd,
    body,
  });
}
```

- [ ] **Step 7: 运行全部后端单测**

Run: `pnpm --filter @lumira/backend test`
Expected: 全部 PASS（含新增 4 个 spec 文件）。

- [ ] **Step 8: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/public
git commit -m "feat(backend): 博客公开页 HTML 模板（布局/文章页/列表页 + SEO 元信息）"
git push origin master
git push github master
```

---

## Task 8: 公开路由注册 + 入口接线 + 样式

**Files:**
- Create: `lumira-server/packages/backend/src/modules/blog/public/register-public-routes.ts`
- Create: `lumira-server/packages/backend/public/css/blog.css`
- Modify: `lumira-server/packages/backend/src/main.ts:10,92`

**Interfaces:**
- Consumes: `BlogService`（Task 4，结构上满足 `BlogPublicDataSource`）、`renderPostPage` / `renderListPage` / `siteBaseUrl`（Task 7）、`resolvePromoContent`（Task 4）
- Produces: `registerBlogPublicRoutes(app: FastifyInstance, deps: BlogPublicDataSource): void`；公开路由 `GET /blog`、`GET /blog/category/:key`、`GET /blog/:slug`、`GET /sitemap.xml`、`GET /robots.txt`

- [ ] **Step 1: 实现 register-public-routes.ts**

新建 `lumira-server/packages/backend/src/modules/blog/public/register-public-routes.ts`：

```ts
// lumira-server/packages/backend/src/modules/blog/public/register-public-routes.ts
// 公开博客路由：注册在「裸 Fastify 实例」上（不带 /api/v1 前缀），与既有 fastify.get('/') 同一手法。
// find-my-way 路由优先级「静态 > 参数 > 通配」，显式 /blog* 不会被 @fastify/static 的 /* 吞掉。
import type { FastifyInstance, FastifyReply } from 'fastify';
import { resolvePromoContent } from '../blog.service';
import type {
  BlogCategoryView,
  BlogPostDetail,
  BlogPostListItem,
  BlogSettingsView,
} from '../blog.service';
import { siteBaseUrl } from './blog-layout';
import { renderListPage } from './list-page';
import { renderPostPage } from './post-page';

export interface BlogPublicDataSource {
  listCategories(): Promise<BlogCategoryView[]>;
  getSettings(): Promise<BlogSettingsView>;
  getPublishedBySlug(slug: string): Promise<BlogPostDetail | null>;
  listPublishedPosts(opts: { page?: number; categoryKey?: string }): Promise<{
    items: BlogPostListItem[];
    total: number;
    page: number;
    pageSize: number;
    category: BlogCategoryView | null;
  }>;
  listPublishedForSitemap(): Promise<{ slug: string; updatedAt: number }[]>;
}

const HTML_CACHE = 'public, max-age=60';

function sendHtml(reply: FastifyReply, body: string) {
  return reply.type('text/html; charset=utf-8').header('Cache-Control', HTML_CACHE).send(body);
}

function sendNotFound(reply: FastifyReply) {
  return reply.code(404).type('text/html; charset=utf-8').send(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>页面不存在 · 如画 Lumira</title>
  <meta name="robots" content="noindex,nofollow" />
  <link rel="stylesheet" href="/css/style.css" />
</head>
<body class="blog-body">
  <main class="blog-main">
    <h1>404</h1>
    <p>页面不存在或已下线。</p>
    <p><a href="/blog">返回博客列表</a></p>
  </main>
</body>
</html>`);
}

function sitemapXml(entries: { loc: string; lastmod?: string }[]): string {
  const urls = entries
    .map((e) => `  <url><loc>${e.loc}</loc>${e.lastmod ? `<lastmod>${e.lastmod}</lastmod>` : ''}</url>`)
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`;
}

export function registerBlogPublicRoutes(app: FastifyInstance, deps: BlogPublicDataSource): void {
  const base = siteBaseUrl();

  // 列表页（?page=N，非正整数 / 越界由 service 层钳制，不报错）
  app.get('/blog', async (request, reply) => {
    const query = request.query as Record<string, string | undefined>;
    const [data, settings, categories] = await Promise.all([
      deps.listPublishedPosts({ page: Number(query.page) }),
      deps.getSettings(),
      deps.listCategories(),
    ]);
    return sendHtml(reply, renderListPage({
      settings, categories,
      items: data.items, page: data.page, total: data.total, pageSize: data.pageSize,
      category: null,
    }));
  });

  // 分类列表页（路径式，利于 SEO 内链）
  app.get('/blog/category/:key', async (request, reply) => {
    const params = request.params as { key: string };
    const query = request.query as Record<string, string | undefined>;
    const data = await deps.listPublishedPosts({ page: Number(query.page), categoryKey: params.key });
    if (!data.category) return sendNotFound(reply);
    const [settings, categories] = await Promise.all([deps.getSettings(), deps.listCategories()]);
    return sendHtml(reply, renderListPage({
      settings, categories,
      items: data.items, page: data.page, total: data.total, pageSize: data.pageSize,
      category: data.category,
    }));
  });

  // 文章页：草稿 / 不存在的 slug 一律 404
  app.get('/blog/:slug', async (request, reply) => {
    const params = request.params as { slug: string };
    const post = await deps.getPublishedBySlug(params.slug);
    if (!post) return sendNotFound(reply);
    const settings = await deps.getSettings();
    const promo = resolvePromoContent(post.promoMode, settings);
    return sendHtml(reply, renderPostPage({ post, promo, settings }));
  });

  app.get('/sitemap.xml', async (_request, reply) => {
    const [posts, categories] = await Promise.all([
      deps.listPublishedForSitemap(),
      deps.listCategories(),
    ]);
    const entries = [
      { loc: `${base}/` },
      { loc: `${base}/blog` },
      ...categories.map((c) => ({ loc: `${base}/blog/category/${c.key}` })),
      ...posts.map((p) => ({ loc: `${base}/blog/${p.slug}`, lastmod: new Date(p.updatedAt * 1000).toISOString() })),
    ];
    return reply.type('application/xml; charset=utf-8').header('Cache-Control', HTML_CACHE).send(sitemapXml(entries));
  });

  app.get('/robots.txt', async (_request, reply) => {
    const body = [
      'User-agent: *',
      'Allow: /',
      'Disallow: /api/',
      '',
      `Sitemap: ${base}/sitemap.xml`,
      '',
    ].join('\n');
    return reply.type('text/plain; charset=utf-8').header('Cache-Control', 'public, max-age=3600').send(body);
  });
}
```

- [ ] **Step 2: 写博客样式**

新建 `lumira-server/packages/backend/public/css/blog.css`（复用 `style.css` 的品牌变量）：

```css
/* lumira-server/packages/backend/public/css/blog.css
   博客公开页样式：沿用 style.css 的品牌变量（暖白底 / 金色品牌色 / 衬线标题）。 */

.blog-body {
  margin: 0;
  background: var(--color-bg);
  color: var(--color-text-primary);
  font-family: var(--font-sans);
  line-height: 1.75;
}

.blog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  max-width: var(--container-max);
  margin: 0 auto;
  padding: 20px 24px;
  border-bottom: 1px solid var(--color-border);
}

.blog-brand {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--color-text-primary);
  text-decoration: none;
  font-family: var(--font-serif);
  font-size: 18px;
  letter-spacing: 0.02em;
}

.blog-nav a {
  margin-left: 20px;
  color: var(--color-text-secondary);
  text-decoration: none;
  font-size: 14px;
}

.blog-nav a:hover { color: var(--color-brand-hover); }

.blog-main {
  max-width: 760px;
  margin: 0 auto;
  padding: 40px 24px 80px;
}

.blog-footer {
  border-top: 1px solid var(--color-border);
  padding: 24px;
  text-align: center;
  color: var(--color-text-tertiary);
  font-size: 13px;
}

.blog-footer a { color: var(--color-text-secondary); }

.blog-post-title {
  font-family: var(--font-serif);
  font-size: 30px;
  line-height: 1.4;
  margin: 0 0 12px;
}

.blog-post-meta {
  color: var(--color-text-tertiary);
  font-size: 13px;
  margin: 0 0 24px;
}

.blog-post-meta a { color: var(--color-brand-hover); text-decoration: none; }

.blog-post-cover {
  width: 100%;
  border-radius: var(--radius-card);
  margin-bottom: 28px;
  display: block;
}

.blog-content h2 {
  font-family: var(--font-serif);
  font-size: 22px;
  margin: 36px 0 12px;
}

.blog-content h3 { font-size: 18px; margin: 28px 0 10px; }
.blog-content p { margin: 0 0 16px; }
.blog-content img { max-width: 100%; height: auto; border-radius: var(--radius-card); }
.blog-content blockquote {
  margin: 20px 0;
  padding: 8px 18px;
  border-left: 3px solid var(--color-brand);
  background: var(--color-surface);
  color: var(--color-text-secondary);
}
.blog-content pre {
  background: var(--color-surface);
  padding: 14px 16px;
  border-radius: var(--radius-card);
  overflow-x: auto;
  font-size: 13px;
}
.blog-content a { color: var(--color-brand-hover); }

/* ===== 底部推广 ===== */
.blog-promo {
  margin-top: 48px;
  padding: 24px;
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
}

.blog-promo-block + .blog-promo-block {
  margin-top: 20px;
  padding-top: 20px;
  border-top: 1px dashed var(--color-border);
}

.blog-promo-block h3 {
  font-family: var(--font-serif);
  font-size: 16px;
  margin: 0 0 8px;
}

.blog-promo-block p {
  margin: 0 0 8px;
  color: var(--color-text-secondary);
  font-size: 14px;
}

.blog-promo-link {
  display: inline-block;
  padding: 6px 14px;
  background: var(--color-brand-light);
  color: var(--color-brand-hover);
  border-radius: var(--radius-btn);
  text-decoration: none;
  font-size: 13px;
}

.blog-promo-qr {
  width: 120px;
  height: 120px;
  object-fit: contain;
  border-radius: 8px;
  background: #fff;
}

/* ===== 列表页 ===== */
.blog-list-head { margin-bottom: 28px; }
.blog-list-head h1 { font-family: var(--font-serif); font-size: 28px; margin: 0 0 8px; }
.blog-list-desc { color: var(--color-text-secondary); font-size: 14px; margin: 0 0 16px; }

.blog-chips { display: flex; flex-wrap: wrap; gap: 8px; }
.blog-chip {
  padding: 5px 12px;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  color: var(--color-text-secondary);
  text-decoration: none;
  font-size: 13px;
}
.blog-chip.is-active { background: var(--color-brand-light); border-color: var(--color-brand-light); color: var(--color-brand-hover); }

.blog-cards { display: grid; gap: 20px; }

.blog-card {
  background: var(--color-card);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  overflow: hidden;
}

.blog-card-cover img { width: 100%; height: 200px; object-fit: cover; display: block; }
.blog-card-title { font-family: var(--font-serif); font-size: 19px; margin: 16px 16px 8px; }
.blog-card-title a { color: var(--color-text-primary); text-decoration: none; }
.blog-card-summary { margin: 0 16px 12px; color: var(--color-text-secondary); font-size: 14px; }
.blog-card-meta { margin: 0 16px 16px; font-size: 13px; }
.blog-card-meta a { color: var(--color-brand-hover); text-decoration: none; }
.blog-empty { color: var(--color-text-tertiary); }

.blog-pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-top: 32px;
  font-size: 14px;
}
.blog-pagination a { color: var(--color-brand-hover); text-decoration: none; }

@media (max-width: 640px) {
  .blog-post-title { font-size: 24px; }
  .blog-main { padding: 24px 16px 64px; }
}
```

- [ ] **Step 3: 在 main.ts 接线**

修改 `lumira-server/packages/backend/src/main.ts`：

1. 第 10 行 `import { registerUploadsRoute } from "./common/storage/uploads.route";` 之后追加两行 import：

```ts
import { BlogService } from "./modules/blog/blog.service";
import { registerBlogPublicRoutes } from "./modules/blog/public/register-public-routes";
```

2. 第 92 行（静态目录 `if (fs.existsSync(publicRoot)) { ... }` 块结束的 `}` 之后、`const port = ...` 之前）插入：

```ts
  // 博客公开页 / sitemap / robots：注册在裸 Fastify 实例上（不受 api/v1 前缀影响），
  // 必须在上面的 @fastify/static 之后注册，与既有 fastify.get('/') 同一手法。
  const blogService = app.get(BlogService);
  registerBlogPublicRoutes(fastifyInstance, blogService);
```

- [ ] **Step 4: 编译 + 全量后端测试**

Run: `pnpm --filter @lumira/backend build`
Expected: 退出码 0。

Run: `pnpm --filter @lumira/backend test`
Expected: 全部 PASS。

- [ ] **Step 5: 本地端到端冒烟（需本地 MySQL；无本地库时跳到 Step 6，改由生产验证）**

Run: `pnpm --filter @lumira/backend dev`
Expected: 控制台输出 `Lumira server running on port 3000`。

Run: `curl -s -o NUL -w "%{http_code}" http://localhost:3000/blog`
Expected: `200`。

Run: `curl -s -o NUL -w "%{http_code}" http://localhost:3000/blog/nonexistent-slug`
Expected: `404`。

Run: `curl -s http://localhost:3000/sitemap.xml`
Expected: 返回以 `<?xml version="1.0"` 开头的 XML，含 `<loc>` 条目。

Run: `curl -s http://localhost:3000/robots.txt`
Expected: 含 `Sitemap: http://localhost:3000/sitemap.xml`。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/backend/src/modules/blog/public/register-public-routes.ts lumira-server/packages/backend/public/css/blog.css lumira-server/packages/backend/src/main.ts
git commit -m "feat(backend): 博客公开路由（/blog、分类页、sitemap、robots）与公开页样式"
git push origin master
git push github master
```

> 说明：`git push origin master` 会触发 `backend-deploy.yml` 生产自动部署（改动命中 `backend/**`）。

## Task 9: Admin 数据层（类型 + api 方法 + server actions）

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（文件末尾追加）
- Modify: `lumira-server/packages/admin/src/lib/api.ts`（顶部 import 增补 + `api` 对象末尾追加 `blog*`）
- Create: `lumira-server/packages/admin/src/actions/blog.ts`

**Interfaces:**
- Consumes: 后端 `BlogService` 的全部签名（Task 4）与 `AdminBlogController` 的端点契约（Task 5）：`GET/POST /admin/blog/posts`、`GET /admin/blog/posts/:id`、`PATCH /admin/blog/posts/:id`、`PATCH /admin/blog/posts/:id/status`、`DELETE /admin/blog/posts/:id`、`GET /admin/blog/posts/:id/preview-html`、`GET/POST /admin/blog/categories`、`PATCH/DELETE /admin/blog/categories/:id`、`GET/PATCH /admin/blog/settings`、`POST /admin/blog/uploads`、`POST /admin/blog/ai/generate`。
- Produces:
  - 类型：`BlogStatus`、`PromoMode`、`BlogCategoryAdmin`、`BlogPostAdminListItem`、`BlogPostAdminDetail`、`BlogPostAdminListResponse`、`BlogSettingsAdmin`、`BlogPostPayload`、`BlogCategoryPayload`、`BlogSettingsPayload`、`AiBlogDraft`、`AiBlogGeneratePayload`
  - `api.blogListPosts(params)` / `api.blogGetPost(id)` / `api.blogCreatePost(formData)` / `api.blogUpdatePost(id, formData)` / `api.blogUpdatePostStatus(id, status)` / `api.blogDeletePost(id)` / `api.blogPreviewHtml(id)` / `api.blogListCategories()` / `api.blogCreateCategory(payload)` / `api.blogUpdateCategory(id, payload)` / `api.blogDeleteCategory(id)` / `api.blogGetSettings()` / `api.blogSaveSettings(formData)` / `api.blogUploadImage(formData)` / `api.blogAiGenerate(payload)`
  - server actions：`saveBlogPost(id, payload, cover)` / `setBlogPostStatus(id, status)` / `removeBlogPost(id)` / `loadBlogPreviewHtml(id)` / `saveBlogCategory(id, payload)` / `removeBlogCategory(id)` / `saveBlogSettings(payload, qr)` / `uploadBlogImage(file, postId?)` / `generateBlogDraft(payload)`

- [ ] **Step 1: 追加博客类型**

在 `lumira-server/packages/admin/src/types/admin.ts` **文件末尾**追加：

```ts
// ===== 图文博客（Task 9）=====

export type BlogStatus = 'draft' | 'published';
export type PromoMode = 'inherit' | 'on' | 'off';

/** 博客分类（后端 /admin/blog/categories 直接返回数组，未包 items） */
export interface BlogCategoryAdmin {
  id: number;
  key: string;
  name: string;
  description: string;
  sortOrder: number;
}

/** 文章列表项。coverUrl 是后端 buildAssetUrl 出的绝对地址，渲染前须过 toAssetUrl() */
export interface BlogPostAdminListItem {
  id: string;
  slug: string;
  title: string;
  summary: string;
  coverUrl: string;
  status: BlogStatus;
  promoMode: PromoMode;
  categoryId: number | null;
  categoryName: string | null;
  categoryKey: string | null;
  publishedAt: number | null;
  createdAt: number;
  updatedAt: number;
}

export interface BlogPostAdminDetail extends BlogPostAdminListItem {
  seoTitle: string;
  seoDescription: string;
  contentMd: string;
}

export interface BlogPostAdminListResponse {
  items: BlogPostAdminListItem[];
  total: number;
  page: number;
  pageSize: number;
}

export interface BlogSettingsAdmin {
  promoEnabled: boolean;
  blogTitle: string;
  blogDescription: string;
  promoOfficialTitle: string;
  promoOfficialBody: string;
  promoAppTitle: string;
  promoAppBody: string;
  promoWechatTitle: string;
  promoWechatBody: string;
  /** 公众号二维码：后端 buildAssetUrl 出的绝对地址，渲染前须过 toAssetUrl() */
  promoWechatQrUrl: string;
}

/** 文章提交体（新建 / 编辑共用），作为 multipart 的 meta 字段 JSON 提交 */
export interface BlogPostPayload {
  title: string;
  slug?: string;
  summary?: string;
  seoTitle?: string;
  seoDescription?: string;
  contentMd?: string;
  categoryId?: number | null;
  status?: BlogStatus;
  promoMode?: PromoMode;
}

/** 分类提交体；更新时 key 不可改（后端 UpdateCategoryDto 不含 key） */
export interface BlogCategoryPayload {
  key: string;
  name: string;
  description?: string;
  sortOrder?: number;
}

export interface BlogSettingsPayload {
  promoEnabled?: boolean;
  blogTitle?: string;
  blogDescription?: string;
  promoOfficialTitle?: string;
  promoOfficialBody?: string;
  promoAppTitle?: string;
  promoAppBody?: string;
  promoWechatTitle?: string;
  promoWechatBody?: string;
}

/** AI 生成草稿（仅回填表单，不落库） */
export interface AiBlogDraft {
  title: string;
  slugSuggestion: string;
  summary: string;
  seoDescription: string;
  contentMd: string;
  categoryKey: string;
}

export interface AiBlogGeneratePayload {
  topic: string;
  requirements?: string;
  wordCount?: number;
  categoryId?: number;
}
```

- [ ] **Step 2: 在 api.ts 增补 import**

修改 `lumira-server/packages/admin/src/lib/api.ts` 的 `import type { ... } from '@/types/admin';` 块（第 5~48 行），在 `StorageConfigPayload,` 之后追加：

```ts
  BlogStatus,
  BlogPostAdminDetail,
  BlogPostAdminListItem,
  BlogPostAdminListResponse,
  BlogCategoryAdmin,
  BlogSettingsAdmin,
  BlogCategoryPayload,
  AiBlogDraft,
  AiBlogGeneratePayload,
```

> `BlogPostPayload` / `BlogSettingsPayload` 只在 `actions/blog.ts` 使用，`api.ts` 只收 FormData，故**不要**在此 import（否则触发 `no-unused-vars`）。

- [ ] **Step 3: 在 api.ts 追加博客方法**

在 `lumira-server/packages/admin/src/lib/api.ts` 的 `api` 对象中，`saveStorageConfig` 之后（对象闭合 `};` 之前）追加：

```ts
  // ===== 图文博客 =====
  blogListPosts: (
    params: {
      status?: 'all' | BlogStatus;
      categoryId?: number;
      keyword?: string;
      page?: number;
      pageSize?: number;
    } = {},
  ) => {
    const search = new URLSearchParams();
    if (params.status) search.set('status', params.status);
    if (params.categoryId !== undefined) search.set('categoryId', String(params.categoryId));
    if (params.keyword) search.set('keyword', params.keyword);
    if (params.page) search.set('page', String(params.page));
    if (params.pageSize) search.set('pageSize', String(params.pageSize));
    const qs = search.toString();
    return adminFetch<BlogPostAdminListResponse>(`/blog/posts${qs ? `?${qs}` : ''}`);
  },

  blogGetPost: (id: string) =>
    adminFetch<BlogPostAdminDetail>(`/blog/posts/${encodeURIComponent(id)}`),

  /** 新建文章：multipart（meta=JSON(BlogPostPayload) + cover 可选） */
  blogCreatePost: (formData: FormData) =>
    adminFetch<BlogPostAdminDetail>('/blog/posts', { method: 'POST', body: formData }),

  /** 更新文章：multipart（meta=JSON(BlogPostPayload) + cover 可选，不传则保留原封面） */
  blogUpdatePost: (id: string, formData: FormData) =>
    adminFetch<BlogPostAdminDetail>(`/blog/posts/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: formData,
    }),

  /** 一键发布 / 取消发布 */
  blogUpdatePostStatus: (id: string, status: BlogStatus) =>
    adminFetch<BlogPostAdminListItem>(`/blog/posts/${encodeURIComponent(id)}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    }),

  blogDeletePost: (id: string) =>
    adminFetch<{ success: boolean }>(`/blog/posts/${encodeURIComponent(id)}`, {
      method: 'DELETE',
    }),

  /** 后台 iframe srcDoc 预览：返回完整文章页 HTML（草稿也可预览） */
  blogPreviewHtml: (id: string) =>
    adminFetch<{ html: string }>(`/blog/posts/${encodeURIComponent(id)}/preview-html`),

  blogListCategories: () => adminFetch<BlogCategoryAdmin[]>('/blog/categories'),

  blogCreateCategory: (payload: BlogCategoryPayload) =>
    adminFetch<BlogCategoryAdmin>('/blog/categories', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  blogUpdateCategory: (id: number, payload: Omit<BlogCategoryPayload, 'key'>) =>
    adminFetch<BlogCategoryAdmin>(`/blog/categories/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }),

  blogDeleteCategory: (id: number) =>
    adminFetch<{ success: boolean }>(`/blog/categories/${id}`, { method: 'DELETE' }),

  blogGetSettings: () => adminFetch<BlogSettingsAdmin>('/blog/settings'),

  /** 保存设置：multipart（meta=JSON(BlogSettingsPayload) + qr 可选，传则替换公众号二维码） */
  blogSaveSettings: (formData: FormData) =>
    adminFetch<BlogSettingsAdmin>('/blog/settings', { method: 'PATCH', body: formData }),

  /** 正文插图 / 封面 / 二维码上传：multipart（file + postId 可选）→ { storageKey, url } */
  blogUploadImage: (formData: FormData) =>
    adminFetch<{ storageKey: string; url: string }>('/blog/uploads', {
      method: 'POST',
      body: formData,
    }),

  /** AI 生成博客草稿（仅回填表单，不落库）：{ title, slugSuggestion, summary, seoDescription, contentMd, categoryKey } */
  blogAiGenerate: (payload: AiBlogGeneratePayload) =>
    adminFetch<AiBlogDraft>(
      '/blog/ai/generate',
      { method: 'POST', body: JSON.stringify(payload) },
      AI_ENDPOINT_TIMEOUT_MS,
    ),
```

- [ ] **Step 4: 写 server actions**

新建 `lumira-server/packages/admin/src/actions/blog.ts`：

```ts
// src/actions/blog.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import type {
  AiBlogDraft,
  AiBlogGeneratePayload,
  BlogCategoryPayload,
  BlogPostPayload,
  BlogSettingsPayload,
  BlogStatus,
} from '@/types/admin';

/**
 * 新建 / 更新文章（id 为 null 表示新建）。
 * payload 打进 multipart 的 meta 字段；cover 仅在用户选了新图时传入。
 */
export async function saveBlogPost(
  id: string | null,
  payload: BlogPostPayload,
  cover: File | null,
): Promise<{ success: true; id: string } | { error: string }> {
  const formData = new FormData();
  formData.set('meta', JSON.stringify(payload));
  if (cover) formData.set('cover', cover);

  let savedId: string;
  try {
    const result = id
      ? await api.blogUpdatePost(id, formData)
      : await api.blogCreatePost(formData);
    savedId = result.id;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/blog');
  revalidatePath(`/dashboard/blog/${savedId}`);
  return { success: true, id: savedId };
}

/** 一键发布 / 取消发布 */
export async function setBlogPostStatus(
  id: string,
  status: BlogStatus,
): Promise<{ success: true; status: BlogStatus } | { error: string }> {
  try {
    const result = await api.blogUpdatePostStatus(id, status);
    revalidatePath('/dashboard/blog');
    revalidatePath(`/dashboard/blog/${id}`);
    return { success: true, status: result.status };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

export async function removeBlogPost(
  id: string,
): Promise<{ success: true } | { error: string }> {
  try {
    await api.blogDeletePost(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/blog');
  return { success: true };
}

/** 取文章页完整 HTML，供 iframe srcDoc 预览（草稿也可预览） */
export async function loadBlogPreviewHtml(
  id: string,
): Promise<{ html: string } | { error: string }> {
  try {
    return await api.blogPreviewHtml(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 新建 / 更新分类（id 为 null 表示新建；更新时 key 不可改） */
export async function saveBlogCategory(
  id: number | null,
  payload: BlogCategoryPayload,
): Promise<{ success: true } | { error: string }> {
  try {
    if (id) {
      await api.blogUpdateCategory(id, {
        name: payload.name,
        description: payload.description,
        sortOrder: payload.sortOrder,
      });
    } else {
      await api.blogCreateCategory(payload);
    }
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/blog/categories');
  revalidatePath('/dashboard/blog');
  return { success: true };
}

export async function removeBlogCategory(
  id: number,
): Promise<{ success: true } | { error: string }> {
  try {
    await api.blogDeleteCategory(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/blog/categories');
  revalidatePath('/dashboard/blog');
  return { success: true };
}

/** 保存博客设置；qr 仅在用户选了新二维码时传入 */
export async function saveBlogSettings(
  payload: BlogSettingsPayload,
  qr: File | null,
): Promise<{ success: true } | { error: string }> {
  const formData = new FormData();
  formData.set('meta', JSON.stringify(payload));
  if (qr) formData.set('qr', qr);

  try {
    await api.blogSaveSettings(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/blog/settings');
  revalidatePath('/dashboard/blog');
  return { success: true };
}

/**
 * 上传正文插图 / 文章封面 / 二维码：选中即传，与保存解耦。
 * 返回 storageKey（写进 Markdown）与 url（本地预览用）。
 */
export async function uploadBlogImage(
  file: File,
  postId?: string,
): Promise<{ storageKey: string; url: string } | { error: string }> {
  const formData = new FormData();
  formData.set('file', file);
  if (postId) formData.set('postId', postId);

  try {
    return await api.blogUploadImage(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** AI 生成博客草稿（仅回填表单，不落库） */
export async function generateBlogDraft(
  payload: AiBlogGeneratePayload,
): Promise<AiBlogDraft | { error: string }> {
  try {
    return await api.blogAiGenerate(payload);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
```

- [ ] **Step 5: 类型与构建校验**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0，无 TypeScript / ESLint 报错。

> 说明：本 Task 只新增类型与数据层，尚无页面引用 `actions/blog.ts`。`next build` 不会因“导出未被引用”报错（ESLint 的 `no-unused-vars` 只针对局部变量，不针对 module exports）。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/lib/api.ts lumira-server/packages/admin/src/actions/blog.ts
git commit -m "feat(admin): 博客数据层（类型 / api 方法 / server actions）"
git push origin master
git push github master
```

> 说明：本 Task 只改 `packages/admin/**`，不会触发后端 SSH 部署（`backend-deploy.yml` 路径未命中），Vercel 将自动构建。

## Task 10: 轻量 Markdown 编辑器（工具栏 + 实时预览 + 插图上传）

**Files:**
- Create: `lumira-server/packages/admin/src/lib/blog-markdown.ts`（纯函数：工具栏变换）
- Create: `lumira-server/packages/admin/src/lib/__tests__/blog-markdown.test.ts`（vitest 单测）
- Create: `lumira-server/packages/admin/src/components/blog/markdown-editor.tsx`
- Modify: `lumira-server/packages/admin/package.json`（新增 `marked`）

**Interfaces:**
- Consumes: `uploadBlogImage(file, postId?)`（Task 9）——由父组件以 `onUploadImage` 回调形式传入。
- Produces:
  - `applyMarkdownTool(value, range, tool): MarkdownEdit`，`MarkdownTool = 'h2' | 'h3' | 'bold' | 'italic' | 'quote' | 'ul' | 'ol' | 'link' | 'code' | 'hr'`；`TextRange { start; end }`；`MarkdownEdit { value; selectionStart; selectionEnd }`
  - 组件 `MarkdownEditor`，props：`{ value: string; onChange: (v: string) => void; onUploadImage: (file: File) => Promise<string | null>; minHeight?: string; disabled?: boolean }`

- [ ] **Step 1: 安装 marked 依赖**

Run: `cd lumira-server; pnpm --filter @lumira/admin add marked`
Expected: `package.json` 的 `dependencies` 出现 `"marked": "^..."`；`pnpm-lock.yaml` 更新。

> 说明：后端在 Task 3 已装 `marked`；本 Task 为 Admin 客户端实时预览再装一份（spec 明确要求「客户端 `marked` 实时预览」）。

- [ ] **Step 2: 写失败的纯函数测试**

新建 `lumira-server/packages/admin/src/lib/__tests__/blog-markdown.test.ts`：

```ts
// src/lib/__tests__/blog-markdown.test.ts
import { describe, expect, it } from 'vitest';
import { applyMarkdownTool } from '../blog-markdown';

describe('applyMarkdownTool', () => {
  it('bold：包裹选中文本，并把选区扩展到包裹后的整段', () => {
    const r = applyMarkdownTool('hello', { start: 0, end: 5 }, 'bold');
    expect(r.value).toBe('**hello**');
    expect(r.value.slice(r.selectionStart, r.selectionEnd)).toBe('**hello**');
  });

  it('bold：空选区时插入空包裹，光标落在中间', () => {
    const r = applyMarkdownTool('ab', { start: 1, end: 1 }, 'bold');
    expect(r.value).toBe('a****b');
    expect(r.selectionStart).toBe(3);
    expect(r.selectionEnd).toBe(3);
  });

  it('h2：给块内每一行加前缀', () => {
    const r = applyMarkdownTool('a\nb', { start: 0, end: 3 }, 'h2');
    expect(r.value).toBe('## a\n## b');
  });

  it('ul：先剥掉已有块前缀，避免叠加', () => {
    const r = applyMarkdownTool('## a', { start: 0, end: 4 }, 'ul');
    expect(r.value).toBe('- a');
  });

  it('ol：按行序编号', () => {
    const r = applyMarkdownTool('a\nb\nc', { start: 0, end: 5 }, 'ol');
    expect(r.value).toBe('1. a\n2. b\n3. c');
  });

  it('link：无选中文本时插入占位文案并选中 URL 占位符', () => {
    const r = applyMarkdownTool('', { start: 0, end: 0 }, 'link');
    expect(r.value).toBe('[链接文字](https://)');
    expect(r.value.slice(r.selectionStart, r.selectionEnd)).toBe('https://');
  });

  it('hr：在光标处补前置换行后插入分隔线', () => {
    const r = applyMarkdownTool('abc', { start: 3, end: 3 }, 'hr');
    expect(r.value).toBe('abc\n---\n');
  });

  it('range 越界时被钳制到文档范围内', () => {
    const r = applyMarkdownTool('abc', { start: 1, end: 99 }, 'italic');
    expect(r.value).toBe('a*bc*');
  });
});
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `cd lumira-server; pnpm --filter @lumira/admin test -- blog-markdown`
Expected: FAIL —— `Failed to resolve import "../blog-markdown"`（文件尚不存在）。

- [ ] **Step 4: 写实现让测试通过**

新建 `lumira-server/packages/admin/src/lib/blog-markdown.ts`：

```ts
// src/lib/blog-markdown.ts
// 工具栏 → Markdown 文本变换（纯函数，便于单测；组件只负责把结果写回 textarea 并恢复选区）。

export interface TextRange {
  start: number;
  end: number;
}

export interface MarkdownEdit {
  value: string;
  selectionStart: number;
  selectionEnd: number;
}

export type MarkdownTool =
  | 'h2'
  | 'h3'
  | 'bold'
  | 'italic'
  | 'quote'
  | 'ul'
  | 'ol'
  | 'link'
  | 'code'
  | 'hr';

/** 行内包裹型工具 → 包裹符 */
const INLINE_WRAP: Partial<Record<MarkdownTool, string>> = {
  bold: '**',
  italic: '*',
  code: '`',
};

/** 行前缀型工具 → 前缀 */
const LINE_PREFIX: Partial<Record<MarkdownTool, string>> = {
  h2: '## ',
  h3: '### ',
  quote: '> ',
  ul: '- ',
  ol: '1. ',
};

/** 已有块级前缀（再次套用前先剥掉，避免 `## - a` 这类叠加） */
const EXISTING_PREFIX = /^(#{1,6}\s+|>\s+|-\s+|\d+\.\s+)/;

function lineStartOf(value: string, index: number): number {
  const nl = value.lastIndexOf('\n', index - 1);
  return nl < 0 ? 0 : nl + 1;
}

function lineEndOf(value: string, index: number): number {
  const nl = value.indexOf('\n', index);
  return nl < 0 ? value.length : nl;
}

/**
 * 把工具栏动作应用到 value 上，返回新文本与应恢复的选区。
 * 选区越界会被钳制；未知工具原样返回。
 */
export function applyMarkdownTool(
  value: string,
  range: TextRange,
  tool: MarkdownTool,
): MarkdownEdit {
  const start = Math.max(0, Math.min(range.start, value.length));
  const end = Math.max(start, Math.min(range.end, value.length));
  const selected = value.slice(start, end);

  if (tool === 'hr') {
    const needsBreak = end > 0 && value[end - 1] !== '\n';
    const insert = `${needsBreak ? '\n' : ''}---\n`;
    const next = `${value.slice(0, end)}${insert}${value.slice(end)}`;
    const caret = end + insert.length;
    return { value: next, selectionStart: caret, selectionEnd: caret };
  }

  const wrap = INLINE_WRAP[tool];
  if (wrap) {
    const next = `${value.slice(0, start)}${wrap}${selected}${wrap}${value.slice(end)}`;
    if (selected) {
      return { value: next, selectionStart: start, selectionEnd: end + wrap.length * 2 };
    }
    const caret = start + wrap.length;
    return { value: next, selectionStart: caret, selectionEnd: caret };
  }

  if (tool === 'link') {
    const label = selected || '链接文字';
    const insert = `[${label}](https://)`;
    const next = `${value.slice(0, start)}${insert}${value.slice(end)}`;
    // 直接选中 `https://` 占位符，方便粘贴真实地址
    const urlStart = start + label.length + 3;
    return { value: next, selectionStart: urlStart, selectionEnd: urlStart + 8 };
  }

  const prefix = LINE_PREFIX[tool];
  if (!prefix) {
    return { value, selectionStart: start, selectionEnd: end };
  }

  const blockStart = lineStartOf(value, start);
  const blockEnd = lineEndOf(value, end);
  const block = value.slice(blockStart, blockEnd);
  const ordered = tool === 'ol';
  const nextBlock = block
    .split('\n')
    .map((line, i) => `${ordered ? `${i + 1}. ` : prefix}${line.replace(EXISTING_PREFIX, '')}`)
    .join('\n');

  const next = `${value.slice(0, blockStart)}${nextBlock}${value.slice(blockEnd)}`;
  return {
    value: next,
    selectionStart: blockStart,
    selectionEnd: blockStart + nextBlock.length,
  };
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd lumira-server; pnpm --filter @lumira/admin test -- blog-markdown`
Expected: PASS —— 8 个用例全绿。

- [ ] **Step 6: 写编辑器组件**

新建 `lumira-server/packages/admin/src/components/blog/markdown-editor.tsx`：

```tsx
// src/components/blog/markdown-editor.tsx
'use client';

import { useMemo, useRef, useState } from 'react';
import { marked } from 'marked';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { applyMarkdownTool, type MarkdownTool } from '@/lib/blog-markdown';
import { TextB } from '@phosphor-icons/react/dist/csr/TextB';
import { TextItalic } from '@phosphor-icons/react/dist/csr/TextItalic';
import { TextHTwo } from '@phosphor-icons/react/dist/csr/TextHTwo';
import { TextHThree } from '@phosphor-icons/react/dist/csr/TextHThree';
import { Quotes } from '@phosphor-icons/react/dist/csr/Quotes';
import { ListBullets } from '@phosphor-icons/react/dist/csr/ListBullets';
import { ListNumbers } from '@phosphor-icons/react/dist/csr/ListNumbers';
import { Link } from '@phosphor-icons/react/dist/csr/Link';
import { Code } from '@phosphor-icons/react/dist/csr/Code';
import { Minus } from '@phosphor-icons/react/dist/csr/Minus';
import { ImageSquare } from '@phosphor-icons/react/dist/csr/ImageSquare';

interface ToolDef {
  tool: MarkdownTool;
  label: string;
  Icon: typeof TextB;
}

const TOOLS: ToolDef[] = [
  { tool: 'h2', label: '二级标题', Icon: TextHTwo },
  { tool: 'h3', label: '三级标题', Icon: TextHThree },
  { tool: 'bold', label: '粗体', Icon: TextB },
  { tool: 'italic', label: '斜体', Icon: TextItalic },
  { tool: 'quote', label: '引用', Icon: Quotes },
  { tool: 'ul', label: '无序列表', Icon: ListBullets },
  { tool: 'ol', label: '有序列表', Icon: ListNumbers },
  { tool: 'link', label: '链接', Icon: Link },
  { tool: 'code', label: '行内代码', Icon: Code },
  { tool: 'hr', label: '分隔线', Icon: Minus },
];

export interface MarkdownEditorProps {
  value: string;
  onChange: (value: string) => void;
  /** 返回可直接写进 Markdown 的图片地址（相对 storageKey，如 /uploads/blog/xxx/a1b2.jpg）；失败返回 null */
  onUploadImage: (file: File) => Promise<string | null>;
  minHeight?: string;
  disabled?: boolean;
}

export function MarkdownEditor({
  value,
  onChange,
  onUploadImage,
  minHeight = '420px',
  disabled,
}: MarkdownEditorProps) {
  const { toast } = useToast();
  const areaRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [tab, setTab] = useState<'edit' | 'preview'>('edit');
  const [uploading, setUploading] = useState(false);

  const previewHtml = useMemo(() => {
    if (tab !== 'preview') return '';
    // 此处仅供后台作者本人预览，不做净化；公开页输出一律走后端 sanitize-html 白名单（Task 3）
    return marked.parse(value) as string;
  }, [tab, value]);

  const restoreCaret = (start: number, end: number) => {
    requestAnimationFrame(() => {
      const el = areaRef.current;
      if (!el) return;
      el.focus();
      el.setSelectionRange(start, end);
    });
  };

  const handleTool = (tool: MarkdownTool) => {
    const el = areaRef.current;
    const range = el
      ? { start: el.selectionStart, end: el.selectionEnd }
      : { start: value.length, end: value.length };
    const result = applyMarkdownTool(value, range, tool);
    onChange(result.value);
    restoreCaret(result.selectionStart, result.selectionEnd);
  };

  const handlePickImage = async (file: File) => {
    setUploading(true);
    try {
      const url = await onUploadImage(file);
      if (!url) return;
      const alt = file.name.replace(/\.[^.]+$/, '');
      const insert = `\n![${alt}](${url})\n`;
      const at = areaRef.current?.selectionEnd ?? value.length;
      onChange(`${value.slice(0, at)}${insert}${value.slice(at)}`);
      restoreCaret(at + insert.length, at + insert.length);
    } catch (e) {
      toast({
        variant: 'destructive',
        title: '插图上传失败',
        description: (e as Error).message,
      });
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-1 border-b pb-2">
        <div className="mr-1 inline-flex rounded-md border p-0.5">
          <button
            type="button"
            onClick={() => setTab('edit')}
            className={cn(
              'rounded px-2 py-1 text-xs',
              tab === 'edit' ? 'bg-primary/10 text-primary' : 'text-muted-foreground',
            )}
          >
            编辑
          </button>
          <button
            type="button"
            onClick={() => setTab('preview')}
            className={cn(
              'rounded px-2 py-1 text-xs',
              tab === 'preview' ? 'bg-primary/10 text-primary' : 'text-muted-foreground',
            )}
          >
            预览
          </button>
        </div>

        {TOOLS.map(({ tool, label, Icon }) => (
          <Button
            key={tool}
            type="button"
            variant="ghost"
            size="sm"
            title={label}
            aria-label={label}
            disabled={disabled || tab !== 'edit'}
            onClick={() => handleTool(tool)}
          >
            <Icon size={16} />
          </Button>
        ))}

        <Button
          type="button"
          variant="ghost"
          size="sm"
          disabled={disabled || uploading || tab !== 'edit'}
          onClick={() => fileRef.current?.click()}
        >
          <ImageSquare size={16} className="mr-1" />
          {uploading ? '上传中…' : '插图'}
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            e.target.value = '';
            if (file) void handlePickImage(file);
          }}
        />
      </div>

      {tab === 'edit' ? (
        <Textarea
          ref={areaRef}
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
          style={{ minHeight }}
          className="font-mono text-[13px] leading-relaxed"
          placeholder="支持 Markdown：## 标题、**粗体**、- 列表、![alt](/uploads/blog/xxx/a1b2.jpg)"
        />
      ) : (
        <div
          className="prose-sm max-w-none overflow-auto rounded-md border bg-background p-4 text-sm leading-relaxed [&_a]:text-primary [&_blockquote]:border-l-2 [&_blockquote]:pl-3 [&_h2]:mt-4 [&_h2]:text-lg [&_h2]:font-semibold [&_h3]:mt-3 [&_h3]:font-semibold [&_img]:max-w-full [&_img]:rounded [&_li]:ml-5 [&_li]:list-disc [&_ol_li]:list-decimal [&_pre]:overflow-auto [&_pre]:rounded [&_pre]:bg-muted [&_pre]:p-3"
          style={{ minHeight }}
          dangerouslySetInnerHTML={{ __html: previewHtml }}
        />
      )}
    </div>
  );
}

export default MarkdownEditor;
```

- [ ] **Step 7: 构建校验**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0。

- [ ] **Step 8: 提交并推送**

```bash
git add lumira-server/packages/admin/src/lib/blog-markdown.ts lumira-server/packages/admin/src/lib/__tests__/blog-markdown.test.ts lumira-server/packages/admin/src/components/blog/markdown-editor.tsx lumira-server/packages/admin/package.json lumira-server/pnpm-lock.yaml
git commit -m "feat(admin): 轻量 Markdown 编辑器（工具栏 / 实时预览 / 插图上传）"
git push origin master
git push github master
```

## Task 11: 文章表单 + AI 生成弹窗 + 新建 / 编辑页

**Files:**
- Create: `lumira-server/packages/admin/src/components/blog/ai-generate-dialog.tsx`
- Create: `lumira-server/packages/admin/src/components/blog/post-form.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/blog/new/page.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/blog/[id]/page.tsx`

**Interfaces:**
- Consumes: `api.blogListCategories()` / `api.blogGetPost(id)`（Task 9）；`MarkdownEditor`（Task 10）；`saveBlogPost` / `removeBlogPost` / `loadBlogPreviewHtml` / `uploadBlogImage` / `generateBlogDraft`（Task 9）。
- Produces:
  - 组件 `AiGenerateDialog`，props：`{ open: boolean; onOpenChange: (open: boolean) => void; categories: BlogCategoryAdmin[]; onApply: (draft: AiBlogDraft) => void }`
  - 组件 `PostForm`，props：`{ post: BlogPostAdminDetail | null; categories: BlogCategoryAdmin[]; backendUrl: string }`（`posts` 为 `null` 即新建模式）
  - 页面 `/dashboard/blog/new`、`/dashboard/blog/[id]`

- [ ] **Step 1: 写 AI 生成弹窗**

新建 `lumira-server/packages/admin/src/components/blog/ai-generate-dialog.tsx`：

```tsx
// src/components/blog/ai-generate-dialog.tsx
'use client';

import { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { generateBlogDraft } from '@/actions/blog';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import type { AiBlogDraft, BlogCategoryAdmin } from '@/types/admin';

export interface AiGenerateDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  categories: BlogCategoryAdmin[];
  /** 生成成功后把草稿回填到表单（由调用方决定字段映射），本组件不做任何落库 */
  onApply: (draft: AiBlogDraft) => void;
}

export function AiGenerateDialog({
  open,
  onOpenChange,
  categories,
  onApply,
}: AiGenerateDialogProps) {
  const { toast } = useToast();
  const [topic, setTopic] = useState('');
  const [requirements, setRequirements] = useState('');
  const [wordCount, setWordCount] = useState('800');
  const [categoryId, setCategoryId] = useState('');
  const [busy, setBusy] = useState(false);

  const handleGenerate = async () => {
    if (!topic.trim()) {
      toast({ variant: 'destructive', title: '请填写文章主题' });
      return;
    }
    setBusy(true);
    try {
      const result = await generateBlogDraft({
        topic: topic.trim(),
        requirements: requirements.trim() || undefined,
        wordCount: Number(wordCount) || undefined,
        categoryId: categoryId ? Number(categoryId) : undefined,
      });
      if ('error' in result) {
        toast({ variant: 'destructive', title: 'AI 生成失败', description: result.error });
        return;
      }
      onApply(result);
      onOpenChange(false);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle className="text-left">AI 生成博客草稿</DialogTitle>
          <DialogDescription className="text-left">
            生成结果只会回填表单，不会自动保存。请通读并核对事实后再发布。
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="ai-topic">文章主题 *</Label>
            <Input
              id="ai-topic"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="例如：新手如何用手机拍出高级感人像"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="ai-requirements">额外要求</Label>
            <Textarea
              id="ai-requirements"
              value={requirements}
              onChange={(e) => setRequirements(e.target.value)}
              placeholder="例如：面向零基础用户，语气轻松，包含 3 个可立即照做的小技巧"
              rows={4}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="ai-word-count">目标字数</Label>
              <Input
                id="ai-word-count"
                type="number"
                min={200}
                max={3000}
                value={wordCount}
                onChange={(e) => setWordCount(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>分类（可选）</Label>
              <Select
                value={categoryId || 'none'}
                onValueChange={(v) => setCategoryId(v === 'none' ? '' : v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="不指定" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">不指定</SelectItem>
                  {categories.map((c) => (
                    <SelectItem key={c.id} value={String(c.id)}>
                      {c.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)} disabled={busy}>
            取消
          </Button>
          <Button type="button" onClick={() => void handleGenerate()} disabled={busy}>
            <MagicWand size={16} className="mr-1" />
            {busy ? '生成中…' : '生成草稿'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export default AiGenerateDialog;
```

> 说明：AI 生成可能要 1~3 分钟（后端 `AI_TIMEOUT_MS = 300_000`），`busy` 期间按钮禁用，**不要**关闭弹窗（`onOpenChange` 由用户点击遮罩触发，弹窗不会自动关闭）。

- [ ] **Step 2: 写文章表单（含封面 / 状态 / 推广三选一 / 预览 / 复制链接 / 删除）**

新建 `lumira-server/packages/admin/src/components/blog/post-form.tsx`：

```tsx
// src/components/blog/post-form.tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogTitle,
} from '@/components/ui/dialog';
import { FileUpload } from '@/components/ui/file-upload';
import { useToast } from '@/hooks/use-toast';
import { MarkdownEditor } from '@/components/blog/markdown-editor';
import { AiGenerateDialog } from '@/components/blog/ai-generate-dialog';
import {
  loadBlogPreviewHtml,
  removeBlogPost,
  saveBlogPost,
  uploadBlogImage,
} from '@/actions/blog';
import { toAssetUrl } from '@/lib/asset-url';
import { MagicWand } from '@phosphor-icons/react/dist/csr/MagicWand';
import { Eye } from '@phosphor-icons/react/dist/csr/Eye';
import { Copy } from '@phosphor-icons/react/dist/csr/Copy';
import { Trash } from '@phosphor-icons/react/dist/csr/Trash';
import type {
  AiBlogDraft,
  BlogCategoryAdmin,
  BlogPostAdminDetail,
  BlogPostPayload,
  BlogStatus,
  PromoMode,
} from '@/types/admin';

/** 封面限制与后端 MAX_COVER_BYTES 对齐 */
const COVER_MAX_BYTES = 5 * 1024 * 1024;

const STATUS_LABEL: Record<BlogStatus, string> = {
  draft: '草稿',
  published: '已发布',
};

const PROMO_OPTIONS: { value: PromoMode; label: string }[] = [
  { value: 'inherit', label: '跟随全局设置（默认）' },
  { value: 'on', label: '始终显示推广内容' },
  { value: 'off', label: '不显示推广内容' },
];

interface FormState {
  title: string;
  slug: string;
  summary: string;
  seoTitle: string;
  seoDescription: string;
  contentMd: string;
  /** '' 表示不分类 */
  categoryId: string;
  status: BlogStatus;
  promoMode: PromoMode;
}

function initialState(post: BlogPostAdminDetail | null): FormState {
  return {
    title: post?.title ?? '',
    slug: post?.slug ?? '',
    summary: post?.summary ?? '',
    seoTitle: post?.seoTitle ?? '',
    seoDescription: post?.seoDescription ?? '',
    contentMd: post?.contentMd ?? '',
    categoryId: post?.categoryId ? String(post.categoryId) : '',
    status: post?.status ?? 'draft',
    promoMode: post?.promoMode ?? 'inherit',
  };
}

export interface PostFormProps {
  /** null = 新建 */
  post: BlogPostAdminDetail | null;
  categories: BlogCategoryAdmin[];
  /** 站点基址，用于拼公开链接与图片预览 */
  backendUrl: string;
}

export function PostForm({ post, categories, backendUrl }: PostFormProps) {
  const router = useRouter();
  const { toast } = useToast();
  const [form, setForm] = useState<FormState>(() => initialState(post));
  const [cover, setCover] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [aiOpen, setAiOpen] = useState(false);
  const [previewHtml, setPreviewHtml] = useState<string | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const siteBase = backendUrl.replace(/\/+$/, '');
  const publicUrl =
    post && post.status === 'published' ? `${siteBase}/blog/${post.slug}` : null;
  const coverPreview = post ? toAssetUrl(post.coverUrl, backendUrl) : null;

  function setField<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  const handleSave = async () => {
    if (!form.title.trim()) {
      toast({ variant: 'destructive', title: '请填写标题' });
      return;
    }
    const payload: BlogPostPayload = {
      title: form.title.trim(),
      slug: form.slug.trim() || undefined,
      summary: form.summary.trim(),
      seoTitle: form.seoTitle.trim(),
      seoDescription: form.seoDescription.trim(),
      contentMd: form.contentMd,
      categoryId: form.categoryId ? Number(form.categoryId) : null,
      status: form.status,
      promoMode: form.promoMode,
    };

    setSaving(true);
    try {
      const result = await saveBlogPost(post?.id ?? null, payload, cover);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '保存失败', description: result.error });
        return;
      }
      setCover(null);
      toast({
        title: '已保存',
        description:
          form.status === 'published'
            ? '文章已发布，公开链接已生效'
            : '文章已保存为草稿（不会出现在公开站）',
      });
      if (post) router.refresh();
      else router.replace(`/dashboard/blog/${result.id}`);
    } finally {
      setSaving(false);
    }
  };

  const handlePreview = async () => {
    if (!post) return;
    setPreviewLoading(true);
    try {
      const result = await loadBlogPreviewHtml(post.id);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '预览失败', description: result.error });
        return;
      }
      setPreviewHtml(result.html);
    } finally {
      setPreviewLoading(false);
    }
  };

  const handleCopy = async () => {
    if (!publicUrl) return;
    await navigator.clipboard.writeText(publicUrl);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2000);
  };

  const handleDelete = async () => {
    if (!post) return;
    if (!window.confirm(`确认删除《${post.title}》？该操作不可恢复，公开链接将立即失效。`)) return;
    setSaving(true);
    try {
      const result = await removeBlogPost(post.id);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '删除失败', description: result.error });
        return;
      }
      toast({ title: '已删除' });
      router.push('/dashboard/blog');
    } finally {
      setSaving(false);
    }
  };

  const handleAiApply = (draft: AiBlogDraft) => {
    const matched = categories.find((c) => c.key === draft.categoryKey);
    setForm((prev) => ({
      ...prev,
      title: draft.title || prev.title,
      slug: prev.slug || draft.slugSuggestion,
      summary: draft.summary || prev.summary,
      seoDescription: draft.seoDescription || prev.seoDescription,
      contentMd: draft.contentMd || prev.contentMd,
      categoryId: matched ? String(matched.id) : prev.categoryId,
    }));
    toast({
      title: 'AI 草稿已回填',
      description: '请核对事实并润色后再保存 / 发布（AI 内容尚未落库）',
    });
  };

  return (
    <div className="space-y-6">
      {/* 顶部状态条 */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Badge variant={form.status === 'published' ? 'default' : 'secondary'}>
            {STATUS_LABEL[form.status]}
          </Badge>
          {publicUrl ? (
            <a
              href={publicUrl}
              target="_blank"
              rel="noreferrer"
              className="text-sm text-primary underline-offset-4 hover:underline"
            >
              {publicUrl}
            </a>
          ) : (
            <span className="text-sm text-muted-foreground">
              草稿不公开；把状态改为「已发布」并保存后生成公开链接
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => setAiOpen(true)}
            disabled={saving}
          >
            <MagicWand size={16} className="mr-1" /> AI 生成
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => void handlePreview()}
            disabled={!post || previewLoading}
            title={post ? '预览完整文章页' : '请先保存草稿后再预览'}
          >
            <Eye size={16} className="mr-1" /> {previewLoading ? '加载中…' : '预览'}
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => void handleCopy()}
            disabled={!publicUrl}
          >
            <Copy size={16} className="mr-1" /> {copied ? '已复制' : '复制链接'}
          </Button>
          {post && (
            <Button
              type="button"
              variant="destructive"
              size="sm"
              onClick={() => void handleDelete()}
              disabled={saving}
            >
              <Trash size={16} className="mr-1" /> 删除
            </Button>
          )}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[2fr_1fr]">
        {/* 左栏：正文 */}
        <div className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="blog-title">标题 *</Label>
            <Input
              id="blog-title"
              value={form.title}
              onChange={(e) => setField('title', e.target.value)}
              placeholder="例如：手机人像怎么拍才不像游客照？"
            />
          </div>

          <div className="space-y-2">
            <Label>正文（Markdown）</Label>
            <MarkdownEditor
              value={form.contentMd}
              onChange={(v) => setField('contentMd', v)}
              onUploadImage={async (file) => {
                const result = await uploadBlogImage(file, post?.id);
                if ('error' in result) {
                  toast({ variant: 'destructive', title: '上传失败', description: result.error });
                  return null;
                }
                return result.storageKey;
              }}
              disabled={saving}
            />
          </div>
        </div>

        {/* 右栏：发布设置 */}
        <div className="space-y-4">
          <div className="space-y-2">
            <Label>状态</Label>
            <Select
              value={form.status}
              onValueChange={(v) => setField('status', v as BlogStatus)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="draft">草稿（不公开）</SelectItem>
                <SelectItem value="published">已发布（公开可访问）</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>分类</Label>
            <Select
              value={form.categoryId || 'none'}
              onValueChange={(v) => setField('categoryId', v === 'none' ? '' : v)}
            >
              <SelectTrigger>
                <SelectValue placeholder="不分类" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">不分类</SelectItem>
                {categories.map((c) => (
                  <SelectItem key={c.id} value={String(c.id)}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>底部推广内容</Label>
            <Select
              value={form.promoMode}
              onValueChange={(v) => setField('promoMode', v as PromoMode)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {PROMO_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">
              全局开关与文案在「博客设置」中维护；此处置为「不显示」可单篇关闭。
            </p>
          </div>

          <Separator />

          <FileUpload
            label="封面图"
            accept="image/jpeg,image/png,image/webp"
            maxSize={COVER_MAX_BYTES}
            value={cover}
            onChange={setCover}
            previewUrl={coverPreview ?? undefined}
            hint="建议 16:9，不超过 5MB；公开列表页与文章页头图使用"
            disabled={saving}
          />

          <Separator />

          <div className="space-y-2">
            <Label htmlFor="blog-slug">URL 短名（slug）</Label>
            <Input
              id="blog-slug"
              value={form.slug}
              onChange={(e) => setField('slug', e.target.value)}
              placeholder="留空则按标题自动生成"
            />
            <p className="text-xs text-muted-foreground">
              公开地址为 <code>{siteBase}/blog/&lt;slug&gt;</code>；手填且已被占用时会提示冲突，留空自动追加
              `-2` / `-3` 去重。
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="blog-summary">摘要</Label>
            <Textarea
              id="blog-summary"
              value={form.summary}
              onChange={(e) => setField('summary', e.target.value)}
              rows={3}
              placeholder="列表页与分享卡片展示，建议 1~2 句"
            />
          </div>

          <Separator />

          <div className="space-y-2">
            <Label htmlFor="blog-seo-title">SEO 标题</Label>
            <Input
              id="blog-seo-title"
              value={form.seoTitle}
              onChange={(e) => setField('seoTitle', e.target.value)}
              placeholder="留空则用文章标题"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="blog-seo-desc">SEO 描述</Label>
            <Textarea
              id="blog-seo-desc"
              value={form.seoDescription}
              onChange={(e) => setField('seoDescription', e.target.value)}
              rows={3}
              placeholder="留空则用摘要；建议 60~120 字"
            />
          </div>
        </div>
      </div>

      <div className="flex items-center gap-3 border-t pt-4">
        <Button type="button" onClick={() => void handleSave()} disabled={saving}>
          {saving ? '保存中…' : '保存'}
        </Button>
        <Button
          type="button"
          variant="ghost"
          onClick={() => router.push('/dashboard/blog')}
          disabled={saving}
        >
          返回列表
        </Button>
      </div>

      <AiGenerateDialog
        open={aiOpen}
        onOpenChange={setAiOpen}
        categories={categories}
        onApply={handleAiApply}
      />

      <Dialog open={previewHtml !== null} onOpenChange={(o) => !o && setPreviewHtml(null)}>
        <DialogContent className="max-w-5xl p-2">
          <DialogTitle className="sr-only">文章页预览</DialogTitle>
          <iframe
            title="文章页预览"
            className="h-[80vh] w-full rounded-md border"
            srcDoc={previewHtml ?? ''}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default PostForm;
```

- [ ] **Step 3: 写新建页**

新建 `lumira-server/packages/admin/src/app/dashboard/blog/new/page.tsx`：

```tsx
// src/app/dashboard/blog/new/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import { PostForm } from '@/components/blog/post-form';
import type { BlogCategoryAdmin } from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function NewBlogPostPage() {
  let categories: BlogCategoryAdmin[];
  try {
    categories = await api.blogListCategories();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">分类加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Button asChild variant="ghost" size="sm">
        <Link href="/dashboard/blog">
          <ArrowLeft size={14} className="mr-1" /> 返回列表
        </Link>
      </Button>

      <Card>
        <CardHeader>
          <CardTitle className="text-left">新建博客</CardTitle>
        </CardHeader>
        <CardContent>
          <PostForm post={null} categories={categories} backendUrl={BACKEND_URL} />
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 4: 写编辑页**

新建 `lumira-server/packages/admin/src/app/dashboard/blog/[id]/page.tsx`：

```tsx
// src/app/dashboard/blog/[id]/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import { PostForm } from '@/components/blog/post-form';
import type { BlogCategoryAdmin, BlogPostAdminDetail } from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function EditBlogPostPage({ params }: { params: { id: string } }) {
  let post: BlogPostAdminDetail;
  let categories: BlogCategoryAdmin[];
  try {
    const [postResp, catResp] = await Promise.all([
      api.blogGetPost(params.id),
      api.blogListCategories(),
    ]);
    post = postResp;
    categories = catResp;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <Button asChild variant="ghost" size="sm">
        <Link href="/dashboard/blog">
          <ArrowLeft size={14} className="mr-1" /> 返回列表
        </Link>
      </Button>

      <Card>
        <CardHeader>
          <CardTitle className="text-left">编辑博客</CardTitle>
        </CardHeader>
        <CardContent>
          <PostForm post={post} categories={categories} backendUrl={BACKEND_URL} />
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 5: 构建校验 + 手工冒烟**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0。

Run: `cd lumira-server; pnpm --filter @lumira/admin dev`
Expected: 打开 `http://localhost:8888/dashboard/blog/new`，页面渲染出表单（左栏正文 + 右栏设置），无控制台报错。若本地未起后端，分类下拉为空、保存会报「无法连接后端服务」，属预期。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/blog/ai-generate-dialog.tsx lumira-server/packages/admin/src/components/blog/post-form.tsx lumira-server/packages/admin/src/app/dashboard/blog/new/page.tsx "lumira-server/packages/admin/src/app/dashboard/blog/[id]/page.tsx"
git commit -m "feat(admin): 博客文章表单、AI 生成弹窗与新建/编辑页"
git push origin master
git push github master
```

## Task 12: 文章列表页（状态 Tab / 筛选 / 一键发布 / 复制链接 / 删除）

**Files:**
- Create: `lumira-server/packages/admin/src/components/blog/post-table.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/blog/page.tsx`

**Interfaces:**
- Consumes: `api.blogListPosts(params)` / `api.blogListCategories()`（Task 9）；actions `setBlogPostStatus` / `removeBlogPost`（Task 9）；`Pagination`（既有组件）；`toAssetUrl`（既有）。
- Produces: 组件 `PostTable`，props：`{ items: BlogPostAdminListItem[]; backendUrl: string }`；页面 `/dashboard/blog`

- [ ] **Step 1: 写列表行操作组件**

新建 `lumira-server/packages/admin/src/components/blog/post-table.tsx`：

```tsx
// src/components/blog/post-table.tsx
'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { removeBlogPost, setBlogPostStatus } from '@/actions/blog';
import { Copy } from '@phosphor-icons/react/dist/csr/Copy';
import { PencilSimple } from '@phosphor-icons/react/dist/csr/PencilSimple';
import { Trash } from '@phosphor-icons/react/dist/csr/Trash';
import { Eye } from '@phosphor-icons/react/dist/csr/Eye';
import { EyeSlash } from '@phosphor-icons/react/dist/csr/EyeSlash';
import type { BlogPostAdminListItem } from '@/types/admin';

const PROMO_LABEL: Record<BlogPostAdminListItem['promoMode'], string> = {
  inherit: '跟随全局',
  on: '显示',
  off: '不显示',
};

function formatSec(value: number): string {
  return new Date(value * 1000).toLocaleString();
}

export function PostTable({
  items,
  backendUrl,
}: {
  items: BlogPostAdminListItem[];
  backendUrl: string;
}) {
  const router = useRouter();
  const { toast } = useToast();
  const [busyId, setBusyId] = useState<string | null>(null);

  const siteBase = backendUrl.replace(/\/+$/, '');

  const toggleStatus = async (item: BlogPostAdminListItem) => {
    const next = item.status === 'published' ? 'draft' : 'published';
    setBusyId(item.id);
    try {
      const result = await setBlogPostStatus(item.id, next);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '操作失败', description: result.error });
        return;
      }
      toast({
        title: next === 'published' ? '已发布' : '已取消发布',
        description:
          next === 'published'
            ? `${siteBase}/blog/${item.slug} 已可公开访问`
            : '该文章已从公开站移除（含列表页与 sitemap）',
      });
      router.refresh();
    } finally {
      setBusyId(null);
    }
  };

  const copyLink = async (item: BlogPostAdminListItem) => {
    await navigator.clipboard.writeText(`${siteBase}/blog/${item.slug}`);
    toast({ title: '公开链接已复制' });
  };

  const handleDelete = async (item: BlogPostAdminListItem) => {
    if (!window.confirm(`确认删除《${item.title}》？该操作不可恢复。`)) return;
    setBusyId(item.id);
    try {
      const result = await removeBlogPost(item.id);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '删除失败', description: result.error });
        return;
      }
      toast({ title: '已删除' });
      router.refresh();
    } finally {
      setBusyId(null);
    }
  };

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>标题</TableHead>
          <TableHead className="w-28">分类</TableHead>
          <TableHead className="w-24">状态</TableHead>
          <TableHead className="w-24">推广</TableHead>
          <TableHead className="w-44">更新时间</TableHead>
          <TableHead className="w-72">操作</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {items.length === 0 && (
          <TableRow>
            <TableCell colSpan={6} className="text-center text-muted-foreground">
              暂无文章
            </TableCell>
          </TableRow>
        )}
        {items.map((item) => (
          <TableRow key={item.id}>
            <TableCell>
              <Link
                href={`/dashboard/blog/${item.id}`}
                className="font-medium text-foreground hover:text-primary"
              >
                {item.title}
              </Link>
              <div className="mt-1 line-clamp-2 text-xs text-muted-foreground">
                {item.summary || '（无摘要）'}
              </div>
              <div className="mt-1 font-mono text-xs text-muted-foreground">/{item.slug}</div>
            </TableCell>
            <TableCell className="text-sm">{item.categoryName ?? '—'}</TableCell>
            <TableCell>
              <Badge variant={item.status === 'published' ? 'default' : 'secondary'}>
                {item.status === 'published' ? '已发布' : '草稿'}
              </Badge>
            </TableCell>
            <TableCell className="text-sm text-muted-foreground">
              {PROMO_LABEL[item.promoMode]}
            </TableCell>
            <TableCell className="text-sm text-muted-foreground">
              {formatSec(item.updatedAt)}
            </TableCell>
            <TableCell>
              <div className="flex flex-wrap items-center gap-1">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={busyId === item.id}
                  onClick={() => void toggleStatus(item)}
                >
                  {item.status === 'published' ? (
                    <>
                      <EyeSlash size={14} className="mr-1" /> 取消发布
                    </>
                  ) : (
                    <>
                      <Eye size={14} className="mr-1" /> 发布
                    </>
                  )}
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={item.status !== 'published'}
                  onClick={() => void copyLink(item)}
                  title={item.status === 'published' ? '复制公开链接' : '草稿无公开链接'}
                >
                  <Copy size={14} />
                </Button>
                <Button asChild variant="ghost" size="sm">
                  <Link href={`/dashboard/blog/${item.id}`}>
                    <PencilSimple size={14} />
                  </Link>
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  disabled={busyId === item.id}
                  onClick={() => void handleDelete(item)}
                >
                  <Trash size={14} className="text-destructive" />
                </Button>
              </div>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

export default PostTable;
```

- [ ] **Step 2: 写列表页**

新建 `lumira-server/packages/admin/src/app/dashboard/blog/page.tsx`：

```tsx
// src/app/dashboard/blog/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Pagination } from '@/components/pagination';
import { PostTable } from '@/components/blog/post-table';
import { Plus } from '@phosphor-icons/react/dist/ssr/Plus';
import { GridFour } from '@phosphor-icons/react/dist/ssr/GridFour';
import { GearSix } from '@phosphor-icons/react/dist/ssr/GearSix';
import { cn } from '@/lib/utils';
import type { BlogCategoryAdmin, BlogPostAdminListResponse, BlogStatus } from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

const STATUS_TABS: { value: 'all' | BlogStatus; label: string }[] = [
  { value: 'all', label: '全部' },
  { value: 'draft', label: '草稿' },
  { value: 'published', label: '已发布' },
];

type ParamValue = string | string[] | undefined;

function pick(value: ParamValue): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

export default async function BlogListPage({
  searchParams,
}: {
  searchParams: Record<string, ParamValue>;
}) {
  const statusParam = pick(searchParams.status);
  const status: 'all' | BlogStatus =
    statusParam === 'draft' || statusParam === 'published' ? statusParam : 'all';
  const categoryIdParam = pick(searchParams.categoryId);
  const categoryId = categoryIdParam ? Number(categoryIdParam) : undefined;
  const keyword = pick(searchParams.keyword);
  const page = Number(pick(searchParams.page)) || 1;
  const pageSize = Number(pick(searchParams.pageSize)) || 20;

  let list: BlogPostAdminListResponse;
  let categories: BlogCategoryAdmin[];
  try {
    const [listResp, catResp] = await Promise.all([
      api.blogListPosts({ status, categoryId, keyword, page, pageSize }),
      api.blogListCategories(),
    ]);
    list = listResp;
    categories = catResp;
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">加载失败：{(e as Error).message}</div>;
  }

  /** 保留现有筛选条件，仅覆盖指定字段 */
  function hrefWith(overrides: Record<string, string | undefined>): string {
    const params = new URLSearchParams();
    const merged: Record<string, string | undefined> = {
      status: status === 'all' ? undefined : status,
      categoryId: categoryIdParam,
      keyword,
      page: undefined,
      pageSize: pageSize === 20 ? undefined : String(pageSize),
      ...overrides,
    };
    Object.entries(merged).forEach(([k, v]) => {
      if (v !== undefined && v !== '') params.set(k, v);
    });
    const qs = params.toString();
    return `/dashboard/blog${qs ? `?${qs}` : ''}`;
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-1">
          {STATUS_TABS.map((tab) => (
            <Link
              key={tab.value}
              href={hrefWith({ status: tab.value === 'all' ? undefined : tab.value, page: undefined })}
              className={cn(
                'rounded-md px-3 py-1.5 text-sm transition-colors',
                status === tab.value
                  ? 'bg-primary/10 font-medium text-primary'
                  : 'text-muted-foreground hover:bg-accent/40',
              )}
            >
              {tab.label}
            </Link>
          ))}
        </div>
        <div className="flex items-center gap-2">
          <Button asChild variant="outline" size="sm">
            <Link href="/dashboard/blog/categories">
              <GridFour size={16} className="mr-1" /> 分类管理
            </Link>
          </Button>
          <Button asChild variant="outline" size="sm">
            <Link href="/dashboard/blog/settings">
              <GearSix size={16} className="mr-1" /> 博客设置
            </Link>
          </Button>
          <Button asChild size="sm">
            <Link href="/dashboard/blog/new">
              <Plus size={16} className="mr-1" /> 新建博客
            </Link>
          </Button>
        </div>
      </div>

      <Card>
        <CardContent className="space-y-4 pt-6">
          {/* GET 表单：服务端渲染筛选，无需客户端状态 */}
          <form method="get" action="/dashboard/blog" className="flex flex-wrap items-end gap-3">
            {status !== 'all' && <input type="hidden" name="status" value={status} />}
            <div className="w-64 space-y-1">
              <label htmlFor="blog-keyword" className="text-xs text-muted-foreground">
                关键词（标题 / 摘要）
              </label>
              <Input
                id="blog-keyword"
                name="keyword"
                defaultValue={keyword ?? ''}
                placeholder="输入后回车搜索"
              />
            </div>
            <div className="w-48 space-y-1">
              <label htmlFor="blog-category" className="text-xs text-muted-foreground">
                分类
              </label>
              <select
                id="blog-category"
                name="categoryId"
                defaultValue={categoryIdParam ?? ''}
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
              >
                <option value="">全部分类</option>
                {categories.map((c) => (
                  <option key={c.id} value={String(c.id)}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            <Button type="submit" variant="secondary">
              筛选
            </Button>
            <Button asChild variant="ghost">
              <Link href="/dashboard/blog">重置</Link>
            </Button>
          </form>

          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <span>共 {list.total} 篇</span>
            {keyword && <Badge variant="outline">关键词：{keyword}</Badge>}
            {categoryIdParam && (
              <Badge variant="outline">
                分类：{categories.find((c) => String(c.id) === categoryIdParam)?.name ?? categoryIdParam}
              </Badge>
            )}
          </div>

          <PostTable items={list.items} backendUrl={BACKEND_URL} />

          <Pagination
            page={list.page}
            pageSize={list.pageSize}
            total={list.total}
            basePath="/dashboard/blog"
            searchParams={{
              status: status === 'all' ? undefined : status,
              categoryId: categoryIdParam,
              keyword,
            }}
          />
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 3: 构建校验**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0。

- [ ] **Step 4: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/blog/post-table.tsx lumira-server/packages/admin/src/app/dashboard/blog/page.tsx
git commit -m "feat(admin): 博客文章列表（状态 Tab / 筛选 / 一键发布 / 复制链接 / 删除）"
git push origin master
git push github master
```

## Task 13: 分类管理页 + 站点/推广设置页

**Files:**
- Create: `lumira-server/packages/admin/src/components/blog/category-manager.tsx`
- Create: `lumira-server/packages/admin/src/components/blog/settings-form.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/blog/categories/page.tsx`
- Create: `lumira-server/packages/admin/src/app/dashboard/blog/settings/page.tsx`

**Interfaces:**
- Consumes: `api.blogListCategories()` / `api.blogGetSettings()`（Task 9）；actions `saveBlogCategory(id, payload)` / `removeBlogCategory(id)` / `saveBlogSettings(payload, qr)`（Task 9，均返回 `{ success: true } | { error: string }`）；类型 `BlogCategoryAdmin` / `BlogSettingsAdmin` / `BlogCategoryPayload` / `BlogSettingsPayload`（Task 9）；既有 `Table*` / `Dialog*` / `Button` / `Input` / `Label` / `Textarea` / `Switch` / `Card*` / `FileUpload` / `compressImage` / `toAssetUrl` / `useToast`。
- Produces: 客户端组件 `BlogCategoryManager`（props `{ categories: BlogCategoryAdmin[] }`）、`BlogSettingsForm`（props `{ settings: BlogSettingsAdmin; backendUrl: string }`）；页面 `/dashboard/blog/categories`、`/dashboard/blog/settings`。

- [ ] **Step 1: 写分类管理客户端组件**

新建 `lumira-server/packages/admin/src/components/blog/category-manager.tsx`：

```tsx
// src/components/blog/category-manager.tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription,
} from '@/components/ui/dialog';
import { Plus } from '@phosphor-icons/react/dist/csr/Plus';
import { PencilSimple } from '@phosphor-icons/react/dist/csr/PencilSimple';
import { Trash } from '@phosphor-icons/react/dist/csr/Trash';
import { FolderOpen } from '@phosphor-icons/react/dist/csr/FolderOpen';
import { useToast } from '@/hooks/use-toast';
import { removeBlogCategory, saveBlogCategory } from '@/actions/blog';
import type { BlogCategoryAdmin } from '@/types/admin';

interface FormState {
  key: string;
  name: string;
  description: string;
  sortOrder: number;
}

const EMPTY_FORM: FormState = { key: '', name: '', description: '', sortOrder: 0 };

/** 与后端 BlogService.CATEGORY_KEY_RE 完全一致 */
const CATEGORY_KEY_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export function BlogCategoryManager({ categories }: { categories: BlogCategoryAdmin[] }) {
  const router = useRouter();
  const { toast } = useToast();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [error, setError] = useState<string | null>(null);
  const [submitPending, startSubmit] = useTransition();
  const [confirmTarget, setConfirmTarget] = useState<BlogCategoryAdmin | null>(null);
  const [deletePending, startDelete] = useTransition();

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError(null);
    setDialogOpen(true);
  };

  const openEdit = (cat: BlogCategoryAdmin) => {
    setEditingId(cat.id);
    setForm({
      key: cat.key,
      name: cat.name,
      description: cat.description,
      sortOrder: cat.sortOrder,
    });
    setError(null);
    setDialogOpen(true);
  };

  const handleSubmit = () => {
    setError(null);
    const key = form.key.trim();
    const name = form.name.trim();
    if (!editingId && !CATEGORY_KEY_RE.test(key)) {
      setError('分类 key 只能包含小写字母、数字与连字符（-），如 camera-tips');
      return;
    }
    if (!name) {
      setError('请填写分类名称');
      return;
    }

    startSubmit(async () => {
      const result = await saveBlogCategory(editingId, {
        key,
        name,
        description: form.description.trim(),
        sortOrder: Number(form.sortOrder) || 0,
      });
      if ('error' in result) {
        setError(result.error);
        return;
      }
      toast({
        title: editingId ? '已更新' : '已创建',
        description: `分类「${name}」已保存`,
      });
      setDialogOpen(false);
      router.refresh();
    });
  };

  const handleDelete = (cat: BlogCategoryAdmin) => {
    startDelete(async () => {
      const result = await removeBlogCategory(cat.id);
      if ('error' in result) {
        toast({ variant: 'destructive', title: '删除失败', description: result.error });
        return;
      }
      toast({ title: '已删除', description: `分类「${cat.name}」已删除` });
      setConfirmTarget(null);
      router.refresh();
    });
  };

  const deleting = deletePending && confirmTarget !== null;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-baseline gap-2.5">
          <h2 className="text-lg font-semibold tracking-tight text-foreground">博客分类</h2>
          <span className="hidden text-xs text-muted-foreground md:inline">
            公开列表页按 /blog/category/:key 归类
          </span>
        </div>
        <Button size="sm" onClick={openCreate}>
          <Plus size={16} className="mr-1" /> 新建分类
        </Button>
      </div>

      <div className="overflow-hidden rounded-lg border border-border bg-card shadow-sm">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/40 hover:bg-muted/40">
              <TableHead className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                名称
              </TableHead>
              <TableHead className="w-44 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                Key
              </TableHead>
              <TableHead className="w-20 text-xs font-medium uppercase tracking-wide text-muted-foreground">
                排序
              </TableHead>
              <TableHead className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                描述
              </TableHead>
              <TableHead className="w-24 text-right text-xs font-medium uppercase tracking-wide text-muted-foreground">
                操作
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {categories.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="py-16 text-center">
                  <div className="mx-auto flex max-w-sm flex-col items-center gap-2">
                    <FolderOpen size={28} className="text-muted-foreground/40" />
                    <p className="text-sm text-muted-foreground">
                      暂无分类，点击右上角「新建分类」创建
                    </p>
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              categories.map((c) => (
                <TableRow key={c.id}>
                  <TableCell className="py-2.5">
                    <span className="text-sm font-medium text-foreground">{c.name}</span>
                  </TableCell>
                  <TableCell className="py-2.5">
                    <code className="font-mono text-xs text-muted-foreground">{c.key}</code>
                  </TableCell>
                  <TableCell className="py-2.5 text-sm tabular-nums text-muted-foreground">
                    {c.sortOrder}
                  </TableCell>
                  <TableCell className="py-2.5">
                    <span className="line-clamp-2 text-sm text-muted-foreground">
                      {c.description || '—'}
                    </span>
                  </TableCell>
                  <TableCell className="py-2.5 text-right">
                    <div className="flex items-center justify-end gap-0.5">
                      <button
                        type="button"
                        title="编辑"
                        onClick={() => openEdit(c)}
                        className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                      >
                        <PencilSimple size={15} />
                      </button>
                      <button
                        type="button"
                        title="删除"
                        onClick={() => setConfirmTarget(c)}
                        className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                      >
                        <Trash size={15} />
                      </button>
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-left">
              {editingId ? '编辑分类' : '新建分类'}
            </DialogTitle>
            <DialogDescription className="text-left">
              {editingId
                ? '分类 key 为公开链接标识，创建后不可修改。'
                : '分类用于公开列表页归类，key 会出现在 /blog/category/:key 链接中。'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="blog-cat-key">Key *</Label>
              <Input
                id="blog-cat-key"
                value={form.key}
                onChange={(e) => setForm({ ...form, key: e.target.value })}
                placeholder="如：camera-tips"
                disabled={Boolean(editingId)}
                className="font-mono"
              />
              <p className="text-xs text-muted-foreground">
                {editingId
                  ? '已有分类的 key 不可修改。'
                  : '小写字母 / 数字 / 连字符，如 camera-tips。'}
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="blog-cat-name">名称 *</Label>
              <Input
                id="blog-cat-name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="如：拍摄技巧"
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="blog-cat-desc">描述（可选）</Label>
              <Textarea
                id="blog-cat-desc"
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                placeholder="一句话介绍该分类，用于公开列表页与 SEO description"
                rows={2}
                maxLength={200}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="blog-cat-sort">排序</Label>
              <Input
                id="blog-cat-sort"
                type="number"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
              />
              <p className="text-xs text-muted-foreground">数字越小越靠前。</p>
            </div>
          </div>

          {error && <p className="text-sm text-destructive" role="alert">{error}</p>}

          <DialogFooter>
            <Button variant="ghost" onClick={() => setDialogOpen(false)} disabled={submitPending}>
              取消
            </Button>
            <Button onClick={handleSubmit} disabled={submitPending}>
              {submitPending ? '保存中…' : editingId ? '保存' : '创建'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog
        open={confirmTarget !== null}
        onOpenChange={(open) => !open && setConfirmTarget(null)}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-left">删除分类</DialogTitle>
            <DialogDescription className="text-left">
              确定要删除分类「{confirmTarget?.name}」({confirmTarget?.key}) 吗？
              该分类下的文章不会被删除，但会变为「未分类」。
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setConfirmTarget(null)} disabled={deleting}>
              取消
            </Button>
            <Button
              variant="destructive"
              disabled={deleting}
              onClick={() => confirmTarget && handleDelete(confirmTarget)}
            >
              {deleting ? '删除中…' : '确认删除'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default BlogCategoryManager;
```

- [ ] **Step 2: 写设置表单客户端组件**

新建 `lumira-server/packages/admin/src/components/blog/settings-form.tsx`：

```tsx
// src/components/blog/settings-form.tsx
'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import { FileUpload } from '@/components/ui/file-upload';
import { useToast } from '@/hooks/use-toast';
import { saveBlogSettings } from '@/actions/blog';
import { compressImage } from '@/lib/image-compress';
import { toAssetUrl } from '@/lib/asset-url';
import type { BlogSettingsAdmin } from '@/types/admin';

const QR_MAX_BYTES = 2 * 1024 * 1024;

/** 三块推广内容中，可编辑的字段名 */
type PromoField =
  | 'promoOfficialTitle' | 'promoOfficialBody'
  | 'promoAppTitle' | 'promoAppBody'
  | 'promoWechatTitle' | 'promoWechatBody';

export function BlogSettingsForm({
  settings,
  backendUrl,
}: {
  settings: BlogSettingsAdmin;
  backendUrl: string;
}) {
  const router = useRouter();
  const { toast } = useToast();
  const [form, setForm] = useState<BlogSettingsAdmin>(settings);
  const [qrFile, setQrFile] = useState<File | null>(null);
  const [pending, startSave] = useTransition();

  const setField = (key: PromoField | 'blogTitle' | 'blogDescription', value: string) =>
    setForm((prev) => ({ ...prev, [key]: value }));

  const handleQr = async (file: File | null) => {
    if (!file) {
      setQrFile(null);
      return;
    }
    try {
      setQrFile(await compressImage(file, { maxDim: 720, quality: 0.9, maxBytes: QR_MAX_BYTES }));
    } catch {
      setQrFile(file);
    }
  };

  const handleSave = () => {
    startSave(async () => {
      const result = await saveBlogSettings(
        {
          promoEnabled: form.promoEnabled,
          blogTitle: form.blogTitle,
          blogDescription: form.blogDescription,
          promoOfficialTitle: form.promoOfficialTitle,
          promoOfficialBody: form.promoOfficialBody,
          promoAppTitle: form.promoAppTitle,
          promoAppBody: form.promoAppBody,
          promoWechatTitle: form.promoWechatTitle,
          promoWechatBody: form.promoWechatBody,
        },
        qrFile,
      );
      if ('error' in result) {
        toast({ variant: 'destructive', title: '保存失败', description: result.error });
        return;
      }
      toast({ title: '已保存', description: '博客与推广设置已更新' });
      setQrFile(null);
      router.refresh();
    });
  };

  const blocks: Array<{ heading: string; hint: string; title: PromoField; body: PromoField }> = [
    {
      heading: 'Lumira 官方信息',
      hint: '介绍 Lumira 是什么。留空则公开页不渲染该块。',
      title: 'promoOfficialTitle',
      body: 'promoOfficialBody',
    },
    {
      heading: 'APP 推广',
      hint: '引导读者下载 / 使用 Lumira。留空则公开页不渲染该块。',
      title: 'promoAppTitle',
      body: 'promoAppBody',
    },
    {
      heading: '公众号信息',
      hint: '例如「关注微信公众号获取更多相关资讯」。可另上传二维码，留空则不渲染该块。',
      title: 'promoWechatTitle',
      body: 'promoWechatBody',
    },
  ];

  return (
    <div className="space-y-5">
      <Card>
        <CardHeader>
          <CardTitle className="text-left text-base">站点信息</CardTitle>
          <CardDescription className="text-left">
            用于公开博客列表页 /blog 的标题与 SEO description。
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="blog-title">博客标题</Label>
            <Input
              id="blog-title"
              value={form.blogTitle}
              onChange={(e) => setField('blogTitle', e.target.value)}
              placeholder="如：Lumira 摄影手记"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="blog-desc">博客描述</Label>
            <Textarea
              id="blog-desc"
              value={form.blogDescription}
              onChange={(e) => setField('blogDescription', e.target.value)}
              placeholder="一句话介绍博客内容，用于列表页与 SEO"
              rows={3}
              maxLength={300}
            />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-left text-base">推广开关</CardTitle>
          <CardDescription className="text-left">
            全局默认值。单篇文章可在编辑页改为「显示」或「不显示」以覆盖此处设置。
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-3">
            <Switch
              checked={form.promoEnabled}
              onCheckedChange={(checked) => setForm((prev) => ({ ...prev, promoEnabled: checked }))}
            />
            <span className="text-sm text-muted-foreground">
              {form.promoEnabled ? '开启：文章底部默认附加推广内容' : '关闭：文章底部默认不附加推广内容'}
            </span>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-left text-base">推广内容</CardTitle>
          <CardDescription className="text-left">
            展示在公开文章底部（推广开关为「显示」时）。三块中任意一块的标题与正文都为空，则该块不渲染。
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {blocks.map((b) => (
            <div key={b.title} className="space-y-3 rounded-lg border border-border p-4">
              <div>
                <p className="text-sm font-semibold text-foreground">{b.heading}</p>
                <p className="text-xs text-muted-foreground">{b.hint}</p>
              </div>
              <div className="space-y-2">
                <Label htmlFor={`${b.title}-input`}>标题</Label>
                <Input
                  id={`${b.title}-input`}
                  value={form[b.title]}
                  onChange={(e) => setField(b.title, e.target.value)}
                  placeholder={`${b.heading}标题`}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor={`${b.body}-input`}>正文</Label>
                <Textarea
                  id={`${b.body}-input`}
                  value={form[b.body]}
                  onChange={(e) => setField(b.body, e.target.value)}
                  placeholder={`${b.heading}正文，支持换行`}
                  rows={4}
                  maxLength={1000}
                />
              </div>
            </div>
          ))}

          <FileUpload
            label="公众号二维码（可选）"
            accept="image/*"
            maxSize={5 * 1024 * 1024}
            value={qrFile}
            onChange={handleQr}
            hint="支持 jpg / png / webp，上传前自动压缩到约 2MB。展示在公众号推广块内。"
            previewUrl={toAssetUrl(form.promoWechatQrUrl, backendUrl) || undefined}
          />
        </CardContent>
      </Card>

      <div className="flex justify-end">
        <Button onClick={handleSave} disabled={pending}>
          {pending ? '保存中…' : '保存设置'}
        </Button>
      </div>
    </div>
  );
}

export default BlogSettingsForm;
```

- [ ] **Step 3: 写分类管理页**

新建 `lumira-server/packages/admin/src/app/dashboard/blog/categories/page.tsx`：

```tsx
// src/app/dashboard/blog/categories/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import { BlogCategoryManager } from '@/components/blog/category-manager';
import type { BlogCategoryAdmin } from '@/types/admin';

export default async function BlogCategoriesPage() {
  let categories: BlogCategoryAdmin[];
  try {
    categories = await api.blogListCategories();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">分类加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <Button asChild variant="ghost" size="sm">
          <Link href="/dashboard/blog">
            <ArrowLeft size={14} className="mr-1" /> 返回列表
          </Link>
        </Button>
        <Button asChild variant="outline" size="sm">
          <Link href="/dashboard/blog/settings">博客设置</Link>
        </Button>
      </div>

      <Card>
        <CardContent className="pt-6">
          <BlogCategoryManager categories={categories} />
        </CardContent>
      </Card>
    </div>
  );
}
```

- [ ] **Step 4: 写设置页**

新建 `lumira-server/packages/admin/src/app/dashboard/blog/settings/page.tsx`：

```tsx
// src/app/dashboard/blog/settings/page.tsx
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from '@phosphor-icons/react/dist/ssr/ArrowLeft';
import { BlogSettingsForm } from '@/components/blog/settings-form';
import type { BlogSettingsAdmin } from '@/types/admin';

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

export default async function BlogSettingsPage() {
  let settings: BlogSettingsAdmin;
  try {
    settings = await api.blogGetSettings();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return <div className="text-destructive">设置加载失败：{(e as Error).message}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3">
        <Button asChild variant="ghost" size="sm">
          <Link href="/dashboard/blog">
            <ArrowLeft size={14} className="mr-1" /> 返回列表
          </Link>
        </Button>
        <Button asChild variant="outline" size="sm">
          <Link href="/dashboard/blog/categories">分类管理</Link>
        </Button>
      </div>

      <BlogSettingsForm settings={settings} backendUrl={BACKEND_URL} />
    </div>
  );
}
```

- [ ] **Step 5: 构建校验**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0。

- [ ] **Step 6: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/blog/category-manager.tsx lumira-server/packages/admin/src/components/blog/settings-form.tsx lumira-server/packages/admin/src/app/dashboard/blog/categories/page.tsx lumira-server/packages/admin/src/app/dashboard/blog/settings/page.tsx
git commit -m "feat(admin): 博客分类管理与站点/推广设置页"
git push origin master
git push github master
```

## Task 14: 后台导航接线（侧边栏入口 + 顶部标题）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`
- Modify: `lumira-server/packages/admin/src/components/dashboard-shell.tsx`

**Interfaces:**
- Consumes: Task 12 / Task 13 建立的页面路径 `/dashboard/blog`、`/dashboard/blog/new`、`/dashboard/blog/[id]`、`/dashboard/blog/categories`、`/dashboard/blog/settings`。
- Produces: 侧边栏导航项 `/dashboard/blog`（label「博客」）；顶部标题映射（`/dashboard/blog` → 博客、`new` → 新建博客、`categories` → 博客分类、`settings` → 博客设置、`[id]` → 编辑博客）。

- [ ] **Step 1: 在侧边栏追加「博客」入口**

修改 `lumira-server/packages/admin/src/components/sidebar.tsx`。

在 `import { Database } from '@phosphor-icons/react/dist/csr/Database';` 之后追加一行：

```tsx
import { NotePencil } from '@phosphor-icons/react/dist/csr/NotePencil';
```

在 `navItems` 数组中，`{ href: '/dashboard/scenes', label: '场景管理', icon: Camera },` 之后追加一行（内容类归在场景管理之后、基础设施类（图片迁移 / 存储配置）之前）：

```tsx
  { href: '/dashboard/blog', label: '博客', icon: NotePencil },
```

- [ ] **Step 2: 在顶部标题映射中补博客路径**

修改 `lumira-server/packages/admin/src/components/dashboard-shell.tsx`。

在 `titleMap` 中 `'/dashboard/scenes': '场景管理',` 之后追加四行：

```tsx
  '/dashboard/blog': '博客',
  '/dashboard/blog/new': '新建博客',
  '/dashboard/blog/categories': '博客分类',
  '/dashboard/blog/settings': '博客设置',
```

在 `resolveTitle()` 中 `if (pathname.match(/\/dashboard\/templates\/[^/]+$/)) return '模板详情';` 之后追加一行（`/dashboard/blog/new` 等已在 titleMap 命中，只有文章 ID 会落到这里）：

```tsx
  if (pathname.match(/\/dashboard\/blog\/[^/]+$/)) return '编辑博客';
```

> 注意顺序：`titleMap[pathname]` 的精确命中在正则之前执行，因此 `/dashboard/blog/new` 会得到「新建博客」而不会被这条正则截走。

- [ ] **Step 3: 构建校验**

Run: `cd lumira-server; pnpm --filter @lumira/admin build`
Expected: 退出码 0。

- [ ] **Step 4: 提交并推送**

```bash
git add lumira-server/packages/admin/src/components/sidebar.tsx lumira-server/packages/admin/src/components/dashboard-shell.tsx
git commit -m "feat(admin): 侧边栏新增博客入口与顶部标题映射"
git push origin master
git push github master
```

## Task 15: 登记后续优化（YAGNI 清单）

**Files:**
- Modify: `docs/future-optimizations.md`（仅追加，不改动既有条目）

**Interfaces:**
- Consumes: 无（纯文档）。
- Produces: 无（下游无代码依赖）。

- [ ] **Step 1: 追加博客模块的后续优化条目**

在 `docs/future-optimizations.md` **文件末尾**追加以下内容（既有条目一律不改）：

```markdown

---

## 后台图文博客（2026-09-28）

> 设计：`docs/specs/2026-09-28-admin-blog-design.md`；计划：`docs/superpowers/plans/2026-09-28-admin-blog.md`。
>
> 以下为 spec 阶段明确排除（YAGNI）、或实现阶段刻意简化而留待后续补齐的能力。

### P1 · `blog/drafts/` 目录的孤儿文件无清理机制

- **模块**：后端博客模块（`lumira-server/packages/backend/src/modules/blog/blog.service.ts` 的 `uploadImage`）
- **优化点**：编辑器插图在没有文章 ID 时（新建页尚未保存）写到 `blog/drafts/{nanoid}.{ext}`。文章保存后，插图键**不会**改写到 `blog/{postId}/` 下；若用户中途放弃创建、或插入后又删掉图片，这些文件会永久滞留在 `blog/drafts/`，没有任何回收路径。
- **背景/动机**：本期为「新建即插图」提供可用路径，按最小改动直接写 drafts 目录；孤儿清理需要按「引用关系扫描 + 时间阈值」判定，属独立的后台运维能力。
- **目标状态**：新增定时任务（或后台「博客图片清理」入口）：列出 `blog/drafts/` 下的键，扫描 `blog_posts.content_md` / `cover_url` 是否仍引用，未被引用且超过 N 天的文件删除；或改为「文章首次保存时把 drafts 插图迁移到 `blog/{postId}/`」。

### P1 · 正文插图未压缩、未生成缩略图

- **模块**：后台博客编辑器（`lumira-server/packages/admin/src/components/blog/markdown-editor.tsx` 的 `onUploadImage`）→ 后端 `blog.service.ts` 的 `uploadImage`
- **优化点**：插图由 `FileUpload` 直接取原图上传，未过 `compressImage()`（封面与公众号二维码有压缩，插图没有）。手机直出 5-10MB 的图会原样落盘并由公开页 `<img>` 全尺寸加载，拖慢首屏、放大带宽。
- **背景/动机**：本期优先跑通「插图上传 + 公开页渲染」，未在编辑器内加压缩环节（编辑器是多入口组件，压缩需在调用侧统一）。
- **目标状态**：在编辑器上传回调里对 `image/*` 走 `compressImage(file, { maxDim: 1600, quality: 0.85, maxBytes: 1.5MB })`（SVG 跳过）；后续如需考虑生成 `-thumb` 变体供列表页使用。

### P2 · 无 RSS / Atom 订阅

- **模块**：后端博客公开路由（`lumira-server/packages/backend/src/modules/blog/public/register-public-routes.ts`）
- **优化点**：公开页只有列表 / 分类 / 文章 / sitemap / robots，没有 `/blog/rss.xml`。
- **背景/动机**：spec 阶段明确不做（用户确认 SEO 范围 = 列表页 + sitemap/robots + 结构化数据）。
- **目标状态**：新增 `/blog/rss.xml`，输出最近 N 篇已发布文章的 title / link / pubDate / description，`Content-Type: application/rss+xml`。

### P2 · 未主动推送搜索引擎

- **模块**：后端博客模块（发布状态变更处 `PATCH /admin/blog/posts/:id/status`）
- **优化点**：发布后只依赖 sitemap 被动收录，没有 IndexNow / 百度站长等主动提交。
- **背景/动机**：spec 阶段明确排除（不做主动推送），避免引入第三方密钥与配额管理。
- **目标状态**：发布/取消发布时按配置调用 IndexNow（或百度站长 API）提交 URL，失败只记日志不影响发布结果。

### P2 · 无评论 / 点赞 / 阅读量

- **模块**：后端博客公开页 + 后台
- **优化点**：文章页无互动能力，也无阅读量统计，后台无法看到哪篇受欢迎。
- **背景/动机**：spec 阶段明确排除（评论与阅读量不在本期范围）；互动数据涉及反垃圾、去重与额外表结构，属独立子系统。
- **目标状态**：按需新增评论表（含审核态）或轻量阅读量计数（`blog_post_stats`，按 IP/设备去重），后台文章列表展示阅读量并支持排序。

### P2 · 无站内搜索

- **模块**：后端博客公开页（列表页 `renderListPage`）
- **优化点**：`GET /blog` 只支持分类筛选与分页，没有关键词搜索；文章多了以后无法定位。
- **背景/动机**：spec 未包含搜索，本期列表页保持简单（分类 + 分页）。
- **目标状态**：`/blog?q=` 对 `title` / `summary` / `content_md` 做 `LIKE` 检索（数据量大后改全文索引），列表页补搜索框并同步 SEO（`noindex` 搜索结果页）。

### P2 · 不支持多作者与角色权限

- **模块**：后台权限（`lumira-server/packages/admin/src/lib/auth.ts`）+ 后端 `blog_posts`
- **优化点**：博客沿用单一 Admin Token 鉴权，无作者字段、无「编辑只能改自己的稿」这类权限区分。
- **背景/动机**：spec 阶段明确排除（不做多作者）。
- **目标状态**：`blog_posts` 增加 `author_id`，后台接入账号体系（或按管理员邮箱区分），列表页显示作者并按作者过滤。

### P2 · 无定时发布

- **模块**：后端博客模块（`blog_posts.status` / `published_at`）
- **优化点**：状态只有 `draft` / `published`，无法约定「未来某时刻自动发布」。
- **背景/动机**：spec 阶段明确排除（不做定时发布）。
- **目标状态**：新增 `scheduled_at` 字段与 `scheduled` 状态，定时任务到点把状态切为 `published` 并写入 `published_at`；列表页展示「已排期」。

### P2 · 无版本历史与回滚

- **模块**：后端 `blog_posts` + 后台编辑页
- **优化点**：`PATCH` 直接覆盖 `content_md`，改错了只能手动还原，无法查看历史版本。
- **背景/动机**：spec 阶段明确排除（不做版本历史）。
- **目标状态**：新增 `blog_post_revisions`（post_id / content_md / title / created_at），每次保存生成一条快照，编辑页提供「历史版本」抽屉与「回滚到该版本」。

### P2 · 封面 / 二维码换扩展名时旧文件残留

- **模块**：后端博客模块（`blog.service.ts` 的 `updatePost` 封面写入、`updateSettings` 二维码写入）
- **优化点**：文件名固定为 `cover.{ext}` / `wechat-qr.{ext}`，扩展名随上传文件变化。同一篇文章先传 `.png` 再传 `.jpg` 时，`cover.png` 不会被删除，磁盘上留下不再被引用的旧文件（DB 只指向新 URL）。
- **背景/动机**：沿用既有存储抽象（`storage.write` 只写入、不负责清理同名前缀的其他扩展名），与模板封面行为一致，故本期不额外处理。
- **目标状态**：写入前用 `storage.listKeys('blog', postId)` 列出同目录文件，删掉除新文件外的旧封面/剪影类固定名文件；或统一把封面重命名为固定 `cover`（不带扩展名由适配器兜底）以天然覆盖。
```

- [ ] **Step 2: 提交**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记图文博客模块的后续优化项"
```

> 本 Task 为纯文档改动，按项目规则「仅纯文档或注释改动可由用户决定是否推送」，**不执行** `git push`；待用户确认后再决定是否同步到两个远程。

---

## 完成标准（Definition of Done）

全部 15 个 Task 完成后，以下场景应手工验证通过（本地需同时起后端与后台）：

1. **迁移与表结构**：启动后端，`_migrations` 表出现 `048_blog.sql` 记录；`blog_categories` / `blog_posts` / `blog_settings` 三表存在，`blog_settings` 有 1 行种子数据（`promo_enabled = 1`）。
2. **草稿 → 发布 → 取消发布**：后台 `/dashboard/blog/new` 新建并保存为草稿（`status = draft`），公开链接 `/blog/{slug}` 返回 **404**；列表页点「发布」后同一链接返回 200 且渲染正文；再点「取消发布」又回到 404。
3. **SEO 输出**：已发布文章页 `<head>` 含 `<title>`、`meta[name=description]`、`link[rel=canonical]`、`og:*` 标签与 JSON-LD `BlogPosting`；`/sitemap.xml` 只列已发布文章；`/robots.txt` 指向 sitemap（二者均为**根路径**裸路由，非 `/blog` 前缀）。
4. **推广开关**：全局开关开启且文章 `promo_mode = inherit` 时，文章底部渲染三块推广内容；把某篇改为 `off` 后该篇不再渲染；三块中标题与正文均为空的块不渲染。
5. **AI 生成**：`/dashboard/blog/new` 的 AI 弹窗输入主题后返回草稿并回填表单（标题 / 摘要 / SEO 描述 / 正文 / 分类），且**不落库**。
6. **Markdown 安全**：在正文中写入 `<script>alert(1)</script>` 与 `<iframe src=...>`，公开页输出中两者均被净化移除；`on*` 属性同样被剥离。
7. **图片链路**：上传封面后公开页与后台列表都能显示（后台经 `/uploads/*` 代理、Flutter/公开页用绝对 URL）；编辑器插图上传后正文 `<img>` 可访问。
8. **分类**：新建分类 → 文章归入该分类 → 公开页 `/blog/category/{key}` 只列该分类文章；删除分类后其下文章变为「未分类」且仍可访问。
9. **导航**：侧边栏出现「博客」入口，顶部标题在 `/dashboard/blog`、`/dashboard/blog/new`、`/dashboard/blog/{id}`、`/dashboard/blog/categories`、`/dashboard/blog/settings` 五处分别正确显示。
10. **回归**：`pnpm --filter @lumira/backend exec tsc --noEmit`（typecheck）、`pnpm --filter @lumira/backend test`、`pnpm --filter @lumira/backend test:e2e`、`pnpm --filter @lumira/admin test`、`pnpm --filter @lumira/admin build`、`pnpm --filter @lumira/backend build` 全部通过；既有落地页 `/` 与模板接口不受影响。