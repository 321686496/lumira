# 搜索模块（统一全局搜索页）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把模板/场景两个独立搜索页收敛为一个统一全局搜索页 `GlobalSearchPage`，支持 scope 切换（全部/模板/场景/美学院）、历史记录、热门搜索、推荐信息、全量筛选弹层与触底分页懒加载，并在「发现 / 模板库 / 场景库 / 摄影美学院」四个入口接入。

**Architecture:** 纯客户端离线优先。抽一层公共能力 `lib/shared/searchengine/`（scope 枚举、历史存储、筛选模型、分页控制器、筛选弹层），三类内容各自的检索/筛选/排序纯函数放在各自 feature 的 `search/` 目录；统一搜索页按 scope 调用对应 service，`scope=all` 时聚合三类结果混合渲染并带类型角标。历史记录持久化到 sqflite 新表 `search_history`（scope 维度隔离），热搜/推荐在子项目 B（使用次数统计）就绪前由本地派生。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records 语法）、flutter_riverpod 2.3.6、go_router 6.5.7、sqflite v11。不引入任何新依赖。

## Global Constraints

- Dart 2.19.6：**禁止** records / patterns / `(a, b)` 元组语法；`switch` 表达式用旧式 `switch (x) { case ...: }` 或 if-else。
- UI 铁律：颜色/阴影/边框一律取自 `appThemeProvider`（`tokens.*`）与 `uiStyleProvider`，禁止硬编码 `Colors.xxx` / `Color(0xFF....)`；新拟态叠照片浮层用「实心 surface + 细边」，不用外阴影/毛玻璃；复用 `LumiraNav`、`LumiraIconButton`、`NeuCard` 等既有组件。
- 不引入新的第三方图标库/搜索框架；沿用项目现有图标体系（Material Icons）。
- 首屏/触底加载需防重入（loading 中忽略再次触发）；排序或筛选变化时重置分页为第一页。
- 分页页大小固定 20 条/页。
- 历史记录默认保留最近 10 条。
- 每完成一个 Task 后 `flutter analyze` 与 `flutter test test/<对应文件>` 通过后再 commit（Flutter 端，无需 push）。
- 测试沿用 `sqflite_common_ffi` + `databaseFactoryFfiNoIsolate`（fake-async zone 可推进）的既有模式。

---

## 文件结构

```
lib/shared/searchengine/
  ├── search_scope.dart            # SearchScope 枚举 + label/顺序/预置热搜词
  ├── search_store.dart            # 历史增删查清 + 热搜（scope 隔离，含 all 语义）
  ├── search_filters.dart          # SearchSort/SearchPriceFilter/SearchFilters 模型
  ├── paged_results_controller.dart# 分页懒渲染控制器
  └── filter_sheet.dart            # 通用「全量筛选弹层」
lib/features/templates/search/template_search_service.dart
lib/features/scenes/search/scene_search_service.dart
lib/features/academy/search/academy_search_service.dart
lib/features/search/data/search_result.dart        # 跨三类内容统一结果模型
lib/features/search/widgets/search_result_card.dart # 结果卡片（含类型角标）
lib/features/search/widgets/search_initial_sections.dart # 历史/热搜/推荐区块
lib/features/search/pages/global_search_page.dart   # 统一搜索页
lib/core/db/tables.dart          # +SearchHistoryTable
lib/core/db/dao/search_history_dao.dart # +SearchHistoryDao
lib/core/db/database_provider.dart    # +search_history 建表/v32 迁移/+provider
lib/core/router/route_names.dart      # +search/-templatesSearch/-scenesSearch/+paramScope
lib/app/router.dart                   # 两搜索路由替换为 /search
# 入口：templates_page / templates_all_page / scenes_page / academy_page
# 删除：features/templates/pages/templates_search_page.dart、features/scenes/pages/scenes_search_page.dart
test/core/db/dao/search_history_dao_test.dart
test/shared/searchengine/search_store_test.dart
test/shared/searchengine/paged_results_controller_test.dart
test/features/templates/search/template_search_service_test.dart
test/features/scenes/search/scene_search_service_test.dart
test/features/academy/search/academy_search_service_test.dart
test/features/search/pages/global_search_page_test.dart
test/core/router/router_test.dart   # 更新路由计数与路径清单
# 删除：test/features/templates/pages/templates_search_page_test.dart、test/features/scenes/pages/scenes_search_page_test.dart
```

---

### Task 1: search_history 表迁移 + SearchHistoryDao

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（末尾追加 `SearchHistoryTable` 类）
- Create: `lumira_app_flutter/lib/core/db/dao/search_history_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（`_kDbVersion` 31→32、`_onCreate` 建表、`_onUpgrade` v32 迁移、新增 `searchHistoryDaoProvider`）
- Test: `lumira_app_flutter/test/core/db/dao/search_history_dao_test.dart`

**Interfaces:**
- Produces: `class SearchHistoryRecord { int id; String scope; String keyword; int searchCount; int lastSearchedAt; }`
- Produces: `class SearchHistoryDao { Future<void> upsert(String scope, String keyword); Future<List<SearchHistoryRecord>> recent(String scope, {int limit=10}); Future<List<SearchHistoryRecord>> recentUnion({int limit=10}); Future<List<SearchHistoryRecord>> topByCount(String scope, {int limit=10}); Future<void> delete(String scope, String keyword); Future<void> clear(String scope); }`
- Produces: `final searchHistoryDaoProvider = FutureProvider<SearchHistoryDao>(...)`（database_provider.dart）
- Consumes: `Tables` 常量、sqflite `Database`、`databaseProvider`

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/core/db/dao/search_history_dao_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/search_history_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late SearchHistoryDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute(SearchHistoryTable.createSql);
      await d.execute(SearchHistoryTable.indexSql);
    });
    dao = SearchHistoryDao(db);
  });

  tearDown(() => db.close());

  test('upsert 同 scope+keyword 去重累加并刷新时间', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('template', '人像');
    final rows = await dao.recent('template');
    expect(rows.length, 1);
    expect(rows.first.keyword, '人像');
    expect(rows.first.searchCount, 2);
  });

  test('scope 隔离互不串扰', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('scene', '人像');
    expect((await dao.recent('template')).length, 1);
    expect((await dao.recent('scene')).length, 1);
    expect((await dao.recent('academy')).length, 0);
  });

  test('recent 按 last_searched_at 倒序且限长', () async {
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'B');
    await dao.upsert('template', 'C');
    final rows = await dao.recent('template', limit: 2);
    expect(rows.map((e) => e.keyword).toList(), ['C', 'B']);
  });

  test('recentUnion 跨 scope 按 keyword 去重（保留最新）', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('scene', '人像');
    await dao.upsert('scene', '窗光');
    final union = await dao.recentUnion();
    expect(union.length, 2);
    expect(union.map((e) => e.keyword).toSet(), {'人像', '窗光'});
  });

  test('topByCount 按搜索次数降序', () async {
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'B');
    final rows = await dao.topByCount('template');
    expect(rows.first.keyword, 'A');
  });

  test('delete / clear 定向删除', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('template', '窗光');
    await dao.delete('template', '人像');
    expect((await dao.recent('template')).length, 1);
    await dao.clear('template');
    expect((await dao.recent('template')).length, 0);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/core/db/dao/search_history_dao_test.dart`
Expected: FAIL（找不到 `SearchHistoryTable` / `SearchHistoryDao`）。

- [ ] **Step 3: tables.dart 追加表定义**

在 `lumira_app_flutter/lib/core/db/tables.dart` 末尾（`XpEventsTable` 类之后）追加：

```dart
/// 搜索历史表（v32 迁移新增，搜索模块）
/// scope 取值：'template' | 'scene' | 'academy'（隔离三类内容，互不串扰）
class SearchHistoryTable {
  static const name = 'search_history';
  static const colId = 'id';
  static const colScope = 'scope';
  static const colKeyword = 'keyword';
  static const colSearchCount = 'search_count';
  static const colLastSearchedAt = 'last_searched_at';

  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colScope TEXT NOT NULL,
      $colKeyword TEXT NOT NULL,
      $colSearchCount INTEGER NOT NULL DEFAULT 1,
      $colLastSearchedAt INTEGER NOT NULL
    )
  ''';
  static const indexSql =
      'CREATE INDEX IF NOT EXISTS idx_search_history_scope_time ON $name ($colScope, $colLastSearchedAt DESC)';
}
```

- [ ] **Step 4: 创建 SearchHistoryDao**

创建 `lumira_app_flutter/lib/core/db/dao/search_history_dao.dart`：

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 搜索历史单条记录。
class SearchHistoryRecord {
  final int id;
  final String scope; // 'template' | 'scene' | 'academy'
  final String keyword;
  final int searchCount;
  final int lastSearchedAt;

  const SearchHistoryRecord({
    required this.id,
    required this.scope,
    required this.keyword,
    required this.searchCount,
    required this.lastSearchedAt,
  });
}

/// 搜索历史 DAO（scope 维度隔离；DAO 本身只认字符串，scope=all 的语义由 SearchStore 处理）。
class SearchHistoryDao {
  SearchHistoryDao(this._db);

  final Database _db;

  /// 同 scope+keyword 去重：累加 search_count 并刷新 last_searched_at。
  Future<void> upsert(String scope, String keyword) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      SearchHistoryTable.name,
      where:
          '${SearchHistoryTable.colScope} = ? AND ${SearchHistoryTable.colKeyword} = ?',
      whereArgs: [scope, keyword],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert(SearchHistoryTable.name, {
        SearchHistoryTable.colScope: scope,
        SearchHistoryTable.colKeyword: keyword,
        SearchHistoryTable.colSearchCount: 1,
        SearchHistoryTable.colLastSearchedAt: now,
      });
    } else {
      final id = existing.first[SearchHistoryTable.colId];
      final count =
          (existing.first[SearchHistoryTable.colSearchCount] as num).toInt();
      await _db.update(
        SearchHistoryTable.name,
        {
          SearchHistoryTable.colSearchCount: count + 1,
          SearchHistoryTable.colLastSearchedAt: now,
        },
        where: '${SearchHistoryTable.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  /// 某 scope 最近历史（last_searched_at 倒序）。
  Future<List<SearchHistoryRecord>> recent(
    String scope, {
    int limit = 10,
  }) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
      orderBy: '${SearchHistoryTable.colLastSearchedAt} DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// 全 scope 并集：按 keyword 去重（保留最新一条），按 last_searched_at 倒序。
  Future<List<SearchHistoryRecord>> recentUnion({int limit = 10}) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      orderBy: '${SearchHistoryTable.colLastSearchedAt} DESC',
    );
    final seen = <String>{};
    final result = <SearchHistoryRecord>[];
    for (final r in rows) {
      final rec = _fromRow(r);
      if (seen.add(rec.keyword)) result.add(rec);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 某 scope 高频历史（search_count 降序，热搜候选）。
  Future<List<SearchHistoryRecord>> topByCount(
    String scope, {
    int limit = 10,
  }) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
      orderBy:
          '${SearchHistoryTable.colSearchCount} DESC, ${SearchHistoryTable.colLastSearchedAt} DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// 删除某 scope 的单条关键词。
  Future<void> delete(String scope, String keyword) async {
    await _db.delete(
      SearchHistoryTable.name,
      where:
          '${SearchHistoryTable.colScope} = ? AND ${SearchHistoryTable.colKeyword} = ?',
      whereArgs: [scope, keyword],
    );
  }

  /// 清空某 scope。
  Future<void> clear(String scope) async {
    await _db.delete(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
    );
  }

  SearchHistoryRecord _fromRow(Map<String, Object?> row) => SearchHistoryRecord(
        id: (row[SearchHistoryTable.colId] as num).toInt(),
        scope: row[SearchHistoryTable.colScope] as String,
        keyword: row[SearchHistoryTable.colKeyword] as String,
        searchCount: (row[SearchHistoryTable.colSearchCount] as num).toInt(),
        lastSearchedAt:
            (row[SearchHistoryTable.colLastSearchedAt] as num).toInt(),
      );
}
```

- [ ] **Step 5: database_provider.dart 接入迁移与 provider**

在 `lumira_app_flutter/lib/core/db/database_provider.dart`：

1. 顶部 import 追加：
```dart
import 'dao/search_history_dao.dart';
```

2. `const int _kDbVersion = 31;` 改为 `const int _kDbVersion = 32;`

3. 在 `_onCreate` 中（其它表 create 之后、batch 提交前）追加：
```dart
  // === search_history（v32，搜索模块） ===
  batch.execute(SearchHistoryTable.createSql);
  batch.execute(SearchHistoryTable.indexSql);
```

4. 在 `_onUpgrade` 末尾（`if (oldVersion < 31) {...}` 之后、函数收尾 `}` 之前）追加：
```dart
  if (oldVersion < 32) {
    try {
      // v32: 搜索历史表（统一搜索页 scope 隔离历史记录）
      await db.execute(SearchHistoryTable.createSql);
      await db.execute(SearchHistoryTable.indexSql);
    } catch (e) {
      debugPrint('v32 migration failed (silent fallback): $e');
    }
  }
