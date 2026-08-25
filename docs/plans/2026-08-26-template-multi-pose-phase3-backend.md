# 模板多姿势 Phase 3：后端 images/poses 数组 + 三级分类 + 迁移 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 按任务逐条执行。步骤用 `- [ ]` 勾选跟踪。

**Goal:** 后端 `templates` 表从「单 cover + 单 pose + 四级分类」改为「images[] 数组 + poses[] 数组 + 三级分类」，同步更新 DTO、service、shared types，并编写幂等迁移 SQL。

**Architecture:** 新增 `images_json` 列存多图；`pose_json` 由单对象改为数组（旧数据包装为 `[single]`）；分类 `method` 不再作为层级（字段保留兼容）。迁移走 `_migrations` 表机制（新增 `022_*.sql`），service 层读写新结构，shared types 对齐。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8；pnpm monorepo（shared/backend）。

## 全局约束

- 迁移幂等：`_migrations` 表保证仅执行一次；SQL 用 `IF NOT EXISTS` / `DEFAULT`。
- 不删列：`cover_url` 保留（兼容旧版 App），`images_json` 承载完整多图。
- `pose_json` 旧单对象数据兼容读取（读时检测 `Array.isArray` 否则包装 `[obj]`）。
- 分类 `method` 字段保留在 `classification_json` 中（兼容旧数据），但不再作为分类树层级。
- 后端改动后须 commit + push 双远程（`origin` gitee + `github`）。
- `BACKEND_PUBLIC_URL` 必须已配置（图片 URL 构造依赖）。

---

### Task 1: 迁移 —— `images_json` 列 + `pose_json` 数组化 + 分类三级注释

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/022_template_images_poses.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（drizzle schema 加列）

- [ ] **Step 1: 编写迁移 SQL**

创建 `022_template_images_poses.sql`：

```sql
-- 022: 模板多姿势改造——新增 images_json 列，pose_json 兼容数组
-- 幂等：由 _migrations 表记录，仅执行一次

-- 1. 新增 images_json 列（存效果图数组，[0]=封面）
ALTER TABLE templates
  ADD COLUMN IF NOT EXISTS images_json LONGTEXT NOT NULL DEFAULT '[]'
  COMMENT '效果图列表 JSON：[{url,data},...]，[0]=封面';

-- 2. 将旧 pose_json 单对象包装为数组（仅在非数组时）
-- MySQL 不支持 IF 条件直接操作 JSON，用 UPDATE + JSON_VALID + JSON_TYPE 判断
UPDATE templates
  SET pose_json = CONCAT('[', pose_json, ']')
  WHERE JSON_TYPE(pose_json) NOT IN ('ARRAY', 'NULL');

-- 3. 将旧 cover_url 同步到 images_json 首元素（仅 images_json 为空数组时）
UPDATE templates
  SET images_json = JSON_ARRAY(JSON_OBJECT('url', cover_url))
  WHERE JSON_LENGTH(images_json) = 0
    AND cover_url IS NOT NULL
    AND cover_url != '';
```

- [ ] **Step 2: 更新 drizzle schema**

在 `schema.ts` 的 `templates` 表定义（L184-210），`poseJson` 行之后新增：

```ts
  // 多效果图列表（[0]=封面）；旧数据由迁移从 cover_url 派生
  imagesJson: longtext('images_json').notNull().default('[]'),
```

- [ ] **Step 3: 验证**

```bash
cd lumira-server && pnpm --filter @lumira/backend typecheck
```
Expected: 0 error。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/022_template_images_poses.sql lumira-server/packages/backend/src/database/schema.ts
git commit -m "feat(backend): 迁移 022 新增 images_json 列 + pose_json 数组化"
```

---

### Task 2: Shared Types —— `poses[]` / `images[]` / 三级分类

**Files:**
- Modify: `lumira-server/packages/shared/src/types/template.ts`

- [ ] **Step 1: 新增 `TemplateImage` / `TemplatePose` 接口**

在 `template.ts` 的 `RemoteTemplateMeta` 之前新增：

```ts
/** 效果图（[0]=封面） */
export interface TemplateImage {
  url: string;
  /** base64 data URL（可选，内置模板用） */
  data?: string;
}

