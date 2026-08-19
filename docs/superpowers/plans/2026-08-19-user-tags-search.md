# 用户自定义标签 & 搜索 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户能给任意模板/场景打自定义标签，并提供模板搜索页、场景搜索页、「我的标签」标签夹页（关键词匹配名称/分类/标签 + 标签筛选）。

**Architecture:** 本地 sqflite 规范化多对多（`user_tags` 字典表 + `item_tags` 绑定表）。新增 `TagsDao` 数据访问层，纯函数 `tag_filter_logic.dart` 承载搜索/筛选核心逻辑（可单测）。三个新页面复用「标签筛选 + 结果网格」组件，`tagsFilterProvider` 共享筛选状态。DB 版本 23 → 24。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，sqflite，flutter_riverpod 2.3.6，GoRouter 6.5.7。

## Global Constraints

- Dart 版本为 2.19.6，**禁止使用 Dart 3 records / 模式匹配语法**。
- 所有代码遵循项目现有 DAO/Provider/主题（`themeTokensProvider`、`appThemeProvider`、`uiStyleProvider`）的既有写法。
- 标识符命名风格：字段常量用 `colXxx`（存于 `Tables`），provider 用 `xxxDaoProvider`，公共页面组件放入 `shared/widgets/`。
- 与现有版本迁移一致：`_onCreate` 与 `_onUpgrade` 双份建表，SQL 用 `CREATE TABLE IF NOT EXISTS`，迁移失败静默 debugPrint 回退，不 DROP 表。
- 禁止为本功能引入任何 UI 库/图标库；图标沿用现有 `Icons.*`。
- 涉及后端（backend/admin）改动不在本计划范围——本功能纯本地。

---

### Task 1: v24 数据库迁移（user_tags + item_tags 表）

**Files:**
- Modify: `lib/core/db/tables.dart`
- Modify: `lib/core/db/database_provider.dart`

**Interfaces:**
- Consumes: 现有 `Tables` 常量约定。
- Produces: 新表 `user_tags`、`item_tags` 及 `Tables.colItemType/colItemId/colTagId` 常量，供 Task 2 的 `TagsDao` 使用。

- [ ] **Step 1: 在 `tables.dart` 追加表/列常量**

在 `Tables` 类末尾（`tutorial_reads` 段之后）追加：

```dart
  // === user_tags / item_tags 表（v24 迁移新增，用户自定义标签 + 搜索） ===
  // colId / colName / colCreatedAt 复用前面已声明的同名常量
  static const String userTags = 'user_tags';
  static const String itemTags = 'item_tags';
  static const String colItemType = 'item_type';
  static const String colItemId = 'item_id';
  static const String colTagId = 'tag_id';
```

- [ ] **Step 2: 在 `database_provider.dart` 升版本号**

`_kDbVersion` 从 23 改为 24：

```dart
const int _kDbVersion = 24;
```

- [ ] **Step 3: 在 `_onCreate` 的 batch 中建表**

在 `_onCreate` 里 `// === scenes ===` 建表块之后、`batch.commit` 之前插入：

```dart
  // === user_tags / item_tags 表（v24，用户自定义标签 + 搜索） ===
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userTags} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colName} TEXT NOT NULL UNIQUE,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.itemTags} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
    )
  ''');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');
```

- [ ] **Step 4: 在 `_onUpgrade` 追加 v24 分支**

在 `_onUpgrade` 末尾（`if (oldVersion < 23)` 块之后）追加：

