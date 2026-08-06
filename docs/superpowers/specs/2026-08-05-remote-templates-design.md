# 后台动态模板上传功能设计文档

- **日期**：2026-08-05
- **范围**：Flutter App + NestJS 后端 + Next.js Admin 后台 + 共享类型包
- **目标**：将模板获取途径从「内置模板 + 自定义模板」扩展为「系统内置模板 + 自定义模板 + 后端动态上传模板」，且分类支持后端动态管理

---

## 1. 总体架构

### 1.1 三层模板来源

| 层 | 来源 | 存储 | 离线可用 | ID 前缀 |
|---|---|---|---|---|
| 系统内置 | Flutter `TemplateRegistry` 的 29 个 `const` 模板 | 编译期常量 + sqflite 镜像 | 是（永远兜底） | 无（如 `soft_portrait`） |
| 用户自定义 | Flutter sqflite `custom_templates` 表（`is_builtin=0`） | 本地 | 是 | 由 Flutter 生成 |
| 后端动态 | 后端 `templates` 表 | 后端 SQLite + Flutter sqflite 缓存（meta） | 是（缓存 meta + 详情时已拉取的完整内容） | `srv_` + nanoid(12) |

### 1.2 数据流

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Admin 后台    │     │     后端        │     │   Flutter App   │
│ (Next.js)       │     │  (NestJS)       │     │                 │
│                 │     │                 │     │                 │
│ 模板管理页      │────▶│ templates 表    │◀────│ remote_templates│
│ 分类管理页      │     │ template_       │     │ _repository     │
│ (表单+.pptpl    │     │   categories 表 │     │                 │
│  上传+图标上传) │     │ template_prices │     │ sqflite:        │
│                 │     │ (复用现有)      │     │  custom_        │
│                 │     │ owned_templates │     │   templates(+   │
│                 │     │ (复用现有)      │     │   source列)     │
│                 │     │                 │     │  template_      │
│                 │     │ uploads/        │     │   categories(新)│
│                 │     │  templates/     │     │                 │
│                 │     │  categories/    │     │ TemplateRegistry│
│                 │     │  silhouettes/   │     │ (29内置,离线兜底)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 1.3 拉取策略

- **列表**：App 启动或进入模板页时调 `GET /templates/list`，仅返回 meta（轻量），upsert 到 sqflite
- **详情**：用户点击模板详情或套用拍摄时调 `GET /templates/:id`，返回完整 6 段内容，upsert 到 sqflite
- **分类**：与模板列表同步拉取 `GET /templates/categories`，upsert 到 sqflite `template_categories` 表
- **离线兜底**：无网络时用 sqflite 缓存的 meta + 已拉取的完整内容；内置 29 模板永远可用

### 1.4 复用现有体系

- `template_prices` 表：Admin 创建后端模板时若 `price>0`，同步写入此表
- `owned_templates` 表：用户兑换后端模板时写入，与内置付费模板兑换流程完全一致
- `templates` 模块的 `exchange` / `listOwned` / `listPrices` 端点：完全复用，无需改动

### 1.5 新增能力

- **后端**：文件上传（`@fastify/multipart`）+ 静态资源服务（`@fastify/static`）+ 模板内容 CRUD + 分类 CRUD
- **Admin**：模板管理页（列表/新建/编辑）+ 分类管理页 + 图片上传组件 + `.pptpl` 文件上传
- **Flutter**：`remote_templates_repository` + sqflite 分类表 + `capture_state` 合并远程模板

---

## 2. 数据模型

### 2.1 后端新增表（Drizzle schema）

在 `lumira-server/packages/backend/src/database/schema.ts` 新增两张表。

#### `template_categories` 表（分类管理）

```typescript
export const templateCategories = sqliteTable('template_categories', {
  key: text('key').primaryKey(),              // 'portrait' / 'landscape' / 自定义 key
  name: text('name').notNull(),                // 显示名 '人像'
  iconUrl: text('icon_url').notNull(),         // 图标文件 URL，空字符串表示用 Flutter 内置映射
  sortOrder: integer('sort_order').notNull().default(0),
  isSystem: integer('is_system').notNull().default(0),  // 1=系统保留, key 锁定不可改不可删
  isActive: integer('is_active').notNull().default(1),  // 0=隐藏不展示
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});
```

#### `templates` 表（后端动态模板内容，结构化存储）

```typescript
export const templates = sqliteTable('templates', {
  // —— meta 拆列（便于 SQL 筛选/排序/分页）——
  id: text('id').primaryKey(),                 // 'srv_' + nanoid(12)
  name: text('name').notNull(),
  author: text('author').notNull().default('Lumira'),
  version: text('version').notNull().default('1.0.0'),
  category: text('category').notNull(),        // 引用 template_categories.key
  price: integer('price').notNull().default(0),
  coverUrl: text('cover_url').notNull(),
  description: text('description').notNull().default(''),
  referenceSource: text('reference_source').notNull().default(''),
  tagsJson: text('tags_json').notNull().default('[]'),
  tagIdsJson: text('tag_ids_json').notNull().default('[]'),
  classificationJson: text('classification_json').notNull().default('{}'),
  sortOrder: integer('sort_order').notNull().default(0),
  isActive: integer('is_active').notNull().default(1),  // 0=下架
  // —— 5 段内容 JSON 列 ——
  compositionJson: text('composition_json').notNull().default('{}'),
  poseJson: text('pose_json').notNull().default('{}'),
  cameraJson: text('camera_json').notNull().default('{}'),
  sceneGuideJson: text('scene_guide_json').notNull().default('{}'),
  postProcessJson: text('post_process_json').notNull().default('{}'),
  createdAt: integer('created_at').notNull(),
  updatedAt: integer('updated_at').notNull(),
});
```

