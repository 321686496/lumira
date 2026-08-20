# 后台展示内置模板使用次数 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让后台模板页看到 App 内嵌内置模板的使用次数统计，并展示其名称；名称以 App 为事实来源，改名自动同步到后端。

**Architecture:** 后端新增 `builtin_templates` 注册表（id/name/updated_at）+ 两个接口（客户端 DeviceAuthGuard 上报、后台 AdminAuthGuard 读取）；App 启动时把 `TemplateRegistry` 内置模板 id/名称全量 upsert 到后端；后台模板页在下方渲染只读「内置模板」分区（名称+id+次数，封面缺失用「无封面」占位）。

**Tech Stack:** NestJS+Fastify+Drizzle ORM+MySQL8（mono repo：`lumira-server/packages/{shared,backend,admin}`）；Flutter 3.7.12 / Dart 2.19.6（riverpod）；Next.js App Router + Tailwind + shadcn。

**Spec:** `docs/superpowers/specs/2026-08-20-builtin-template-stats-design.md`

## Global Constraints

- **Flutter：Dart 2.19.6 限制** —— 禁止 record 字面量、switch-expression、pattern matching；多字段数据结构一律用类。大对象放 `lib/` 且不新增排版/样式。
- **数据库迁移编号**：migration 目录现有 `015_template_ambience_short_desc.sql`，本功能用 **`016_builtin_templates.sql`**（唯一，勿冲突）。
- **迁移执行**：`DatabaseService.runMigrations()` 按文件名排序、对未应用的 `.sql` 幂等执行并记入 `_migrations`；新表用 `CREATE TABLE IF NOT EXISTS`。
- **表命名拼接**：Drizzle 常量导入按 `import { mysqlTable, varchar, text, bigint } from 'drizzle-orm/mysql-core'`（`bigint` 用 `{ mode: 'number' }`）。
- **shared 包**：改 `packages/shared/src/**` 后必须 `pnpm --filter @lumira/shared build`，backend/admin 的依赖来自构建产物。
- **API 路径**：backend 全局前缀 `/api/v1`；client 端用 DeviceAuthGuard、后台用 AdminAuthGuard。相对路径如 `/usage/...`。
- **后台 best-effort**：内置模板读取失败返回 `[]`，空态展示，不影响主模板渲染（与 `getUsageStats` 一致）。
- **提交/推送（AGENTS.md）**：凡改动 `backend/**` 或 `admin/**` 的提交必须 commit 后同时 push 到 `origin`(gitee) 与 `github` 两个远端（`git push origin master` + `git push github master`）。仅 Flutter 改动可不推送（除非要求）。
- 工作区存在与本次无关的 watermark/theme 未提交改动，**只 add 本次任务相关文件**，不得 `git add .` / `git add -A`。

---

### Task 1: 后端 `builtin_templates` 表 + shared 类型

**Files:**
- Modify: `lumira-server/packages/shared/src/types/usage.ts`（追加类型）
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（追加表）
- Create: `lumira-server/packages/backend/src/database/migrations/016_builtin_templates.sql`

**Interfaces:**
- Consumes: `packages/shared/src/types/usage.ts`（现有 `UsageStatsItem` 等，保持不动）
- Produces: shared 类型 `BuiltinTemplate` / `BuiltinTemplateSyncInput` / `BuiltinTemplateListResponse`；Drizzle 表常量 `builtinTemplates`（`builtinTemplates.id`/`name`/`updatedAt`）；迁移 `016_builtin_templates.sql`

- [ ] **Step 1: 在 shared 追加三种类型**

在 `lumira-server/packages/shared/src/types/usage.ts` 文件末尾追加：

```ts
// ===== 内置模板注册表 =====
export interface BuiltinTemplate {
  id: string;
  name: string;
}

/** App 全量上报内置模板（id + 当前名称）。 */
export interface BuiltinTemplateSyncInput {
  items: BuiltinTemplate[];
}

export interface BuiltinTemplateListResponse {
  items: BuiltinTemplate[];
}
```

- [ ] **Step 2: 在 schema.ts 追加表定义**

在 `lumira-server/packages/backend/src/database/schema.ts` 中，`systemScenes` 定义之后追加：

