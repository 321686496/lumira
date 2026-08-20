# 通知中心优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将通知中心从 mock 改造为真实数据：后端公告（后台可配置定向投放：全部/指定设备/按型号/版本/平台/邮箱/用户属性）+ 本地应用事件通知（真实本地数值），已读/清除/未读红点存本机（方案 C）。

**Architecture:** 后端新增 `notifications` 表（公告内容+定向），提供设备端拉取接口（按 deviceId 查 `devices` 后逐条匹配 scope/criteria/投放窗口）与后台 CRUD 接口。App 端依据 `remote_templates` 等远端同步的模式：进通知中心拉后端公告 upsert 进 sqflite、合并本地生成的通知、排序、读/删状态存本机，首页铃铛展示未读红点。后台复用 shadcn/ui + server action 模式。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL8；Next.js(App Router)+Tailwind+shadcn/ui；Flutter 3.7.12/Dart 2.19.6 + flutter_riverpod + sqflite。

## Global Constraints

- 客户端 Flutter 3.7.12 / Dart 2.19.6，**不支持 Dart 3 records 语法**；Dart 大对象一律用类。
- 本地表列名/表名集中在 `lib/core/db/tables.dart`，不得在 SQL 中散落硬编码字符串。
- sqflite 逐版本迁移在 `database_provider.dart` 的 `_onUpgrade` 用 `if (oldVersion < N)`，新增表用 `CREATE TABLE IF NOT EXISTS`；DB 大版本号升到 32。
- 后端迁移：`src/database/schema.ts`（Drizzle 表）+ `src/database/migrations/020_notifications.sql`（DDL），启动时 `DatabaseService.runMigrations()` 按文件名幂等应用。
- 后端公开 client 接口挂 `/api/v1/notifications`（`DeviceAuthGuard` + `@DeviceId()`）；后台接口挂 `/api/v1/admin/notifications`（`AdminAuthGuard`）。
- admin 后台 API 方法统一加在 `packages/admin/src/lib/api.ts`；server action 在 `src/actions/`；类型在 `types/admin.ts`。
- 「按用户属性筛选」落地为 `targetCriteriaJson`（platform/deviceModel/osVersion/appVersion/email/region/userIdList，各为数组，空数组=不限，支持 `*` 通配），不接入积分/问卷业务属性（保留预留位）。
- 后端公告 `source='remote'` 不可跳转（仅已读）；本地 app 事件通知 `source='local'` 可跳转。
- 后端公告下架/删除后，App 端以便拉取列表为准清理本地已不存在 `remoteId` 的记录。
- 后端/后台每完成一次修改必须 commit 并按 AGENTS.md 规则 push 到 origin(gitee) 与 github，不要积压。
- Flutter UI 严格遵循 `themeTokensProvider`/`uiStyleProvider` 风格规范，禁止硬编码主题色（见 AGENTS.md「Flutter UI 设计规范」）。

---

### Task 1: 后端 shared 类型 + Drizzle schema + 迁移 SQL

**Files:**
- Create: `lumira-server/packages/shared/src/types/notifications.ts`
- Modify: `lumira-server/packages/shared/src/index.ts`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/020_notifications.sql`

**Interfaces:**
- Produces: shared 类型 `NotificationTargetScope`, `NotificationItem`, `NotificationListResponse`；Drizzle 表 `notifications`（列：`id/title/body/iconKey/category/targetScope/targetDeviceIdsJson/targetCriteriaJson/startAt/endAt/isActive/sortOrder/createdAt/updatedAt`）；迁移 `020_notifications.sql`。

- [ ] **Step 1: 新增 shared 类型文件**

```ts
// lumira-server/packages/shared/src/types/notifications.ts
export type NotificationTargetScope = 'all' | 'devices' | 'criteria';

export interface NotificationCriteria {
  /** 空数组=不限；支持 '*' 整体通配 */
  platform?: string[];
  deviceModel?: string[];
  osVersion?: string[];
  appVersion?: string[];
  email?: string[];
  /** 预留：按地区 / deviceId 列表 */
  region?: string[];
  userIdList?: string[];
}