> 剪影图片（pose.silhouette.data 若为 image 类型）单独上传到 `uploads/templates/{templateId}/silhouette.{ext}`，URL 存入 `poseJson` 内部。

### 2.2 后端 SQL 迁移

新增 `lumira-server/packages/backend/src/database/migrations/003_templates.sql`，幂等写法（遵循现有惯例）：

```sql
CREATE TABLE IF NOT EXISTS template_categories (
  key         TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  icon_url    TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_system   INTEGER NOT NULL DEFAULT 0,
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_at  INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS templates (
  id                   TEXT PRIMARY KEY,
  name                 TEXT NOT NULL,
  author               TEXT NOT NULL DEFAULT 'Lumira',
  version              TEXT NOT NULL DEFAULT '1.0.0',
  category             TEXT NOT NULL,
  price                INTEGER NOT NULL DEFAULT 0,
  cover_url            TEXT NOT NULL,
  description          TEXT NOT NULL DEFAULT '',
  reference_source     TEXT NOT NULL DEFAULT '',
  tags_json            TEXT NOT NULL DEFAULT '[]',
  tag_ids_json         TEXT NOT NULL DEFAULT '[]',
  classification_json  TEXT NOT NULL DEFAULT '{}',
  sort_order           INTEGER NOT NULL DEFAULT 0,
  is_active            INTEGER NOT NULL DEFAULT 1,
  composition_json     TEXT NOT NULL DEFAULT '{}',
  pose_json            TEXT NOT NULL DEFAULT '{}',
  camera_json          TEXT NOT NULL DEFAULT '{}',
  scene_guide_json     TEXT NOT NULL DEFAULT '{}',
  post_process_json    TEXT NOT NULL DEFAULT '{}',
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_templates_category ON templates(category);
CREATE INDEX IF NOT EXISTS idx_templates_sort_order ON templates(sort_order);

-- 预置 7 个系统分类（key 与 Flutter 内置 7 类严格对齐）
INSERT OR IGNORE INTO template_categories (key, name, icon_url, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('portrait',    '人像',   '', 1, 1, 1, 0, 0),
  ('landscape',   '风景',   '', 2, 1, 1, 0, 0),
  ('food',        '美食',   '', 3, 1, 1, 0, 0),
  ('street',      '街拍',   '', 4, 1, 1, 0, 0),
  ('night',       '夜景',   '', 5, 1, 1, 0, 0),
  ('macro',       '微距',   '', 6, 1, 1, 0, 0),
  ('still-life',  '静物',   '', 7, 1, 1, 0, 0);
```

### 2.3 Flutter sqflite 改动

#### A. 新增 `template_categories` 表

文件：`lumira_app_flutter/lib/core/db/tables.dart` + `database_provider.dart`

```sql
CREATE TABLE IF NOT EXISTS template_categories (
  key         TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  icon_url    TEXT NOT NULL DEFAULT '',
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_system   INTEGER NOT NULL DEFAULT 0,
  is_active   INTEGER NOT NULL DEFAULT 1,
  updated_at  INTEGER NOT NULL
);
```

> 不存 `created_at`（缓存场景不需要）。种子数据由 `BuiltinDataSeeder.seedCategories(db)` 预置 7 个系统分类。

#### B. `custom_templates` 表新增 `source` 列

DB 版本从 v12 升到 v13：

```sql
ALTER TABLE custom_templates ADD COLUMN source TEXT NOT NULL DEFAULT 'builtin';
```

`source` 取值：
- `builtin`：系统内置模板
- `custom`：用户自定义模板
- `remote`：后端动态模板

> `is_builtin` 列保留不变，避免破坏现有查询。`source` 是更细粒度的来源标记。

#### C. DB 版本迁移逻辑（v12 → v13）

在 `database_provider.dart` 的 `_onUpgrade` 增加：

```dart
if (oldVersion < 13) {
  await db.execute('ALTER TABLE custom_templates ADD COLUMN source TEXT NOT NULL DEFAULT \'builtin\'');
  await db.execute('UPDATE custom_templates SET source = \'custom\' WHERE is_builtin = 0');
  await db.execute('UPDATE custom_templates SET source = \'builtin\' WHERE is_builtin = 1');
  await db.execute('''CREATE TABLE IF NOT EXISTS template_categories (
    key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon_url TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_system INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL
  )''');
  await BuiltinDataSeeder.seedCategories(db);
}
```

同步更新 `database_provider.dart` 顶部 `DB_VERSION = 13`，并在 `_onCreate` 中创建 `template_categories` 表 + 调用 `seedCategories`。

### 2.4 共享类型定义

新增 `lumira-server/packages/shared/src/types/template.ts`：