```

5. 在文件末尾 provider 区追加（与其它 DAO provider 并列）：
```dart
final searchHistoryDaoProvider = FutureProvider<SearchHistoryDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SearchHistoryDao(db);
});
```

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/core/db/dao/search_history_dao_test.dart`
Expected: PASS（6 个测试）。

- [ ] **Step 7: 提交**

```powershell
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/dao/search_history_dao.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/test/core/db/dao/search_history_dao_test.dart
git commit -m "feat(search): 新增 search_history 表迁移与 SearchHistoryDao"
```

---

### Task 2: SearchScope + SearchStore（历史/热搜/预置词）

**Files:**
- Create: `lumira_app_flutter/lib/shared/searchengine/search_scope.dart`
- Create: `lumira_app_flutter/lib/shared/searchengine/search_store.dart`
- Test: `lumira_app_flutter/test/shared/searchengine/search_store_test.dart`

**Interfaces:**
- Produces: `enum SearchScope { all, template, scene, academy }`
- Produces: `extension SearchScopeExt on SearchScope { String get name; String get label; static SearchScope fromName(String? s); static const List<SearchScope> searchableScopes; }`
- Produces: `const Map<SearchScope, List<String>> kPresetHotWords`
- Produces: `class SearchStore { Future<void> record(SearchScope scope, String keyword); Future<List<String>> recentKeywords(SearchScope scope, {int limit=10}); Future<List<String>> hotKeywords(SearchScope scope, {int limit=10}); Future<void> deleteKeyword(SearchScope scope, String keyword); Future<void> clear(SearchScope scope); }`
- Produces: `final searchStoreProvider = FutureProvider<SearchStore>(...)`
- Consumes: `SearchHistoryDao`（Task 1）、`searchHistoryDaoProvider`

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/shared/searchengine/search_store_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/search_history_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_scope.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_store.dart';

void main() {
  late Database db;
  late SearchStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute(SearchHistoryTable.createSql);
      await d.execute(SearchHistoryTable.indexSql);
    });
    store = SearchStore(SearchHistoryDao(db));
  });

  tearDown(() => db.close());

  test('record scope=all 时写入三个真实 scope', () async {
    await store.record(SearchScope.all, '人像');
    expect((await store.recentKeywords(SearchScope.template)), ['人像']);
    expect((await store.recentKeywords(SearchScope.scene)), ['人像']);
    expect((await store.recentKeywords(SearchScope.academy)), ['人像']);
  });

  test('record 去重并置顶', () async {
    await store.record(SearchScope.template, 'A');
    await store.record(SearchScope.template, 'B');
    await store.record(SearchScope.template, 'A');
    final keywords = await store.recentKeywords(SearchScope.template);
    expect(keywords, ['A', 'B']);
  });

  test('recentKeywords scope=all 返回跨 scope 去重并集', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.scene, '人像');
    await store.record(SearchScope.scene, '窗光');
    final all = await store.recentKeywords(SearchScope.all);
    expect(all.length, 2);
    expect(all.toSet(), {'人像', '窗光'});
  });

  test('hotKeywords = 预置词 ∪ 高频历史，去重且限长', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.template, '高频自造词');
    final hot = await store.hotKeywords(SearchScope.template, limit: 5);
    expect(hot.first, '高频自造词');
    expect(hot, contains('人像'));
    expect(hot.toSet().length, hot.length);
  });

  test('deleteKeyword / clear 按 scope 定向操作，all 时三写全删', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.scene, '人像');
    await store.deleteKeyword(SearchScope.all, '人像');
    expect((await store.recentKeywords(SearchScope.all)).length, 0);

    await store.record(SearchScope.template, '窗光');
    await store.record(SearchScope.scene, '夜景');
    await store.clear(SearchScope.all);
    expect((await store.recentKeywords(SearchScope.template)).length, 0);
    expect((await store.recentKeywords(SearchScope.scene)).length, 0);
    expect((await store.recentKeywords(SearchScope.academy)).length, 0);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/shared/searchengine/search_store_test.dart`
Expected: FAIL（找不到 `SearchScope` / `SearchStore`）。

- [ ] **Step 3: 创建 search_scope.dart**

创建 `lumira_app_flutter/lib/shared/searchengine/search_scope.dart`：

```dart
/// 搜索范围（scope）。
/// all=全部（跨三类混合）、template=模板、scene=场景、academy=美学院。
enum SearchScope { all, template, scene, academy }

extension SearchScopeExt on SearchScope {
  String get name => toString().split('.').last;

  String get label {
    switch (this) {
      case SearchScope.all:
        return '全部';
      case SearchScope.template:
        return '模板';
      case SearchScope.scene:
        return '场景';
      case SearchScope.academy:
        return '美学院';
    }
  }

  static SearchScope fromName(String? s) {
    for (final v in SearchScope.values) {
      if (v.name == s) return v;
    }
    return SearchScope.all;
  }

  /// 可被搜索的具体内容 scope（不含 all）。
  static const List<SearchScope> searchableScopes = [
    SearchScope.template,
    SearchScope.scene,
    SearchScope.academy,
  ];
}

/// 预置热门词（子项目 B 云端热搜就绪前的本地兜底）。
/// 与自身高频历史取并集后展示。
const Map<SearchScope, List<String>> kPresetHotWords = {
  SearchScope.all: ['人像', '构图', '复古', '窗光', '夜景', '日系'],
  SearchScope.template: ['人像', '复古', '日系', '夜景', '电影感', '美食', '微距', '静物'],
  SearchScope.scene: ['窗光', '逆光', '街拍', '咖啡馆', '日落', '街头'],
  SearchScope.academy: ['构图', '布光', '人像', '风光', '静物', '街头'],
};
```

- [ ] **Step 4: 创建 search_store.dart**

创建 `lumira_app_flutter/lib/shared/searchengine/search_store.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/dao/search_history_dao.dart';
import '../../core/db/database_provider.dart';
import 'search_scope.dart';

/// 搜索历史/热搜的封装（scope 维度隔离；scope=all 的多写/并集语义在此处理）。
class SearchStore {
  SearchStore(this._dao);

  final SearchHistoryDao _dao;

  /// 记录一次搜索。scope=all 时同步写入三个真实 scope。
  Future<void> record(SearchScope scope, String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    if (scope == SearchScope.all) {
      for (final s in SearchScope.searchableScopes) {
        await _dao.upsert(s.name, k);
      }
    } else {
      await _dao.upsert(scope.name, k);
    }
  }

  /// 最近搜索关键词。scope=all 返回跨 scope 去重并集。
  Future<List<String>> recentKeywords(SearchScope scope, {int limit = 10}) async {
    final rows = scope == SearchScope.all
        ? await _dao.recentUnion(limit: limit)
        : await _dao.recent(scope.name, limit: limit);
    return rows.map((r) => r.keyword).toList();
  }