```dart
  if (oldVersion < 24) {
    try {
      // v24: 用户自定义标签表（标签字典 + 绑定关系）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.userTags} (
          ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${Tables.colName} TEXT NOT NULL UNIQUE,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.itemTags} (
          ${Tables.colItemType} TEXT NOT NULL,
          ${Tables.colItemId} TEXT NOT NULL,
          ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
          ${Tables.colCreatedAt} INTEGER NOT NULL,
          PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');
    } catch (e) {
      debugPrint('v24 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 5: 编译校验**

Run: `flutter analyze lib/core/db/tables.dart lib/core/db/database_provider.dart`
Expected: 无错误。

- [ ] **Step 6: Commit**

```bash
git add lib/core/db/tables.dart lib/core/db/database_provider.dart
git commit -m "feat: v24 新增 user_tags / item_tags 本地表（用户自定义标签）"
```

---

### Task 2: TagsDao 数据访问层

**Files:**
- Create: `lib/core/db/dao/tags_dao.dart`
- Modify: `lib/core/db/database_provider.dart`
- Test: `test/core/db/dao/tags_dao_test.dart`

**Interfaces:**
- Consumes: Task 1 的表与 `Tables` 常量、现有 `Database`。
- Produces:
  - `TagItemType.template = 'template'`、`TagItemType.scene = 'scene'`
  - `class UserTag { int id; String name; int createdAt; }`
  - `class TagWithCount { UserTag tag; int count; }`
  - `class TagsDao` 方法：`touchTag` / `addTag` / `setTags` / `removeTag` / `deleteTag` / `renameTag` / `tagsFor` / `itemIdsByTag` / `allTags` / `matchingTagIds`
  - provider `userTagsDaoProvider`
  - 供 Task 3–7 使用。

- [ ] **Step 1: 先写失败的单测**

创建 `test/core/db/dao/tags_dao_test.dart`（沿用现有 DAO 测试的 in-memory sqflite 方式，参考 `templates_dao_test.dart` 的 `DatabaseFactory` 初始化）：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app/core/db/dao/tags_dao.dart';
import 'package:lumira_app/core/db/database_provider.dart';
import 'package:lumira_app/core/db/tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  sqfliteFfi = databaseFactoryFfi;

  late Database db;
  late TagsDao dao;

  Future<void> createSchema() async {
    // 直接调用迁移建表逻辑（含 v24）
    await _onCreate(db, 24);
  }

  setUp(() async {
    final dir = await getDatabasesPath();
    db = await openDatabase(
      '${dir}tags_test_${DateTime.now().microsecondsSinceEpoch}.db',
      version: 24,
      onCreate: (d, v) async => _onCreate(d, v),
    );
    dao = TagsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('addTag 同名标签跨条目复用同一个 tag id', () async {
    final t1 = await dao.addTag(
        itemType: TagItemType.template, itemId: 'tpl-1', name: '人像');
    final t2 = await dao.addTag(
        itemType: TagItemType.template, itemId: 'tpl-2', name: ' 人像 ');
    expect(t1, t2, reason: 'trim 后同名应复用同一标签');

    final tags = await dao.tagsFor(
        itemType: TagItemType.template, itemId: 'tpl-1');
    expect(tags, hasLength(1));
    expect(tags.first.name, '人像');
  });

  test('tagsFor 只返回指定条目的标签', () async {
    await dao.addTag(itemType: TagItemType.scene, itemId: 's1', name: '淘气泡');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's2', name: '鲸鱼');
    final tags = await dao.tagsFor(itemType: TagItemType.scene, itemId: 's1');
    expect(tags.map((t) => t.name), ['淘气泡']);
  });

  test('itemIdsByTag 返回该标签下所有条目并区分类型', () async {
    final tagId = await dao.addTag(
        itemType: TagItemType.template, itemId: 't-1', name: '人像');
    await dao.addTag(itemType: TagItemType.template, itemId: 't-2', name: '人像');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's-1', name: '人像');
    final templates =
        await dao.itemIdsByTag(itemType: TagItemType.template, tagId: tagId);
    expect(templates.toSet(), {'t-1', 't-2'});
    final scenes = await dao.itemIdsByTag(
        itemType: TagItemType.scene, tagId: tagId);
    expect(scenes, ['s-1']);
  });

  test('allTags 返回标签及 count 并按 itemType 过滤', () async {
    await dao.addTag(itemType: TagItemType.template, itemId: 't1', name: 'a');
    await dao.addTag(itemType: TagItemType.template, itemId: 't2', name: 'a');
    await dao.addTag(itemType: TagItemType.template, itemId: 't3', name: 'b');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's1', name: 'a');
    final tags = await dao.allTags(itemType: TagItemType.template);
    expect(tags, hasLength(2));
    final a = tags.firstWhere((t) => t.tag.name == 'a');
    expect(a.count, 2);
  });

  test('removeTag / deleteTag / renameTag', () async {
    final tagId = await dao.addTag(
        itemType: TagItemType.template, itemId: 't1', name: '原标签');
    await dao.renameTag(tagId, '新标签');
    final tags = await dao.tagsFor(
        itemType: TagItemType.template, itemId: 't1');
    expect(tags.first.name, '新标签');

    await dao.removeTag(
        itemType: TagItemType.template, itemId: 't1', tagId: tagId);
    expect(await dao.tagsFor(itemType: TagItemType.template, itemId: 't1'),
        isEmpty);

    final t2 = await dao.addTag(
        itemType: TagItemType.scene, itemId: 's1', name: '待删');
    await dao.deleteTag(t2);
    expect(await dao.itemIdsByTag(itemType: TagItemType.scene, tagId: t2),
        isEmpty);
  });

  test('matchingTagIds 关键词匹配标签名', () async {
    await dao.addTag(itemType: TagItemType.template, itemId: 't1', name: '日系');
    await dao.addTag(itemType: TagItemType.template, itemId: 't2', name: '复古');
    final hits = await dao.matchingTagIds('日');
    expect(hits, hasLength(1));
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/db/dao/tags_dao_test.dart`
Expected: FAIL。报错为 `import 'package:lumira_app/core/db/dao/tags_dao.dart'` 找不到（文件未创建）。

- [ ] **Step 3: 实现 `tags_dao.dart`**

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 可打标签的内容类型
class TagItemType {
  TagItemType._();
  static const String template = 'template';
  static const String scene = 'scene';
}

/// 一条用户标签（user_tags 行）
class UserTag {
  const UserTag({required this.id, required this.name, required this.createdAt});

  final int id;
  final String name;
  final int createdAt;

  factory UserTag.fromRow(Map<String, Object?> row) => UserTag(
        id: row[Tables.colId] as int,
        name: row[Tables.colName] as String,
        createdAt: (row[Tables.colCreatedAt] as num).toInt(),
      );
}

/// 标签 + 关联内容数量（标签夹/筛选栏展示）
class TagWithCount {
  const TagWithCount({required this.tag, required this.count});

  final UserTag tag;
  final int count;
}

class TagsDao {
  TagsDao(this._db);

  final Database _db;

  /// 归一化标签名：trim + 长度截断（最长 20 字）
  static String normalize(String name) {
    final t = name.trim();
    if (t.length > 20) return t.substring(0, 20);
    return t;
  }