```typescript
// 分类
export interface TemplateCategory {
  key: string;
  name: string;
  iconUrl: string;
  sortOrder: number;
  isSystem: boolean;
  isActive: boolean;
  updatedAt: number;
}

export interface TemplateCategoryListResponse {
  categories: TemplateCategory[];
}

// 后端动态模板 meta（列表用，轻量）
export interface RemoteTemplateMeta {
  id: string;
  name: string;
  author: string;
  version: string;
  category: string;
  price: number;
  coverUrl: string;
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: { type: string; style: string; method: string };
  sortOrder: number;
  updatedAt: number;
}

export interface RemoteTemplateListResponse {
  templates: RemoteTemplateMeta[];
  serverUpdatedAt: number;
}

// 后端动态模板完整内容（详情用）
export interface RemoteTemplateDetail extends RemoteTemplateMeta {
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}

// Admin 管理用
export interface AdminTemplateListItem {
  id: string;
  name: string;
  category: string;
  categoryName: string;
  price: number;
  coverUrl: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: number;
  updatedAt: number;
}

export interface AdminTemplateDetail extends AdminTemplateListItem {
  author: string;
  version: string;
  description: string;
  referenceSource: string;
  tags: string[];
  tagIds: string[];
  classification: { type: string; style: string; method: string };
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}

export interface CreateTemplateRequest {
  name: string;
  author?: string;
  version?: string;
  category: string;
  price: number;
  description?: string;
  referenceSource?: string;
  tags?: string[];
  tagIds?: string[];
  classification?: { type: string; style: string; method: string };
  sortOrder?: number;
  isActive?: boolean;
  composition?: Record<string, unknown>;
  pose?: Record<string, unknown>;
  camera?: Record<string, unknown>;
  sceneGuide?: Record<string, unknown>;
  postProcess?: Record<string, unknown>;
}

export interface UpdateTemplateRequest extends Partial<CreateTemplateRequest> {}

export interface CreateCategoryRequest {
  key: string;
  name: string;
  iconUrl?: string;
  sortOrder?: number;
  isActive?: boolean;
}

export interface UpdateCategoryRequest extends Partial<Omit<CreateCategoryRequest, 'key'>> {}
```

在 `shared/src/index.ts` 添加 `export * from './types/template';`。

### 2.5 ID 命名规则

- 后端动态模板 ID：`srv_` + nanoid(12)，如 `srv_a1b2c3d4e5f6`
- 与 Flutter 内置 29 个 ID（如 `soft_portrait`）永不冲突
- 用户自定义模板 ID 由 Flutter 端生成（现有逻辑保持）

### 2.6 字段映射关系（后端 ↔ Flutter sqflite）

| 后端 `templates` 表 | Flutter `custom_templates` 表（source='remote'） | 说明 |
|---|---|---|
| `id` | `id` | 直接映射 |
| `name` | `name` | 直接映射 |
| `author` | `author` | 直接映射 |
| `version` | `version` | 直接映射 |
| `category` | `category` | 引用 template_categories.key |
| `price` | `price` | 直接映射 |
| `cover_url` | `cover` | URL 字符串 |
| `description` | `description` | 直接映射 |
| `reference_source` | `reference_source` | 直接映射 |
| `tags_json` | `tags_json` | JSON 字符串 |
| `tag_ids_json` | `tag_ids_json` | JSON 字符串 |
| `classification_json` | `classification_json` | JSON 字符串 |
| `composition_json` | `composition_json` | JSON 字符串 |
| `pose_json` | `pose_json` | JSON 字符串 |
| `camera_json` | `camera_json` | JSON 字符串 |
| `scene_guide_json` | `scene_guide_json` | JSON 字符串 |
| `post_process_json` | `post_process_json` | JSON 字符串 |
| `sort_order` | （不缓存） | 仅列表排序用 |
| `is_active` | （不缓存） | 下架后从 list 移除 |
| `updated_at` | `updated_at` | 用于增量同步比较 |
| — | `source='remote'` | Flutter 端标记来源 |
| — | `is_builtin=0` | 后端模板不是内置 |
| — | `is_recommended=0` | 推荐由 Flutter 端逻辑控制 |
| — | `cover_data=null` | 后端模板 cover 用 URL |

---

## 3. 后端 API 设计

### 3.1 模块组织

扩展现有 `lumira-server/packages/backend/src/modules/templates/` 模块：

```
modules/templates/
├── templates.module.ts              # @Module 注册（需补到 app.module.ts）
├── templates.controller.ts          # 客户端接口（已有，扩展 list/detail）
├── templates.service.ts             # 业务逻辑（已有，扩展）
├── admin-templates.controller.ts    # 新增：Admin 管理接口
├── admin-templates.service.ts       # 新增：Admin 业务逻辑
├── categories.controller.ts         # 新增：客户端分类接口
├── categories.service.ts            # 新增：分类业务逻辑
├── admin-categories.controller.ts   # 新增：Admin 分类管理接口
├── admin-categories.service.ts      # 新增：Admin 分类业务逻辑
└── dto/
    ├── exchange-template.dto.ts     # 已有
    ├── create-template.dto.ts       # 新增
    ├── update-template.dto.ts       # 新增
    ├── create-category.dto.ts       # 新增
    └── update-category.dto.ts       # 新增
```

### 3.2 客户端接口（DeviceAuthGuard）