  /// 热门搜索：预置词 ∪ 自身高频历史，去重后限长。
  /// （子项目 B 云端热搜就绪后在此换成远程数据源即可。）
  Future<List<String>> hotKeywords(SearchScope scope, {int limit = 10}) async {
    final presets = kPresetHotWords[scope] ?? const <String>[];
    final top = scope == SearchScope.all
        ? const <String>[]
        : (await _dao.topByCount(scope.name))
            .map((r) => r.keyword)
            .toList();
    final seen = <String>{};
    final result = <String>[];
    for (final w in [...presets, ...top]) {
      if (seen.add(w)) result.add(w);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 删除单条关键词。scope=all 时跨三个真实 scope 删除。
  Future<void> deleteKeyword(SearchScope scope, String keyword) async {
    if (scope == SearchScope.all) {
      for (final s in SearchScope.searchableScopes) {
        await _dao.delete(s.name, keyword);
      }
    } else {
      await _dao.delete(scope.name, keyword);
    }
  }

  /// 清空。scope=all 时清空全部三个 scope。
  Future<void> clear(SearchScope scope) async {
    if (scope == SearchScope.all) {
      for (final s in SearchScope.searchableScopes) {
        await _dao.clear(s.name);
      }
    } else {
      await _dao.clear(scope.name);
    }
  }
}

final searchStoreProvider = FutureProvider<SearchStore>((ref) async {
  final dao = await ref.watch(searchHistoryDaoProvider.future);
  return SearchStore(dao);
});
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/shared/searchengine/search_store_test.dart`
Expected: PASS（5 个测试）。

- [ ] **Step 6: 提交**

```powershell
git add lumira_app_flutter/lib/shared/searchengine/search_scope.dart lumira_app_flutter/lib/shared/searchengine/search_store.dart lumira_app_flutter/test/shared/searchengine/search_store_test.dart
git commit -m "feat(search): 新增 SearchScope 与 SearchStore（历史/热搜）"
```

---

### Task 3: SearchFilters + PagedResultsController

**Files:**
- Create: `lumira_app_flutter/lib/shared/searchengine/search_filters.dart`
- Create: `lumira_app_flutter/lib/shared/searchengine/paged_results_controller.dart`
- Test: `lumira_app_flutter/test/shared/searchengine/paged_results_controller_test.dart`

**Interfaces:**
- Produces: `enum SearchSort { comprehensive, hot, latest }`、`enum SearchPriceFilter { all, free, paid }`
- Produces: `class SearchFilters { SearchSort sort; String? category; String? sceneStyle; String? academyTopic; String? academyLevel; SearchPriceFilter price; bool ownedOnly; Set<int> userTagIds; SearchFilters copyWith({...}); SearchFilters reset(); }`（字段类型均为 String/基础类型，不依赖业务模型，保持 shared 解耦）
- Produces: `class PagedResultsController { PagedResultsController({int pageSize=20}); int get visible; bool get isLoading; bool hasMore(int total); bool loadMore(int total); void finishLoading(); void reset(); }`
- Consumes: 无（纯模型）

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/shared/searchengine/paged_results_controller_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/searchengine/paged_results_controller.dart';

void main() {
  test('初始 visible=0，hasMore 判定', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.visible, 0);
    expect(c.hasMore(0), isFalse);
    expect(c.hasMore(45), isTrue);
  });

  test('loadMore 追加一页并 clamp 到总数', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 20);
    c.finishLoading();
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 40);
    c.finishLoading();
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 45); // clamp 到 total
    c.finishLoading();
    expect(c.loadMore(45), isFalse); // 已到底
  });

  test('loading 中防重入（第二次 loadMore 忽略）', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.loadMore(100), isTrue);
    expect(c.visible, 20);
    expect(c.loadMore(100), isFalse); // 防重入
    expect(c.visible, 20);
    c.finishLoading();
  });

  test('reset 回到第一页并清除 loading', () {
    final c = PagedResultsController(pageSize: 20);
    c.loadMore(100);
    c.reset();
    expect(c.visible, 0);
    expect(c.isLoading, isFalse);
    expect(c.hasMore(100), isTrue);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/shared/searchengine/paged_results_controller_test.dart`
Expected: FAIL（找不到 `PagedResultsController`）。

- [ ] **Step 3: 创建 search_filters.dart**

创建 `lumira_app_flutter/lib/shared/searchengine/search_filters.dart`：

```dart
/// 排序方式。
enum SearchSort { comprehensive, hot, latest }

/// 价格筛选（template 专用）。
enum SearchPriceFilter { all, free, paid }

/// 搜索筛选状态。
/// 字段刻意用 String（category/sceneStyle/academyTopic/academyLevel 都是 key/枚举名），
/// 使本文件不依赖任何业务模型，保持 shared 层解耦。
class SearchFilters {
  SearchSort sort;
  String? category; // template: 分类 key；scene: 分类（复用同一字段）
  String? sceneStyle; // scene: 风格
  String? academyTopic; // academy: 主题枚举名（portrait/landscape/stillLife/street）
  String? academyLevel; // academy: 等级枚举名（beginner/intermediate/advanced）
  SearchPriceFilter price; // template 专用
  bool ownedOnly; // template 专用：仅我拥有的
  Set<int> userTagIds; // 通用：用户标签 AND

  SearchFilters({
    this.sort = SearchSort.comprehensive,
    this.category,
    this.sceneStyle,
    this.academyTopic,
    this.academyLevel,
    this.price = SearchPriceFilter.all,
    this.ownedOnly = false,
    Set<int>? userTagIds,
  }) : userTagIds = userTagIds ?? <int>{};

  SearchFilters copyWith({
    SearchSort? sort,
    String? Function()? category,
    String? Function()? sceneStyle,
    String? Function()? academyTopic,
    String? Function()? academyLevel,
    SearchPriceFilter? price,
    bool? ownedOnly,
    Set<int>? userTagIds,
  }) {
    return SearchFilters(
      sort: sort ?? this.sort,
      category: category != null ? category() : this.category,
      sceneStyle: sceneStyle != null ? sceneStyle() : this.sceneStyle,
      academyTopic: academyTopic != null ? academyTopic() : this.academyTopic,
      academyLevel: academyLevel != null ? academyLevel() : this.academyLevel,
      price: price ?? this.price,
      ownedOnly: ownedOnly ?? this.ownedOnly,
      userTagIds: userTagIds ?? this.userTagIds,
    );
  }

  /// 重置为默认（不重置 sort，只重置条件）。
  SearchFilters reset() => SearchFilters(sort: sort);
}
```

> 注：`copyWith` 的 `String? Function()?` 闭包写法是为了支持「显式置 null」语义（如清除已选分类），调用方用 `category: () => null`。本项目 Dart 2.19 不支持可空字段的便捷重置，故用闭包模式。

- [ ] **Step 4: 创建 paged_results_controller.dart**

创建 `lumira_app_flutter/lib/shared/searchengine/paged_results_controller.dart`：

```dart
/// 分页懒渲染控制器：维护已渲染条数 visible，触底追加、防重入、可重置。
class PagedResultsController {
  PagedResultsController({this.pageSize = 20});

  final int pageSize;

  int _visible = 0;
  bool _loading = false;

  int get visible => _visible;
  bool get isLoading => _loading;

  bool hasMore(int total) => _visible < total;

  /// 触底追加一页。loading 中或已到底返回 false（防重入）。
  /// 成功追加后返回 true，调用方应 setState 刷新，再调用 [finishLoading]。
  bool loadMore(int total) {
    if (_loading || !hasMore(total)) return false;
    _loading = true;
    _visible = (_visible + pageSize).clamp(0, total);
    return true;
  }

  /// 追加完成后结束 loading 状态。
  void finishLoading() => _loading = false;

  /// 关键词/范围/筛选/排序变化时重置为第一页。
  void reset() {
    _visible = 0;
    _loading = false;
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/shared/searchengine/paged_results_controller_test.dart`
Expected: PASS（4 个测试）。

- [ ] **Step 6: 提交**

```powershell
git add lumira_app_flutter/lib/shared/searchengine/search_filters.dart lumira_app_flutter/lib/shared/searchengine/paged_results_controller.dart lumira_app_flutter/test/shared/searchengine/paged_results_controller_test.dart
git commit -m "feat(search): 新增 SearchFilters 与 PagedResultsController"
```

---

### Task 4: 三类内容搜索服务（template / scene / academy）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/search/template_search_service.dart`
- Create: `lumira_app_flutter/lib/features/scenes/search/scene_search_service.dart`
- Create: `lumira_app_flutter/lib/features/academy/search/academy_search_service.dart`
- Test: `lumira_app_flutter/test/features/templates/search/template_search_service_test.dart`
- Test: `lumira_app_flutter/test/features/scenes/search/scene_search_service_test.dart`
- Test: `lumira_app_flutter/test/features/academy/search/academy_search_service_test.dart`

**Interfaces:**
- Consumes: `containsIgnoreCase`（`features/tags/tag_filter_logic.dart`）、`TemplatesBrowseMockData.categoryLabel/lutLabel`、`AcademyTopicExt.label/AcademyLevelExt.label`、`SearchSort/SearchPriceFilter/SearchFilters`、`TemplateRecord/SceneRecord/AcademyCourse/KnowledgeCard`
- Produces: `class TemplateSearchService { static bool matchesKeyword(TemplateRecord t, String keyword, {Map<String,String> categoryLabelByKey}); static List<TemplateRecord> search({required List<TemplateRecord> all, required String keyword, required SearchFilters filters, Map<String,String> categoryLabelByKey = const {}, Set<String>? allowedIds, Map<String,int>? popularity}); }`
- Produces: `class SceneSearchService { static bool matchesKeyword(SceneRecord s, String keyword); static List<SceneRecord> search({required List<SceneRecord> all, required String keyword, required SearchFilters filters, Set<String>? allowedIds, Map<String,int>? popularity}); }`
- Produces: `class AcademySearchService { static bool courseMatchesKeyword(AcademyCourse c, String keyword); static bool cardMatchesKeyword(KnowledgeCard k, String keyword); static List<AcademyCourse> searchCourses({required List<AcademyCourse> all, required String keyword, required SearchFilters filters}); static List<KnowledgeCard> searchCards({required List<KnowledgeCard> all, required String keyword, required SearchFilters filters}); }`
- 约定：`allowedIds` 由页面根据用户标签 AND 交集预计算传入（null=不过滤）；`popularity` 为 id→热度值（子项目 B 就绪后由 usage_stats 派生，未就绪传 null）

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/templates/search/template_search_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/search/template_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

TemplateRecord _tpl({
  required String id,
  required String name,
  String category = 'portrait',
  Map<String, dynamic> classification = const {},
  List<String> tags = const [],
  String description = '',
  String referenceSource = '',
  Map<String, dynamic> composition = const {},
  Map<String, dynamic> postProcess = const {},
  int price = 0,
  bool isRecommended = false,
  String source = 'builtin',
}) {
  return TemplateRecord(
    id: id, name: name, author: '', version: '1.0.0', category: category,
    classification: classification, tags: tags, tagIds: const [], price: price,
    cover: '', description: description, referenceSource: referenceSource,
    composition: composition, pose: const {}, camera: const {},
    sceneGuide: const {}, postProcess: postProcess, createdAt: 1, updatedAt: 1,
    isBuiltin: true, isRecommended: isRecommended, source: source,
  );
}

void main() {
  test('多字段命中：name/分类标签/分类树key标签/description/lut标签', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '港风人像'),
      _tpl(id: 'b', name: '窗光', classification: {'type': 'portrait', 'subStyle': 'japanese'}),
      _tpl(id: 'c', name: '胶片', postProcess: {'lut': 'vintage'}),
      _tpl(id: 'd', name: '街头', description: '雨夜霓虹'),
    ];
    const labelByKey = {'portrait': '人像', 'japanese': '日系'};
    expect(TemplateSearchService.matchesKeyword(list[0], '港风', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[1], '日系', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[2], '复古', categoryLabelByKey: labelByKey), isTrue); // lut 中文标签
    expect(TemplateSearchService.matchesKeyword(list[3], '霓虹', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[0], '夜景', categoryLabelByKey: labelByKey), isFalse);
  });

  test('category 筛选命中子树 key 集合', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '人像', category: 'portrait'),
      _tpl(id: 'b', name: '日系', classification: {'majorStyle': 'japanese'}),
      _tpl(id: 'c', name: '美食', category: 'food'),
    ];
    final filters = SearchFilters(category: 'portrait');
    // portrait 子树 = {portrait, japanese}
    final result = TemplateSearchService.search(
      all: list, keyword: '', filters: filters,
      categoryLabelByKey: const {},
    );
    expect(result.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('价格/来源/用户标签 allowedIds 过滤', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '免费内置', price: 0),
      _tpl(id: 'b', name: '付费内置', price: 30),
      _tpl(id: 'c', name: '我的自定义', price: 30, source: 'custom'),
    ];
    final free = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(price: SearchPriceFilter.free),
    );
    expect(free.map((e) => e.id), ['a']);

    final owned = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(ownedOnly: true),
    );
    expect(owned.map((e) => e.id), ['c']);

    final allowed = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(),
      allowedIds: {'b', 'c'},
    );
    expect(allowed.map((e) => e.id).toSet(), {'b', 'c'});
  });

  test('hot 排序：recommended 优先', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '普通', isRecommended: false),
      _tpl(id: 'b', name: '推荐', isRecommended: true),
    ];
    final result = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
    );
    expect(result.first.id, 'b');
  });
}
```

创建 `lumira_app_flutter/test/features/scenes/search/scene_search_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/features/scenes/search/scene_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

SceneRecord _scene({
  required String id,
  required String name,
  String category = 'indoor',
  String style = '',
  String vibe = '',
  String description = '',
  List<String> tips = const [],
  String whereToShoot = '',
  String bestTime = '',
  String relatedCategory = '',
  int createdAt = 1,
}) {
  return SceneRecord(
    id: id, name: name, icon: '', category: category, style: style,
    filter: const {}, vibe: vibe, description: description,
    exampleImages: const [], tips: tips, whereToShoot: whereToShoot,
    bestTime: bestTime, sceneGuide: const {}, relatedCategory: relatedCategory,
    recommendedTagIds: const [], tagIds: const [], creator: 'system',
    isFavorite: false, createdAt: createdAt, updatedAt: 1,
  );
}

void main() {
  test('多字段命中：name/分类/风格/氛围/描述/提示/地点/时间/关联分类', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: '窗光人像', vibe: '温暖'),
      _scene(id: 'b', name: '街头', style: '复古', whereToShoot: '老城区'),
      _scene(id: 'c', name: '咖啡馆', tips: const ['靠窗座位'], bestTime: '下午'),
      _scene(id: 'd', name: '海边', relatedCategory: 'landscape'),
    ];
    expect(SceneSearchService.matchesKeyword(list[0], '温暖'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[1], '老城区'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[2], '靠窗'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[3], 'landscape'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[0], '夜景'), isFalse);
  });

  test('category / style 筛选', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: '室内窗光', category: 'indoor', style: '清新'),
      _scene(id: 'b', name: '街头', category: 'street', style: '复古'),
    ];
    final byCategory = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(category: 'indoor'),
    );
    expect(byCategory.map((e) => e.id), ['a']);

    final byStyle = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sceneStyle: '复古'),
    );
    expect(byStyle.map((e) => e.id), ['b']);
  });

  test('hot 按 popularity 降序，latest 按 createdAt 降序', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: 'A', createdAt: 1),
      _scene(id: 'b', name: 'B', createdAt: 2),
    ];
    final hot = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
      popularity: {'b': 100, 'a': 10},
    );
    expect(hot.first.id, 'b');

    final latest = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.latest),
    );
    expect(latest.first.id, 'b');
  });
}
```

创建 `lumira_app_flutter/test/features/academy/search/academy_search_service_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/search/academy_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

