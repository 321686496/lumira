# 「我的模板」页收藏入口实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax.

**Goal:** 「我的模板」页顶部收藏数接真实数据 + 可点击进入新的「我的收藏」页（全来源）+ 页内「收藏」筛选。

**Architecture:** 复用已落地的 `template_favorites` + `favoriteTemplateIdsProvider`；新增 `favoriteTemplatesProvider`（按收藏时间倒序返回全来源收藏卡片）；从 `templates_all_page.dart` 抽出共享模板网格组件，供全部模板页与「我的收藏」页共用。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不支持 records 三元组），flutter_riverpod 2.3.6，sqflite v11，go_router。

**工作目录：** `lumira_app_flutter/`（所有命令在此目录执行）。

## Global Constraints

- 语言 Dart 2.19.6；riverpod 2.3.6；go_router 6.5.7。
- 复用现有共享组件（`NeuCard`、`LumiraNav`、`TemplateCoverImage`、`tokens.*`）；不新建大而全抽象。
- UI 主题铁律：颜色/阴影/圆角一律取自 `ThemeTokens`（`tokens.*`）；不硬编码 `Colors.xxx`（追加在照片上的半透明遮罩除外，本功能不涉及）。复用 `NeuCard`、`TemplateCoverImage` 卡片渲染。
- 数据只读，不改后端；收藏唯一数据源为 `template_favorites` + `favoriteTemplateIdsProvider`。
- 静默降级：DAO/provider 失败时显示 0 / 空态，不弹错误。
- 每次 Task 完成跑 `flutter analyze` 无新增 error/warning，再 commit。
- 分支：`feat/template-favorite`（当前 head `260939f1`）。只 commit 不 push（本功能属 Flutter 客户端，不涉及后端双远端推送）。

---

### Task 1: 抽取共享模板网格组件并回接全部模板页

**Files:**
- Create: `lib/features/templates/widgets/template_grid.dart`
- Modify: `lib/features/templates/pages/templates_all_page.dart`

**Interfaces:**
- Consumes: `AllTemplateItem`（定义在 `lib/features/templates/data/templates_browse_mock_data.dart`）、`TemplateRecord`、`TemplateMapper`、`NeuCard`、`TemplateCoverImage`、`tokens.*`。
- Produces: 公共 `TemplateGridItem`（复用 `AllTemplateItem`，不新建模型）、`templateGridItemFromRecord(TemplateRecord, {required bool isCustom}) → AllTemplateItem`、`TemplateGrid`（瀑布流双列）、`TemplateCard`、`truncate(String, {int maxLen})`。

**说明：** 把 `templates_all_page.dart` 中私有的网格/卡片渲染工厂原样迁到新共享文件并公开命名（去掉 `_` 前缀），全部模板页改为 import 该文件、删除本地私有副本。**保持渲染逻辑逐字不变**，仅改类名与 import。

- [ ] **Step 1: 新建 `template_grid.dart`**

把以下内容从 `templates_all_page.dart` 迁入（去 `_` 前缀、公开命名），并补齐所需 import（`AllTemplateItem` 从 `../data/templates_browse_mock_data.dart`；`TemplateRecord` 从 `core/db/dao/templates_dao.dart`；`TemplateMapper` 从 `../services/template_mapper.dart`；`NeuCard`、`TemplateCoverImage`、`FadeUp`、`templateCategory...` 等按实际引用补）：
- `_recordToItem` → `templateGridItemFromRecord`
- `_truncate` → `truncate`
- `_TemplateGrid` → `TemplateGrid`
- `_TplCard` → `TemplateCard`
- `_estimateCardHeight` 一并随 `_TemplateGrid` 迁入。

> 迁移时严格保留原逻辑。`TemplateCard` 内部 `onTap` 的详情跳转沿用 `/templates/detail?templateId=${template.id}`（或 `RouteNames`）。

- [ ] **Step 2: 回接 `templates_all_page.dart`**

- 删除文件内 `_recordToItem`、`_truncate`、`_TemplateGrid`、`_TplCard`、`_estimateCardHeight` 的定义。
- 新增 import：`import '../widgets/template_grid.dart';`（及文件原已 import 的 `templates_browse_mock_data.dart` 保留，用于 `AllTemplateItem` 类型）。
- 将原有调用点改为公共命名：
  - `_recordToItem(...)` → `templateGridItemFromRecord(...)`
  - `_TemplateGrid(` → `TemplateGrid(`
  - `_TplCard(` → `TemplateCard(`
  - `templates_all_page.dart` 内的 `_estimateCardHeight`/`_truncate` 内部引用随迁移消失，改用 `truncate`（如卡片短描述调用处）。

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/templates/widgets/template_grid.dart lib/features/templates/pages/templates_all_page.dart`
Expected: 无新增 error/warning。

- [ ] **Step 4: 既有测试**

Run: `flutter test test/features/templates`
Expected: `templates_all_page_test.dart` 相关用例仍通过（若文件内测试引用私有类名被改动，同步更新测试到公共命名）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/widgets/template_grid.dart lib/features/templates/pages/templates_all_page.dart
git commit -m "refactor(templates): 抽取共享模板网格组件"
```