/** 姿势剪影 */
export interface TemplatePose {
  name?: string;
  description?: string;
  silhouette: { type: string; data?: string; url?: string };
  position: { x: number; y: number };
  scale: number;
  rotation: number;
}
```

- [ ] **Step 2: `RemoteTemplateMeta` 增加 `images` + `poses`**

```ts
export interface RemoteTemplateMeta {
  // ... 原有字段不变 ...
  coverUrl: string;          // 保留（= images[0].url 派生）
  /** 效果图列表（[0]=封面）。旧数据由 cover_url 派生单元素。 */
  images?: TemplateImage[];
  /** 姿势组。旧数据由 pose 派生单元素。 */
  poses?: TemplatePose[];
  // classification 改为三级：
  classification: { type: string; majorStyle: string; style: string; method?: string };
  // ... 其余不变 ...
}
```

> `style` 取代旧 `subStyle`（对齐三级命名：大类→风格→子风格）。`subStyle` / `method` 保留为可选兼容字段。

- [ ] **Step 3: `RemoteTemplateDetail` 改 `pose` → `poses`**

```ts
export interface RemoteTemplateDetail extends RemoteTemplateMeta {
  composition: Record<string, unknown>;
  /** 兼容旧 App：首个姿势 */
  pose: Record<string, unknown>;
  /** 姿势组（多姿势） */
  poses?: TemplatePose[];
  camera: Record<string, unknown>;
  sceneGuide: Record<string, unknown>;
  postProcess: Record<string, unknown>;
}
```

- [ ] **Step 4: `AdminTemplateDetail` / `CreateTemplateRequest` 同步**

在 `AdminTemplateDetail` 增加 `images?: TemplateImage[]` / `poses?: TemplatePose[]`；`classification` 改 `{ type; majorStyle; style; method? }`。
在 `CreateTemplateRequest` 的 `pose?` 改为 `poses?: TemplatePose[]`（兼容 `pose?`），增加 `images?: TemplateImage[]`。

- [ ] **Step 5: 构建 shared**

```bash
cd lumira-server && pnpm --filter @lumira/shared build
```
Expected: 编译通过。

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/shared/src/types/template.ts
git commit -m "feat(shared): 模板类型增加 images/poses 数组 + 三级分类"
```

---

### Task 3: DTO —— `poses` / `images` + 三级分类

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/dto/create-template.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/dto/update-template.dto.ts`

- [ ] **Step 1: `CreateTemplateDto` 增加 `poses` / `images`**

在 `create-template.dto.ts`：
- `pose?: Record<string, unknown>` 保留（兼容旧 admin）
- 新增 `poses?: Record<string, unknown>[]`（多姿势数组）
- 新增 `images?: Record<string, unknown>[]`（多效果图）
- `classification` 类型改为 `{ type: string; majorStyle: string; style: string; method?: string; subStyle?: string }`

- [ ] **Step 2: `UpdateTemplateDto` 同步**

在 `update-template.dto.ts` 做相同改动（所有字段可选）。

- [ ] **Step 3: Commit**

```bash
git add lumira-server/packages/backend/src/modules/templates/dto/create-template.dto.ts lumira-server/packages/backend/src/modules/templates/dto/update-template.dto.ts
git commit -m "feat(backend): DTO 支持 poses/images 数组 + 三级分类"
```

---

### Task 4: Service —— `admin-templates.service.ts` 读写多图/多姿势

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts`

- [ ] **Step 1: create 方法写 images / poses**

在 `create()` 的 INSERT 中（L230-260）：
- `poseJson` 改为 `JSON.stringify(meta.poses ?? (meta.pose ? [meta.pose] : []))`
- 新增 `imagesJson: JSON.stringify(meta.images ?? (coverUrl ? [{ url: coverUrl }] : []))`
- `classificationJson` 中 `subStyle` 改为 `style`（保留 `subStyle` 兼容写旧值）

- [ ] **Step 2: 多图上传存储**

在 `create()` / `update()` 中，支持多张效果图文件上传：
- 接受 `images: UploadFile[]`（可选）
- 每张存为 `templates/{id}/image_{i}.{ext}`，URL 写入 `imagesJson`
- 首张同时写 `cover_url`（兼容旧 App）

- [ ] **Step 3: update 方法同步**

在 `update()` 中，读写 `imagesJson` / `poses` 数组，保留旧 `cover` / `silhouette` 兼容路径。

- [ ] **Step 4: `rowToMeta` / `rowToDetail` 读多图/多姿势**

在 `templates.service.ts`：
- `rowToMeta`: 增加 `images` 解析（`images_json` 为空数组时由 `coverUrl` 派生单元素），`classification.style` 取 `subStyle` 兼容
- `rowToDetail`: 增加 `poses` 解析（`pose_json` 为数组时直接用，旧单对象包装为 `[obj]`），保留 `pose` 兼容输出首个

- [ ] **Step 5: Controller 接受多图文件**

在 `admin-templates.controller.ts` 的 create/update 装饰器中，增加 `@UploadedFiles() images` 支持。

- [ ] **Step 6: typecheck + e2e**

```bash
cd lumira-server && pnpm --filter @lumira/backend typecheck
cd lumira-server && pnpm --filter @lumira/backend test:e2e -- --testPathPattern=templates
```

- [ ] **Step 7: Commit + Push 双远程**

```bash
git add lumira-server/packages/backend/src/modules/templates/
git commit -m "feat(backend): service 读写 images/poses 数组 + 多图上传"
git push origin master
git push github master
```

---

### Task 5: 旧数据兼容验证 + 全量 typecheck

- [ ] **Step 1: 验证迁移幂等**

确认 `022_*.sql` 在已有 `images_json` 列时不报错（`IF NOT EXISTS`）。

- [ ] **Step 2: 全量 typecheck**

```bash
cd lumira-server && pnpm -r typecheck
```

- [ ] **Step 3: Commit + Push**

```bash
git add -u lumira-server/
git commit -m "chore(backend): Phase 3 全量验证"
git push origin master
git push github master
```