export interface NotificationItem {
  id: string;
  title: string;
  body: string;
  iconKey: string;
  category: string;
  startAt?: number | null;
  endAt?: number | null;
}

export interface NotificationListResponse {
  notifications: NotificationItem[];
}
```

在 `src/index.ts` 顶部 `export * from './types/notifications';`（观察 `index.ts` 现有导出顺序，追加一行）。

- [ ] **Step 2: 运行 shared build 验证**

Run: `pnpm --filter @lumira/shared build`（在 `lumira-server/` 下）
Expected: 构建成功、无 TS 报错。

- [ ] **Step 3: schema.ts 新增 `notifications` 表**

在 `src/database/schema.ts` 末尾追加，字段类型参考既有表（id 用 `text` PK，时间戳用 `int` 毫秒）：

```ts
// ===== 通知公告（spec 2026-08-20-notifications-center）=====
export const notifications = mysqlTable('notifications', {
  id: text('id').primaryKey(),
  title: text('title').notNull(),
  body: text('body').notNull(),
  iconKey: text('icon_key').notNull().default('announcement'),
  category: text('category').notNull().default('announcement'),
  targetScope: text('target_scope').notNull().default('all'),
  targetDeviceIdsJson: text('target_device_ids_json').notNull().default('[]'),
  targetCriteriaJson: text('target_criteria_json').notNull().default('{}'),
  startAt: int('start_at'),
  endAt: int('end_at'),
  isActive: int('is_active').notNull().default(1),
  sortOrder: int('sort_order').notNull().default(0),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
});
```

- [ ] **Step 4: 新增迁移 SQL**

创建 `src/database/migrations/020_notifications.sql`，与 schema 保持一致（幂等建表）：

```sql
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` TEXT NOT NULL,
  `title` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `icon_key` TEXT NOT NULL DEFAULT 'announcement',
  `category` TEXT NOT NULL DEFAULT 'announcement',
  `target_scope` TEXT NOT NULL DEFAULT 'all',
  `target_device_ids_json` TEXT NOT NULL DEFAULT '[]',
  `target_criteria_json` TEXT NOT NULL DEFAULT '{}',
  `start_at` INT NULL,
  `end_at` INT NULL,
  `is_active` INT NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL,
  `updated_at` INT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 5: 后端 typecheck**

Run（在 `lumira-server/`）：`pnpm --filter @lumira/backend typecheck`
Expected: 通过（无 `notifications` 未使用报错即视为 schema 编译 OK）。

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/shared/src/types/notifications.ts lumira-server/packages/shared/src/index.ts lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/database/migrations/020_notifications.sql
git commit -m "feat(backend): notification schema + shared types + migration"
```

---

### Task 2: 后端公开设备接口 GET /api/v1/notifications + 定向匹配

**Files:**
- Create: `lumira-server/packages/backend/src/modules/notifications/notifications.service.ts`
- Create: `lumira-server/packages/backend/src/modules/notifications/notifications.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/notifications/notifications.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`

**Interfaces:**
- Consumes: 上一步的 `notifications` 表、`NotificationItem`/`NotificationListResponse`；`DatabaseService`；`DeviceAuthGuard`/`@DeviceId`。
- Produces: `NotificationsService.listForDevice(deviceId: string): Promise<NotificationListResponse>`；控制器 `GET /notifications`（`@UseGuards(DeviceAuthGuard)`）。

- [ ] **Step 1: 编写 service（含定向匹配）**