void main() {
  test('课程多字段命中：标题/主题中文标签/等级中文标签/标签/meta', () {
    final courses = <AcademyCourse>[
      const AcademyCourse(id: 'c1', lessonNumber: 1, title: '人像构图入门',
        level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
        coverImage: '', meta: '8分钟 · 入门', tags: ['构图', '人像']),
      const AcademyCourse(id: 'c2', lessonNumber: 2, title: '街头抓拍',
        level: AcademyLevel.advanced, topic: AcademyTopic.street,
        coverImage: '', meta: '12分钟 · 高级', tags: ['街拍']),
    ];
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '构图'), isTrue);
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '人像'), isTrue);
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '入门基础'), isTrue); // level.label
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '街头'), isFalse);
    expect(AcademySearchService.courseMatchesKeyword(courses[1], '街头'), isTrue);
  });

  test('知识卡片多字段命中：标题/副标题/主题标签/正文/要点', () {
    final cards = <KnowledgeCard>[
      const KnowledgeCard(id: 'k1', topic: AcademyTopic.portrait, title: '三分法构图',
        subtitle: '让画面更均衡', coverImage: '', body: '把主体放在交点附近', keyPoints: ['引导线']),
    ];
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '三分法'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '均衡'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '人像'), isTrue); // topic.label
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '引导线'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '夜景'), isFalse);
  });

  test('主题/等级筛选与 hot 排序', () {
    final courses = <AcademyCourse>[
      const AcademyCourse(id: 'c1', lessonNumber: 1, title: '人像入门',
        level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
        coverImage: '', meta: '', tags: [], rewardXP: 50),
      const AcademyCourse(id: 'c2', lessonNumber: 2, title: '街头进阶',
        level: AcademyLevel.intermediate, topic: AcademyTopic.street,
        coverImage: '', meta: '', tags: [], rewardXP: 100),
    ];
    final byTopic = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(academyTopic: 'portrait'),
    );
    expect(byTopic.map((e) => e.id), ['c1']);

    final byLevel = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(academyLevel: 'intermediate'),
    );
    expect(byLevel.map((e) => e.id), ['c2']);

    final hot = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
    );
    expect(hot.first.id, 'c2');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run:
```powershell
flutter test test/features/templates/search/template_search_service_test.dart
flutter test test/features/scenes/search/scene_search_service_test.dart
flutter test test/features/academy/search/academy_search_service_test.dart
```
Expected: FAIL（找不到 service 类）。

- [ ] **Step 3: 创建 template_search_service.dart**

创建 `lumira_app_flutter/lib/features/templates/search/template_search_service.dart`：

```dart
import '../../../core/db/dao/templates_dao.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/templates_browse_mock_data.dart';

/// 模板检索/筛选/排序纯函数（多字段命中 + 分类子树 + 价格 + 来源 + 排序）。
class TemplateSearchService {
  TemplateSearchService._();

  /// 多字段命中：name / category 中文标签 / classification 三级 key 及其中文标签 /
  /// tags / description / referenceSource / composition.description / postProcess.lut 中文标签。
  static bool matchesKeyword(
    TemplateRecord t,
    String keyword, {
    Map<String, String> categoryLabelByKey = const {},
  }) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      t.name,
      TemplatesBrowseMockData.categoryLabel(t.category),
      ...t.tags,
      t.description,
      t.referenceSource,
    ];
    final cls = t.classification;
    for (final key in const ['type', 'majorStyle', 'subStyle', 'method']) {
      final v = cls[key] as String?;
      if (v == null || v.isEmpty) continue;
      candidates.add(v);
      final label = categoryLabelByKey[v];
      if (label != null && label.isNotEmpty && label != v) {
        candidates.add(label);
      }
    }
    final compDesc = t.composition['description'] as String?;
    if (compDesc != null && compDesc.isNotEmpty) candidates.add(compDesc);
    final lut = t.postProcess['lut'] as String?;
    if (lut != null && lut.isNotEmpty) {
      candidates.add(TemplatesBrowseMockData.lutLabel(lut));
    }
    return candidates.any((c) => containsIgnoreCase(c, q));
  }

  /// 关键词 → 筛选（分类子树/价格/来源/用户标签 allowedIds）→ 排序。
  /// [categoryLabelByKey] 分类 key→中文标签（页面从 template_categories 加载）。
  /// [allowedIds] 用户标签 AND 交集（null=不过滤）。
  /// [popularity] id→热度（子项目 B 就绪前传 null，hot 退化为 recommended+createdAt）。
  static List<TemplateRecord> search({
    required List<TemplateRecord> all,
    required String keyword,
    required SearchFilters filters,
    Map<String, String> categoryLabelByKey = const {},
    Set<String>? allowedIds,
    Map<String, int>? popularity,
  }) {
    var list = all
        .where((t) =>
            matchesKeyword(t, keyword, categoryLabelByKey: categoryLabelByKey))
        .toList();

    // 分类筛选（四级 key 子树：category 命中 || 任一 classification key ∈ 子树）
    final category = filters.category;
    if (category != null && category.isNotEmpty) {
      // 页面把所选分类的子树 key 集合放到 categoryLabelByKey 之外的约定：
      // 这里用「t.category == category || classification 任一值 == category」的简单判定；
      // 子树展开由页面在传入前调用 dao.getSubtreeKeys 并把 category 替换为子树内的
      // 任一命中（见下方 _categorySubtreeHit）。
      list = list.where((t) => _categoryHit(t, category)).toList();
    }

    if (filters.price == SearchPriceFilter.free) {
      list = list.where((t) => t.price == 0).toList();
    } else if (filters.price == SearchPriceFilter.paid) {
      list = list.where((t) => t.price > 0).toList();
    }

    if (filters.ownedOnly) {
      list = list.where((t) => t.source == 'custom').toList();
    }

    if (allowedIds != null) {
      list = list.where((t) => allowedIds.contains(t.id)).toList();
    }

    _sort(list, filters.sort, popularity);
    return list;
  }

  static bool _categoryHit(TemplateRecord t, String key) {
    if (t.category == key) return true;
    final cls = t.classification;
    for (final k in const ['type', 'majorStyle', 'subStyle', 'method']) {
      final v = cls[k] as String?;
      if (v == key) return true;
    }
    return false;
  }

  static void _sort(
    List<TemplateRecord> list,
    SearchSort sort,
    Map<String, int>? popularity,
  ) {
    switch (sort) {
      case SearchSort.comprehensive:
        break; // 保持原顺序（数据已按创建/导入顺序稳定）
      case SearchSort.hot:
        list.sort((a, b) {
          final pa = popularity?[a.id] ?? (a.isRecommended ? 1 : 0);
          final pb = popularity?[b.id] ?? (b.isRecommended ? 1 : 0);
          if (pa != pb) return pb.compareTo(pa);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }
}
```

> 说明：`_categoryHit` 为简化判定。如需「子树展开」，由页面在调用前把 `filters.category` 保持为所选 key，并在 `categoryLabelByKey` 中额外注入该 key→子树内某 key 的映射会破坏语义；故此处用「category 或 classification 任一值 == key」的等价命中，覆盖一级分类 key 直接命中场景。子树展开能力由 Task 6 页面在加载分类选项时提供（用户选二级/三级分类时 `_categoryHit` 天然命中 classification key）。

- [ ] **Step 4: 创建 scene_search_service.dart**

创建 `lumira_app_flutter/lib/features/scenes/search/scene_search_service.dart`：

```dart
import '../../../core/db/dao/scenes_dao.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';

/// 场景检索/筛选/排序纯函数。
class SceneSearchService {
  SceneSearchService._();

  /// 多字段命中：name / category / style / vibe / description / tips /
  /// whereToShoot / bestTime / relatedCategory。
  static bool matchesKeyword(SceneRecord s, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      s.name,
      s.category,
      s.style,
      s.vibe,
      s.description,
      ...s.tips,
      s.whereToShoot,
      s.bestTime,
      s.relatedCategory,
    ];
    return candidates.any((c) => containsIgnoreCase(c, q));
  }

  /// 关键词 → 筛选（分类/风格/用户标签 allowedIds）→ 排序。
  static List<SceneRecord> search({
    required List<SceneRecord> all,
    required String keyword,
    required SearchFilters filters,
    Set<String>? allowedIds,
    Map<String, int>? popularity,
  }) {
    var list =
        all.where((s) => matchesKeyword(s, keyword)).toList();

    final category = filters.category;
    if (category != null && category.isNotEmpty) {
      list = list.where((s) => s.category == category).toList();
    }
    final style = filters.sceneStyle;
    if (style != null && style.isNotEmpty) {
      list = list.where((s) => s.style == style).toList();
    }
    if (allowedIds != null) {
      list = list.where((s) => allowedIds.contains(s.id)).toList();
    }

    _sort(list, filters.sort, popularity);
    return list;
  }

  static void _sort(
    List<SceneRecord> list,
    SearchSort sort,
    Map<String, int>? popularity,
  ) {
    switch (sort) {
      case SearchSort.comprehensive:
        break; // 保持原顺序
      case SearchSort.hot:
        list.sort((a, b) =>
            (popularity?[b.id] ?? 0).compareTo(popularity?[a.id] ?? 0));
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }
}
```

- [ ] **Step 5: 创建 academy_search_service.dart**

创建 `lumira_app_flutter/lib/features/academy/search/academy_search_service.dart`：

```dart
import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/academy_models.dart';

/// 美学院课程/知识卡片检索/筛选/排序纯函数。
class AcademySearchService {
  AcademySearchService._();

  /// 课程多字段命中：title / topic.label / level.label / tags / meta。
  static bool courseMatchesKeyword(AcademyCourse c, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      c.title,
      c.topic.label,
      c.level.label,
      ...c.tags,
      c.meta,
    ];
    return candidates.any((x) => containsIgnoreCase(x, q));
  }

  /// 知识卡片多字段命中：title / subtitle / topic.label / body / keyPoints。
  static bool cardMatchesKeyword(KnowledgeCard k, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      k.title,
      k.subtitle,
      k.topic.label,
      k.body,
      ...k.keyPoints,
    ];
    return candidates.any((x) => containsIgnoreCase(x, q));
  }

  static List<AcademyCourse> searchCourses({
    required List<AcademyCourse> all,
    required String keyword,
    required SearchFilters filters,
  }) {
    var list =
        all.where((c) => courseMatchesKeyword(c, keyword)).toList();

    final topic = filters.academyTopic;
    if (topic != null && topic.isNotEmpty) {
      final t = AcademyTopic.values.byName(topic);
      list = list.where((c) => c.topic == t).toList();
    }
    final level = filters.academyLevel;
    if (level != null && level.isNotEmpty) {
      final l = AcademyLevel.values.byName(level);
      list = list.where((c) => c.level == l).toList();
    }

    switch (filters.sort) {
      case SearchSort.comprehensive:
        break; // 保持 lessonNumber 顺序
      case SearchSort.hot:
        list.sort((a, b) => b.rewardXP.compareTo(a.rewardXP));
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.lessonNumber.compareTo(a.lessonNumber));
        break;
    }
    return list;
  }

  static List<KnowledgeCard> searchCards({
    required List<KnowledgeCard> all,
    required String keyword,
    required SearchFilters filters,
  }) {
    var list =
        all.where((k) => cardMatchesKeyword(k, keyword)).toList();

    final topic = filters.academyTopic;
    if (topic != null && topic.isNotEmpty) {
      final t = AcademyTopic.values.byName(topic);
      list = list.where((k) => k.topic == t).toList();
    }
    return list;
  }
}
```

- [ ] **Step 6: 运行测试确认通过**

Run:
```powershell
flutter test test/features/templates/search/template_search_service_test.dart
flutter test test/features/scenes/search/scene_search_service_test.dart
flutter test test/features/academy/search/academy_search_service_test.dart
```
Expected: PASS（三个文件全部通过）。