| 方法 | 路径 | 说明 | 响应 |
|---|---|---|---|
| GET | `/templates/list` | 后端动态模板 meta 列表（仅 isActive=1） | `RemoteTemplateListResponse` |
| GET | `/templates/:id` | 单个模板完整内容 | `RemoteTemplateDetail` |
| GET | `/templates/categories` | 分类列表（仅 isActive=1，按 sortOrder 排序） | `TemplateCategoryListResponse` |
| GET | `/templates/owned` | 已有，复用 | — |
| GET | `/templates/prices` | 已有，复用 | — |
| POST | `/templates/exchange` | 已有，复用 | — |

**`GET /templates/list` 查询参数**：
- `?since=timestamp`（可选）：增量同步，返回 `updatedAt > since` 的模板
- `?category=key`（可选）：按分类筛选

**响应示例**：

```json
{
  "templates": [
    {
      "id": "srv_a1b2c3d4e5f6",
      "name": "秋日森林",
      "author": "Lumira",
      "version": "1.0.0",
      "category": "landscape",
      "price": 100,
      "coverUrl": "https://server/api/v1/uploads/templates/srv_a1b2c3d4e5f6/cover.jpg",
      "description": "秋日森林光线",
      "referenceSource": "原创",
      "tags": ["秋季", "森林"],
      "tagIds": [],
      "classification": { "type": "landscape", "style": "natural", "method": "available-light" },
      "sortOrder": 1,
      "updatedAt": 1722864000
    }
  ],
  "serverUpdatedAt": 1722864000
}
```

### 3.3 Admin 管理接口（AdminAuthGuard）

#### 模板管理

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/admin/templates` | 模板列表（分页，含 isActive=0） |
| GET | `/admin/templates/:id` | 模板详情 |
| POST | `/admin/templates` | 创建模板（multipart：JSON 表单 + 封面图 + 剪影图 + 可选 .pptpl 文件） |
| PATCH | `/admin/templates/:id` | 更新模板（multipart：JSON 表单 + 可选新封面 + 可选新剪影） |
| DELETE | `/admin/templates/:id` | 删除模板（同时删文件） |
| POST | `/admin/templates/:id/toggle-active` | 上架/下架切换 |

#### 分类管理

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/admin/categories` | 分类列表（含 isActive=0） |
| POST | `/admin/categories` | 创建分类（multipart：JSON 表单 + 图标文件） |
| PATCH | `/admin/categories/:key` | 更新分类（系统分类 key 不可改，multipart：JSON 表单 + 可选新图标） |
| DELETE | `/admin/categories/:key` | 删除分类（系统分类不可删，返回 400） |
| POST | `/admin/categories/:key/toggle-active` | 显示/隐藏切换 |

### 3.4 创建模板接口详细设计

`POST /admin/templates`（multipart/form-data）：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `meta` | JSON string | 是 | `CreateTemplateRequest` 的 JSON 字符串（含 name/category/price/description 等） |
| `cover` | file | 是 | 封面图片（jpg/png/webp，≤2MB） |
| `silhouette` | file | 否 | 剪影图片（png/svg，≤1MB），仅当 pose.silhouette.type='image' 时上传 |
| `pptpl` | file | 否 | .pptpl 文件，若上传则覆盖 meta 中的 5 段内容字段 |

**处理流程**：
1. 解析 multipart，读取 `meta` JSON
2. 若有 `pptpl` 文件：解析其 5 段内容，覆盖 meta 中的 composition/pose/camera/sceneGuide/postProcess
3. 生成 `srv_` + nanoid(12) 作为 ID
4. 保存封面到 `uploads/templates/{id}/cover.{ext}`
5. 若有剪影，保存到 `uploads/templates/{id}/silhouette.{ext}`
6. 构造 `coverUrl` / 剪影 URL，写入 poseJson
7. INSERT 到 `templates` 表
8. 若 `price > 0`：UPSERT 到 `template_prices` 表
9. 返回 `AdminTemplateDetail`

### 3.5 文件上传与静态资源服务

#### 依赖安装

```bash
cd lumira-server/packages/backend
pnpm add @fastify/multipart @fastify/static
```

#### `main.ts` 配置

```typescript
// 注册 multipart
fastify.register(multipart, {
  limits: {
    fileSize: 5 * 1024 * 1024,  // 单文件 5MB
    files: 5,                    // 单次最多 5 个文件
  },
});

// 注册静态资源服务
fastify.register(staticPlugin, {
  root: path.resolve(process.env.UPLOAD_DIR || './data/uploads'),
  prefix: '/uploads/',
});
```

> 注意：`@fastify/static` 的 prefix 不含全局 `/api/v1` 前缀，访问路径为 `https://server/uploads/templates/...`。需要在 Flutter 端构造 URL 时使用 `BACKEND_BASE_URL + '/uploads/...'` 而非 `API_PREFIX`。

#### 存储路径

```
data/uploads/
├── templates/
│   └── {templateId}/
│       ├── cover.jpg
│       └── silhouette.png
└── categories/
    └── {key}/
        └── icon.svg
```

#### URL 规则

- 封面：`${BACKEND_BASE_URL}/uploads/templates/{templateId}/cover.{ext}`
- 剪影：`${BACKEND_BASE_URL}/uploads/templates/{templateId}/silhouette.{ext}`
- 图标：`${BACKEND_BASE_URL}/uploads/categories/{key}/icon.{ext}`

### 3.6 .pptpl 文件解析