  /// 确保标签字典中存在 name，返回其 id（不存在则创建，同名复用）。
  Future<int> touchTag(String name) async {
    final normalized = normalize(name);
    if (normalized.isEmpty) {
      throw ArgumentError('label name must not be empty');
    }
    final rows = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colName} = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first[Tables.colId] as int;
    }
    return _db.insert(Tables.userTags, {
      Tables.colName: normalized,
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 为某条目打一个标签（同名标签跨条目复用；重复绑定自动忽略，返回 tagId）。
  Future<int> addTag({
    required String itemType,
    required String itemId,
    required String name,
  }) async {
    final tagId = await touchTag(name);
    await _db.insert(Tables.itemTags, {
      Tables.colItemType: itemType,
      Tables.colItemId: itemId,
      Tables.colTagId: tagId,
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return tagId;
  }

  /// 全量替换某条目的标签集合（names 为空则清空）。编辑场景下一次性保存用。
  Future<void> setTags({
    required String itemType,
    required String itemId,
    required List<String> names,
  }) async {
    await _db.delete(
      Tables.itemTags,
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} = ?',
      whereArgs: [itemType, itemId],
    );
    for (final name in names) {
      final normalized = normalize(name);
      if (normalized.isEmpty) continue;
      await addTag(itemType: itemType, itemId: itemId, name: normalized);
    }
  }

  /// 取消某条目上的某标签绑定。
  Future<void> removeTag({
    required String itemType,
    required String itemId,
    required int tagId,
  }) async {
    await _db.delete(
      Tables.itemTags,
      where:
          '${Tables.colItemType} = ? AND ${Tables.colItemId} = ? AND ${Tables.colTagId} = ?',
      whereArgs: [itemType, itemId, tagId],
    );
  }

  /// 删除一个标签（级联删除其所有绑定；sqflite 需手动删绑定再删字典行）。
  Future<void> deleteTag(int tagId) async {
    await _db.delete(
      Tables.itemTags,
      where: '${Tables.colTagId} = ?',
      whereArgs: [tagId],
    );
    await _db.delete(
      Tables.userTags,
      where: '${Tables.colId} = ?',
      whereArgs: [tagId],
    );
  }

  /// 标签改名（新名归一化，若与现有标签重名则复用后者并合并绑定）。
  Future<void> renameTag(int tagId, String newName) async {
    final normalized = normalize(newName);
    if (normalized.isEmpty) return;
    final existed = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colId} != ? AND ${Tables.colName} = ?',
      whereArgs: [tagId, normalized],
      limit: 1,
    );
    if (existed.isNotEmpty) {
      final target = existed.first[Tables.colId] as int;
      // 合并绑定到目标 id
      await _db.rawInsert(
        'INSERT OR IGNORE INTO ${Tables.itemTags}'
        '(${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId}, ${Tables.colCreatedAt})'
        ' SELECT ${Tables.colItemType}, ${Tables.colItemId}, ?, ${Tables.colCreatedAt}'
        ' FROM ${Tables.itemTags} WHERE ${Tables.colTagId} = ?',
        [target, tagId],
      );
      await deleteTag(tagId);
      return;
    }
    await _db.update(
      Tables.userTags,
      {Tables.colName: normalized},
      where: '${Tables.colId} = ?',
      whereArgs: [tagId],
    );
  }

  /// 某条目的全部用户标签。
  Future<List<UserTag>> tagsFor({
    required String itemType,
    required String itemId,
  }) async {
    final rows = await _db.rawQuery('''
      SELECT u.* FROM ${Tables.userTags} u
      INNER JOIN ${Tables.itemTags} b ON b.${Tables.colTagId} = u.${Tables.colId}
      WHERE b.${Tables.colItemType} = ? AND b.${Tables.colItemId} = ?
      ORDER BY u.${Tables.colId}
    ''', [itemType, itemId]);
    return rows.map(UserTag.fromRow).toList();
  }

  /// 某标签下指定类型的所有条目 id。
  Future<List<String>> itemIdsByTag({
    required String itemType,
    required int tagId,
  }) async {
    final rows = await _db.query(
      Tables.itemTags,
      columns: [Tables.colItemId],
      where: '${Tables.colItemType} = ? AND ${Tables.colTagId} = ?',
      whereArgs: [itemType, tagId],
    );
    return rows.map((r) => r[Tables.colItemId] as String).toList();
  }

  /// 某条目已绑定的 tag id 集合（供“已打标签”判断/剔除）。
  Future<Set<int>> tagIdsFor({
    required String itemType,
    required String itemId,
  }) async {
    final rows = await _db.query(
      Tables.itemTags,
      columns: [Tables.colTagId],
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} = ?',
      whereArgs: [itemType, itemId],
    );
    return rows.map((r) => r[Tables.colTagId] as int).toSet();
  }

  /// 全部用户标签（含各自 count），可选按 itemType 过滤。
  Future<List<TagWithCount>> allTags({String? itemType}) async {
    final whereType = itemType != null;
    final rows = await _db.rawQuery('''
      SELECT u.${Tables.colId}, u.${Tables.colName}, u.${Tables.colCreatedAt},
             COUNT(b.${Tables.colItemType}) AS cnt
      FROM ${Tables.userTags} u
      LEFT JOIN ${Tables.itemTags} b ON b.${Tables.colTagId} = u.${Tables.colId}
        ${whereType ? 'AND b.${Tables.colItemType} = ?' : ''}
      GROUP BY u.${Tables.colId}
      ORDER BY cnt DESC, u.${Tables.colName}
    ''', whereType ? [itemType] : []);
    return rows.map((r) => TagWithCount(
      tag: UserTag.fromRow(r),
      count: (r['cnt'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  /// 标签名模糊匹配关键词，返回命中的 tag id 列表（搜索“匹配标签名”用）。
  Future<List<int>> matchingTagIds(String query) async {
    final key = '%$query%';
    final rows = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colName} LIKE ?',
      whereArgs: [key],
    );
    return rows.map((r) => r[Tables.colId] as int).toList();
  }
}

/// 便捷拦截函数：将 TagItemType 字符串转为内部 tagId 并查 item（供 DAO provider 层复用）。
Set<String> _identitySet(List<String> list) => list.toSet();
```

- [ ] **Step 4: 注册 `userTagsDaoProvider`**

在 `database_provider.dart` 的 import 加：

```dart
import 'dao/tags_dao.dart';
```

在文件底部（`tutorialReadDaoProvider` 之后）加：

```dart
final userTagsDaoProvider = FutureProvider<TagsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TagsDao(db);
});
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/core/db/dao/tags_dao_test.dart`
Expected: PASS。注意：若 `templates_dao_test.dart` 用了内存库而此处不行，可参考其初始化方式保持一致。

- [ ] **Step 6: Commit**

```bash
git add lib/core/db/dao/tags_dao.dart lib/core/db/database_provider.dart test/core/db/dao/tags_dao_test.dart
git commit -m "feat: 新增 TagsDao 数据访问层（增删改查/聚合/关键词匹配标签）与 provider"
```

---

### Task 3: 搜索与标签筛选核心纯函数

**Files:**
- Create: `lib/features/tags/tag_filter_logic.dart`
- Test: `test/features/tags/tag_filter_logic_test.dart`

**Interfaces:**
- Consumes: 纯字符串/列表输入，不依赖 DB，便于单测。
- Produces:
  - `bool containsIgnoreCase(String source, String query)`
  - `bool templateMatchesKeyword(String name, String category, List<String> systemTags, String keyword)`
  - `bool sceneMatchesKeyword(String name, String vibe, String category, String keyword)`
  - `List<MapEntry<String, int>> filterTagsByKeyword(List<MapEntry<String, int>> tags, String keyword)`
  - 供 Task 5/6 搜索页使用。

- [ ] **Step 1: 写失败单测**

创建 `test/features/tags/tag_filter_logic_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/features/tags/tag_filter_logic.dart';

