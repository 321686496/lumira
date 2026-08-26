# 模板收藏功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为模板（内置/自定义/远程全来源）增加本地收藏能力：详情页红心切换 + 「全部模板」页收藏过滤。

**Architecture:** 新增独立关系表 `template_favorites`（template_id PK + created_at）存储收藏集合（非原表加字段），新 DAO `TemplatesFavoriteDao` 封装存取，`favoriteTemplateIdsProvider` 驱动 UI。纯 Flutter 本地，不动后端。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，sqflite v11，flutter_riverpod 2.3.6，flutter_test + sqflite_common_ffi。

**工作目录：** `lumira_app_flutter/`（所有命令在此目录执行）。

## Global Constraints

- 语言：Dart 2.19.6（不支持 records 三元组），riverpod 2.3.6。
- 数据层遵循现有 DAO 模式：`Database _db` 构造注入，provider 在 `core/db/database_provider.dart` 注册。
- UI 遵循主题铁律：红心/按钮颜色一律取自 `ThemeTokens`（实心 `tokens.brand`、空心 `tokens.textSecondary`），不硬编码 `Colors.xxx`；点击反馈走 `LumiraIconButton` 自带呼吸按压。
- 复用现有组件（`LumiraIconButton`、`_CustomToggle`）；不新建大而全的抽象。
- 迁移用 `_addColumnIfNotExists`/`CREATE TABLE IF NOT EXISTS` + `try/catch` 静默降级（`debugPrint`），保证幂等。
- DB 版本：`_kDbVersion` 由 41 → 42。
- 改动仅限 `lumira_app_flutter/`，不涉及 `lumira-server/` 后端，无需双远端推送。
- 每次 Task 完成跑 `flutter analyze` 无新增 error，再 commit。

---

### Task 1: 数据层 — 表常量 + 建表迁移 + DAO + provider 注册

**Files:**
- Modify: `lib/core/db/tables.dart`（新增表名常量）
- Create: `lib/core/db/dao/templates_favorite_dao.dart`
- Modify: `lib/core/db/database_provider.dart`（版本 42、onCreate 建表、v42 迁移、provider、import）

**Interfaces:**
- Consumes: `Tables.colId`（`'id'`）、`Tables.colCreatedAt`（`'created_at'`）——已存在，复用。
- Produces: 新常量 `Tables.templateFavorites` = `'template_favorites'`；类 `TemplatesFavoriteDao`，构造 `TemplatesFavoriteDao(Database _db)`，方法：`Future<bool> isFavorite(String templateId)` / `Future<void> addFavorite(String templateId)` / `Future<void> removeFavorite(String templateId)` / `Future<bool> toggleFavorite(String templateId)` → 返回切换后收藏态 / `Future<List<String>> getFavoriteIds()`（created_at DESC）/ `Future<int> countFavorites()`；provider `templatesFavoriteDaoProvider`（`FutureProvider<TemplatesFavoriteDao>`）。

- [ ] **Step 1: tables.dart 新增表名常量**

在 `Tables` 类顶部（`custom_templates` 段内，紧跟 `colUpdatedAt` 后）加：

```dart
  // === template_favorites（v42 新增，模板收藏独立关系表） ===
  // 复用 colId / colCreatedAt 常量。
  static const String templateFavorites = 'template_favorites';
```

- [ ] **Step 2: 新建 DAO `templates_favorite_dao.dart`**

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 模板收藏 DAO：独立关系表，模板 id 为主键，覆盖全来源（builtin/custom/remote）。
class TemplatesFavoriteDao {
  TemplatesFavoriteDao(this._db);

  final Database _db;