```ts
// notifications.service.ts
import { Injectable } from '@nestjs/common';
import { and, eq, gte, lte, asc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { notifications, devices } from '../../database/schema';

@Injectable()
export class NotificationsService {
  constructor(private readonly dbService: DatabaseService) {}

  async listForDevice(deviceId: string) {
    const db = this.dbService.getDb();
    const now = Date.now();
    const rows = await db.select()
      .from(notifications)
      .where(eq(notifications.isActive, 1))
      .orderBy(asc(notifications.sortOrder), notifications.createdAt);
    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    const list = rows
      .filter((n) => {
        if (n.startAt && now < n.startAt) return false;
        if (n.endAt && now > n.endAt) return false;
        return this.matches(n, device);
      })
      .map((n) => ({
        id: n.id,
        title: n.title,
        body: n.body,
        iconKey: n.iconKey,
        category: n.category,
        startAt: n.startAt ?? null,
        endAt: n.endAt ?? null,
      }));
    return { notifications: list };
  }

  /** 定向匹配：scope=all 恒真；devices 按 id；criteria 按设备字段 + 通配 */
  private matches(n: typeof notifications.$inferSelect, device: { platform: string | null; osVersion: string | null; deviceModel: string | null; appVersion: string | null; email: string | null; ipRegion: string | null } | undefined) {
    if (n.targetScope === 'all') return true;
    if (n.targetScope === 'devices') {
      const ids: string[] = JSON.parse(n.targetDeviceIdsJson || '[]');
      const devId = device ? (device as { deviceId: string }).deviceId : undefined;
      return Boolean(device && devId && ids.includes(devId));
    }
    // criteria
    const c = JSON.parse(n.targetCriteriaJson || '{}') as Record<string, string[] | undefined>;
    const hit = (field: keyof typeof device, key: string): boolean => {
      const list = c[key];
      if (!list || list.length === 0) return true;
      const value = device ? device[field] : null;
      return list.some((rule) => rule === '*' || (value != null && value === rule));
    };
    if (!hit('platform', 'platform')) return false;
    if (!hit('deviceModel', 'deviceModel')) return false;
    if (!hit('osVersion', 'osVersion')) return false;
    if (!hit('appVersion', 'appVersion')) return false;
    if (!hit('email', 'email')) return false;
    return true;
  }
}
```

> 说明：`devices` 表查询需返回 `deviceId` 字段用于 `scope='devices'` 匹配。若类型签名不适配，可在 `matches` 内直接把 `device` 参数的 id 提前读出传参，避免依赖 `$inferSelect`。email 通配仅支持整体 `*`；如需局部通配（`*@x.com`），在 `hit` 的匹配分支加 `value.endsWith(rule.slice(1))` 处理，保持简洁即可。

- [ ] **Step 2: 编写 controller + module**

`notifications.controller.ts`：`@Controller('notifications')` + `@UseGuards(DeviceAuthGuard)`，`@Get()` 注入 `@DeviceId() deviceId` 调 `service.listForDevice(deviceId)`。

`notifications.module.ts`：仿 `scenes.module.ts`，imports `[DatabaseModule, JwtModule.register({ secret: process.env.JWT_SECRET || 'dev-secret-change-me', signOptions: { expiresIn: '30d' } })]`（DeviceAuthGuard 依赖 JwtService），controllers/ providers 补全。

- [ ] **Step 3: 注册模块到 app.module.ts**

参考现有 `ScenesModule` 的导入与注册方式，把 `NotificationsModule` 加入 `imports`。

- [ ] **Step 4: typecheck**

Run（在 `lumira-server/`）：`pnpm --filter @lumira/backend typecheck`
Expected: 通过。

- [ ] **Step 5: Commit（并 push 到双远程，见 AGENTS.md）**

```bash
git add lumira-server/packages/backend/src/modules/notifications lumira-server/packages/backend/src/app.module.ts
git commit -m "feat(backend): device notifications list API with targeting"
git push origin master; git push github master
```

---

### Task 3: 后端 Admin CRUD 接口

**Files:**
- Create: `lumira-server/packages/backend/src/modules/notifications/dto/create-notification.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/notifications/dto/update-notification.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/notifications/admin-notifications.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/notifications/notifications.service.ts`（追加 admin 方法）
- Modify: `lumira-server/packages/backend/src/modules/notifications/notifications.module.ts`

**Interfaces:**
- Consumes: `notifications` 表。
- Produces: `NotificationsService.listAdmin()`、`create(dto)`、`update(id,dto)`、`remove(id)`、`toggleActive(id)`；`CreateNotificationDto`/`UpdateNotificationDto`；`AdminNotificationsController`（`@Controller('admin/notifications')` + `AdminAuthGuard`）。

- [ ] **Step 1: 定义 DTO**

