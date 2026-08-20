# 后台展示内置模板使用次数 — 设计

> 日期：2026-08-20 · 关联功能：使用次数统计 + 推荐增强（usage-stats-recommend）

## 1. 背景与问题

后台已经能在模板页/场景页按卡片展示「拍摄 / 查看（/ 选场）」的使用次数。但**内置模板**（App 内嵌于 `TemplateRegistry`，共 29 款，如 `soft_portrait`、`night_cityscape`）后端完全没有它们的信息，后台模板列表只渲染后端 `templates` 表的记录，导致这些内置模板**一张卡片都没有、次数完全不可见**——即便后端 `GET /api/v1/usage/stats` 已按 `item_id` 聚合了它们的次数。

目标：后台能看到内置模板的使用次数统计；取不到的数据（封面）不展示；同时展示内置模板名称，且名称以 App 为准、改名可自动同步到后端。

## 2. 需求确认（来自用户）

- 独立「内置模板」分区展示（Recommended）。
- 显示模板 id（Recommended），并且**同时展示内置模板名称**。
- 后续若修改内置模板名称，需同步到后端（后端作为展示名的事实来源 = App 同步）。
- 名称进后端方式：**后端注册表 + App 同步**（Recommended）。
- 场景次数组已在后台按卡片展示，本需求不改场景部分。

## 3. 方案总览

| 层 | 改动 |
|---|---|
| 后端 | 新增 `builtin_templates` 注册表 + 客户端上报接口 + 后台读取接口 |
| App | 新增 `BuiltinTemplateSyncService`，启动同步内置模板 id→名称 |
| 后台 | 模板页新增「内置模板」只读分区，展示名称 + id + 次数 |

## 4. 后端

### 4.1 数据模型：`builtin_templates`

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | VARCHAR PK | 内置模板 id（如 `soft_portrait`） |
| `name` | VARCHAR NOT NULL | 当前名称（App 同步更新） |
| `updated_at` | BIGINT NOT NULL | 毫秒时间戳，同步时刷新 |

- 迁移：`lumira-server/packages/backend/src/database/migrations/015_builtin_templates.sql`（`CREATE TABLE IF NOT EXISTS ...`，幂等）。
- Drizzle schema：`src/database/schema.ts` 新增 `builtinTemplates` 表定义（与 `usageEvents` 同风格）。
- shared：`packages/shared/src/types/usage.ts` 新增
  - `BuiltinTemplate { id: string; name: string }`
  - `BuiltinTemplateSyncInput { items: BuiltinTemplate[] }`
  - `BuiltinTemplateListResponse { items: BuiltinTemplate[] }`

### 4.2 客户端上报（DeviceAuthGuard）

`POST /api/v1/usage/builtin-templates`
- Controller：`usage.controller.ts`（已有 DeviceAuthGuard）新增方法，调用 service。
- Body：`{ items: [{ id, name }] }`；空数组直接返回忽略。
- Service：逐条 `INSERT ... ON DUPLICATE KEY UPDATE name=VALUES(name), updated_at=VALUES(updated_at)`（`id` 主键幂等）。返回 `{ upserted: items.length }`。
- 不删除除，离线重连重复上报只更新 name。

### 4.3 后台读取（AdminAuthGuard）

`GET /api/v1/admin/usage/builtin-templates`
- Controller：`admin-usage.controller.ts` 新增方法。
- 返回 `{ items: [{ id, name }] }`，按 `id` 排序。

## 5. App：内置模板名称同步

- 新增 `lib/features/usage/builtin_template_sync_service.dart`（或在 usage 目录内新建）：
  - `class BuiltinTemplateSyncService`，可注入网络抽象 `BuiltinTemplateNetwork { Future<void> sync(List<BuiltinTemplateEntry>) }`（风格对齐 `UsageSyncService` 的 `DioUsageNetwork`）。
  - `Future<bool> syncBuiltinTemplates()`：取 `TemplateRegistry.allTemplates` 的 `[{ id, name }]` 全量列表 POST 到 `/usage/builtin-templates`；失败/离线抛异常 → 返回 `false`，调用方静默，不阻塞启动。
  - 提供 `builtinTemplateSyncServiceProvider`（FutureProvider，依赖 apiClientProvider）。
- 触发：在 `main.dart` 启动注册 device 成功后，与 `UsageSyncService` 同步链一起执行（best-effort），离线跳过等下次启动。

## 6. 后台：模板页「内置模板」分区

`packages/admin/src/app/dashboard/templates/page.tsx` + `components/template-card-grid.tsx`：

- 页面数据源：
  - 新增 `getBuiltinTemplates(): Promise<BuiltinTemplate[]>`（`adminFetch` `/usage/builtin-templates?`，best-effort 失败返回 `[]`）。
  - **复用**已存在的 `getUsageStats('template')`（已含内置模板 id 的次数）。
- 合并规则：
  - `builtinRecords = builtins.filter(b => !templates.some(t => t.id === b.id))`（排除主网格已展示的内置 id，避免重复）。
  - 次数 `u = usage[b.id]`，无则显示 0。
- 渲染：在模板卡片网格**下方**新增独立「内置模板」分区（标题 + 分隔）。
  - 卡片：`内置` Badge + 名称（缺省回退 id）+ id（小字）+ 「拍摄 x · 查看 y」（无则 0）+ 「无封面」占位（封面取不到不展示）。**只读**，无编辑/删除/上下架。
- 空态：`builtinRecords` 为空时显示「暂未获取到内置模板记录，App 同步后展示」。
- 对每个后端已注册的内置模板都渲染一张卡片（即使次数为 0，也显示 0，便于运营查看全量热度）；不渲染后端未注册的额外占位。

## 7. 错误处理与降级

- App 同步失败：静默，不阻塞启动，下次启动再同步。
- 后台读取后台接口失败：`getBuiltinTemplates` 返回 `[]`，分区显示空态，不影响主营页渲染（与现有 `getUsageStats` best-effort 一致）。
- `stats` 端点无内置数据：分区为空态，不报错。

## 8. 测试

- 后端：`usage.service` 新增 upsert 幂等的单元测试；`admin-usage.controller` DTO/返回结构测试（沿用现有 `.spec` 风格）。
- App：`builtin_template_sync_service_test.dart` —— 断言全量同步、空列表跳过、离线返回 false 不抛。
- 后台：`api.test.ts` 补充 `getBuiltinTemplates` 的 URL/鉴权断言。

## 9. 范围外（YAGNI）

- 不做内置模板的封面/剪影等资产托管（取不到即「无封面」）。
- 不做内置模板在后台的增删改（名称以 App 为唯一来源）。
- 不改场景次数展示（已完善）。

## 10. 交付约束

- 后端/后台改动完成后 commit 并 push 到 gitee(`origin`) 与 github(`github`) 双远端（AGENTS.md）。
- shared 类型改动需同步 `shared` 包 build 供 backend/admin 引用。