```ts
// ===== 内置模板注册表（App 同步，后台展示内置模板名称）=====
export const builtinTemplates = mysqlTable('builtin_templates', {
  id: varchar('id', { length: 128 }).primaryKey(),
  name: text('name').notNull(),
  updatedAt: bigint('updated_at', { mode: 'number' }).notNull(),
});
```

确认文件顶部已从 `'drizzle-orm/mysql-core'` 导入 `mysqlTable, text, varchar, bigint`（eslint/tsc 若报未用导入再 d隔。

- [ ] **Step 3: 创建迁移文件**

新建 `lumira-server/packages/backend/src/database/migrations/016_builtin_templates.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/016_builtin_templates.sql
CREATE TABLE IF NOT EXISTS `builtin_templates` (
  `id` VARCHAR(128) NOT NULL,
  `name` TEXT NOT NULL,
  `updated_at` BIGINT NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 4: 构建 shared 并验证 backend 类型检查**

Run (cwd = `lumira-server`):
```bash
pnpm --filter @lumira/shared build
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
```
Expected: 退出码 0，无新错误。

- [ ] **Step 5: 提交（含 push 到双远端）**

```bash
git add lumira-server/packages/shared/src/types/usage.ts lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/database/migrations/016_builtin_templates.sql lumira-server/packages/shared/dist
git commit -m "feat(backend): 内置模板注册表 builtin_templates + shared 类型"
git push origin master
git push github master
```
> 若 `shared/dist` 未纳入版本管理或首尾检查不需要，可只 add `src` 文件；具体以仓库现状为准（seen 用 `git status` 决定，勿 `git add -A`）。

---

### Task 2: 后端接口（客户端上报 + 后台读取）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/usage/usage.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/usage/usage.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/usage/admin-usage.controller.ts`
- Modify: `lumira-server/packages/backend/src/modules/usage/usage.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `builtinTemplates` Drizzle 表、shared 类型 `BuiltinTemplateSyncInput`/`BuiltinTemplateListResponse`；现有 `DatabaseService.getDb()`、`sql`、`UsageService` 构造。
- Produces: `UsageService.upsertBuiltinTemplates(items): Promise<{upserted:number}>`；`UsageService.listBuiltinTemplates(): Promise<BuiltinTemplateListResponse>`；路由 `POST /api/v1/usage/builtin-templates`（DeviceAuthGuard）、`GET /api/v1/admin/usage/builtin-templates`（AdminAuthGuard）。

Files to touch alongside:

- [ ] **Step 1: usage.service.ts 增加方法**

在 `usage.service.ts` 顶部把 schema 导入补上 `builtinTemplates`，并导入 shared 的 `BuiltinTemplateListResponse`：

```ts
import { builtinTemplates, usageEvents } from '../../database/schema';
import type { BuiltinTemplateListResponse } from '@lumira/shared';
```

在 `stats()` 方法之后追加：

```ts
/** App 全量上报内置模板 id/名称，主键幂等 upsert。 */
async upsertBuiltinTemplates(items: { id: string; name: string }[]): Promise<{ upserted: number }> {
  if (items.length === 0) return { upserted: 0 };
  const db = this.dbService.getDb();
  const now = Date.now();
  for (const it of items) {
    await db.execute(sql`
      INSERT INTO ${builtinTemplates} (${builtinTemplates.id}, ${builtinTemplates.name}, ${builtinTemplates.updatedAt})
      VALUES (${it.id}, ${it.name}, ${now})
      ON DUPLICATE KEY UPDATE \`name\` = VALUES(\`name\`), \`updated_at\` = VALUES(\`updated_at\`)
    `);
  }
  return { upserted: items.length };
}