`create-notification.dto.ts`：`id`（可选，缺省生成 `ntf-` + 随机串）、`title`、`body` 必填；`iconKey`、`category`、`targetScope`、`targetDeviceIdsJson`、`targetCriteriaJson`、`startAt`、`endAt`、`isActive`、`sortOrder` 可选。用 `@IsString()`/`@IsOptional()`/`@IsInt()` 等 decorate（观察现有 DTO 写法如 `scenes/dto/create-scene.dto.ts`）。
`update-notification.dto.ts`：全部可选（PartialType 或全可选字段，参考现有 update dto）。

- [ ] **Step 2: service 追加 admin 方法**

`listAdmin()`：`SELECT` 全部 `notifications`，`orderBy(sortOrder asc, createdAt`，r-aw 返回数组即可（后台前端转 camel 由 admin 类型层处理，或直接返回 drizzle 行）。
`create(dto)`：`id = dto.id || \`ntf-${Date.now()}-${Math.random().toString(36).slice(2,8)}\``，`createdBy=updated=Date.now()`，`INSERT`。
`update(id,dto)`：`UPDATE ... .set({...dto, updatedAt: Date.now()})`，仅更新传入字段。
`remove(id)`：`DELETE`。
`toggleActive(id)`：`SELECT` 当前 `isActive`，翻转让后 `UPDATE`，返回新 `isActive`。

- [ ] **Step 3: admin controller + module 注册**

`admin-notifications.controller.ts`：`@Controller('admin/notifications')` + `@UseGuards(AdminAuthGuard)`，`@Get/@Post/@Patch(':id')/@Delete(':id')/@Post(':id/toggle')`，仿 `admin-scenes.controller.ts`。
`notifications.module.ts` controllers 补 `AdminNotificationsController`。

- [ ] **Step 4: typecheck**

Run（在 `lumira-server/`）：`pnpm --filter @lumira/backend typecheck`
Expected: 通过。

- [ ] **Step 5: Commit + push**

```bash
git add lumira-server/packages/backend/src/modules/notifications
git commit -m "feat(backend): admin notifications CRUD API"
git push origin master; git push github master
```

---

### Task 4: 后台 Next.js 通知公告管理页

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Modify: `lumira-server/packages/admin/src/lib/api.ts`
- Create: `lumira-server/packages/admin/src/actions/notifications.ts`
- Create: `lumira-server/packages/admin/src/app/dashboard/notifications/page.tsx`
- Create: `lumira-server/packages/admin/src/components/notification-manager.tsx`
- Modify: `lumira-server/packages/admin/src/components/sidebar.tsx`

**Interfaces:**
- Consumes: 后端 admin API（camelCase 键）。
- Produces: admin `NotificationAdminItem` 类型、`api.listNotifications/createNotification/updateNotification/deleteNotification/toggleNotification`、server action `saveNotification/removeNotification/setNotificationActive`；通知管理页面与侧边栏入口。

- [ ] **Step 1: 添加 admin 类型**

在 `types/admin.ts` 追加：
```ts
export interface NotificationAdminItem {
  id: string; title: string; body: string;
  iconKey: string; category: string;
  targetScope: 'all' | 'devices' | 'criteria';
  targetDeviceIds: string[];        // 从 targetDeviceIdsJson 解析
  targetCriteria: Record<string, string[]>;
  startAt?: number | null; endAt?: number | null;
  isActive: number; sortOrder: number;
  createdAt: number; updatedAt: number;
}
```

- [ ] **Step 2: api.ts 追加方法**

仿现有 `listScenes/updateScene` 等，新增：
`listNotifications(): Promise<{ notifications: NotificationAdminItem[] }>`（GET `/notifications`）
`createNotification(payload)`（POST）、`updateNotification(id,payload)`（PATCH）、`deleteNotification(id)`（DELETE）、`toggleNotification(id)`（POST `:id/toggle`）。
请求体 key 用 camelCase；后端 `@Body() dto` 若用注入校验对象，需接受 camelCase→snake 转换（在 action 或 service 层映射），保持与现有模板/场景模式一致。

- [ ] **Step 3: server actions**

`actions/notifications.ts`，仿 `actions/scenes.ts`，实现 `saveNotification(id, body)`、`removeNotification(id)`、`setNotificationActive(id)`，`revalidatePath('/dashboard/notifications')`、未登录 `redirect('/login')`。

