# Task 1: 数据层 — 表常量 + 建表迁移 + DAO + provider 注册

> 项目：Flutter 客户端 `lumira_app_flutter/`（模板收藏功能）。所有命令在 `lumira_app_flutter/` 目录下执行。
> 分支：feat/template-favorite（base 4a868d58）。只 commit，不 push。

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

将 `_kDbVersion` 从 41 改为 42（当前 `const int _kDbVersion = 41;`）：

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
git commit -m "feat(templates): 新增模板收藏表与 Tv42 迁移及 DAO"
```

> 提交前确认 git status 暂存内容仅含以上 3 个文件。**只 commit，不 push。**