void main() {
  test('containsIgnoreCase 不区分大小写', () {
    expect(containsIgnoreCase('Portrait', 'port'), isTrue);
    expect(containsIgnoreCase('人像', '像'), isTrue);
    expect(containsIgnoreCase('Street', 'xx'), isFalse);
  });

  test('templateMatchesKeyword 匹配名称/分类/系统标签/空关键词', () {
    expect(templateMatchesKeyword('港风人像', 'portrait', const [], '港风'), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const ['胶片'], '胶片'), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const [], ''), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const [], '夜景'), isFalse);
  });

  test('sceneMatchesKeyword 匹配名称/氛围/分类', () {
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '窗光'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '温暖'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', 'indoor'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '大理'), isFalse);
  });

  test('filterTagsByKeyword 过滤标签并对齐大小写顺序', () {
    final tags = <MapEntry<String, int>>[
      const MapEntry('人像', 3),
      const MapEntry('日系', 2),
      const MapEntry('复古', 5),
    ];
    final hits = filterTagsByKeyword(tags, '系');
    expect(hits.map((e) => e.key), ['日系']);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/tags/tag_filter_logic_test.dart`
Expected: FAIL（找不到 `tag_filter_logic.dart`）。

- [ ] **Step 3: 实现 `tag_filter_logic.dart`**

```dart
/// 用户标签的搜索/筛选核心纯函数。
/// 不依赖 DB，便于独立单元测试。

/// 大小写不敏感的子串匹配（含全匹配）。
bool containsIgnoreCase(String source, String query) {
  if (query.isEmpty) return true;
  return source.toLowerCase().contains(query.toLowerCase());
}

/// 模板是否命中关键词（匹配名称/分类/系统标签；空关键词恒匹配）。
bool templateMatchesKeyword(
  String name,
  String category,
  List<String> systemTags,
  String keyword,
) {
  if (keyword.trim().isEmpty) return true;
  final candidates = <String>[name, category, ...systemTags];
  return candidates.any((c) => containsIgnoreCase(c, keyword.trim()));
}

/// 场景是否命中关键词（匹配名称/氛围/分类；空关键词恒匹配）。
bool sceneMatchesKeyword(
  String name,
  String vibe,
  String category,
  String keyword,
) {
  if (keyword.trim().isEmpty) return true;
  final candidates = <String>[name, vibe, category];
  return candidates.any((c) => containsIgnoreCase(c, keyword.trim()));
}

/// 从标签（name, count）列表中筛出名称命中关键词的项，保持原顺序。
List<MapEntry<String, int>> filterTagsByKeyword(
  List<MapEntry<String, int>> tags,
  String keyword,
) {
  final q = keyword.trim();
  if (q.isEmpty) return tags;
  return tags.where((e) => containsIgnoreCase(e.key, q)).toList();
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/features/tags/tag_filter_logic_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/features/tags/tag_filter_logic.dart test/features/tags/tag_filter_logic_test.dart
git commit -m "feat: 搜索/标签筛选核心纯函数 tag_filter_logic"
```

---

### Task 4: 可复用标签区块 UserTagsSection + 详情页接入

**Files:**
- Create: `lib/shared/widgets/tags/user_tags_section.dart`
- Modify: `lib/features/templates/pages/templates_detail_page.dart`
- Modify: `lib/features/capture/pages/capture_scene_detail_page.dart`
- Test: `test/shared/widgets/tags/user_tags_section_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `TagsDao`/`TagItemType`/`userTagsDaoProvider`。
- Produces: 可复用 widget `UserTagsSection`（输入：`itemType`、`itemId`、`showSystemTags`、`systemTags`），供模板/场景详情页使用；点击标签 Chip 的 × 可移除。

- [ ] **Step 1: 写基础 widget 测试**

创建 `test/shared/widgets/tags/user_tags_section_test.dart`（用 providerScope override `userTagsDaoProvider` 注入假 DAO）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app/core/db/dao/tags_dao.dart';
import 'package:lumira_app/core/db/database_provider.dart';
import 'package:lumira_app/shared/widgets/tags/user_tags_section.dart';

class _FakeTagsDao implements TagsDao {
  @override
  final Database? _ = null;
  // 手动实现关键方法（省略其余），返回固定数据
}

void main() {
  testWidgets('UserTagsSection 展示系统标签(只读)与加入输入框', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [userTagsDaoProvider.overrideWith((_) async => _FakeTagsDao())],
      child: const MaterialApp(
        home: Scaffold(
          body: UserTagsSection(
            itemType: 'template',
            itemId: 'tpl-1',
            systemTags: ['人像', '胶片'],
          ),
        ),
      ),
    ));
    expect(find.text('人像'), findsOneWidget);
    expect(find.text('胶片'), findsOneWidget);
  });
}
```

（届时 `_FakeTagsDao` 需要用 `class _FakeTagsDao extends TagsDao { _FakeTagsDao() : super(_fakeDb); }` 继承并重写方法，验证编译即可；若 `TagsDao` 无法直接 mock，可改为注入一个返回常量数据的轻量抽象，见下方实现说明。）

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/shared/widgets/tags/user_tags_section_test.dart`
Expected: FAIL（`user_tags_section.dart` 不存在）。

- [ ] **Step 3: 实现 `user_tags_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_tokens.dart';

/// 用户自定义标签区块（可复用于模板/场景详情页）。
///
/// - [itemType]/[itemId]：定位内容
/// - [systemTags]：该内容自带系统标签（只读展示，带“系统”角标）
/// - 用户标签可实时增删；输入时联想已有标签名。
class UserTagsSection extends ConsumerStatefulWidget {
  const UserTagsSection({
    super.key,
    required this.itemType,
    required this.itemId,
    this.systemTags = const [],
  });

  final String itemType;
  final String itemId;
  final List<String> systemTags;

  @override
  ConsumerState<UserTagsSection> createState() => _UserTagsSectionState();
}

class _UserTagsSectionState extends ConsumerState<UserTagsSection> {
  final TextEditingController _controller = TextEditingController();
  List<UserTag> _userTags = const [];
  List<String> _suggestions = const [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final tags = await dao.tagsFor(
      itemType: widget.itemType,
      itemId: widget.itemId,
    );
    if (!mounted) return;
    setState(() => _userTags = tags);
  }

  void _onChanged(String value) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final all = await dao.allTags(itemType: widget.itemType);
    final q = value.trim();
    final hits = q.isEmpty
        ? const <MapEntry<String, int>>[]
        : all.where((e) => e.tag.name.contains(q)).take(5).toList();
    if (!mounted) return;
    setState(() => _suggestions = hits.map((e) => e.tag.name).toList());
  }

  Future<void> _submit(String raw) async {
    final name = TagsDao.normalize(raw);
    if (name.isEmpty) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.addTag(
      itemType: widget.itemType,
      itemId: widget.itemId,
      name: name,
    );
    _controller.clear();
    setState(() {
      _suggestions = const [];
      _expanded = false;
    });
    await _load();
  }

  Future<void> _remove(int tagId) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.removeTag(
      itemType: widget.itemType,
      itemId: widget.itemId,
      tagId: tagId,
    );
    await _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标签',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 10),
          if (widget.systemTags.isNotEmpty || _userTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in widget.systemTags)
                    _Chip(
                      label: s,
                      isSystem: true,
                      tokens: tokens,
                      onDeleted: null,
                    ),
                  for (final t in _userTags)
                    _Chip(
                      label: t.name,
                      isSystem: false,
                      tokens: tokens,
                      onDeleted: () => _remove(t.id),
                    ),
                ],
              ),
            ),
          if (!_expanded)
            GestureDetector(
              onTap: () => setState(() {
                _expanded = true;
                _onChanged('');
              }),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('添加标签，方便日后查找',
                        style: TextStyle(fontSize: 12, color: tokens.brand)),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '输入标签名，回车添加'),
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                ),
                if (_suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _suggestions)
                          GestureDetector(
                            onTap: () => _submit(s),
                            child: _Chip(
                                label: s,
                                isSystem: false,
                                tokens: tokens,
                                onDeleted: null),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSystem,
    required this.tokens,
    this.onDeleted,
  });

  final String label;
  final bool isSystem;
  final ThemeTokens tokens;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final color = isSystem ? tokens.textTertiary : tokens.brand;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isSystem ? tokens.surfaceAlt : tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSystem) ...[
            Text(label,
                style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(width: 4),
            Text('系统',
                style: TextStyle(
                    fontSize: 9, color: tokens.textTertiary)),
          ] else ...[
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onDeleted,
              child: Icon(Icons.close, size: 14, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
```