- [ ] **Step 4: 页面 + 管理组件**

`app/dashboard/notifications/page.tsx`：仿 `scenes/page.tsx`，`await api.listNotifications()`（`UnauthenticatedError` → redirect），渲染 `<NotificationManager notifications={list} />`。
`components/notification-manager.tsx`：客户端组件，参照 `scene-manager.tsx` 骨架：
- 列表表格（shadcn `Table`）：标题/分类/定向摘要/投放窗口/创建时间/启停 `Switch`/删除。
- 新建/编辑 `Dialog` + `Form`：公共字段（title/body/category/iconKey/startAt/endAt/sortOrder/isActive）+ 定向作用域 `Select`（all/devices/criteria）+ devices 多行输入框 + criteria 各条件输入（platform/deviceModel/osVersion/appVersion/email，逗号分隔转数组）。

- [ ] **Step 5: 侧边栏入口**

在 `components/sidebar.tsx` 加入「通知公告」导航到 `/dashboard/notifications`（仿既有项）。

- [ ] **Step 6: 构建验证**

Run（在 `lumira-server/packages/admin`）：`pnpm build`（或 `pnpm --filter @lumira/admin build`）
Expected: 构建通过、无类型错误。

- [ ] **Step 7: Commit + push**

```bash
git add lumira-server/packages/admin/src
git commit -m "feat(admin): notifications announcement manager"
git push origin master; git push github master
```

---

### Task 5: Flutter DB 表 + 版本升级 + DAO

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`
- Create: `lumira_app_flutter/lib/features/notification/data/notification_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（注册 DAO provider）

**Interfaces:**
- Produces: `Tables.notifications` + 列常量；本地表 `notifications`；`NotificationDao`（`upsertRemote`, `insertLocal`, `list`, `markRead`, `markAllRead`, `clearById`, `clearAll`, `pruneRemoteIds`, `countUnread`, `getByLocalKey`）；`notificationDaoProvider`。

- [ ] **Step 1: tables.dart 追加常量**

```dart
// === notifications 表（v32 迁移新增，通知中心） ===
static const String notifications = 'notifications';
static const String colSource = 'source';        // 'remote' | 'local'
static const String colRemoteId = 'remote_id';
static const String colKind = 'kind';
static const String colRead = 'read';            // 0 未读 1 已读
static const String colCleared = 'cleared';      // 0 未清除 1 已清除
static const String colTimeMs = 'time_ms';
// title/body 复用自定义模板段的 colName? 不，直接用独立常量
static const String colTitleN = 'title';
static const String colBodyN = 'body';
```

> 注意：`colSource` 在 `custom_templates` 段已是 `'source'` 同名常量，直接复用同一字符串值即可，勿重复声明同名。`colTitleN`/`colBodyN` 同样避免与既有 `colName`/已有 `title`/`body` 成员冲突——查重后选用未占用名。如 `tables.dart` 中已有 `title`/`body` 常量则直接复用，否则新增带后缀名。

- [ ] **Step 2: DB 版本升级 + 迁移**

`_kDbVersion` 改 `32`；`_onCreate` 末尾追加建表（含 `CREATE INDEX idx_notifications_cleared`）；`_onUpgrade` 结尾追加：
```dart
if (oldVersion < 32) {
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.notifications} (
        ${Tables.colId} TEXT PRIMARY KEY,
        ${Tables.colSource} TEXT NOT NULL,
        ${Tables.colRemoteId} TEXT,
        ${Tables.colKind} TEXT NOT NULL,
        ${Tables.colTitleN} TEXT NOT NULL,
        ${Tables.colBodyN} TEXT NOT NULL,
        ${Tables.colTimeMs} INTEGER NOT NULL,
        ${Tables.colRead} INTEGER NOT NULL DEFAULT 0,
        ${Tables.colCleared} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_cleared ON ${Tables.notifications}(${Tables.colCleared})');
  } catch (e) { debugPrint('v32 migration failed (silent fallback): $e'); }
}
```

- [ ] **Step 3: 实现 NotificationDao**