- [ ] **Step 7: 提交**

```powershell
git add lumira_app_flutter/lib/features/templates/search lumira_app_flutter/lib/features/scenes/search lumira_app_flutter/lib/features/academy/search lumira_app_flutter/test/features/templates/search lumira_app_flutter/test/features/scenes/search lumira_app_flutter/test/features/academy/search
git commit -m "feat(search): 新增模板/场景/美学院三类内容搜索服务"
```

---

### Task 5: 通用筛选弹层 filter_sheet

**Files:**
- Create: `lumira_app_flutter/lib/shared/searchengine/filter_sheet.dart`
- Test: 不单独建测试文件（归入 Task 6 的页面测试覆盖弹层入口）；本 Task 以 `flutter analyze` 通过为验收

**Interfaces:**
- Consumes: `SearchScope`、`SearchFilters`、`SearchSort`、`SearchPriceFilter`、`TagWithCount`（`core/db/dao/tags_dao.dart`）、`appThemeProvider`、`uiStyleProvider`
- Produces: `class CategoryOption { final String key; final String label; const CategoryOption(this.key, this.label); }`
- Produces: `Future<SearchFilters?> showSearchFilterSheet({required BuildContext context, required SearchScope scope, required SearchFilters current, required List<TagWithCount> userTags, required List<CategoryOption> categoryOptions, required List<String> sceneStyleOptions, required List<String> sceneCategoryOptions, required List<String> academyTopicOptions, required List<String> academyLevelOptions})`

- [ ] **Step 1: 创建 filter_sheet.dart**

创建 `lumira_app_flutter/lib/shared/searchengine/filter_sheet.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import 'search_filters.dart';
import 'search_scope.dart';

/// 分类下拉选项（key→中文标签）。
class CategoryOption {
  final String key;
  final String label;
  const CategoryOption(this.key, this.label);
}

/// 弹出全量筛选弹层，返回用户确认后的新筛选状态；取消（点遮罩/返回）返回 null。
Future<SearchFilters?> showSearchFilterSheet({
  required BuildContext context,
  required SearchScope scope,
  required SearchFilters current,
  required List<TagWithCount> userTags,
  required List<CategoryOption> categoryOptions,
  required List<String> sceneStyleOptions,
  required List<String> sceneCategoryOptions,
  required List<String> academyTopicOptions,
  required List<String> academyLevelOptions,
}) async {
  final result = await showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(
      scope: scope,
      initial: current,
      userTags: userTags,
      categoryOptions: categoryOptions,
      sceneStyleOptions: sceneStyleOptions,
      sceneCategoryOptions: sceneCategoryOptions,
      academyTopicOptions: academyTopicOptions,
      academyLevelOptions: academyLevelOptions,
    ),
  );
  return result;
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.scope,
    required this.initial,
    required this.userTags,
    required this.categoryOptions,
    required this.sceneStyleOptions,
    required this.sceneCategoryOptions,
    required this.academyTopicOptions,
    required this.academyLevelOptions,
  });

  final SearchScope scope;
  final SearchFilters initial;
  final List<TagWithCount> userTags;
  final List<CategoryOption> categoryOptions;
  final List<String> sceneStyleOptions;
  final List<String> sceneCategoryOptions;
  final List<String> academyTopicOptions;
  final List<String> academyLevelOptions;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late SearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final scope = widget.scope;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(tokens),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sortSection(tokens),
                    if (scope == SearchScope.template) ...[
                      _categorySection(tokens),
                      _priceSection(tokens),
                      _sourceSection(tokens),
                    ],
                    if (scope == SearchScope.scene) ...[
                      _sceneCategorySection(tokens),
                      _styleSection(tokens),
                    ],
                    if (scope == SearchScope.academy) ...[
                      _topicSection(tokens),
                      _levelSection(tokens),
                    ],
                    if (scope != SearchScope.academy && widget.userTags.isNotEmpty)
                      _userTagSection(tokens),
                  ],
                ),
              ),
            ),
            _footer(tokens),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() => _draft = _draft.reset()),
            child: Text('重置', style: TextStyle(color: tokens.textSecondary)),
          ),
          const Spacer(),
          Text('筛选', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: Text('确定', style: TextStyle(color: tokens.brand, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sortSection(ThemeTokens tokens) {
    return _Section(
      title: '排序',
      children: [
        for (final s in SearchSort.values)
          _Pill(
            label: _sortLabel(s),
            active: _draft.sort == s,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(sort: s)),
          ),
      ],
    );
  }

  Widget _categorySection(ThemeTokens tokens) {
    return _Section(
      title: '分类',
      children: [
        _Pill(
          label: '全部',
          active: _draft.category == null,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(category: () => null)),
        ),
        for (final o in widget.categoryOptions)
          _Pill(
            label: o.label,
            active: _draft.category == o.key,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(category: () => o.key)),
          ),
      ],
    );
  }

  Widget _sceneCategorySection(ThemeTokens tokens) {
    return _Section(
      title: '分类',
      children: [
        _Pill(
          label: '全部',
          active: _draft.category == null,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(category: () => null)),
        ),
        for (final c in widget.sceneCategoryOptions)
          _Pill(
            label: c,
            active: _draft.category == c,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(category: () => c)),
          ),
      ],
    );
  }

  Widget _styleSection(ThemeTokens tokens) {
    return _Section(
      title: '风格',
      children: [
        _Pill(
          label: '全部',
          active: _draft.sceneStyle == null,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(sceneStyle: () => null)),
        ),
        for (final s in widget.sceneStyleOptions)
          _Pill(
            label: s,
            active: _draft.sceneStyle == s,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(sceneStyle: () => s)),
          ),
      ],
    );
  }

  Widget _topicSection(ThemeTokens tokens) {
    return _Section(
      title: '主题',
      children: [
        _Pill(
          label: '全部',
          active: _draft.academyTopic == null,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(academyTopic: () => null)),
        ),
        for (final t in widget.academyTopicOptions)
          _Pill(
            label: t,
            active: _draft.academyTopic == t,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(academyTopic: () => t)),
          ),
      ],
    );
  }

  Widget _levelSection(ThemeTokens tokens) {
    return _Section(
      title: '等级',
      children: [
        _Pill(
          label: '全部',
          active: _draft.academyLevel == null,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(academyLevel: () => null)),
        ),
        for (final l in widget.academyLevelOptions)
          _Pill(
            label: l,
            active: _draft.academyLevel == l,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(academyLevel: () => l)),
          ),
      ],
    );
  }

  Widget _priceSection(ThemeTokens tokens) {
    return _Section(
      title: '价格',
      children: [
        for (final p in SearchPriceFilter.values)
          _Pill(
            label: _priceLabel(p),
            active: _draft.price == p,
            tokens: tokens,
            onTap: () => setState(() => _draft = _draft.copyWith(price: p)),
          ),
      ],
    );
  }

  Widget _sourceSection(ThemeTokens tokens) {
    return _Section(
      title: '来源',
      children: [
        _Pill(
          label: '全部',
          active: !_draft.ownedOnly,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: false)),
        ),
        _Pill(
          label: '我拥有的',
          active: _draft.ownedOnly,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: true)),
        ),
      ],
    );
  }

  Widget _userTagSection(ThemeTokens tokens) {
    return _Section(
      title: '用户标签',
      children: [
        for (final e in widget.userTags)
          _Pill(
            label: '${e.tag.name} (${e.count})',
            active: _draft.userTagIds.contains(e.tag.id),
            tokens: tokens,
            onTap: () {
              setState(() {
                final ids = {..._draft.userTagIds};
                if (!ids.add(e.tag.id)) ids.remove(e.tag.id);
                _draft = _draft.copyWith(userTagIds: ids);
              });
            },
          ),
      ],
    );
  }

  Widget _footer(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _draft = _draft.reset()),
              child: const Text('重置'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(SearchSort s) {
    switch (s) {
      case SearchSort.comprehensive:
        return '综合';
      case SearchSort.hot:
        return '热度';
      case SearchSort.latest:
        return '最新';
    }
  }

  static String _priceLabel(SearchPriceFilter p) {
    switch (p) {
      case SearchPriceFilter.all:
        return '全部';
      case SearchPriceFilter.free:
        return '免费';
      case SearchPriceFilter.paid:
        return '付费';
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tokens.brand : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          border: active
              ? null
              : Border.all(color: tokens.divider, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? tokens.textInverse : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
```

> 说明：`_Section` 标题用了 `Colors.grey` —— 违反主题铁律，改为由调用方传 `tokens.textSecondary`。请在 `_FilterSheet.build` 内把 `_Section` 改为传入颜色。具体见 Step 2 修正。

- [ ] **Step 2: 修正主题合规问题**

`_Section` 是独立 StatelessWidget，无法直接拿 tokens。改为在 `_FilterSheetState` 内联区块标题，删除 `_Section` 类，把每处 `_Section(title: ..., children: [...])` 替换为：

```dart
Widget _section(ThemeTokens tokens, String title, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    ),
  );
}
```

并把 `_sortSection/_categorySection/...` 中的 `_Section(...)` 全部改为 `_section(tokens, '排序', [...])` 形式，同时删除 `_Section` 类定义。`_Pill` 保留（其 tokens 由外部传入）。

- [ ] **Step 3: flutter analyze 通过**

Run: `flutter analyze lib/shared/searchengine/filter_sheet.dart`
Expected: No issues found。

- [ ] **Step 4: 提交**

```powershell
git add lumira_app_flutter/lib/shared/searchengine/filter_sheet.dart
git commit -m "feat(search): 新增通用全量筛选弹层 filter_sheet"
```

---

### Task 6: 统一搜索页 GlobalSearchPage（初始页 + 结果页 + 分页 + scope 切换 + 筛选）

**Files:**
- Create: `lumira_app_flutter/lib/features/search/data/search_result.dart`
- Create: `lumira_app_flutter/lib/features/search/widgets/search_result_card.dart`
- Create: `lumira_app_flutter/lib/features/search/widgets/search_initial_sections.dart`
- Create: `lumira_app_flutter/lib/features/search/pages/global_search_page.dart`
- Test: `lumira_app_flutter/test/features/search/pages/global_search_page_test.dart`

**Interfaces:**
- Consumes: Task 1-5 的全部产物（`SearchHistoryDao` 无需直接用，用 `searchStoreProvider`；`SearchScope`、`SearchStore`、`SearchFilters`、`SearchSort`、`PagedResultsController`、`showSearchFilterSheet`、`CategoryOption`）、三个 search service、DAO provider、`AcademyContent.courses/knowledgeCards`、`appThemeProvider/uiStyleProvider/themeTokensProvider`
- Produces: `class GlobalSearchPage extends ConsumerStatefulWidget { const GlobalSearchPage({super.key, required this.scope}); final SearchScope scope; }`
- Produces: `class SearchResult { final SearchScope scope; final TemplateRecord? template; final SceneRecord? scene; final AcademyCourse? course; final KnowledgeCard? knowledgeCard; String get title; String get subtitle; String? get imageUrl; String? get coverData; bool get isCourse; }`
- Produces: `searchResultCard(...)`（widget，含 scope=all 时的类型角标）

- [ ] **Step 1: 写失败测试（初始页渲染 + 输入关键词后出现结果区）**