说明：若 `UserTagsSection` 测试难以 mock 底层 `TagsDao`，可把数据获取抽象成 `UserTagDataSource` 接口并在 widget 中注入，测试传假实现。以“测试可编译且断言系统标签展示”为最低验收，不必 mock 全部方法。

- [ ] **Step 4: 接入模板详情页**

在 `templates_detail_page.dart` 的正文 Column 中，`_TitleAndTags` 之后、`_SceneGuideCard` 之前插入：

```dart
              UserTagsSection(
                itemType: TagItemType.template,
                itemId: template.id,
                systemTags: template.tags,
              ),
```

（`template.tags` 为 `List<String>`；`TagItemType` 来自 `core/db/dao/tags_dao.dart`，需在文件顶部 import。）

- [ ] **Step 5: 接入场景详情页**

在 `capture_scene_detail_page.dart` 的正文 Column 中，现有 `_TagsSection` 之后插入：

```dart
                      UserTagsSection(
                        itemType: TagItemType.scene,
                        itemId: scene.id,
                      ),
```

- [ ] **Step 6: 运行测试与分析**

Run: `flutter analyze lib/shared/widgets/tags/user_tags_section.dart lib/features/templates/pages/templates_detail_page.dart lib/features/capture/pages/capture_scene_detail_page.dart`
Run: `flutter test test/shared/widgets/tags/user_tags_section_test.dart`
Expected: 均通过。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/widgets/tags/user_tags_section.dart lib/features/templates/pages/templates_detail_page.dart lib/features/capture/pages/capture_scene_detail_page.dart test/shared/widgets/tags/user_tags_section_test.dart
git commit -m "feat: 模板/场景详情页接入用户自定义标签区块"
```

---

### Task 5: 模板搜索页

**Files:**
- Create: `lib/features/templates/pages/templates_search_page.dart`
- Modify: `lib/features/templates/pages/templates_page.dart`（导航加搜索入口）
- Modify: `lib/core/router/route_names.dart`（`templateSearch`）
- Modify: `lib/app/router.dart`（注册路由）
- Test: `test/features/templates/pages/templates_search_page_test.dart`

**Interfaces:**
- Consumes: Task 2 `TagsDao`/`userTagsDaoProvider`，Task 3 纯函数，现有 `templatesDaoProvider`/`LumiraNav`/`themeTokensProvider`、`_TemplateGrid` 网格卡片（`templates_all_page.dart` 内，若为私有则在本页内复制同款 2 列网格）。
- Produces: `TemplateSearchPage` 页面 + `templateSearch` 路由。

- [ ] **Step 1: 在 `route_names.dart` 加常量**

在 `templatesAll` 常量附近追加：

```dart
  static const String templatesSearch = '/templates/search';
```

- [ ] **Step 2: 在 `router.dart` 注册路由**

在 `templatesAll` 的 `GoRoute` 之后追加：

```dart
      GoRoute(
        path: RouteNames.templatesSearch,
        name: 'templatesSearch',
        builder: (context, state) => const TemplatesSearchPage(),
      ),
```

顶部 import 加：

```dart
import '../features/templates/pages/templates_search_page.dart';
```

- [ ] **Step 3: 实现 `templates_search_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/templates_browse_mock_data.dart';
import '../widgets/template_cover_image.dart';

/// 模板搜索页：关键词（名称/分类/系统标签/用户标签）+ 标签筛选 + 结果 2 列网格。
class TemplatesSearchPage extends ConsumerStatefulWidget {
  const TemplatesSearchPage({super.key});

  @override
  ConsumerState<TemplatesSearchPage> createState() =>
      _TemplatesSearchPageState();
}