仿 `usage_dao.dart` / `templates_dao` 风格。核心方法（以真实 sql 实现）：
`upsertRemote(NotificationRecord)`（`INSERT OR REPLACE` 由 `id=remote_id` 作主键，合并/更新已读前内容）。
`insertLocal(NotificationRecord)`（`insert`，`ConflictAlgorithm.ignore`）。
`list()`（按 `cleared=0`，`timeMs DESC`）。
`markRead(id)`、`markAllRead()`、`clearById(id)`、`clearAll()`。
`pruneRemoteIds(Set<String> validIds)`：`DELETE WHERE source='remote' AND remote_id NOT IN validIds`（sqlite 对空集合用占位符而非 IN()）。
`countUnread()`：`SELECT COUNT(*) WHERE read=0 AND cleared=0`。
`getByLocalKey(String linkKey)`（供本地生成去重判断）。
`NotificationRecord` 类：id/source/remoteId/kind/title/body/timeMs/read/cleared。
在 `database_provider.dart` 注册 `final notificationDaoProvider = FutureProvider<NotificationDao>(...)`。

- [ ] **Step 4: flutter analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/core/db lib/features/notification`
Expected: 无新增 error。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/core/db lib/features/notification
git commit -m "feat(app): local notifications table + DAO + db v32"
```

---

### Task 6: Flutter 模型 + Repository + Providers（远程拉取 + 合并 + 读/清）

**Files:**
- Create: `lumira_app_flutter/lib/features/notification/notification_models.dart`
- Create: `lumira_app_flutter/lib/features/notification/notification_repository.dart`
- Create: `lumira_app_flutter/lib/features/notification/notification_providers.dart`

**Interfaces:**
- Consumes: `ApiClient`/`apiClientProvider`、`NotificationDao`/`notificationDaoProvider`。
- Produces: `NotificationItem`（UI 模型）、`NotificationRepository`（`fetchRemote()`）、`remoteNotificationsSyncProvider`、`notificationsProvider`（合并后有序列表）、`unreadCountProvider`（红点）。

- [ ] **Step 1: 模型 + Repository**

`notification_models.dart`：`NotificationItem`（id/source/remoteId/kind/title/body/timeMs/read + 便捷 `toRecord()`）。
`notification_repository.dart`：仿 `remote_templates_repository.dart`，`fetchRemote()` → `api.get('/notifications', fromJson: NotificationListDto.fromJson)`；`NotificationListDto` 含 `List<RemoteNotificationDto>`（id/title/body/iconKey/category/startAt/endAt）。`remoteNotificationsProvider = FutureProvider<RemoteNotificationsRepository>`。

- [ ] **Step 2: 同步 provider**

`remoteNotificationsSyncProvider = FutureProvider<void>`：拉取后端 → 每条 `dao.upsertRemote(...)`（id=`remote:<id>`，timeMs=startAt 或当前时间）→ `dao.pruneRemoteIds(validRemoteIds)`。网络失败静默（同 `remoteTemplatesSyncProvider` 模式）。

- [ ] **Step 3: 合并 provider + 未读 provider**

`notificationsProvider = FutureProvider<List<NotificationItem>>`：触发 `remoteNotificationsSyncProvider`（可选点火）+ `unreadLocalGeneratedProvider`（见 Task 7）→ 读 `dao.list()` → 过滤 cleared=0 → 返回 `NotificationItem` 列表。
`unreadCountProvider = FutureProvider<int>`：`dao.countUnread()`（供首页铃铛红点）。
`markAsReadProvider`/`clearNotificationProvider`：用于调用 DAO 写操作后 `ref.invalidate(notificationsProvider/unreadCountProvider)`。

- [ ] **Step 4: flutter analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/notification`
Expected: 无新增 error。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/notification
git commit -m "feat(app): notifications repository + merge providers"
```

---

### Task 7: Flutter 本地应用事件通知生成器（真实数据）

**Files:**
- Create: `lumira_app_flutter/lib/features/notification/local_notification_generator.dart`

