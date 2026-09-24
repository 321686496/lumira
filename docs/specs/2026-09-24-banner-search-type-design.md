# 运营 Banner 新增「App 内搜索」类型设计

日期：2026-09-24
状态：待评审

## 背景与目标

当前运营 Banner 的 `kind` 仅支持 `operation`（条件触达运营位）与 `ad`（活动/广告曝光）两种类型。现需新增第 3 种类型 `search`：

> 运营在后台配置一个「App 内搜索」类型 Banner：设置**搜索关键字**与**搜索范围（scope）**，用户在 App 首页点击该 Banner 后，自动跳转到全局搜索页（`GlobalSearchPage`）并**预填关键字自动搜索**，落地为一次搜索结果展示。

## 需求点

- 后台可新增/编辑 `kind=search` 的 Banner。
- 后台为该 Banner 配置：`search_keyword`（必填）、`search_scope`（可选，四选一：`all` / `template` / `scene` / `academy`，默认 `all`）。
- reachable 行为对齐 `ad`：**无条件直接展示**，不参与 `operation` 的条件触达匹配，按 `position` 归位插入首页轮播。
- App 端点击后跳转 `GlobalSearchPage`，预填关键字并触发搜索，不再显示初始页/历史页。
- 点击埋点、曝光埋点沿用现有 `bannerExpose/bannerClick`，`trackingId` 沿用 `banner.id`。

## 现状勘察结论

- `GlobalSearchPage` 已支持 `scope` + `initialKeyword` 两个构造入参（`lib/features/search/pages/global_search_page.dart#L41-L45`），路由层已定义 `RouteNames.paramScope` 并在 `router.dart` 的 `search` builder 消费（`#L251-L253`）；`RouteNames.paramKeyword` 常量已存在（`route_names.dart#L118`）但 **search builder 尚未消费**——需补传。
- `Router` 中 `search` route 建 Path 为 `/search`，可带 query：`?scope=xx&keyword=yy`。
- 后端运营 Banner 单表 `operation_banners`（`schema.ts#L320-L344`），`kind` 默认 `operation`；`ad` 通过 `position` 归位、`external_url` 跳转浏览器，`create`/`update` 时 `condition` 存占位 `hasLockedTemplate`。
- App 端 `recommendation_service.buildBanners` 的分组逻辑（`services/recommendation_service.dart#L140-L146`）：
  ```dart
  final ads = operationBanners.where((b) => b.kind == OperationBannerKind.ad).toList();
  final ops = operationBanners.where((b) => b.kind != OperationBannerKind.ad).toList();
  ```
  **关键坑**：`ops` 取「非 ad」，若直接新增 `search`，会误入 `matchOperationBanner` 的条件匹配。必须把 `ops` 改为 `kind == operation`，让 `ad` 与 `search` 统一进入 position 归位组。

## 架构设计

分层共 4 个改动域，均复用现有 `ad` 的「无条件 + position 归位」语义，不引入新机制。

### 1. 后端（`lumira-server/packages/backend/`）

**迁移**：新增 `037_banner_search.sql`
```sql
ALTER TABLE `operation_banners`
  ADD COLUMN `search_keyword` varchar(128) NULL AFTER `external_url`,
  ADD COLUMN `search_scope` varchar(16) NULL DEFAULT 'all' AFTER `search_keyword`;
```
（`NULL` 兼容旧数据与非 search 条目；App 读取时 `search_scope` 空回退 `all`）

**schema.ts**（`operationBanners` 表）：追加两列
```ts
searchKeyword: varchar('search_keyword', { length: 128 }),
searchScope: varchar('search_scope', { length: 16 }).default('all'),
```

**DTO**
- `dto/create-banner.dto.ts`：加可选 `searchKeyword?: string`、`searchScope?: SearchScope`
- `dto/update-banner.dto.ts`：同上

**service（banners.service.ts）**
- `create`：透传 `searchKeyword`（空清 null）、`searchScope`（空置 `'all'`）
- `update`：同上
- `listForApp`：下发 `searchKeyword`、`searchScope`
- `listAdmin`：透传原生行（已含新列，无需额外改造）

**rules（operation-banner.rules.ts）**：**不修改**。`search` 与 `ad` 一样走独立校验分支，`OPERATION_BANNER_ROUTES` 白名单仅约束 `operation` 类型；`OPERATION_BANNER_CONDITIONS` 不变。

**测试**：更新 `banners.service.spec.ts`，覆盖 search 由 listForApp 下发 `searchKeyword/searchScope`。

### 2. 后台（`lumira-server/packages/admin/`）