class _TemplatesSearchPageState extends ConsumerState<TemplatesSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  // 已被选中的用户标签 tagId
  final Set<int> _selectedTagIds = <int>{};
  // 已加载的全部模板
  List<TemplateRecord> _allTemplates = const [];
  // 全部用户标签（name -> tagId,count）
  List<TagWithCount> _allTags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tDao = await ref.read(templatesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final builtin = await tDao.getBuiltinAndRemote();
    final customs = await tDao.getCustomOnly();
    final tags = await tagDao.allTags(itemType: TagItemType.template);
    if (!mounted) return;
    setState(() {
      _allTemplates = [...builtin, ...customs];
      _allTags = tags;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(tokens),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKeywordField(tokens),
                    if (_allTags.isNotEmpty)
                      _buildTagBar(tokens),
                    _buildResults(tokens),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(ThemeTokens tokens) {
    return LumiraNav(
      title: '搜索模板',
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: () => Navigator.of(context).pop(),
        size: 20,
      ),
    );
  }

  Widget _buildKeywordField(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: TextField(
        controller: _controller,
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          hintText: '搜索模板名称、分类或标签',
          prefixIcon: Icon(Icons.search, size: 18, color: tokens.textSecondary),
          isDense: true,
          filled: true,
          fillColor: tokens.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTagBar(ThemeTokens tokens) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _allTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = _allTags[i];
          final active = _selectedTagIds.contains(e.tag.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (active) {
                  _selectedTagIds.remove(e.tag.id);
                } else {
                  _selectedTagIds.add(e.tag.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? tokens.brand : tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '${e.tag.name} (${e.count})',
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : tokens.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(ThemeTokens tokens) {
    final q = _keyword.trim();
    // 1) 关键词过滤（名称/分类/系统标签）
    final keywordHits = _allTemplates
        .where((t) => templateMatchesKeyword(
            t.name, t.category, t.tags, q))
        .toList();
    // 2) 标签筛选放于状态内，设置界面时简化：仅关键词 + 系统标签展示。
    // 用户标签的 AND 筛选（需 DB join）在 _applySelectedTags 中处理，
    // 本页完整实现见 Task 5 验收：keyword + 系统标签 + 用户标签三者叠加。
    final results = _selectedTagIds.isEmpty
        ? keywordHits
        : keywordHits; // 占位，Task 5 完善为结合 _selectedTagIds 过滤

    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('未找到相关模板')),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: results.length,
      itemBuilder: (_, index) {
        final t = results[index];
        return GestureDetector(
          onTap: () => GoRouter.of(context).push(
            RouteNames.withTemplateId(RouteNames.templatesDetail, t.id),
          ),
          child: _SearchTplCard(template: t, tokens: tokens),
        );
      },
    );
  }
}

class _SearchTplCard extends ConsumerWidget {
  const _SearchTplCard({required this.template, required this.tokens});

  final TemplateRecord template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TemplateCoverImage(
                  cover: template.cover.isEmpty
                      ? null
                      : template.cover,
                  coverData: template.coverData,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        color: tokens.textTertiary, size: 28),
                  ),
                  errorFallback: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  TemplatesBrowseMockData.categoryLabel(template.category),
                  style: TextStyle(fontSize: 11, color: tokens.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> 重要：`_buildResults` 中的「用户标签 AND 筛选」需合并 `_selectedTagIds` 的真实过滤。运行时在 `setState` 里调用 `_applySelectedTags(_selectedTagIds, keywordHits)` 并把结果存为 `_tagFiltered`，再在 `_buildResults` 里用 `_tagFiltered` 展示。实现在 Task 5 内补齐（保持“关键词 + 系统标签 + 用户标签”三者叠加），占位逻辑梳理见下方 Step 4 的说明，勿提交半成品占位。

- [ ] **Step 4: 在 `templates_page.dart` 加搜索入口**

在 `actions` 列表里，`Icons.apps_outlined` 按钮之前插入：

```dart
          GestureDetector(
            onTap: () => GoRouter.of(context).push(RouteNames.templatesSearch),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.search, size: 20),
            ),
          ),
```

- [ ] **Step 5: 写页面测试**

创建 `test/features/templates/pages/templates_search_page_test.dart`（override DAO provider 注入空数据，断言搜索框与导航存在）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app/core/db/database_provider.dart';
import 'package:lumira_app/features/templates/pages/templates_search_page.dart';

void main() {
  testWidgets('模板搜索页渲染搜索框与导航', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        templatesDaoProvider.overrideWith((ref) => _fakeTemplatesDao()),
        userTagsDaoProvider.overrideWith((ref) => _fakeTagsDao()),
      ],
      child: const MaterialApp(home: TemplatesSearchPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('搜索模板'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
```

（`_fakeTemplatesDao`/`_fakeTagsDao` 用继承 DAO 后覆写关键方法的方式实现，返回常量数据；以编译通过为最低验收。）

- [ ] **Step 6: 运行分析 + 测试**

Run: `flutter analyze lib/features/templates/pages/templates_search_page.dart lib/features/templates/pages/templates_page.dart lib/app/router.dart lib/core/router/route_names.dart`
Run: `flutter test test/features/templates/pages/templates_search_page_test.dart`
Expected: 通过。若 `TemplateRecord.tags` 为私有或类型不符，调整字段读取方式。

- [ ] **Step 7: Commit**

```bash
git add lib/features/templates/pages/templates_search_page.dart lib/features/templates/pages/templates_page.dart lib/app/router.dart lib/core/router/route_names.dart test/features/templates/pages/templates_search_page_test.dart
git commit -m "feat: 模板搜索页（关键词+标签筛选）+ 路由与入口"
```

---

### Task 6: 场景搜索页

**Files:**
- Create: `lib/features/scenes/pages/scenes_search_page.dart`
- Modify: `lib/features/scenes/pages/scenes_page.dart`（搜索按钮改为跳转）
- Modify: `lib/core/router/route_names.dart`（`sceneSearch`）
- Modify: `lib/app/router.dart`（注册路由）
- Test: `test/features/scenes/pages/scenes_search_page_test.dart`

**Interfaces:**
- Consumes: Task 2 `TagsDao`，Task 3 纯函数，`scenesDaoProvider`，现有 `_SceneCard`/`_SceneGrid`（scenes_page.dart 内私有，本页复制同款）。
- Produces: `SceneSearchPage` + `sceneSearch` 路由。

- [ ] **Step 1: 加路由常量 + 注册**

`route_names.dart` 在 `scenes` 邻接追加：

```dart
  static const String scenesSearch = '/scenes/search';
```

`router.dart` 在 `scenes` 的 `GoRoute` 后追加：

```dart
      GoRoute(
        path: RouteNames.scenesSearch,
        name: 'scenesSearch',
        builder: (context, state) => const ScenesSearchPage(),
      ),
```

import 加 `import '../features/scenes/pages/scenes_search_page.dart';`

- [ ] **Step 2: 实现 `scenes_search_page.dart`**

结构同模板搜索页，区别在数据/匹配/网格：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../tags/tag_filter_logic.dart';

class ScenesSearchPage extends ConsumerStatefulWidget {
  const ScenesSearchPage({super.key});

  @override
  ConsumerState<ScenesSearchPage> createState() => _ScenesSearchPageState();
}

class _ScenesSearchPageState extends ConsumerState<ScenesSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  List<SceneRecord> _allScenes = const [];
  List<TagWithCount> _allTags = const [];
  final Set<int> _selectedTagIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sDao = await ref.read(scenesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final scenes = await sDao.getAll();
    final tags = await tagDao.allTags(itemType: TagItemType.scene);
    if (!mounted) return;
    setState(() {
      _allScenes = scenes;
      _allTags = tags;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final q = _keyword.trim();
    final hits = _allScenes
        .where((s) => sceneMatchesKeyword(s.name, s.vibe, s.category, q))
        .toList();
    final results = hits;
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '搜索场景',
              transparent: true,
              leading: LumiraIconButton(
                icon: Icons.arrow_back_ios_new,
                onPressed: () => Navigator.of(context).pop(),
                size: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _controller,
                onChanged: (v) => setState(() => _keyword = v),
                decoration: InputDecoration(
                  hintText: '搜索场景名称或氛围',
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: tokens.textSecondary),
                  isDense: true,
                  filled: true,
                  fillColor: tokens.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_allTags.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _allTags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = _allTags[i];
                    final active = _selectedTagIds.contains(e.tag.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (active) {
                            _selectedTagIds.remove(e.tag.id);
                          } else {
                            _selectedTagIds.add(e.tag.id);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? tokens.brand : tokens.surfaceAlt,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '${e.tag.name} (${e.count})',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                active ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('未找到相关场景'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: results.length,
                      itemBuilder: (_, index) {
                        final s = results[index];
                        return GestureDetector(
                          onTap: () => GoRouter.of(context).push(
                            RouteNames.withSceneId(
                                RouteNames.captureSceneDetail, s.id),
                          ),
                          child: _SceneSearchCard(scene: s, tokens: tokens),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneSearchCard extends StatelessWidget {
  const _SceneSearchCard({required this.scene, required this.tokens});

  final SceneRecord scene;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final first = scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: first != null
                ? Image.network(first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(tokens))
                : _placeholder(tokens),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scene.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary)),
                const SizedBox(height: 4),
                Text(scene.vibe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: tokens.brand)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeTokens tokens) => Container(
        color: tokens.brandSubtle,
        child: Center(
          child: Icon(Icons.image_outlined,
              size: 28, color: tokens.brand),
        ),
      );
}
```

> 同样，用户标签 AND 筛选需在 `_selectedTagIds` 非空时通过 `TagsDao.itemIdsByTag` 取命中 id 集合，对 `hits` 做交集过滤。请在本 Task 内补齐（勿提交占位）。

- [ ] **Step 3: 改 `scenes_page.dart` 搜索按钮跳转**

把 `_onSearch` 改为：

```dart
  void _onSearch() {
    GoRouter.of(context).push(RouteNames.scenesSearch);
  }
```

（顶部已 import `route_names.dart` 与 `go_router`，`LumiraToast` 不再需要时若成未用 import，一并清理。）

- [ ] **Step 4: 写页面测试 + 运行**

创建 `test/features/scenes/pages/scenes_search_page_test.dart`（override `scenesDaoProvider`/`userTagsDaoProvider`，断言搜索框与标题）。

Run: `flutter analyze lib/features/scenes/pages/scenes_search_page.dart lib/features/scenes/pages/scenes_page.dart lib/app/router.dart lib/core/router/route_names.dart`
Run: `flutter test test/features/scenes/pages/scenes_search_page_test.dart`
Expected: 通过。

- [ ] **Step 5: Commit**

```bash
git add lib/features/scenes/pages/scenes_search_page.dart lib/features/scenes/pages/scenes_page.dart lib/app/router.dart lib/core/router/route_names.dart test/features/scenes/pages/scenes_search_page_test.dart
git commit -m "feat: 场景搜索页（关键词+标签筛选）+ 路由与入口"
```

---

### Task 7: 「我的标签」标签夹页

**Files:**
- Create: `lib/features/tags/pages/my_tags_page.dart`
- Modify: `lib/core/router/route_names.dart`（`myTags`)
- Modify: `lib/app/router.dart`（注册路由）
- Modify: `lib/features/templates/pages/templates_search_page.dart` / `lib/features/scenes/pages/scenes_search_page.dart`（顶栏加「我的标签」入口）
- Test: `test/features/tags/pages/my_tags_page_test.dart`

**Interfaces:**
- Consumes: Task 2 `TagsDao`/`allTags`、Task 4 `UserTagsSection`。
- Produces: `MyTagsPage` + `myTags` 路由，支持顶部 tab（模板/场景）、标签改名、删除标签。

- [ ] **Step 1: 加路由常量 + 注册**

`route_names.dart` 追加：

```dart
  static const String myTags = '/my-tags';
```

`router.dart` 追加：

```dart
      GoRoute(
        path: RouteNames.myTags,
        name: 'myTags',
        builder: (context, state) => const MyTagsPage(),
      ),
```

import `import '../features/tags/pages/my_tags_page.dart';`

- [ ] **Step 2: 实现 `my_tags_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 「我的标签」：以标签为中心浏览/管理用户自定义标签。
class MyTagsPage extends ConsumerStatefulWidget {
  const MyTagsPage({super.key});

  @override
  ConsumerState<MyTagsPage> createState() => _MyTagsPageState();
}

class _MyTagsPageState extends ConsumerState<MyTagsPage> {
  String _itemType = TagItemType.template;
  List<TagWithCount> _tags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dao = await ref.read(userTagsDaoProvider.future);
    final tags = await dao.allTags(itemType: _itemType);
    if (!mounted) return;
    setState(() => _tags = tags);
  }

  void _switch(String itemType) {
    setState(() => _itemType = itemType);
    _load();
  }

  Future<void> _rename(TagWithCount e) async {
    final controller = TextEditingController(text: e.tag.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.renameTag(e.tag.id, newName);
    await _load();
  }

  Future<void> _delete(TagWithCount e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('将同时移除「${e.tag.name}」关联的全部内容，确定删除？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    final dao = await ref.read(userTagsDaoProvider.future);
    await dao.deleteTag(e.tag.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '我的标签',
              transparent: true,
              leading: LumiraIconButton(
                icon: Icons.arrow_back_ios_new,
                onPressed: () => Navigator.of(context).pop(),
                size: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  _Tab(
                    label: '模板',
                    active: _itemType == TagItemType.template,
                    onTap: () => _switch(TagItemType.template),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: '场景',
                    active: _itemType == TagItemType.scene,
                    onTap: () => _switch(TagItemType.scene),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tags.isEmpty
                  ? Center(
                      child: Text('还没有标签，去给模板/场景打上标签吧',
                          style: TextStyle(
                              fontSize: 13, color: tokens.textTertiary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _tags.length,
                      itemBuilder: (_, i) {
                        final e = _tags[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.tag.name} · ${e.count} 个',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _rename(e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => _delete(e),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context
        .dependOnInheritedWidgetOfExactType<_TokensScope>() ??
        _TokensScope(tokens: const _FallbackTokens());
    // 注意：此处依赖 theme，用 Provider 传递更稳妥；本实现改为接收 tokens 参数。
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tokens.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Colors.white : tokens.textSecondary)),
      ),
    );
  }
}
```

> 说明：`_Tab` 中不应使用自定义 `_TokensScope`（不存在）。请改为把 `tokens` 作为构造参数传入 `_Tab`（`_Tab({required label, required active, required onTap, required tokens})`），并在 build 处用传入的 `tokens` 渲染。上面代码为示意，实现时以“编译通过”为准修正。每完成一处请更新对应 `docs/superpowers` 文档不需重建，直接改代码。

- [ ] **Step 3: 在搜索页顶栏加「我的标签」入口**

`templates_search_page.dart` 的 `_buildNav` 里，在 `LumiraNav.actions` 加：

```dart
          actions: [
            LumiraIconButton(
              icon: Icons.label_outline,
              onPressed: () =>
                  GoRouter.of(context).push(RouteNames.myTags),
              size: 20,
            ),
          ],
```

`scenes_search_page.dart` 的 `LumiraNav` 同样加 `actions`「我的标签」。

- [ ] **Step 4: 写页面测试**

创建 `test/features/tags/pages/my_tags_page_test.dart`（override `userTagsDaoProvider` 注入空/常量数据，断言标题与 tab 存在）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app/core/db/database_provider.dart';
import 'package:lumira_app/features/tags/pages/my_tags_page.dart';

void main() {
  testWidgets('我的标签页渲染标题与 tab', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [userTagsDaoProvider.overrideWith((ref) => _fakeTagsDao())],
      child: const MaterialApp(home: MyTagsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('我的标签'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
  });
}
```

- [ ] **Step 5: 运行分析 + 测试**

Run: `flutter analyze lib/features/tags/pages/my_tags_page.dart lib/features/templates/pages/templates_search_page.dart lib/features/scenes/pages/scenes_search_page.dart lib/app/router.dart lib/core/router/route_names.dart`
Run: `flutter test test/features/tags/pages/my_tags_page_test.dart`
Expected: 通过。

- [ ] **Step 6: Commit**

```bash
git add lib/features/tags/pages/my_tags_page.dart lib/app/router.dart lib/core/router/route_names.dart lib/features/templates/pages/templates_search_page.dart lib/features/scenes/pages/scenes_search_page.dart test/features/tags/pages/my_tags_page_test.dart
git commit -m "feat: 我的标签标签夹页（tab/改名/删除）"
```

---

### Task 8: 完善用户标签 AND 筛选 + 全量回归

**Files:**
- Modify: `lib/features/templates/pages/templates_search_page.dart`
- Modify: `lib/features/scenes/pages/scenes_search_page.dart`

**Interfaces:**
- Consumes: Task 2 `TagsDao.itemIdsByTag`，Task 5/6 页面状态 `_selectedTagIds`。
- Produces: 用户标签多选 AND 过滤在搜索结果中正确生效（补充 Task 5/6 的占位逻辑，提交可运行版本）。

- [ ] **Step 1: 模板搜索页补全标签 AND 过滤**

在 `_TemplatesSearchPageState` 中维护 `List<TemplateRecord> _userTagFiltered;`，`_load` 时初始化。新增方法并在选中标签变化时调用：

```dart
  Future<void> _refreshUserTagFilter(List<TemplateRecord> keywordHits) async {
    if (_selectedTagIds.isEmpty) {
      if (!mounted) return;
      setState(() => _userTagFiltered = keywordHits);
      return;
    }
    final dao = await ref.read(userTagsDaoProvider.future);
    var keep = keywordHits.map((e) => e.id).toSet();
    for (final tagId in _selectedTagIds) {
      final ids = (await dao.itemIdsByTag(
              itemType: TagItemType.template, tagId: tagId))
          .toSet();
      keep = keep.intersection(ids);
    }
    final filtered =
        keywordHits.where((t) => keep.contains(t.id)).toList();
    if (!mounted) return;
    setState(() => _userTagFiltered = filtered);
  }
```

- [ ] **Step 2: 场景搜索页补全标签 AND 过滤**

同理维护 `List<SceneRecord> _userTagFiltered`，`refreshUserTagFilter(keywordHits)` 用 `TagItemType.scene` 做交集。

- [ ] **Step 3: 确保关键词变化也触发过滤重算**

在模板/场景搜索页 `TextField.onChanged` 或 `_buildResults` 调用处，改为先算 `keywordHits`，再 `await _refreshUserTagFilter(keywordHits)`，展示 `_userTagFiltered`。

- [ ] **Step 4: 全量回归**

Run: `cd lumira_app_flutter && flutter analyze && flutter test`
Expected: 无 error、无 fatal warning；既有测试全绿，本项目新增测试通过。

- [ ] **Step 5: Finish + 提交汇总（feature 完成）**

```bash
git add -A
git commit -m "feat: 完成用户自定义标签 + 搜索/筛选（标签AND过滤）回归通过"
```

---

## 自检记录（可实现时逐项核对）

1. **Spec 覆盖**：`user_tags`/`item_tags` 表（T1）✅、TagsDao（T2）✅、纯函数（T3）✅、打标签 UI（T4）✅、模板搜索页（T5）✅、场景搜索页（T6）✅、标签夹页（T7）✅、标签 AND 筛选（T8）✅。
2. **占位扫描**：T5/T6/T7 中明确标注需补齐的占位逻辑（用户标签 AND 过滤、`_Tab` 的 tokens 传参）在对应 Task 内置步骤要求完成，禁止以占位提交。
3. **类型一致性**：`TagItemType.template/'scene'`、`UserTag{id,name,createdAt}`、`TagWithCount{tag,count}`、`userTagsDaoProvider` 在 T2 定义并在 T4–T8 引用，命名统一；`colItemType/colItemId/colTagId` 在 T1 定义并被 T2 使用。