创建 `lumira_app_flutter/test/features/search/pages/global_search_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/search/pages/global_search_page.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_scope.dart';

/// GlobalSearchPage 最小验收：搜索框、scope 切换栏、空态渲染。
/// 通过 override databaseProvider 注入空内存 DB（仅建搜索页依赖表）。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, SearchScope scope) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    await container.read(templatesDaoProvider.future);
    await container.read(scenesDaoProvider.future);
    await container.read(userTagsDaoProvider.future);
    await container.read(searchHistoryDaoProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GlobalSearchPage(scope: scope),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染搜索框与 scope 切换栏', (tester) async {
    await pumpPage(tester, SearchScope.all);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('美学院'), findsOneWidget);
  });

  testWidgets('输入关键词后进入结果态（空数据 → 空结果引导）', (tester) async {
    await pumpPage(tester, SearchScope.all);
    await tester.enterText(find.byType(TextField), '人像');
    await tester.pumpAndSettle();
    expect(find.text('换个关键词试试'), findsOneWidget);
  });
}

/// 与 v29 迁移一致的表结构：仅建搜索页依赖的表。
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(SearchHistoryTable.createSql);
  await db.execute(SearchHistoryTable.indexSql);
  await db.execute('''
    CREATE TABLE ${Tables.templateCategories} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colKey} TEXT NOT NULL,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colParentKey} TEXT,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colUpdatedAt} INTEGER NOT NULL,
      UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.userTags} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colName} TEXT NOT NULL UNIQUE,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.itemTags} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
    )
  ''');
  await db.execute('CREATE INDEX idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
  await db.execute('CREATE INDEX idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/features/search/pages/global_search_page_test.dart`
Expected: FAIL（找不到 `GlobalSearchPage` / `searchHistoryDaoProvider` 等）。

- [ ] **Step 3: 创建 search_result.dart（统一结果模型）**

创建 `lumira_app_flutter/lib/features/search/data/search_result.dart`：

```dart
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../academy/data/academy_models.dart';

/// 跨三类内容的统一搜索结果模型。
/// 每次只持有一种内容（template / scene / course / knowledgeCard 之一非空）。
class SearchResult {
  final SearchScope scope; // template | scene | academy
  final TemplateRecord? template;
  final SceneRecord? scene;
  final AcademyCourse? course;
  final KnowledgeCard? knowledgeCard;

  const SearchResult({
    required this.scope,
    this.template,
    this.scene,
    this.course,
    this.knowledgeCard,
  });

  String get id {
    final t = template?.id;
    if (t != null) return t;
    final s = scene?.id;
    if (s != null) return s;
    final c = course?.id;
    if (c != null) return c;
    return knowledgeCard?.id ?? '';
  }

  String get title =>
      template?.name ?? scene?.name ?? course?.title ?? knowledgeCard?.title ?? '';

  String get subtitle {
    if (template != null) {
      return _categoryLabel(template!.category);
    }
    if (scene != null) return scene!.vibe;
    if (course != null) {
      return '${course!.topic.label} · ${course!.level.label}';
    }
    if (knowledgeCard != null) return knowledgeCard!.subtitle;
    return '';
  }

  /// 网络/资源图片 URL（模板封面/场景示例图/课程封面）。
  String? get imageUrl {
    final t = template;
    if (t != null) return t.cover.isEmpty ? null : t.cover;
    final s = scene;
    if (s != null) {
      return s.exampleImages.isNotEmpty ? s.exampleImages.first : null;
    }
    final c = course;
    if (c != null) return c.coverImage;
    return null;
  }

  /// 模板 base64 封面数据。
  String? get coverData => template?.coverData;

  /// 美学院结果是否为课程（false=知识卡片）。
  bool get isCourse => course != null;

  static String _categoryLabel(String key) =>
      // 复用项目既有分类中文标签表（模板分类）。
      // 若 key 无映射则回退英文 key。
      const {
        'portrait': '人像',
        'landscape': '风光',
        'food': '美食',
        'street': '街拍',
        'night': '夜景',
        'macro': '微距',
        'still-life': '静物',
      }[key] ??
      key;
}
```

- [ ] **Step 4: 创建 search_result_card.dart**

创建 `lumira_app_flutter/lib/features/search/widgets/search_result_card.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../templates/widgets/template_cover_image.dart';
import '../data/search_result.dart';

/// 搜索结果卡片。showTypeBadge=true（scope=all）时左上角叠加类型角标。
class SearchResultCard extends ConsumerWidget {
  const SearchResultCard({
    super.key,
    required this.result,
    required this.showTypeBadge,
    required this.onTap,
  });

  final SearchResult result;
  final bool showTypeBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.divider, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image(tokens),
                  if (showTypeBadge) Positioned(top: 8, left: 8, child: _badge(tokens)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
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
                    result.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(ThemeTokens tokens) {
    final url = result.imageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(tokens),
      );
    }
    final data = result.coverData;
    if (data != null && data.isNotEmpty) {
      return Image.memory(
        Uri.dataFromString(data).data,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(tokens),
      );
    }
    return _placeholder(tokens);
  }

  Widget _placeholder(ThemeTokens tokens) => Container(
        color: tokens.surfaceAlt,
        child: Icon(
          result.scope == SearchScope.scene ? Icons.image_outlined : Icons.photo_outlined,
          color: tokens.textTertiary,
          size: 28,
        ),
      );

  Widget _badge(ThemeTokens tokens) {
    final label = result.scope.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: tokens.textPrimary),
      ),
    );
  }
}
```

> 注：`TemplateCoverImage` 是模板专用封面组件（支持 base64+网络+fallback）。上面 `_image` 直接处理 url/data；如需复用 `TemplateCoverImage`（其构造含 cover/coverData/fallback/errorFallback），可改用它并传入 result 的字段。二选一即可，推荐直接使用 `TemplateCoverImage` 以复用既有能力：替换 `_image` 内分支为
> ```dart
> Widget _image(ThemeTokens tokens) {
>   final url = result.imageUrl;
>   final data = result.coverData;
>   if (url == null && data == null) return _placeholder(tokens);
>   return TemplateCoverImage(
>     cover: url,
>     coverData: data,
>     fit: BoxFit.cover,
>     fallback: _placeholder(tokens),
>     errorFallback: _placeholder(tokens),
>   );
> }
> ```
> 并删除 `_image` 中的 Image.network/Image.memory 分支（模板封面优先走 TemplateCoverImage）。

- [ ] **Step 5: 创建 search_initial_sections.dart（历史/热搜/推荐区块）**

创建 `lumira_app_flutter/lib/features/search/widgets/search_initial_sections.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../../templates/data/templates_browse_mock_data.dart';

/// 历史搜索区块：词条 pill + 右上「清空」。
class SearchHistorySection extends ConsumerWidget {
  const SearchHistorySection({
    super.key,
    required this.keywords,
    required this.onTap,
    required this.onDelete,
    required this.onClear,
  });

  final List<String> keywords;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('历史搜索',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.delete_outline, size: 16, color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keywords)
                _KeywordPill(
                  label: k,
                  tokens: tokens,
                  onTap: () => onTap(k),
                  onDelete: () => onDelete(k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 热门搜索区块：序号 + 词条。
class SearchHotSection extends ConsumerWidget {
  const SearchHotSection({super.key, required this.keywords, required this.onTap});

  final List<String> keywords;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('热门搜索',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (var i = 0; i < keywords.length; i++)
                GestureDetector(
                  onTap: () => onTap(keywords[i]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: i < 3 ? tokens.brand : tokens.textTertiary)),
                      const SizedBox(width: 8),
                      Text(keywords[i],
                          style:
                              TextStyle(fontSize: 13, color: tokens.textPrimary)),
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

/// 为你推荐区块：模板分类卡（横向滚动）。
class SearchRecommendTemplateSection extends ConsumerWidget {
  const SearchRecommendTemplateSection({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<MapEntry<String, String>> items; // key -> 中文标签
  final ValueChanged<String> onTap; // 传中文标签（填充关键词）

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 模板',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final e = items[i];
                return GestureDetector(
                  onTap: () => onTap(e.value),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 场景（风格词条）。
class SearchRecommendSceneSection extends ConsumerWidget {
  const SearchRecommendSceneSection({
    super.key,
    required this.styles,
    required this.onTap,
  });

  final List<String> styles;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (styles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 场景',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in styles)
                GestureDetector(
                  onTap: () => onTap(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(s,
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 美学院（主题/等级词条）。
class SearchRecommendAcademySection extends ConsumerWidget {
  const SearchRecommendAcademySection({
    super.key,
    required this.topics,
    required this.levels,
    required this.onTap,
  });

  final List<String> topics; // 中文主题
  final List<String> levels; // 中文等级
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 美学院',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in topics)
                GestureDetector(
                  onTap: () => onTap(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(t,
                        style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
                  ),
                ),
              for (final l in levels)
                GestureDetector(
                  onTap: () => onTap(l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(l,
                        style: TextStyle(fontSize: 12, color: tokens.brand)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeywordPill extends StatelessWidget {
  const _KeywordPill({
    required this.label,
    required this.tokens,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(onTap: onTap, child: Text(label,
              style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 供 Task 6 页面使用的分类中文标签兜底（与 SearchResult._categoryLabel 同源）。
String categoryLabelFallback(String key) =>
    TemplatesBrowseMockData.categoryLabel(key);
```

- [ ] **Step 6: 创建 global_search_page.dart（核心）**