后端新增 `pptpl-parser.util.ts`：

```typescript
// 解析 .pptpl JSON，提取 5 段内容
export function parsePptpl(buffer: Buffer): {
  composition: Record<string, unknown>;
  pose: Record<string, unknown>;
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
} {
  const json = JSON.parse(buffer.toString('utf-8'));
  if (json.format !== 'pptpl') throw new Error('Invalid pptpl format');
  return {
    composition: json.composition || {},
    pose: json.pose || {},
    camera: json.camera || {},
    sceneGuide: json.sceneGuide || {},
    postProcess: json.postProcess || {},
  };
}
```

### 3.7 AppModule 注册

在 `app.module.ts` 的 `imports` 中添加 `TemplatesModule`（当前缺失，疑似 bug）。

---

## 4. Admin 后台改造

### 4.1 路由结构

新增 `lumira-server/packages/admin/src/app/dashboard/templates/`：

```
app/dashboard/templates/
├── page.tsx                  # 模板列表页
├── new/page.tsx              # 新建模板页
├── [id]/
│   ├── page.tsx              # 模板详情/编辑页
│   └── edit/page.tsx         # 编辑页（可选，也可合并到 [id]/page.tsx）
```

新增 `app/dashboard/categories/`：

```
app/dashboard/categories/
└── page.tsx                  # 分类管理页（内联新建/编辑）
```

### 4.2 Sidebar 扩展

文件：`lumira-server/packages/admin/src/components/sidebar.tsx`

```typescript
// 在导航项数组添加：
{ href: '/dashboard/templates', label: '模板管理', icon: SquaresFour },
{ href: '/dashboard/categories', label: '分类管理', icon: GridFour },
```

### 4.3 titleMap 扩展

文件：`lumira-server/packages/admin/src/components/dashboard-shell.tsx`

```typescript
'/dashboard/templates': '模板管理',
'/dashboard/templates/new': '新建模板',
'/dashboard/templates/[id]': '模板详情',
'/dashboard/categories': '分类管理',
```

### 4.4 图片上传组件

新增 `components/ui/file-upload.tsx`：

- 基于 `<input type="file" accept="image/*">`
- 本地预览（`URL.createObjectURL`）
- 支持 `accept` / `maxSize` / `multiple` props
- 拖放支持（可选）
- shadcn/ui 风格（border-dashed、hover:bg-muted）
- 暴露 `value: File | null` 给父组件

### 4.5 模板表单组件

新增 `components/template-form.tsx`：

- 使用 `react-hook-form` + `zod` 校验
- **分步向导**（Step Wizard）而非单页表单（字段过多）：
  - Step 1: 基本信息（name/category/price/description/author/tags/referenceSource）
  - Step 2: 封面与剪影（封面图上传 + 剪影图上传 + 剪影类型选择）
  - Step 3: 构图（composition 字段）
  - Step 4: 相机参数（camera 字段）
  - Step 5: 场景引导（sceneGuide 字段）
  - Step 6: 后期处理（postProcess 字段）
- **.pptpl 上传入口**：在 Step 1 顶部提供"上传 .pptpl 文件自动填充"按钮，上传后解析 JSON 自动填充 Step 3-6 的字段
- 字段定义参考 Flutter `templates_editor_mock_data.dart`
- 提交时构造 `FormData`（meta JSON + cover file + silhouette file + 可选 pptpl file）调用 Server Action

### 4.6 Server Actions

新增 `actions/templates.ts`：

```typescript
'use server';
import { api } from '@/lib/api';

export async function createTemplate(formData: FormData) {
  // 转发 multipart 到后端 POST /admin/templates
  const res = await api.createTemplate(formData);
  revalidatePath('/dashboard/templates');
  redirect('/dashboard/templates');
}

export async function updateTemplate(id: string, formData: FormData) { ... }
export async function deleteTemplate(id: string) { ... }
export async function toggleTemplateActive(id: string) { ... }
```

新增 `actions/categories.ts`：分类 CRUD Server Actions。

### 4.7 lib/api.ts 扩展

扩展 `adminFetch` 支持 FormData：

```typescript
async function adminFetch(path: string, options: RequestInit = {}) {
  const token = cookies().get(AUTH_COOKIE_NAME)?.value;
  const isFormData = options.body instanceof FormData;
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    ...options.headers as Record<string, string>,
  };
  if (!isFormData) headers['Content-Type'] = 'application/json';
  // FormData 时不设 Content-Type，让 fetch 自动设 multipart boundary
  const res = await fetch(`${BACKEND_URL}/api/v1/admin${path}`, { ...options, headers });
  if (res.status === 401) throw new UnauthenticatedError();
  return res;
}
```

---

## 5. Flutter 端改造

### 5.1 remote_templates_repository.dart

新增 `lumira_app_flutter/lib/features/templates/data/remote_templates_repository.dart`：

```dart
class RemoteTemplatesRepository {
  final http.Client _client;
  final String _baseUrl;

  Future<RemoteTemplateListResponse> list({int? since, String? category}) async { ... }
  Future<RemoteTemplateDetail> fetchDetail(String id) async { ... }
  Future<List<TemplateCategoryDto>> fetchCategories() async { ... }
}
```

### 5.2 拉取与同步逻辑

新增 Provider（在 `templates_providers.dart` 或新建 `remote_templates_providers.dart`）：