- `types/admin.ts`：Banner 类型补 `searchKeyword?: string | null`、`searchScope?: string`
- `actions/banners.ts`：类型透传（两个新字段随 payload 提交）
- `components/banner-manager.tsx`：`kind` 三选一（运营位 / 广告 / App内搜索）；选中「App内搜索」时显示「搜索关键字」必填输入框 + 「搜索范围」下拉（全部/模板/场景/美学院），保存时校验关键字非空
- `app/dashboard/banners/page.tsx`：列表透传新字段即可（如已全量字段透传则无需改）

### 3. Flutter（`lumira_app_flutter/`）

**`data/operation_banners.dart`**
- `OperationBannerKind` 加 `search`
- `OperationBanner` 加 `searchKeyword`、`searchScope`
- `operationBannerFromJson`：新增 `kind == search` 分支——`searchKeyword` 必须是非空 String，否则整条丢弃；`searchScope` 取值需落在 4 个合法枚举内（`SearchScopeExt.fromName` 兜底 `all`）；`position` 复用现有解析；不要求 `externalUrl`
- `operationBannerToItem`：`kind == search` 时拼跳转 route
  ```dart
  '/search?scope=${banner.searchScope ?? 'all'}&keyword=$encodedKeyword'
  ```
  （`keyword` 需 URL 编码；`externalUrl` 保持 null → 走 App 内 `GoRouter.push`）

**`services/recommendation_service.dart` L140-146**：分组改为
```dart
final ops = operationBanners.where((b) => b.kind == OperationBannerKind.operation).toList();
final fixed = operationBanners.where((b) => b.kind != OperationBannerKind.operation).toList();
// fixed 含 ad + search，统一按 position 归位（沿用原有插入逻辑）
```

**`app/router.dart` search builder（L248-254）**：消费现有 `paramKeyword`
```dart
builder: (context, state) => GlobalSearchPage(
  scope: SearchScopeExt.fromName(state.queryParams[RouteNames.paramScope]),
  initialKeyword: state.queryParams[RouteNames.paramKeyword],
),
```

**`widgets/home_banner.dart`**：无需改动（`onTap` 对 `externalUrl == null` 已走 `GoRouter.push(banner.route)`，route 已拼好 query）。

**测试**：更新 `operation_banners_test.dart`、`recommendation_service_test.dart`、`home_page_test.dart`；新增 search 解析/归位/跳转断言。

## 数据流

```
运营后台(banner-manager) --kind=search, search_keyword, search_scope--> 后端(DB operation_banners)
  --> GET /api/v1/banners 下发 {searchKeyword, searchScope}
  --> Flutter operationBannerFromJson(kind==search)
  --> recommendation_service 归入 position 归位组 插入首页轮播
  --> 用户点击 home_banner onTap（externalUrl 空）--> GoRouter.push('/search?scope=X&keyword=Y')
  --> router search builder 传 scope+keyword --> GlobalSearchPage 预填并自动搜索
```

## 边界与容错

- 后台不填 `search_keyword` 不给保存（表单校验）。
- 后端 `listForApp` 对非法 `searchScope` 不做约束，由 App 端 `SearchScopeExt.fromName` 兜底 `all`。
- App 端解析 `kind=search` 时 `searchKeyword` 缺失/为空 → 丢弃该条（fail-safe，避免跳空白搜索页）。
- search 类型**不写** `externalUrl`；若运营误填，App 端以 `kind==search` 为准忽略 externalUrl，仍走 App 内跳转。

## 明确不实现（YAGNI）

- 不新增独立搜索运营表 / 复用搜索热词权重。
- 不做 A/B 或频次控制（与 ad 当前能力对齐）。
- 不支持 App 端本地静态 search 条目（与 ad 一致，仅远端下发）。

## 改动文件清单

后端：
- `packages/backend/src/database/migrations/037_banner_search.sql`（新增）
- `packages/backend/src/database/schema.ts`
- `packages/backend/src/modules/banners/dto/create-banner.dto.ts`
- `packages/backend/src/modules/banners/dto/update-banner.dto.ts`
- `packages/backend/src/modules/banners/banners.service.ts`
- `packages/backend/src/modules/banners/banners.service.spec.ts`

后台：
- `packages/admin/src/types/admin.ts`
- `packages/admin/src/actions/banners.ts`
- `packages/admin/src/components/banner-manager.tsx`

Flutter：
- `lib/features/home/data/operation_banners.dart`
- `lib/features/home/services/recommendation_service.dart`
- `lib/app/router.dart`
- `test/features/home/operation_banners_test.dart`
- `test/features/home/recommendation_service_test.dart`
- `test/features/home/home_page_test.dart`

## 验证方式

- 后端：`pnpm --filter @lumira/backend test:banners` / typecheck / e2e。
- 后台：`pnpm --filter @lumira/admin build`。
- Flutter：`flutter analyze` + `flutter test`（覆盖 search 相关测试）。