---

### Task 2: 新增收藏 Provider + 「我的收藏」页 + 路由

**Files:**
- Modify: `lib/features/templates/data/templates_providers.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/app/router.dart`
- Create: `lib/features/templates/pages/templates_favorites_page.dart`

**Interfaces:**
- Consumes: `favoriteTemplateIdsProvider`/`templatesFavoriteDaoProvider`（Task 1 完成）、`TemplatesDao`（`getFavoriteIds`/`getBuiltinAndRemote`/`getCustomOnly`）、`templateGridItemFromRecord`/`TemplateGrid`（Task 1）、`LumiraNav`、`NeuCard`。
- Produces: provider `favoriteTemplatesProvider`；路由 `RouteNames.templatesFavorites = '/templates/favorites'`；页面 `TemplatesFavoritesPage`。

- [ ] **Step 1: `templates_providers.dart` 新增 `favoriteTemplatesProvider`**

```dart
/// 全来源已收藏模板（按收藏时间倒序）。DRY：排序交给 DAO 的 CreatedAt DESC；
/// 按有序收藏 id 命中 builtin/remote/custom 全池记录，转成卡片项。
final favoriteTemplatesProvider = FutureProvider<List<AllTemplateItem>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final favDao = await ref.watch(templatesFavoriteDaoProvider.future);
  final orderedIds = await favDao.getFavoriteIds();
  if (orderedIds.isEmpty) return const <AllTemplateItem>[];
  // 全来源池（内置+远程，自定义+导入）
  final records = <TemplateRecord>[
    ...await dao.getBuiltinAndRemote(),
    ...await dao.getCustomOnly(),
  ];
  final byId = <String, TemplateRecord>{ for (final r in records) r.id: r };
  final items = <AllTemplateItem>[];
  for (final id in orderedIds) {
    final r = byId[id];
    if (r == null) continue; // 模板已删，静默跳过
    items.add(templateGridItemFromRecord(r, isCustom: r.source == 'custom'));
  }
  return items;
});
```

> 需确认 `TemplateRecord.source` 字段名（若不同，使用与 `templates_all_page._recordToItem` 调用处一致的来源判定方式；`getCustomOnly()` 返回的自定义记录应标 isCustom: true）。请读取 `TemplatesDao.getCustomOnly`/`getBuiltinAndRemote` 返回值与 `TemplateRecord` 是否含 `source` 字段后按实际适配，并在报告中说明。
> 文件 import：`AllTemplateItem`（`../data/templates_browse_mock_data.dart`）、`TemplateRecord`（`core/db/dao/templates_dao.dart`）、`templateGridItemFromRecord`（`../widgets/template_grid.dart`）。

- [ ] **Step 2: `route_names.dart` 新增路由常量**

```dart
  static const String templatesFavorites = '/templates/favorites';
```

- [ ] **Step 3: `router.dart` 注册路由**

仿 `templatesAll`（`lib/app/router.dart` L230-237）新增：

```dart
      GoRoute(
        path: RouteNames.templatesFavorites,
        name: 'templatesFavorites',
        builder: (context, state) => const TemplatesFavoritesPage(),
      ),
```

并加 import `TemplatesFavoritesPage`。

- [ ] **Step 4: 新建 `templates_favorites_page.dart`**

页面结构（前缀 `_` 私有组件沿用本文件私有约定）：
- `LumiraNav`：标题「我的收藏」，左侧返回（`Navigator.canPop` 则 pop，否则 `go(RouteNames.templates)` 或经 `templatesAll`），背景透明，沿用 `_BackButton` 风格（参考 `profile_my_templates_page.dart`）。
- 内容：`ref.watch(favoriteTemplatesProvider)`：
  - loading → 居中 `LumiraProgress.circular()`
  - error/空列表 → 空态（`NeuCard` 内「暂无收藏」文案 + 图标），空态样式参考 `templates_all_page._EmptyState`
  - data → `TemplateGrid(tokens: tokens, templates: items, usageCounts: <String,int>{})`（收藏列表不展示「已拍 N 张」）