```dart
// 拉取后端分类并 upsert 到 sqflite
final remoteCategoriesSyncProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(remoteTemplatesRepositoryProvider);
  final dao = ref.read(templatesDaoProvider);
  final cats = await repo.fetchCategories();
  for (final c in cats) {
    await dao.upsertCategory(c);
  }
});

// 拉取后端模板 meta 并 upsert 到 sqflite
final remoteTemplatesSyncProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(remoteTemplatesRepositoryProvider);
  final dao = ref.read(templatesDaoProvider);
  final resp = await repo.list();
  for (final meta in resp.templates) {
    final record = _metaToRecord(meta);
    await dao.upsert(record);
  }
  // 删除后端已不存在的 remote 模板
  await dao.pruneRemoteTemplates(resp.templates.map((t) => t.id).toSet());
});

// 按需拉取单个模板完整内容
final remoteTemplateDetailProvider = FutureProvider.family<PhotoTemplate?, String>((ref, id) async {
  final repo = ref.read(remoteTemplatesRepositoryProvider);
  final dao = ref.read(templatesDaoProvider);
  final detail = await repo.fetchDetail(id);
  final record = _detailToRecord(detail);
  await dao.upsert(record);
  return TemplateMapper.toPhotoTemplate(record);
});
```

### 5.3 TemplatesDao 扩展

文件：`lumira_app_flutter/lib/core/db/dao/templates_dao.dart`

新增方法：

```dart
// 分类操作
Future<List<TemplateCategoryRecord>> getCategories({bool activeOnly = true}) async { ... }
Future<void> upsertCategory(TemplateCategoryRecord record) async { ... }

// 后端模板同步
Future<List<TemplateRecord>> getRemote() async {
  // WHERE source = 'remote'
}
Future<void> pruneRemoteTemplates(Set<String> validIds) async {
  // DELETE FROM custom_templates WHERE source = 'remote' AND id NOT IN (validIds)
}
```

### 5.4 capture_state.dart 合并远程模板

修改 `allTemplatesProvider`（第 133-156 行）：

```dart
final allTemplatesProvider = FutureProvider<List<PhotoTemplate>>((ref) async {
  final dao = ref.read(templatesDaoProvider);

  // 1. 系统内置模板（同步）
  final builtin = TemplateRegistry.allTemplates;

  // 2. 用户自定义 + 后端动态模板（异步，从 sqflite）
  final customAndRemote = await dao.getCustomAndRemote();
  final mapped = customAndRemote.map(TemplateMapper.toPhotoTemplate).toList();

  return [...builtin, ...mapped];
});
```

新增 `getCustomAndRemote()`：

```sql
SELECT * FROM custom_templates WHERE source IN ('custom', 'remote') ORDER BY updated_at DESC
```

### 5.5 触发同步的时机

- **App 启动**：在 `app.dart` 或 splash 流程中触发 `remoteCategoriesSyncProvider` + `remoteTemplatesSyncProvider`（异步，不阻塞 UI）
- **进入模板列表页**：`templates_page.dart` 的 initState 触发刷新
- **下拉刷新**：模板列表页支持下拉刷新手动触发同步
- **失败处理**：网络失败静默忽略，使用本地缓存，不打扰用户

### 5.6 模板详情页改造

`templates_detail_page.dart` 在打开后端模板（`source='remote'` 且 sqflite 中只有 meta 无完整内容）时：

1. 先用 meta 渲染基础信息（name/cover/category/price/description）
2. 调用 `remoteTemplateDetailProvider(id)` 拉取完整内容
3. 拉取成功后展示完整的 6 段内容 + 启用"套用拍摄"按钮
4. 拉取失败时显示"网络错误，无法加载完整内容"，禁用"套用拍摄"

**判断"只有 meta 无完整内容"**：检查 `composition_json` 是否为 `{}` 且 `source='remote'`。

### 5.7 分类 UI 改造

`templates_all_page.dart` 的分类瀑布流：

- 数据源从硬编码 7 类改为 `dao.getCategories()`（从 sqflite 读取）
- 图标渲染：`icon_url` 非空用 `Image.network(iconUrl)`，为空回退到内置 Phosphor icon 映射
- 离线时用 sqflite 缓存的分类

新增 `lib/features/templates/data/builtin_category_icons.dart`：

```dart
// 内置 7 类的 Phosphor icon 映射（icon_url 为空时回退用）
final Map<String, IconData> builtinCategoryIcons = {
  'portrait': PhosphorIcons.user,
  'landscape': PhosphorIcons.mountain,
  'food': PhosphorIcons.forkKnife,
  'street': PhosphorIcons.roadHorizon,
  'night': PhosphorIcons.moon,
  'macro': PhosphorIcons.magnifyingGlass,
  'still-life': PhosphorIcons.flower,
};
```

### 5.8 配置

在 `app_config.dart` 或 `secrets.dart` 中确认 `BACKEND_BASE_URL` 已定义（应已存在，被 `owned_templates_repository.dart` 使用）。

---

## 6. 同步策略

### 6.1 模板同步

- **全量列表**：`GET /templates/list` 返回所有 `isActive=1` 的模板 meta
- **增量同步**（可选优化）：客户端记录上次同步的 `serverUpdatedAt`，下次请求带 `?since=timestamp`，仅返回 `updatedAt > since` 的模板
- **删除处理**：客户端比对本地 `source='remote'` 的模板与新列表，删除后端已不存在的（`pruneRemoteTemplates`）
- **下架处理**：后端 `isActive=0` 的模板不在 list 中返回，客户端同步时删除本地缓存