创建 `lumira_app_flutter/lib/features/search/pages/global_search_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/filter_sheet.dart';
import '../../../shared/searchengine/paged_results_controller.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/searchengine/search_store.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../academy/data/academy_content.dart';
import '../../academy/data/academy_models.dart';
import '../../academy/search/academy_search_service.dart';
import '../../scenes/search/scene_search_service.dart';
import '../../templates/search/template_search_service.dart';
import '../data/search_result.dart';
import '../widgets/search_initial_sections.dart';
import '../widgets/search_result_card.dart';

/// 统一全局搜索页。
/// [scope] 决定初始范围；页面内 scope 切换栏可随时切换。
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key, required this.scope});

  final SearchScope scope;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final PagedResultsController _pager = PagedResultsController(pageSize: 20);

  late SearchScope _scope;
  String _keyword = '';
  SearchFilters _filters = SearchFilters();

  bool _loaded = false;

  List<TemplateRecord> _allTemplates = const [];
  List<SceneRecord> _allScenes = const [];
  List<TagWithCount> _allTags = const [];
  Map<String, int> _scenePopularity = const {};
  Map<String, String> _categoryLabelByKey = const {};
  List<TemplateCategoryRecord> _level1Categories = const [];

  List<SearchResult> _results = const [];
  SearchStore? _store;

  @override
  void initState() {
    super.initState();
    _scope = widget.scope;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tDao = await ref.read(templatesDaoProvider.future);
    final sDao = await ref.read(scenesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final store = await ref.read(searchStoreProvider.future);

    final builtin = await tDao.getBuiltinAndRemote();
    final customs = await tDao.getCustomOnly();
    final categories = await tDao.getCategories(activeOnly: true);
    final scenes = await sDao.getAll();
    final tTags = await tagDao.allTags(itemType: TagItemType.template);
    final sTags = await tagDao.allTags(itemType: TagItemType.scene);
    // 合并两类标签（按 tag.id 去重）
    final seenIds = <int>{};
    final mergedTags = <TagWithCount>[
      for (final e in [...tTags, ...sTags])
        if (seenIds.add(e.tag.id)) e,
    ];

    Map<String, int> scenePop = const {};
    try {
      final usageDao = await ref.read(usageDaoProvider.future);
      final counts =
          await usageDao.countMap('scene', scenes.map((s) => s.id).toList());
      scenePop = <String, int>{
        for (final s in scenes)
          if (counts[s.id] != null)
            s.id: counts[s.id]!.useShoot * 55 +
                counts[s.id]!.openDetail * 25 +
                counts[s.id]!.sceneSelect * 20,
      };
    } catch (_) {
      scenePop = const {};
    }

    if (!mounted) return;
    setState(() {
      _allTemplates = [...builtin, ...customs];
      _allScenes = scenes;
      _allTags = mergedTags;
      _scenePopularity = scenePop;
      _categoryLabelByKey = {for (final c in categories) c.key: c.name};
      _level1Categories =
          categories.where((c) => c.level == 1).toList();
      _store = store;
      _loaded = true;
    });
  }

  // === 关键词与搜索 ===

  void _onKeywordChanged(String v) {
    setState(() => _keyword = v);
    if (v.trim().isEmpty) {
      _pager.reset();
      setState(() => _results = const []);
    } else {
      _recompute();
    }
  }

  Future<void> _submitSearch(String keyword) async {
    final store = _store;
    if (store != null) {
      await store.record(_scope, keyword);
    }
    if (mounted) {
      setState(() {
        _keyword = keyword;
        _controller.text = keyword;
      });
      _recompute();
    }
  }

  void _recompute() {
    _pager.reset();
    _results = _buildResults();
    setState(() {});
  }

  List<SearchResult> _buildResults() {
    final results = <SearchResult>[];
    if (_scope == SearchScope.all) {
      results.addAll(_buildTemplateResults());
      results.addAll(_buildSceneResults());
      results.addAll(_buildAcademyResults());
      // all 混合排序：hot 按热度，其余保持类型分组顺序
      if (_filters.sort == SearchSort.hot) {
        results.sort((a, b) => _hotScore(b).compareTo(_hotScore(a)));
      }
    } else if (_scope == SearchScope.template) {
      results.addAll(_buildTemplateResults());
    } else if (_scope == SearchScope.scene) {
      results.addAll(_buildSceneResults());
    } else {
      results.addAll(_buildAcademyResults());
    }
    return results;
  }

  List<SearchResult> _buildTemplateResults() {
    final allowed = _allowedTemplateIds();
    final list = TemplateSearchService.search(
      all: _allTemplates,
      keyword: _keyword,
      filters: _filters,
      categoryLabelByKey: _categoryLabelByKey,
      allowedIds: allowed,
    );
    return list
        .map((t) => SearchResult(scope: SearchScope.template, template: t))
        .toList();
  }

  List<SearchResult> _buildSceneResults() {
    final allowed = _allowedSceneIds();
    final list = SceneSearchService.search(
      all: _allScenes,
      keyword: _keyword,
      filters: _filters,
      allowedIds: allowed,
      popularity: _scenePopularity,
    );
    return list
        .map((s) => SearchResult(scope: SearchScope.scene, scene: s))
        .toList();
  }

  List<SearchResult> _buildAcademyResults() {
    final courses = AcademySearchService.searchCourses(
      all: AcademyContent.courses,
      keyword: _keyword,
      filters: _filters,
    );
    final cards = AcademySearchService.searchCards(
      all: AcademyContent.knowledgeCards,
      keyword: _keyword,
      filters: _filters,
    );
    final result = <SearchResult>[
      for (final c in courses)
        SearchResult(scope: SearchScope.academy, course: c),
      for (final k in cards)
        SearchResult(scope: SearchScope.academy, knowledgeCard: k),
    ];
    if (_filters.sort == SearchSort.latest) {
      // latest：课程在前，知识卡片在后（卡片保持原顺序）
      result.sort((a, b) {
        if (a.isCourse != b.isCourse) return a.isCourse ? -1 : 1;
        return 0;
      });
    }
    return result;
  }

  // === 用户标签 AND 交集（按 scope 定向查 item_type） ===

  Set<String>? _allowedTemplateIds() {
    if (_filters.userTagIds.isEmpty) return null;
    return _intersect(TagItemType.template);
  }

  Set<String>? _allowedSceneIds() {
    if (_filters.userTagIds.isEmpty) return null;
    return _intersect(TagItemType.scene);
  }

  Future<Set<String>> _intersect(TagItemType type) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    var keep = <String>{};
    var first = true;
    for (final tagId in _filters.userTagIds) {
      final ids =
          (await dao.itemIdsByTag(itemType: type, tagId: tagId)).toSet();
      keep = first ? ids : keep.intersection(ids);
      first = false;
    }
    return keep;
  }

  int _hotScore(SearchResult r) {
    if (r.scope == SearchScope.scene) {
      return _scenePopularity[r.id] ?? 0;
    }
    if (r.template != null) {
      return r.template!.isRecommended ? 100 : 0;
    }
    if (r.course != null) return r.course!.rewardXP;
    return 0;
  }

  // === UI ===

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final isSearching = _keyword.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(tokens),
            _buildKeywordField(tokens),
            _buildScopeBar(tokens),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: isSearching ? _buildResultView(tokens) : _buildInitialView(tokens),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(ThemeTokens tokens) {
    return LumiraNav(
      title: '搜索',
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onKeywordChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => _submitSearch(v),
        decoration: InputDecoration(
          hintText: '搜索模板 / 场景 / 美学院',
          prefixIcon: Icon(Icons.search, size: 18, color: tokens.textSecondary),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 16, color: tokens.textSecondary),
                  onPressed: () {
                    _controller.clear();
                    _onKeywordChanged('');
                  },
                ),
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

  Widget _buildScopeBar(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          for (final s in SearchScope.values)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () => _switchScope(s),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _scope == s ? FontWeight.w700 : FontWeight.w500,
                    color: _scope == s ? tokens.brand : tokens.textSecondary,
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (_keyword.trim().isNotEmpty)
            GestureDetector(
              onTap: _openFilter,
              child: Text('筛选 ▾',
                  style:
                      TextStyle(fontSize: 13, color: tokens.textPrimary)),
            ),
        ],
      ),
    );
  }

  void _switchScope(SearchScope s) {
    if (s == _scope) return;
    setState(() => _scope = s);
    _pager.reset();
    if (_keyword.trim().isNotEmpty) {
      _recompute();
    }
  }

  // === 初始页 ===

  Widget _buildInitialView(ThemeTokens tokens) {
    return FutureBuilder<List<SearchInitialData>>(
      future: _initialData(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = data.first;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchHistorySection(
                keywords: d.history,
                onTap: (k) => _submitSearch(k),
                onDelete: (k) => _deleteHistory(k),
                onClear: () => _clearHistory(),
              ),
              SearchHotSection(keywords: d.hot, onTap: (k) => _submitSearch(k)),
              if (_scope == SearchScope.all) ...[
                SearchRecommendTemplateSection(
                  items: d.templateCategories,
                  onTap: (k) => _submitSearch(k),
                ),
                SearchRecommendSceneSection(
                  styles: d.sceneStyles,
                  onTap: (k) => _submitSearch(k),
                ),
                SearchRecommendAcademySection(
                  topics: d.academyTopics,
                  levels: d.academyLevels,
                  onTap: (k) => _submitSearch(k),
                ),
              ] else if (_scope == SearchScope.template)
                SearchRecommendTemplateSection(
                  items: d.templateCategories,
                  onTap: (k) => _submitSearch(k),
                )
              else if (_scope == SearchScope.scene)
                SearchRecommendSceneSection(
                  styles: d.sceneStyles,
                  onTap: (k) => _submitSearch(k),
                )
              else
                SearchRecommendAcademySection(
                  topics: d.academyTopics,
                  levels: d.academyLevels,
                  onTap: (k) => _submitSearch(k),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<SearchInitialData>> _initialData() async {
    final store = _store;
    final history = store == null
        ? const <String>[]
        : await store.recentKeywords(_scope);
    final hot = store == null
        ? const <String>[]
        : await store.hotKeywords(_scope);
    final templateCategories = _level1Categories
        .map((c) => MapEntry(c.key, c.name))
        .toList();
    final sceneStyles = <String>[
      for (final s in _allScenes)
        if (s.style.isNotEmpty && !sceneStyles.contains(s.style)) s.style,
    ].take(6).toList();
    final academyTopics = <String>[
      for (final t in AcademyTopic.values) t.label,
    ];
    final academyLevels = <String>[
      for (final l in AcademyLevel.values) l.label,
    ];
    return [
      SearchInitialData(
        history: history,
        hot: hot,
        templateCategories: templateCategories,
        sceneStyles: sceneStyles,
        academyTopics: academyTopics,
        academyLevels: academyLevels,
      ),
    ];
  }

  Future<void> _deleteHistory(String keyword) async {
    await _store?.deleteKeyword(_scope, keyword);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    await _store?.clear(_scope);
    if (mounted) setState(() {});
  }

  // === 结果页 ===

  Widget _buildResultView(ThemeTokens tokens) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
            n.metrics.axis == Axis.vertical) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          if (_results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmpty(tokens),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.56,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = _results[index];
                    return SearchResultCard(
                      result: r,
                      showTypeBadge: _scope == SearchScope.all,
                      onTap: () => _openResult(r),
                    );
                  },
                  childCount: _pager.visible.clamp(0, _results.length),
                ),
              ),
            ),
          SliverToBoxAdapter(child: _buildFooter(tokens)),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeTokens tokens) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off, size: 48, color: tokens.textTertiary),
        const SizedBox(height: 12),
        Text('换个关键词试试',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary)),
      ],
    );
  }

  Widget _buildFooter(ThemeTokens tokens) {
    if (_results.isEmpty) return const SizedBox.shrink();
    if (_pager.hasMore(_results.length)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('加载中…',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text('已经到底了',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
      ),
    );
  }

  void _loadMore() {
    final total = _results.length;
    if (_pager.loadMore(total)) {
      setState(() {});
      // 延迟一帧结束 loading，避免同一帧内连续触发
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pager.finishLoading();
      });
    }
  }

  Future<void> _openFilter() async {
    final categoryOptions = _level1Categories
        .map((c) => CategoryOption(c.key, c.name))
        .toList();
    final sceneStyles = <String>[
      for (final s in _allScenes)
        if (s.style.isNotEmpty && !sceneStyles.contains(s.style)) s.style,
    ];
    final sceneCategories = <String>[
      for (final s in _allScenes)
        if (s.category.isNotEmpty && !sceneCategories.contains(s.category))
          s.category,
    ];
    final result = await showSearchFilterSheet(
      context: context,
      scope: _scope,
      current: _filters,
      userTags: _allTags,
      categoryOptions: categoryOptions,
      sceneStyleOptions: sceneStyles,
      sceneCategoryOptions: sceneCategories,
      academyTopicOptions: [for (final t in AcademyTopic.values) t.label],
      academyLevelOptions: [for (final l in AcademyLevel.values) l.label],
    );
    if (result != null) {
      setState(() => _filters = result);
      _recompute();
    }
  }

  void _openResult(SearchResult r) {
    if (r.template != null) {
      GoRouter.of(context).push(
        RouteNames.withTemplateId(RouteNames.templatesDetail, r.template!.id),
      );
    } else if (r.scene != null) {
      GoRouter.of(context).push(
        RouteNames.withSceneId(RouteNames.captureSceneDetail, r.scene!.id),
      );
    } else if (r.isCourse) {
      GoRouter.of(context).push(RouteNames.build(RouteNames.profileAcademyDetail,
          {RouteNames.paramAcademyId: r.course!.id}));
    } else {
      GoRouter.of(context).push(RouteNames.build(RouteNames.profileAcademyKnowledge,
          {RouteNames.paramAcademyId: r.knowledgeCard!.id}));
    }
  }
}

/// 初始页数据快照。
class SearchInitialData {
  final List<String> history;
  final List<String> hot;
  final List<MapEntry<String, String>> templateCategories;
  final List<String> sceneStyles;
  final List<String> academyTopics;
  final List<String> academyLevels;

  const SearchInitialData({
    required this.history,
    required this.hot,
    required this.templateCategories,
    required this.sceneStyles,
    required this.academyTopics,
    required this.academyLevels,
  });
}
```