  Future<bool> isFavorite(String templateId) async {
    final rows = await _db.query(
      Tables.templateFavorites,
      columns: [Tables.colId],
      where: '${Tables.colId} = ?',
      whereArgs: [templateId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addFavorite(String templateId) async {
    await _db.insert(
      Tables.templateFavorites,
      {
        Tables.colId: templateId,
        Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String templateId) async {
    await _db.delete(
      Tables.templateFavorites,
      where: '${Tables.colId} = ?',
      whereArgs: [templateId],
    );
  }

  Future<bool> toggleFavorite(String templateId) async {
    if (await isFavorite(templateId)) {
      await removeFavorite(templateId);
      return false;
    }
    await addFavorite(templateId);
    return true;
  }

  Future<List<String>> getFavoriteIds() async {
    final rows = await _db.query(
      Tables.templateFavorites,
      columns: [Tables.colId],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map((r) => r[Tables.colId] as String).toList();
  }

  Future<int> countFavorites() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.templateFavorites}',
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
```

- [ ] **Step 3: database_provider.dart 版本号 + import**

将 `_kDbVersion` 从 41 改为 42：

```dart
const int _kDbVersion = 42;
```

在同文件 import 区加：

```dart
import 'dao/templates_favorite_dao.dart';
```

- [ ] **Step 4: database_provider.dart onCreate 建表**

在 `_onCreate` 的 `custom_templates` 段（`idx_custom_templates_source` 之后、`=== template_categories` 之前）插入：

```dart
  // === template_favorites（v42 新增，模板收藏独立关系表） ===
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.templateFavorites} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
```

- [ ] **Step 5: database_provider.dart v42 迁移**

在 `_onUpgrade` 末尾、`oldVersion < 41` 块之后追加：

```dart
  if (oldVersion < 42) {
    try {
      // v42: 新增 template_favorites 表（模板收藏独立关系表）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.templateFavorites} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
    } catch (e) {
      debugPrint('v42 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 6: 注册 provider**

仿 `templatesDaoProvider`，在 `templatesDaoProvider` 定义之后加：

```dart
final templatesFavoriteDaoProvider =
    FutureProvider<TemplatesFavoriteDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TemplatesFavoriteDao(db);
});
```

- [ ] **Step 7: analyze**

Run: `flutter analyze lib/core/db`
Expected: 无新增 error/warning。

- [ ] **Step 8: Commit**

```bash
git add lib/core/db/tables.dart lib/core/db/dao/templates_favorite_dao.dart lib/core/db/database_provider.dart
git commit -m "feat(templates): 新增模板收藏表与 TVersion 42 迁移及 DAO"
```

---

### Task 2: DAO 单元测试

**Files:**
- Create: `test/core/db/dao/templates_favorite_dao_test.dart`

**Interfaces:**
- Consumes: `TemplatesFavoriteDao`（Task 1 定义的所有方法）、`Tables.templateFavorites`。

- [ ] **Step 1: 编写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_favorite_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late TemplatesFavoriteDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.templateFavorites} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
    });
    dao = TemplatesFavoriteDao(db);
  });

  tearDown(() => db.close());

  test('初始未收藏', () async {
    expect(await dao.isFavorite('t1'), false);
    expect(await dao.getFavoriteIds(), isEmpty);
  });

  test('addFavorite 后收藏且幂等', () async {
    await dao.addFavorite('t1');
    await dao.addFavorite('t1');
    expect(await dao.isFavorite('t1'), true);
    expect(await dao.countFavorites(), 1);
  });

  test('removeFavorite 取消收藏', () async {
    await dao.addFavorite('t1');
    await dao.removeFavorite('t1');
    expect(await dao.isFavorite('t1'), false);
    expect(await dao.getFavoriteIds(), isEmpty);
  });

  test('toggleFavorite 往返切换返回新状态', () async {
    expect(await dao.toggleFavorite('t1'), true);
    expect(await dao.isFavorite('t1'), true);
    expect(await dao.toggleFavorite('t1'), false);
    expect(await dao.isFavorite('t1'), false);
  });

  test('getFavoriteIds 按收藏时间倒序、多模板独立', () async {
    await dao.addFavorite('a');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await dao.addFavorite('b');
    expect(await dao.getFavoriteIds(), ['b', 'a']);
    expect(await dao.countFavorites(), 2);
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test test/core/db/dao/templates_favorite_dao_test.dart`
Expected: 5 个 test 全 PASS。

- [ ] **Step 3: Commit**

```bash
git add test/core/db/dao/templates_favorite_dao_test.dart
git commit -m "test(templates): 模板收藏 DAO 单元测试"
```

---

### Task 3: 收藏状态 Provider

**Files:**
- Modify: `lib/features/templates/data/templates_providers.dart`

**Interfaces:**
- Consumes: `templatesFavoriteDaoProvider`（Task 1）、方法 `getFavoriteIds()`。
- Produces: provider `favoriteTemplateIdsProvider`（`FutureProvider<Set<String>>`）——已收藏的模板 id 集合，改收藏后 `ref.invalidate` 它。

- [ ] **Step 1: 新增 provider**

在 `templates_providers.dart` 的 `templatesDaoProvider`（或同类 document 顶部）后加：

```dart
/// 已收藏的模板 id 集合（收藏状态 UI 的唯一数据源）。
/// 收藏/取消后 `ref.invalidate(favoriteTemplateIdsProvider)` 触发重建。
final favoriteTemplateIdsProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(templatesFavoriteDaoProvider.future);
  final ids = await dao.getFavoriteIds();
  return ids.toSet();
});
```

> 若文件未 import `templatesFavoriteDaoProvider`，在文件底部补充对应 import（从 `core/db/database_provider.dart`）。

- [ ] **Step 2: analyze**

Run: `flutter analyze lib/features/templates/data`
Expected: 无新增 error。

- [ ] **Step 3: Commit**

```bash
git add lib/features/templates/data/templates_providers.dart
git commit -m "feat(templates): 新增收藏状态 provider"
```

---

### Task 4: 模板详情页红心收藏按钮

**Files:**
- Modify: `lib/features/templates/pages/templates_detail_page.dart`（`_navActions` 重构 + 新增 `_FavoriteToggle` widget）

**Interfaces:**
- Consumes: `favoriteTemplateIdsProvider`、`templatesFavoriteDaoProvider`（Task 1/3）；`_template?.id`；`tokens.brand` / `tokens.textSecondary`；`LumiraIconButton`。
- Produces: 收藏按钮始终为 `LumiraNav.actions` 第一个；`_FavoriteToggle` 内部点击后切换并向 `favoriteTemplateIdsProvider` invalidate。

- [ ] **Step 1: 重构 `_navActions`**

将现有 `_navActions(ThemeTokens tokens, bool isLocked)` 整体替换为「收藏按钮恒在首位 + 原分支按钮」：

```dart
  List<Widget>? _navActions(ThemeTokens tokens, bool isLocked) {
    final id = _template?.id;
    final heart = id == null
        ? null
        : _FavoriteToggle(
            templateId: id,
            tokens: tokens,
          );
    final rest = <Widget>[
      if (_isMyTemplate) ...[
        if (_isCustomTemplate)
          LumiraIconButton(
            icon: Icons.ios_share,
            onPressed: _goExport,
            color: tokens.textPrimary,
            size: 20,
          ),
        LumiraIconButton(
          icon: Icons.edit_outlined,
          onPressed: _goEdit,
          color: tokens.textPrimary,
          size: 20,
        ),
      ],
      if (isLocked) _CreditBalanceChip(onTap: _goPointsWallet),
    ];
    if (heart == null && rest.isEmpty) return null;
    return [if (heart != null) heart, ...rest];
  }
```

- [ ] **Step 2: 新增 `_FavoriteToggle` widget**

在详情页 `build` 之外的顶层新增（与本文件其他私有 widget 同级）：

```dart
/// 详情页红心收藏按钮：跟随收藏状态切换空心/实心，点击切换收藏并刷新列表。
class _FavoriteToggle extends ConsumerWidget {
  const _FavoriteToggle({required this.templateId, required this.tokens});

  final String templateId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds =
        ref.watch(favoriteTemplateIdsProvider).valueOrNull ?? const <String>{};
    final isFav = favoriteIds.contains(templateId);
    return LumiraIconButton(
      icon: isFav ? Icons.favorite : Icons.favorite_border,
      onPressed: () async {
        final dao = await ref.read(templatesFavoriteDaoProvider.future);
        await dao.toggleFavorite(templateId);
        ref.invalidate(favoriteTemplateIdsProvider);
      },
      color: isFav ? tokens.brand : tokens.textSecondary,
      size: 20,
    );
  }
}
```

> 顶部 import 若无，补充：`import '../../../../core/db/database_provider.dart';` 与既有的 `templates_providers.dart` import。确认该文件是 ConsumerState/ConsumerWidget，能访问 `favoriteTemplateIdsProvider` 的 import 路径。

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/templates/pages/templates_detail_page.dart`
Expected: 无新增 error。若 `LumiraIconButton` 缺少 `tooltip`/类型不匹配，按该组件既有签名补齐。

- [ ] **Step 4: Commit**

```bash
git add lib/features/templates/pages/templates_detail_page.dart
git commit -m "feat(templates): 详情页新增红心收藏按钮"
```

---

### Task 5: 「全部模板」页收藏过滤 toggle

**Files:**
- Modify: `lib/features/templates/pages/templates_all_page.dart`（`_showFavorites` 状态 + 过滤 + `_FilterSection` toggle）

**Interfaces:**
- Consumes: `favoriteTemplateIdsProvider`（Task 3）；现有 `_FilterSection` / `_CustomToggle`。
- Produces: 「收藏」toggle（`_showFavorites`）与「我的」toggle 并排，命中时仅展示已收藏模板。

- [ ] **Step 1: 泛化 `_CustomToggle` 以支持 icon/label**

将 `_CustomToggle` 构造参数扩展为可选图标与文案（`_CustomToggle` 内 `Icons.bookmark`/文本「我的」改为读构造参数）：

```dart
class _CustomToggle extends ConsumerWidget {
  const _CustomToggle({
    required this.tokens,
    required this.active,
    required this.onTap,
    this.icon = Icons.bookmark,
    this.activeIcon = Icons.bookmark,
    this.label = '我的',
  });

  final ThemeTokens tokens;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  ...
  // build() 内 Icon 改：Icon(active ? activeIcon : icon, ...)
  // 文本改：Text(label, ...)
}
```

- [ ] **Step 2: state 新增 `_showFavorites`**

在 `_TemplatesAllPageState` 中，`_showCustom` 同域加：

```dart
  bool _showFavorites = false;
```

- [ ] **Step 3: 过滤逻辑**

在现有构建过滤结果处（`_priceFilter` 之后的最终 `filtered` 上）追加以收藏收缩；同时传给 `_FilterSection` 的 `onToggleFavorites`：

```dart
    // 收藏过滤：仅保留已收藏模板（与分类、价格、我的 toggle 取交集）
    if (_showFavorites) {
      final favIds = ref.read(favoriteTemplateIdsProvider).valueOrNull;
      if (favIds != null) {
        filtered = filtered.where((t) => favIds.contains(t.id)).toList();
      }
    }
```

> 「全部模板」页的 `_TemplatesAllPageState` 为 `ConsumerState`，可在构建中 `ref.watch(favoriteTemplateIdsProvider)` 以响应收藏变化自动刷新列表；过滤代码插入到 `_priceFilter` 分支之后、组装 `TemplateListData` 之前的位置。

- [ ] **Step 4: `_FilterSection` 新增收藏 toggle**

在 `_FilterSection` 现有「我的」toggle（`_CustomToggle`，`showCustom`）里增加并排第二个 toggle，参数贯通到顶层回调：

```dart
            // "收藏" toggle：切换是否只看已收藏模板
            _CustomToggle(
              tokens: tokens,
              active: showFavorites,
              onTap: () => onToggleFavorites(!showFavorites),
              icon: Icons.favorite_border,
              activeIcon: Icons.favorite,
              label: '收藏',
            ),
```

并在 `_FilterSection` 与 `_TemplatesAllPageState` 之间补充字段：`showFavorites`、`onToggleFavorites`，在调用处传入 `_showFavorites` 与 `_onToggleFavorites`。

新增顶层回调：

```dart
  void _onToggleFavorites(bool value) {
    setState(() => _showFavorites = value);
  }
```

- [ ] **Step 5: analyze**

Run: `flutter analyze lib/features/templates/pages/templates_all_page.dart`
Expected: 无新增 error。

- [ ] **Step 6: 运行既有相关测试**

Run: `flutter test test/features/templates/...`
Expected: 通过的测试仍全部通过（本任务不改 DAO/SQL，仅 UI）。

- [ ] **Step 7: Commit**

```bash
git add lib/features/templates/pages/templates_all_page.dart
git commit -m "feat(templates): 全部模板页新增收藏过滤 toggle"
```

---

### Task 6: 收尾验证与手工清单

**Files:**
- Modify: 无（仅验证）

- [ ] **Step 1: 全量 analyze + test**

Run: `flutter analyze` 与 `flutter test`
Expected: 均通过，无新增 error。

- [ ] **Step 2: 手工验证**

启动 App，逐项核对：
1. 内置 / 自定义 / 远程模板详情页右上角均出现红心按钮；点击空心↔实心切换，toast 提示，刷新后状态保持。
2. 「全部模板」页「收藏」toggle 置灰后选中，列表仅剩已收藏模板；与价格/分类/「我的」筛选可叠加。
3. 红心配色随主题与 UI 风格切换（实心 `tokens.brand`、空心 `tokens.textSecondary`），按压呼吸反馈正常。
4. 完全没有收藏时选「收藏」toggle 显示「暂无模板」占位。

- [ ] **Step 3: Commit（如有遗留小修）**

如验证中有必要的小修，单独 commit 说明。