/** 后台读取内置模板 id/名称列表。 */
async listBuiltinTemplates(): Promise<BuiltinTemplateListResponse> {
  const db = this.dbService.getDb();
  const rows = await db.execute(sql`
    SELECT ${builtinTemplates.id}, ${builtinTemplates.name}
    FROM ${builtinTemplates} ORDER BY ${builtinTemplates.id}
  `);
  const items = (rows[0] as unknown as Array<Record<string, unknown>>).map((r) => ({
    id: String(r.id),
    name: String(r.name),
  }));
  return { items };
}
```

- [ ] **Step 2: usage.controller.ts 增加上报路由**

在 `usage.controller.ts` 顶部导入 shared 类型：

```ts
import type { BuiltinTemplateSyncInput } from '@lumira/shared';
```

在 `GET stats` 方法之后追加：

```ts
@Post('builtin-templates')
async builtinTemplates(@Body() dto: BuiltinTemplateSyncInput) {
  return this.usageService.upsertBuiltinTemplates(dto.items);
}
```

- [ ] **Step 3: admin-usage.controller.ts 增加读取路由**

在 `admin-usage.controller.ts` 的 `stats` 方法之后追加：

```ts
@Get('builtin-templates')
async builtinTemplates() {
  return this.usageService.listBuiltinTemplates();
}
```

- [ ] **Step 4: 补 service 单测**

在 `usage.service.spec.ts` 内追加两个用例（沿用现有 `buildService` 的 mock 风格，`execute` 用 `execImpl` 返回 `[ { affectedRows: 1 } ]` 或 `execRows`）：

```ts
it('upsertBuiltinTemplates 空数组返回 0，非空逐条 upsert', async () => {
  const { service, execute } = buildService({
    execImpl: () => Promise.resolve([{ affectedRows: 1 }]),
  });
  expect((await service.upsertBuiltinTemplates([])).upserted).toBe(0);
  const res = await service.upsertBuiltinTemplates([{ id: 'soft_portrait', name: '柔和人像' }]);
  expect(res.upserted).toBe(1);
  expect(execute).toHaveBeenCalledTimes(1);
});

it('listBuiltinTemplates 返回 id/名称列表', async () => {
  const rows = [
    { id: 'night_cityscape', name: '夜拍城市' },
    { id: 'soft_portrait', name: '柔和人像' },
  ];
  const { service } = buildService({ execRows: rows });
  const res = await service.listBuiltinTemplates();
  expect(res.items).toEqual([
    { id: 'soft_portrait', name: '柔和人像' },
    { id: 'night_cityscape', name: '夜拍城市' },
  ]);
});
```
> 注：`listBuiltinTemplates` 的排序在 SQL 侧；若 mock 返回行序即 SQL 返回序，用例断言顺序按 SQL `ORDER BY id`。若实现里 `ORDER BY id`，上例应交换为 `soft_portrait` 在前 —— **以 SQL 实际结果为准**，测试期望与它一致即可。

- [ ] **Step 5: 验证 + 提交（含 push）**

Run (cwd = `lumira-server`):
```bash
pnpm --filter @lumira/shared build
pnpm --filter @lumira/backend exec tsc --noEmit -p tsconfig.build.json
pnpm --filter @lumira/backend exec jest src/modules/usage/usage.service.spec.ts --silent
```
Expected: typecheck 退出码 0；jest 全绿。

```bash
git add lumira-server/packages/backend/src/modules/usage
git commit -m "feat(backend): 内置模板上报/读取接口"
git push origin master
git push github master
```

---

### Task 3: Flutter 内置模板名称同步服务

**Files:**
- Create: `lumira_app_flutter/lib/features/usage/builtin_template_sync_service.dart`
- Modify: `lumira_app_flutter/lib/features/usage/usage_providers.dart`
- Modify: `lumira_app_flutter/lib/main.dart`
- Test: `lumira_app_flutter/test/features/usage/builtin_template_sync_service_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（`apiClientProvider`，`post<T>(path, { body, fromJson })`，baseUrl 含 `/api/v1`）；`TemplateRegistry`（`TemplateRegistry.allTemplates: List<PhotoTemplate>`，每项 `.meta.id`/`.meta.name`）。
- Produces: `BuiltinTemplateNetwork.syncBuiltinTemplates(Map<String,dynamic> body)`；`DioBuiltinTemplateNetwork(ApiClient)`；`BuiltinTemplateSyncService.syncBuiltinTemplates(): Future<bool>`；provider `builtinTemplateSyncServiceProvider`。

- [ ] **Step 1: 写失败测试**