### 6.2 分类同步

- **全量列表**：`GET /templates/categories` 返回所有 `isActive=1` 的分类
- **upsert**：客户端按 key upsert 到 sqflite
- **系统分类保护**：后端预置的 7 个系统分类 key 永远存在，保证内置模板永远能分类
- **离线兜底**：sqflite 种子数据预置 7 个系统分类，无网络时用本地

### 6.3 冲突处理

- **后端模板 vs 本地缓存**：以后端 `updatedAt` 为准，新版本覆盖旧版本
- **用户自定义 vs 后端动态**：ID 不冲突（自定义无前缀，后端 `srv_` 前缀），不会互相覆盖
- **内置模板 vs 后端动态**：ID 不冲突，互不影响

---

## 7. 错误处理

### 7.1 后端

- **文件上传失败**：返回 400，错误信息含字段名
- **.pptpl 解析失败**：返回 400，错误信息"Invalid pptpl format"
- **分类 key 冲突**：创建分类时 key 已存在，返回 409
- **系统分类保护**：尝试删除或改 key 系统分类，返回 400
- **模板不存在**：返回 404
- **分类被引用**：删除分类时若仍有模板引用该 key，返回 409

### 7.2 Flutter

- **网络失败**：静默忽略，使用本地缓存，日志记录
- **JSON 解析失败**：跳过该条目，日志记录
- **详情拉取失败**：UI 提示"网络错误"，禁用"套用拍摄"按钮

---

## 8. 测试策略

### 8.1 后端

- 单元测试：`pptpl-parser.util.ts`、`admin-templates.service.ts`、`categories.service.ts`
- 集成测试：multipart 上传、静态资源访问、CRUD 流程
- 边界测试：系统分类保护、文件大小超限、无效 .pptpl

### 8.2 Admin

- 表单校验：必填字段、价格范围、.pptpl 格式
- 上传组件：文件类型、大小限制、预览

### 8.3 Flutter

- 同步逻辑：全量/增量、删除清理、离线兜底
- 分类合并：系统分类保护、自定义分类增删
- 详情按需拉取：成功/失败/离线

---

## 9. 实施顺序

1. **共享类型**：`shared/src/types/template.ts`
2. **后端**：schema + 迁移 + 模块（categories + templates + admin）
3. **Admin**：路由 + 组件 + Server Actions
4. **Flutter**：DB 迁移 + DAO + Repository + Provider + UI 改造

各层可并行开发，但需先完成共享类型定义。

---

## 10. 关键文件清单

### 新增文件

**后端**：
- `src/database/migrations/003_templates.sql`
- `src/modules/templates/admin-templates.controller.ts`
- `src/modules/templates/admin-templates.service.ts`
- `src/modules/templates/categories.controller.ts`
- `src/modules/templates/categories.service.ts`
- `src/modules/templates/admin-categories.controller.ts`
- `src/modules/templates/admin-categories.service.ts`
- `src/modules/templates/dto/create-template.dto.ts`
- `src/modules/templates/dto/update-template.dto.ts`
- `src/modules/templates/dto/create-category.dto.ts`
- `src/modules/templates/dto/update-category.dto.ts`
- `src/modules/templates/utils/pptpl-parser.ts`

**Admin**：
- `src/app/dashboard/templates/page.tsx`
- `src/app/dashboard/templates/new/page.tsx`
- `src/app/dashboard/templates/[id]/page.tsx`
- `src/app/dashboard/categories/page.tsx`
- `src/actions/templates.ts`
- `src/actions/categories.ts`
- `src/components/ui/file-upload.tsx`
- `src/components/template-form.tsx`
- `src/components/template-list-table.tsx`
- `src/components/category-manager.tsx`

**Flutter**：
- `lib/features/templates/data/remote_templates_repository.dart`
- `lib/features/templates/data/remote_templates_providers.dart`
- `lib/features/templates/data/remote_template_dto.dart`
- `lib/features/templates/data/builtin_category_icons.dart`
- `lib/core/db/dao/template_categories_dao.dart`

**共享**：
- `packages/shared/src/types/template.ts`

### 修改文件

**后端**：
- `src/database/schema.ts`（新增两张表）
- `src/modules/templates/templates.module.ts`（注册新 controller/service）
- `src/modules/templates/templates.controller.ts`（新增 list/detail/categories 端点）
- `src/modules/templates/templates.service.ts`（新增 list/detail 方法）
- `src/app.module.ts`（注册 TemplatesModule）
- `src/main.ts`（注册 multipart + static）
- `package.json`（新增依赖）

**Admin**：
- `src/components/sidebar.tsx`（新增导航项）
- `src/components/dashboard-shell.tsx`（扩展 titleMap）
- `src/lib/api.ts`（支持 FormData）
- `src/types/admin.ts`（新增模板/分类类型）