**Interfaces:**
- Consumes: `challengeDaoProvider`、`userTagsDaoProvider`？不——读取真实本地状态：连续打卡（`user_progress`）、挑战、成就、模板更新时间、App 版本。
- Produces: `NotificationItem` 列表；`unreadLocalGeneratedProvider`。

- [ ] **Step 1: 读取本地真实状态生成五类通知**

实现 `LocalNotificationGenerator.uniq(list)`（按 `kind+业务键` 去重，只插入本地表不重复叠加）：
- **连续打卡**：查 `user_progress.streak_days`（>1），生成 `kind='streak'`，body 含真实天数。
- **挑战提醒**：查今日挑战未完成（复用 challenge DAO 的“今日是否完成”逻辑），`kind='challenge'`。
- **成就解锁**：读 `user_progress.achievements_json` 最新解密项，`kind='achievement'`。
- **模板更新**：读内置/远端模板最近时间 `updatedAt` 或 `remote_templates`，`kind='template'`。
- **系统通知**：App 版本常量（`package_info` 或硬编码版本号）+ 静态文案，`kind='system'`。
> 每条生成用 `getByLocalKey('${kind}:${dateOrId}')` 判重，已存在则跳过（避免每次进页重复插入）。生成后 `insertLocal`。

- [ ] **Step 2: provider**

`unreadLocalGeneratedProvider = FutureProvider<void>`：调 generator，将新生成的本地通知插入 DAO（未读）。

- [ ] **Step 3: flutter analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/notification`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/notification
git commit -m "feat(app): local app-event notification generator"
```

---

### Task 8: Flutter 通知中心页 + 首页铃铛红点

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_notifications_page.dart`（改为真实数据实现）
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart:121`（铃铛挂未读红点）

**Interfaces:**
- Consumes: `notificationsProvider`/`unreadCountProvider`/`remoteNotificationsSyncProvider`/`markAsReadProvider`/`clearNotificationProvider`。
- Produces: 改造后的通知中心页；首页铃铛未读角标。

- [ ] **Step 1: 重写通知中心页**

改为 `ConsumerWidget`：进入时读取 `notificationsProvider`（自动触发同步+本地生成）。UI：
- 列表按 `timeMs` 倒序；未读项加粗 + 左侧指示点。
- 顶部操作栏（`LumiraNav` title 右侧）：「全部已读」「清空」。
- 行交互：点后端公告 → `markRead`（不跳转）；点本地通知 → `markRead` + 跳转对应页（打卡/挑战/成就/模板，用 `GoRouter` 到既有路由）。
- 长按或左滑（`Dismissible`）→ `clearNotification`；空态 `Center('暂无通知')`。
- 视觉严格用 `ref.watch(themeTokensProvider)`/`uiStyleProvider`，不硬编码主题色；复用 `LumiraNav`/`NeuCard` 等（可参考原页面骨架，仅数据源与交互改为真实）。
- 移除 `_kMockNotifications`。

- [ ] **Step 2: 首页铃铛红点**

`home_page.dart` 铃铛图标用 `ref.watch(unreadCountProvider)` 显示 `Badge`/红点角标（接入 provider；provider 在首页更早 build 前同步可用，失败静默不阻断）。点击仍 `push(RouteNames.profileNotifications)`。

- [ ] **Step 3: flutter analyze**

Run（在 `lumira_app_flutter/`）：`flutter analyze lib/features/home lib/features/profile lib/features/notification`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/home lib/features/profile lib/features/notification
git commit -m "feat(app): notifications center real data + home badge"
```

---

## 验证清单

- 后端：`pnpm --filter @lumira/backend typecheck`；本地起后端后 `curl -H "Authorization: Bearer <deviceToken>" http://localhost:3000/api/v1/notifications` 返回命中公告。
- 后台：curl admin `GET /api/v1/admin/notifications`（带 `ADMIN_TOKEN`）。
- App：`flutter analyze` 无 error；进通知中心见真实合并列表；首页铃铛红点随已读变化。
- e2e：`pnpm --filter @lumira/backend e2e`（若存在通知相关测试补齐）。

## 后续优化（已登记 `docs/future-optimizations.md`）

- P1 · 通知读状态由本机 sqflite 迁移到后端数据库持久化（跨设备同步红点），保留离线回退。