新建 `test/features/usage/builtin_template_sync_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/usage/builtin_template_sync_service.dart';

class FakeBuiltinNetwork implements BuiltinTemplateNetwork {
  Map<String, dynamic>? lastBody;
  bool shouldFail = false;
  @override
  Future<void> syncBuiltinTemplates(Map<String, dynamic> body) async {
    if (shouldFail) throw Exception('offline');
    lastBody = body;
  }
}

void main() {
  test('syncBuiltinTemplates 上报 items 全量并返回 true', () async {
    final net = FakeBuiltinNetwork();
    final svc = BuiltinTemplateSyncService(net);
    final ok = await svc.syncBuiltinTemplates();
    expect(ok, isTrue);
    final items = (net.lastBody!['items'] as List);
    expect(items, isNotEmpty);
    expect(items.first, containsPair('id'));
    expect(items.first, containsPair('name'));
  });

  test('离线失败返回 false 不抛', () async {
    final net = FakeBuiltinNetwork()..shouldFail = true;
    final svc = BuiltinTemplateSyncService(net);
    expect(await svc.syncBuiltinTemplates(), isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run (cwd = `lumira_app_flutter`): `flutter test test/features/usage/builtin_template_sync_service_test.dart`
Expected: FAIL（编译错误：文件不存在 `BuiltinTemplateNetwork`）。

- [ ] **Step 3: 实现服务**

新建 `lib/features/usage/builtin_template_sync_service.dart`：

```dart
// lib/features/usage/builtin_template_sync_service.dart
//
// 内置模板名称同步：启动联网时把 App 内置模板（TemplateRegistry）的 id/当前名称
// 全量上报到后端 builtin_templates 注册表，使后台能展示内置模板名称。
// 离线/失败静默返回 false，下次启动再同步，不影响功能。

import '../../../core/network/api_client.dart';
import '../../capture/data/template_registry.dart';

/// 网络抽象（便于单测注入 fake）。
abstract class BuiltinTemplateNetwork {
  /// 全量上报内置模板。path: POST /usage/builtin-templates。
  Future<void> syncBuiltinTemplates(Map<String, dynamic> body);
}

/// 基于全局 [ApiClient] 的网络实现。
class DioBuiltinTemplateNetwork implements BuiltinTemplateNetwork {
  DioBuiltinTemplateNetwork(this._api);
  final ApiClient _api;