**Flutter**：
- `lib/core/db/tables.dart`（新增 template_categories 表 + source 列常量）
- `lib/core/db/database_provider.dart`（v13 迁移 + onCreate）
- `lib/core/db/dao/templates_dao.dart`（新增分类方法 + remote 方法）
- `lib/core/db/seeders/builtin_data_seeder.dart`（新增 seedCategories）
- `lib/features/capture/data/capture_state.dart`（allTemplatesProvider 合并 remote）
- `lib/features/templates/pages/templates_all_page.dart`（分类数据源改为 sqflite）
- `lib/features/templates/pages/templates_detail_page.dart`（按需拉取完整内容）
- `lib/features/templates/services/template_mapper.dart`（新增 remote DTO → TemplateRecord）

---

## 11. 三级分类扩展（增量设计）

### 11.1 问题背景

模板分类实际为三级结构：`type`（一级，拍摄题材）→ `style`（二级，视觉风格）→ `method`（三级，拍摄方式），对应 `TemplateClassification.{type, style, method}`。初始实施仅管理了一级分类，二三级硬编码在 Flutter `templates_browse_mock_data.dart` 的 `styleMap` / `methodMap` 字典中，且字典严重过时（17 个新 style + 4 个新 method 未收录）。

### 11.2 存储方案：单表自引用树形

扩展现有 `template_categories` 表，新增 `parent_key` + `level` 列：

| 列 | 说明 |
|---|---|
| `key` | 分类 key（全局唯一），如 `portrait` / `japanese` / `normal` |
| `name` | 显示名，如 `人像` / `日系` / `他拍` |
| `parent_key` | 父分类 key，一级为 NULL |
| `level` | 层级：1=一级(type) / 2=二级(style) / 3=三级(method) |
| `icon_url` | 图标 URL（仅一级有，二三级为空） |
| `sort_order` | 排序 |
| `is_system` | 1=系统保留，key 锁定不可删不可改 |
| `is_active` | 1=启用 |
| `updated_at` | 更新时间戳 |

### 11.3 预置系统分类树

把 29 个内置模板实际使用的所有 type/style/method + 字典中的值全部预置为 `is_system=1`：

**portrait (人像)**:
- japanese (日系) → normal(他拍), selfie(自拍), overhead(俯拍)
- emotional (情绪) → wide(远景), selfie(自拍)
- film (胶片) → normal(他拍), selfie(自拍)
- western (欧美) → normal(他拍), wide(远景)
- ccd_retro (CCD复古) → half_body(半身)
- hk_noir (港风Noir) → half_body(半身)
- japanese_fresh (日系清新) → seven_body(七分身)
- cream_healing (奶油治愈) → half_body(半身)
- chinese_classical (中式古典) → full_body(全身)
- french_lazy (法式慵懒) → half_body(半身)
- morandi_minimal (莫兰迪极简) → half_body(半身)
- dark_indoor (暗调室内) → half_body(半身)
- neon_city (霓虹都市) → half_body(半身)
- fresh_green (清新绿意) → full_body(全身)
- y2k (Y2K千禧) → half_body(半身)
- anime_dream (动漫梦境) → full_body(全身)
- blue_night (蓝色之夜) → seven_body(七分身)
- purple_dusk (紫色黄昏) → half_body(半身)
- foodie_portrait (美食人像) → half_body(半身)
- sweet_girl (甜美少女) → half_body(半身)
- elegant_lady (优雅女士) → seven_body(七分身)

**landscape (风景)**: fresh(清新)→wide,flat / epic(大气)→wide,overhead
**food (美食)**: overhead(俯拍)→flat,overhead / closeup(特写)→macro,detail
**street (街拍)**: casual(随性)→normal,wide / geometric(几何)→wide,overhead
**night (夜景)**: neon(霓虹)→normal,wide / starry(星空)→(无method)
**macro (微距)**: nature(自然)→macro / object(物品)→(无method)
**still-life (静物)**: minimal(极简)→single / flat(扁平)→(无method)

### 11.4 后端改动

- **schema.ts**：`templateCategories` 表新增 `parentKey` (text, nullable) + `level` (integer, notNull default 1)
- **003_templates.sql 或新建 004 分类层级迁移**：ALTER TABLE 添加两列 + 预置所有二三级系统分类
- **categories.service.ts**：新增 `listTree()` 返回完整三级树；`listByParent(parentKey)` 返回子分类
- **admin-categories.service.ts**：CRUD 支持 parent_key/level；创建二级时 parent_key 必须是一级 key，创建三级时 parent_key 必须是二级 key
- **admin-templates.service.ts**：创建/更新模板时 `classification.type` 自动设为 `category` 值

### 11.5 Admin 改动

- **分类管理页**：改为树形展示（一级 > 二级 > 三级缩进）；新建/编辑时选择 parent（一级无，二三级必须选父分类）
- **模板表单 Step 1**：category 选择改为三级级联 select（选 type → 动态加载 style → 动态加载 method）

### 11.6 Flutter 改动

- **sqflite template_categories 表**：新增 parent_key + level 列（DB v14 → v15 迁移）
- **种子数据**：预置所有 style/method 为系统分类
- **templates_all_page.dart**：
  - 分类数据源从 `styleMap`/`methodMap` 改为 sqflite 三级树
  - 修复筛选 bug：style/method 选择真正参与 `where` 过滤
- **templates_browse_mock_data.dart**：`styleMap`/`methodMap` 标记废弃，改为从 sqflite 读取
- **templates_editor_page.dart**：编辑器的 style/method 选项从 sqflite 读取
