# 模板多姿势 Phase 4：Admin 多图上传 + 多剪影 + 三级级联 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 按任务逐条执行。

**Goal:** Admin 模板表单从「单封面 + 单剪影 + 四级级联」改为「多效果图上传（首张=封面）+ 多姿势剪影配置 + 三级级联」，对齐 Phase 3 后端 API。

**Architecture:** `template-form.tsx` 新增多图上传状态 + 多 pose 编辑器；分类级联删第四层；`templates.ts` action 提交 `images[]` / `poses[]`；`admin.ts` 类型对齐 shared。

**Tech Stack:** Next.js App Router + Tailwind + shadcn/ui + React Hook Form + Zod。

## 全局约束

- 不引入新依赖；复用 shadcn/ui 组件。
- 多图上传 UI：横排缩略图 + 添加/删除/拖拽排序；首张标「封面」角标。
- 多姿势 UI：列表 + 增删 + 切换当前编辑；每个姿势含剪影上传/内置选择/位置/缩放/旋转。
- 三级级联：大类(type) → 风格(majorStyle) → 子风格(style)；删第四层(method)渲染。
- 提交格式对齐 Phase 3 后端：`images[]` (FormData 多文件) + `poses` (JSON) + `classification { type, majorStyle, style }`。
- Vercel 部署：push master 改动 admin/** 时自动触发。

---

### Task 1: 类型对齐

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`

- [ ] **Step 1: 更新 `AdminTemplateDetail` / `CreateTemplateRequest`**

从 `@lumira/shared` 导入 `TemplateImage` / `TemplatePose`，在 `AdminTemplateDetail` 增加 `images?: TemplateImage[]` / `poses?: TemplatePose[]`；`classification` 改 `{ type; majorStyle; style; method? }`。

- [ ] **Step 2: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts
git commit -m "feat(admin): 类型对齐 shared TemplateImage/TemplatePose"
```

---

### Task 2: 多图上传 UI

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`

- [ ] **Step 1: 新增多图状态**

在组件 state 中，将 `coverFile: File | null` 改为 `imageFiles: File[]`，新增 `imagePreviews: string[]`。编辑模式时从 `initial.images` 初始化预览。

- [ ] **Step 2: 多图上传 UI**

替换原单封面上传区域为横向缩略图列表：
- 缩略图横排（`flex gap-2 overflow-x-auto`），每张 120×120
- 首张标「封面」角标（`absolute top-1 left-1` badge）
- 每张有删除按钮（`absolute top-1 right-1`）
- 末尾「+ 添加」按钮触发 `<input type="file" multiple accept="image/*">`
- 支持 drag-and-drop 排序（可用简单的「左移/右移」按钮替代复杂拖拽）

- [ ] **Step 3: 封面一致性**

封面始终取 `imageFiles[0]` / `imagePreviews[0]`；删除首张时第二张自动成封面。提交时首图同时作为 `cover` 字段发送（兼容后端）。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/components/template-form.tsx
git commit -m "feat(admin): 模板表单多效果图上传 UI"
```

---

### Task 3: 多姿势编辑器

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`

- [ ] **Step 1: pose 状态改为数组**

将单个 `silhouetteFile` / `poseDescription` / `posePositionX/Y` / `poseScale` / `poseRotation` / `silhouetteType` / `silhouetteBuiltinKey` 改为 `poses: PoseFormData[]`，每个含完整 pose 字段。编辑模式时从 `initial.poses` 初始化。

- [ ] **Step 2: 姿势列表 UI**

在表单中新增姿势列表区域：
- 横排胶囊/Tab 切换当前编辑的姿势（`Pose 1` / `Pose 2` / ...）
- 「+ 添加姿势」按钮
- 「删除当前姿势」按钮（至少保留 1 个）
- 当前选中姿势的编辑面板（复用现有 silhouette 上传/内置选择/位置/缩放/旋转 UI）

- [ ] **Step 3: 剪影独立上传**

每个姿势的剪影独立上传，存为 `templates/{id}/silhouette_{i}.{ext}`。内置剪影选择不变。

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/components/template-form.tsx
git commit -m "feat(admin): 多姿势编辑器（列表+增删+切换）"
```

---

### Task 4: 三级级联 + onSubmit 改造

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`
- Modify: `lumira-server/packages/admin/src/actions/templates.ts`

- [ ] **Step 1: 删除第四级级联**

删除 `methodOptions` 和 `classificationMethod` 的渲染（`Select` 组件）。保留 `level <= 3` 的级联。zod schema 中删 `classificationMethod`。

- [ ] **Step 2: onSubmit 提交 poses/images**

在 `onSubmit` 中：
- `pose` 改为 `poses` 数组（遍历 `poses` state 构造 `TemplatePose[]`）
- `images` 多文件 append 到 FormData（`images_0`, `images_1`, ... 或 `images[]`）
- `classification` 改 `{ type, majorStyle, style }`（删 `method`/`subStyle`，`style` 取原 `subStyle` 值）

- [ ] **Step 3: `templates.ts` action 适配**

在 `createTemplate` / `updateTemplate` 中，接受多图文件参数，FormData append 多个 `images` 字段。

- [ ] **Step 4: Commit + Push**

```bash
git add lumira-server/packages/admin/src/components/template-form.tsx lumira-server/packages/admin/src/actions/templates.ts
git commit -m "feat(admin): 三级级联 + onSubmit 提交 poses/images 数组"
git push origin master
git push github master
```