  @override
  Future<void> syncBuiltinTemplates(Map<String, dynamic> body) async {
    await _api.post<Map<String, dynamic>>(
      '/usage/builtin-templates',
      body: body,
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}

class BuiltinTemplateSyncService {
  BuiltinTemplateSyncService(this._network);
  final BuiltinTemplateNetwork _network;

  /// 上报全量内置模板；返回 true 表示上报成功。
  Future<bool> syncBuiltinTemplates() async {
    try {
      final items = TemplateRegistry.allTemplates
          .map((t) => {'id': t.meta.id, 'name': t.meta.name})
          .toList();
      await _network.syncBuiltinTemplates({'items': items});
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 4: 注册 provider**

在 `usage_providers.dart` 顶部 `import` 新增：

```dart
import 'builtin_template_sync_service.dart';
```

在文件末尾追加：

```dart
/// 内置模板名称同步服务。
final builtinTemplateSyncServiceProvider =
    FutureProvider<BuiltinTemplateSyncService>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return BuiltinTemplateSyncService(DioBuiltinTemplateNetwork(api));
});
```

- [ ] **Step 5: main.dart 启动触发**

在 `main.dart` 现有「6.5 使用次数同步」块之后追加：

```dart
  // 6.6 内置模板名称同步（同步 id/名称到后端；失败静默不阻塞启动）
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) async {
    if (!ok) return;
    try {
      final bts = await container.read(builtinTemplateSyncServiceProvider.future);
      await bts.syncBuiltinTemplates();
    } catch (_) {
      // 网络/鉴权失败静默
    }
  });
```

并在 `main.dart` 顶部加入 import（若已有 usage providers import 则并到同处）：
`import 'features/usage/usage_providers.dart';`（确认 `main.dart` 已 import 该文件；未 import 才新增）。

- [ ] **Step 6: 验证**

Run (cwd = `lumira_app_flutter`):
```bash
flutter analyze lib/features/usage/builtin_template_sync_service.dart lib/features/usage/usage_providers.dart lib/main.dart
flutter test test/features/usage/builtin_template_sync_service_test.dart
```
Expected: analyze 无新 error/warning；单测全绿。

- [ ] **Step 7: 提交（Flutter 端不推送）**

```bash
git add lumira_app_flutter/lib/features/usage/builtin_template_sync_service.dart lumira_app_flutter/lib/features/usage/usage_providers.dart lumira_app_flutter/lib/main.dart lumira_app_flutter/test/features/usage/builtin_template_sync_service_test.dart
git commit -m "feat(flutter): 启动同步内置模板名称到后端"
```

---

### Task 4: 后台「内置模板」分区

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/api.ts`（新增 `BuiltinTemplate` + `getBuiltinTemplates`）
- Modify: `lumira-server/packages/admin/src/lib/__tests__/api.test.ts`（补测试）
- Modify: `lumira-server/packages/admin/src/app/dashboard/templates/page.tsx`（fetch 内置模板并传入）
- Modify: `lumira-server/packages/admin/src/components/template-card-grid.tsx`（渲染「内置模板」分区）

**Interfaces:**
- Consumes: Task 2 的 `GET /api/v1/admin/usage/builtin-templates` → `{ items: [{id,name}] }`；现有 `getUsageStats('template')` → `UsageStatsItem[]`（含内置模板 id 的次数）；`adminFetch<T>(path, init?)`；`TemplateCardGrid` props `templates`/`usage`。
- Produces: `getBuiltinTemplates(): Promise<BuiltinTemplate[]>`；`TemplateCardGrid` 新 prop `builtinTemplates: {id,name}[]`，渲染内置模板只读卡片。

- [ ] **Step 1: api.ts 增加读取函数**

在 `getUsageStats` 之后追加（保持 `adminFetch` best-effort 风格）：

```ts
export interface BuiltinTemplate {
  id: string;
  name: string;
}

/**
 * 后台读取 App 内置模板 id/名称。best-effort：失败静默返回 []，不影响主列表。
 */
export async function getBuiltinTemplates(): Promise<BuiltinTemplate[]> {
  try {
    const data = await adminFetch<{ items?: BuiltinTemplate[] }>('/usage/builtin-templates');
    return Array.isArray(data?.items) ? data.items : [];
  } catch {
    return [];
  }
}
```

- [ ] **Step 2: 补 api 单测**

在 `src/lib/__tests__/api.test.ts` 追加：

```ts
it('getBuiltinTemplates calls /usage/builtin-templates and returns items', async () => {
  global.fetch = jest.fn().mockResolvedValue({
    ok: true,
    json: async () => ({ items: [{ id: 'soft_portrait', name: '柔和人像' }] }),
  });
  const items = await getBuiltinTemplates();
  expect(items).toEqual([{ id: 'soft_portrait', name: '柔和人像' }]);
  expect((global.fetch as jest.Mock).mock.calls[0][0]).toContain('/api/v1/admin/usage/builtin-templates');
});
```
> 顶部按需 `import { getBuiltinTemplates } from './api'`（若该文件已从 `@/lib/api` 导入则并入）。

- [ ] **Step 3: templates/page.tsx 拉取并传入**

在 `page.tsx` 顶部 `import { api, getUsageStats, getBuiltinTemplates } from '@/lib/api';`

在 `usage` 计算之后追加：

```tsx
  // 内置模板（App 同步注册）；best-effort，失败返回空数组
  const builtinArr = await getBuiltinTemplates();
```

并把 `builtInTemplates={builtinArr}`（prop 名见 Step 4）传入 `<TemplateCardGrid ... />`，与既有 prop 并列：

```tsx
      <TemplateCardGrid
        templates={templates}
        categories={categories}
        backendUrl={BACKEND_URL}
        usage={usage}
        builtinTemplates={builtinArr}
      />
```

- [ ] **Step 4: template-card-grid.tsx 渲染分区**

在导入区新增类型：

```tsx
import type { BuiltinTemplate } from '@/lib/api';
```

在 `TemplateCardGridProps` 增加字段并解构：

```tsx
interface TemplateCardGridProps {
  templates: AdminTemplateListItem[];
  categories: TemplateCategory[];
  backendUrl?: string;
  usage?: Record<string, Pick<UsageStatsItem, 'useShoot' | 'openDetail'>>;
  builtinTemplates?: BuiltinTemplate[];
}
```

解构处增加默认值：

```tsx
  usage = {},
  builtinTemplates = [],
```

用 `useMemo` 计算「内置但未在后端主网格出现的」记录（放在现有 `filtered` 同区）：

```tsx
  // 内置模板（排除已在主网格展示的后端模板 id，避免重复）
  const builtinRecords = useMemo(() => {
    const backendIds = new Set(templates.map((t) => t.id));
    return builtinTemplates.filter((b) => !backendIds.has(b.id));
  }, [builtinTemplates, templates]);
```

在主网格 `</div>` 之后、`{/* 删除确认弹窗 */}` 之前追加「内置模板」分区：

```tsx
      {/* 内置模板分区（App 内嵌，后端只读展示名称与次数） */}
      <div className="space-y-3">
        <div className="flex items-center gap-2 pt-2">
          <h2 className="text-sm font-semibold text-foreground">内置模板</h2>
          <Badge variant="secondary" className="text-xs">
            {builtinRecords.length}
          </Badge>
        </div>
        {builtinRecords.length === 0 ? (
          <div className="rounded-lg border border-dashed border-border bg-card py-10 text-center text-sm text-muted-foreground">
            暂未获取到内置模板记录，App 同步后展示
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-4">
            {builtinRecords.map((b) => {
              const u = usage[b.id];
              return (
                <div
                  key={b.id}
                  className="flex flex-col overflow-hidden rounded-lg border border-border bg-card shadow-sm"
                >
                  <div className="relative aspect-[3/4] w-full bg-muted">
                    <span className="flex h-full w-full items-center justify-center text-xs text-muted-foreground">
                      无封面
                    </span>
                    <span className="absolute left-2 top-2 rounded-full bg-indigo-500/85 px-2 py-0.5 text-[11px] font-medium text-white backdrop-blur">
                      内置
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-1 p-3">
                    <span className="truncate text-sm font-medium text-foreground">
                      {b.name || b.id}
                    </span>
                    <span className="truncate text-xs text-muted-foreground">{b.id}</span>
                    <span className="mt-1 flex items-center gap-2 text-[11px] text-muted-foreground tabular-nums">
                      <span>拍摄 {u?.useShoot ?? 0}</span>
                      <span>查看 {u?.openDetail ?? 0}</span>
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
```

- [ ] **Step 5: 验证 + 提交（含 push）**

Run (cwd = `lumira-server/packages/admin`):
```bash
pnpm --filter @lumira/shared build
pnpm --filter @lumira/admin exec tsc --noEmit
pnpm --filter @lumira/admin exec jest src/lib/__tests__/api.test.ts --silent
pnpm --filter @lumira/admin build
```
Expected: typecheck/jest/build 均通过（`tsc --noEmit` 需确认 admin 有该 script；若无用 `pnpm --filter @lumira/admin build` 校验 + jest）。

```bash
git add lumira-server/packages/admin/src/lib/api.ts lumira-server/packages/admin/src/lib/__tests__/api.test.ts lumira-server/packages/admin/src/app/dashboard/templates/page.tsx lumira-server/packages/admin/src/components/template-card-grid.tsx
git commit -m "feat(admin): 模板页内置模板分区展示名称与次数"
git push origin master
git push github master
```

---

### Self-Review Checklist

**Spec coverage:**
- §4.1 `builtin_templates` 表 → Task 1 ✅
- §4.2 客户端上报接口 → Task 2 ✅
- §4.3 后台读取接口 → Task 2 ✅
- §5 App 同步服务 + 触发 → Task 3 ✅
- §6 后台「内置模板」分区（名称+id+次数+内置徽标+无封面+空态+排除已展示）+ `getBuiltinTemplates` → Task 4 ✅
- §8 测试（service 单测 / Flutter 单测 / admin api 测试）→ Task 2/3/4 ✅

**Type consistency:**
- shared：`BuiltinTemplate`/`BuiltinTemplateSyncInput`/`BuiltinTemplateListResponse`（Task 1 → 2/4）。
- backend service：`upsertBuiltinTemplates` / `listBuiltinTemplates`（Task 2）。
- Flutter：`BuiltinTemplateNetwork.syncBuiltinTemplates` / provider `builtinTemplateSyncServiceProvider`（Task 3）。
- admin：`BuiltinTemplate` + `getBuiltinTemplates` + prop `builtinTemplates`（Task 4）。