- 顶部可加一个渐变背景装饰（`tokens.brandSubtle` 径向，参考 `profile_my_templates_page` build）。

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/templates/pages/templates_favorites_page.dart lib/features/templates/data/templates_providers.dart lib/core/router/route_names.dart lib/app/router.dart`
Expected: 无新增 error/warning。

- [ ] **Step 6: Commit**

```bash
git add lib/features/templates/data/templates_providers.dart lib/core/router/route_names.dart lib/app/router.dart lib/features/templates/pages/templates_favorites_page.dart
git commit -m "feat(templates): 新增我的收藏页与全来源收藏 provider"
```

---

### Task 3: 「我的模板」页 —— 收藏数真实 + 可点击入口 + 页内收藏筛选

**Files:**
- Modify: `lib/features/profile/pages/profile_my_templates_page.dart`

**Interfaces:**
- Consumes: `favoriteTemplateIdsProvider`（计数 + 筛选）、`RouteNames.templatesFavorites`、既有 `_StatsBar`/`_FilterBar`/`_FilterKey`。
- Produces: `_StatsBar` 收藏数真实 + 收藏项可点击；`_FilterKey` 新增 `favorites` 筛选。

- [ ] **Step 1: `_StatsBar` 支持「收藏」项可点击**

`_StatsBar` 增加 `final VoidCallback? onFavoriteTap;` 参数。其 `_statItem` 目前纯 `Column`；给「收藏」项（`_statItem('$favoriteCount', '收藏')`）包 `GestureDetector(onTap: onFavoriteTap, behavior: HitTestBehavior.opaque)`，样式不变。

- [ ] **Step 2: build 中接入真实收藏数**

在 `build()` 顶部 watch：
```dart
    final favoriteAsync = ref.watch(favoriteTemplateIdsProvider);
    final favoriteCount = favoriteAsync.valueOrNull?.length ?? 0;
```
将 `_StatsBar` 调用改为：
```dart
                    _StatsBar(
                      tokens: tokens,
                      totalCount: filtered.length,
                      totalUsage: 0, // 仍为占位（使用次数未持久化）
                      favoriteCount: favoriteCount,
                      onFavoriteTap: () => GoRouter.of(context).push(RouteNames.templatesFavorites),
                    ),
```
> 需新增 import：`templates_providers.dart`（`favoriteTemplateIdsProvider`）与 `core/router/route_names.dart`（若未 import）。

- [ ] **Step 3: `_FilterKey` 新增 `favorites` + 过滤逻辑**

- `enum _FilterKey` 新增 `favorites`。
- `_filteredTemplatesWith` 增加分支：`case _FilterKey.favorites:` 返回 `all.where((t) => favIds.contains(t.id))`，其中 `favIds` 通过 `ref.read(favoriteTemplateIdsProvider).valueOrNull` 获取（非空才过滤）。
  > `_filteredTemplatesWith` 是 `ConsumerState` 的普通方法，可 `ref.read`。在 build 顶部已 `ref.watch(favoriteTemplateIdsProvider)`（Step 2），切换筛选时列表会随收藏集重建。
- `_FilterBar._filters` 追加一项：`_FilterConfig(key: _FilterKey.favorites, label: '收藏')`（放「我的」对象区，或「全部」之后，视觉顺序见 Step 4）。因该列表现在超出一屏，`_FilterBar` 已是横向 `SingleChildScrollView`，无需改布局。

- [ ] **Step 4: analyze**

Run: `flutter analyze lib/features/profile/pages/profile_my_templates_page.dart`
Expected: 无新增 error/warning。

- [ ] **Step 5: 既有测试**

Run: `flutter test test/features/profile`
Expected: 相关用例仍通过（若测试断言 `_StatsBar`/过滤行为，需同步）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/pages/profile_my_templates_page.dart
git commit -m "feat(profile): 我的模板页收藏数真实化并新增收藏入口与筛选"
```

---

### Task 4: 收尾验证 + 全分支终审

- [ ] **Step 1: 全量 analyze + 相关 test**
Run: `flutter analyze`（focus 本分支改动文件无新增 error/warning）；`flutter test test/features/templates test/features/profile`
Expected: `templates_all_page_test.dart`、favorites 相关、profile 相关通过；`templates_page_test.dart` 已知 10 例预存失败与本分支无关（沿用 Task 5 记录）。

- [ ] **Step 2: 手工清单**
1. 「我的模板」页顶部「收藏」数 = 真实收藏数（随详情页红心切换实时更新）。
2. 点击「收藏」数 → 进入「我的收藏」页，展示全部来源模板、按收藏时间倒序；点击卡片进详情。
3. 无收藏时「我的收藏」页显示空态；「我的模板」页选「收藏」筛选显示空态。
4. 「我的模板」页「收藏」筛选：仅显示已收藏的自定义模板，与顶部收藏数语义一致。
5. 主题/UI 风格切换：卡片、收藏数、空态配色跟随。

- [ ] **Step 3: Commit（如有遗留小修）**
如有必要小修，单独 commit 说明。

---

## 后续优化（登记 `docs/future-optimizations.md`）
- 清理已删除模板的孤立收藏记录。