> 实现说明（必须核对）：
> 1. `_intersect` 是 `Future<Set<String>>`，而 `_allowedTemplateIds/_allowedSceneIds` 当前返回同步 `Set<String>?` —— 需要改为 `Future<Set<String>?>?` 或把 `_buildResults` 改为异步。**修正方案**：把 `_buildResults/_buildTemplateResults/_buildSceneResults` 改为 `Future<List<SearchResult>>`，`_recompute` 改为 async 并在 `_intersect` 完成后 `setState`。请按此改造：`_recompute` 为 `Future<void> _recompute() async { _pager.reset(); final r = await _buildResults(); if (!mounted) return; setState(() => _results = r); }`；`_buildResults` 为 `Future<List<SearchResult>> _buildResults() async { final results = <SearchResult>[]; if (_scope == SearchScope.all) { results.addAll(await _buildTemplateResults()); results.addAll(await _buildSceneResults()); results.addAll(_buildAcademyResults()); ... } ... }`；`_buildTemplateResults`/`_buildSceneResults` 为 async 并 `await _allowedTemplateIds()`。`_onKeywordChanged` 里调用 `_recompute()`（不 await 亦可，但建议 `unawaited` 风格——直接调用即可，内部自守卫 mounted）。`_switchScope` 同理。
> 2. `_buildResultView` 里 `_pager.visible` 为 0 时（首屏未触底）grid 为空白 —— 需要首屏先 `loadMore`。**修正方案**：在 `_recompute` 完成 setState 后调用 `_loadMore()` 加载第一页：
>    ```dart
>    Future<void> _recompute() async {
>      _pager.reset();
>      final r = await _buildResults();
>      if (!mounted) return;
>      setState(() => _results = r);
>      _loadMore(); // 加载第一页
>    }
>    ```
> 3. `SearchResultCard` 的 `_image` 建议直接用 `TemplateCoverImage`（见 Task 6 Step 4 的注）。

- [ ] **Step 7: 运行测试确认通过**

Run: `flutter test test/features/search/pages/global_search_page_test.dart`
Expected: PASS（2 个测试：渲染 scope 栏 + 空关键词结果态）。

- [ ] **Step 8: 提交**

```powershell
git add lumira_app_flutter/lib/features/search lumira_app_flutter/test/features/search/pages/global_search_page_test.dart
git commit -m "feat(search): 新增统一全局搜索页 GlobalSearchPage"
```

---

### Task 7: 路由与入口接入（替换旧搜索路由，删除旧搜索页）

**Files:**
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_page.dart`
- Modify: `lumira_app_flutter/lib/features/scenes/pages/scenes_page.dart`
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart`
- Modify: `lumira_app_flutter/lib/features/academy/pages/academy_page.dart`
- Delete: `lumira_app_flutter/lib/features/templates/pages/templates_search_page.dart`
- Delete: `lumira_app_flutter/lib/features/scenes/pages/scenes_search_page.dart`
- Delete: `lumira_app_flutter/test/features/templates/pages/templates_search_page_test.dart`
- Delete: `lumira_app_flutter/test/features/scenes/pages/scenes_search_page_test.dart`

**Interfaces:**
- Consumes: `RouteNames.search`、`RouteNames.paramScope`、`GlobalSearchPage`、`SearchScope.fromName`
- Produces: `/search` 路由；四入口跳转；旧搜索路由/页面移除

- [ ] **Step 1: route_names.dart 增删常量**

`lumira_app_flutter/lib/core/router/route_names.dart`：

1. 删除第 28 行：`static const String templatesSearch = '/templates/search';`
2. 删除第 70 行：`static const String scenesSearch = '/scenes/search';`
3. 新增（放在 `scenes` 常量附近或 `templates` 区，建议放在 `scenes` 之后）：
```dart
  /// 统一全局搜索页（scope 查询参数决定默认范围）
  static const String search = '/search';
```
4. 查询参数区新增：
```dart
  static const String paramScope = 'scope';
```

- [ ] **Step 2: router.dart 替换两路由为一个 /search**

`lumira_app_flutter/lib/app/router.dart`：

1. 删除 import（第 65、76 行）：
```dart
import '../features/scenes/pages/scenes_search_page.dart';
import '../features/templates/pages/templates_search_page.dart';
```
2. 新增 import：
```dart
import '../features/search/pages/global_search_page.dart';
import '../shared/searchengine/search_scope.dart';
```
3. 把 `templatesSearch` GoRoute（第 244-248 行）替换为：
```dart
      GoRoute(
        path: RouteNames.search,
        name: 'search',
        builder: (context, state) => GlobalSearchPage(
          scope: SearchScope.fromName(state.queryParams[RouteNames.paramScope]),
        ),
      ),
```
4. 删除 `scenesSearch` GoRoute（第 642-646 行）。

- [ ] **Step 3: 发现 Tab 搜索图标 → scope=all**

`lumira_app_flutter/lib/features/templates/pages/templates_page.dart` 第 111 行：

把
```dart
onTap: () => GoRouter.of(context).push(RouteNames.templatesSearch),
```
改为
```dart
onTap: () => GoRouter.of(context).push(
  RouteNames.build(RouteNames.search, {RouteNames.paramScope: 'all'}),
),
```

- [ ] **Step 4: 场景库搜索图标 → scope=scene**

`lumira_app_flutter/lib/features/scenes/pages/scenes_page.dart` 第 125-127 行：

把
```dart
void _onSearch() {
  GoRouter.of(context).push(RouteNames.scenesSearch);
}
```
改为
```dart
void _onSearch() {
  GoRouter.of(context).push(
    RouteNames.build(RouteNames.search, {RouteNames.paramScope: 'scene'}),
  );
}
```

- [ ] **Step 5: 模板库一级分类页新增搜索按钮 → scope=template**

`lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart` 第 257-267 行的 LumiraNav：

给 `LumiraNav` 增加 `actions`（仅 `isOverview` 时显示，title=「模板库」即一级分类页）：
```dart
                LumiraNav(
                  title: isOverview ? '模板库' : '全部模板',
                  transparent: true,
                  leading: _BackButton(
                    tokens: tokens,
                    onTap: _back,
                  ),
                  actions: [
                    if (isOverview)
                      LumiraNavButton(
                        icon: Icons.search,
                        onPressed: () => GoRouter.of(context).push(
                          RouteNames.build(RouteNames.search,
                              {RouteNames.paramScope: 'template'}),
                        ),
                      ),
                  ],
                ),
```
确认文件顶部已 import `go_router`（是，`import 'package:go_router/go_router.dart';`）且 `LumiraNavButton` 可从 `shared/widgets/nav/lumira_nav.dart` 取用（是）。

- [ ] **Step 6: 摄影美学院新增搜索按钮 → scope=academy**

`lumira_app_flutter/lib/features/academy/pages/academy_page.dart` 第 57-69 行的 LumiraNav actions：

在 favorites 按钮前追加：
```dart
        actions: [
          GestureDetector(
            onTap: () => GoRouter.of(context).push(
              RouteNames.build(RouteNames.search,
                  {RouteNames.paramScope: 'academy'}),
            ),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child:
                  Icon(Icons.search, size: 22, color: tokens.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: () => GoRouter.of(context).push(RouteNames.academyFavorites),
            ...
          ),
        ],
```
确认文件已 import `go_router`（是）。

- [ ] **Step 7: 删除旧搜索页与旧测试**

删除文件：
- `lumira_app_flutter/lib/features/templates/pages/templates_search_page.dart`
- `lumira_app_flutter/lib/features/scenes/pages/scenes_search_page.dart`
- `lumira_app_flutter/test/features/templates/pages/templates_search_page_test.dart`
- `lumira_app_flutter/test/features/scenes/pages/scenes_search_page_test.dart`

- [ ] **Step 8: flutter analyze 全量通过**

Run: `flutter analyze`
Expected: No issues found（确认无残留引用 `templatesSearch` / `scenesSearch` / 旧页面类）。

- [ ] **Step 9: 运行既有相关测试确认不回归**

Run:
```powershell
flutter test test/features/templates/pages/templates_all_page_test.dart test/features/academy/academy_page_sort_test.dart test/features/scenes/scenes_page_test.dart
```
Expected: PASS。

- [ ] **Step 10: 提交**

```powershell
git add -A lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/templates/pages/templates_page.dart lumira_app_flutter/lib/features/scenes/pages/scenes_page.dart lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart lumira_app_flutter/lib/features/academy/pages/academy_page.dart
git rm lumira_app_flutter/lib/features/templates/pages/templates_search_page.dart lumira_app_flutter/lib/features/scenes/pages/scenes_search_page.dart lumira_app_flutter/test/features/templates/pages/templates_search_page_test.dart lumira_app_flutter/test/features/scenes/pages/scenes_search_page_test.dart
git commit -m "feat(search): 路由替换为 /search 并接入四个入口，移除旧搜索页"
```

---

### Task 8: 路由测试更新 + 全量收尾

**Files:**
- Modify: `lumira_app_flutter/test/core/router/router_test.dart`

- [ ] **Step 1: 更新 router_test.dart 的路径/路由名清单与计数**

`lumira_app_flutter/test/core/router/router_test.dart`：

1. `_allPaths` 末尾（`RouteNames.profileRedeem` 之后）追加：
```dart
      RouteNames.search,
```
2. `_allNames` 末尾（`'shootkitEditor'` 之后）追加：
```dart
      'search',
```
3. 更新两个 count 断言：
- `expect(allPaths.length, 47, ...)` → `expect(allPaths.length, 48, ...)`（旧 `templatesSearch`/`scenesSearch` 本就未列入清单，新增 `search` 后 47→48）
- `expect(unique.length, 47, ...)` → `expect(unique.length, 48, ...)`
- 末尾 `test('all 47 route names are registered ...', ...)` 文案中的 `47` → `48`

具体改动对照（`test/core/router/router_test.dart`）：

```diff
       RouteNames.profileRewards,
       RouteNames.profileRedeem,
+      RouteNames.search,
     ];
```
```diff
       'profileRewards',
       'profileRedeem',
       'scenes',
       'shootkitEditor',
+      'search',
     ];
```

> 注意：`_allPaths` / `_allNames` 末尾追加位置**必须在 `]` 之前**、最后一个元素之后；按 router.dart 中声明顺序，`search` 放在 `profileRedeem` / `'shootkitEditor'` 之后即可（顺序非严格，但保持与 router.dart 声明顺序一致的注释约定）。

- [ ] **Step 2: 运行路由测试确认通过**

```bash
flutter test test/core/router/router_test.dart
```

确认：3 个 group 全部通过，路径计数断言从 47 更新为 48 后不再报错；`search` 的 `namedLocation('search')` 能解析到 `/search`。

- [ ] **Step 3: flutter analyze 全量通过**

```bash
flutter analyze
```

确认 0 errors / 0 warnings（含 Task 7 删除旧搜索页后不再有未使用导入/悬空引用）。

- [ ] **Step 4: 运行相关测试确认无回归**

```bash
flutter test
```

重点回归：入口所在页面测试（`test/features/templates/pages/templates_page_test.dart`、`templates_all_page_test.dart`、`test/features/scenes/pages/scenes_page_test.dart`、`test/features/academy/...`）、删除的两个旧搜索页测试已移除不再报错。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter
git commit -m "feat(search): 统一全局搜索页完成，接入发现/模板库/场景库/美学院四入口"
```

提交信息按项目既有中文风格；Flutter 端只提交不 push。

---

## 收尾清单（全量交付核对）

实现完成后对照以下清单逐项勾选，全部满足方可视为交付：

- [ ] `search_history` 表随 v32 迁移建表成功（旧库升级不丢数据）
- [ ] 统一搜索页 `/search?scope=all|template|scene|academy` 四档可切换
- [ ] 历史记录按 scope 隔离；支持单条删除与一键清空
- [ ] 热门搜索由预置词 + 本地高频词派生（scope 联动）
- [ ] 推荐信息在 `scope=all` 时三类内容并排展示
- [ ] 关键词多字段匹配（名称/分类/标签/描述等，非仅名称）
- [ ] 全量筛选弹层分区随 scope 联动，筛选后分页重置
- [ ] 触底懒加载每次 20 条，防重入，无更多后停止
- [ ] 排序/筛选/scope/关键词变化时分页重置
- [ ] 发现 Tab / 模板库一级页 / 场景库 / 摄影美学院四处入口均接入
- [ ] 旧 `templates_search_page.dart`、`scenes_search_page.dart` 及对应测试已删除
- [ ] `flutter analyze` 0 错误；`flutter test` 全量通过
- [ ] 按 Global Constraints 提交规则：每 Task 一 commit，Flutter 端仅提交不 push