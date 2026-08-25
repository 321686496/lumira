# 个性化模板推荐引擎实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让推荐从"全站热度+单分类统计"升级为**个人化反馈闭环（越用越懂你、越用越停不下来）**——新增强落地的 `user_interests` 画像 + `TemplateRanking` 混合排序，并接入发现页/Banner/灵感页三入口；**后端零改动、零新增请求，QPS 不变**。

**Architecture:** 全部本机运行。用户行为（拍摄/看详情/收藏）经 `InterestService.recordSignal` 增量写回 `user_interests`（就地时间衰减+加权）；`TemplateRanking` 纯 Dart 引擎读取画像做 `兴趣50% + 探索50%` 混合，各入口消费统一 `userInterestProvider`。失败静默回退，不影响既有逻辑。**构建独立新引擎，不触碰现有 `features/templates/recommend/recommendation_engine.dart`（服务"为你推荐"页）**，避免回归。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁止 Dart 3 records）、sqflite、flutter_riverpod 2.3.6、`flutter analyze` + `flutter test`。

## Global Constraints

- Dart 2.19.6：**不使用 records 语法**（`(double, int)`、positional records 均禁止）。
- 后端零改动；新代码仅在本 Flutter 工程内。
- 所有失败静默回退（`try/catch + debugPrint`），绝不影响拍摄/详情/推荐主流程。
- 排序对象为内置模板全集，量级极小；画像增量 upsert，禁止全表历史扫描。
- 每个任务结束跑 `flutter analyze`（本项目在 `lumira_app_flutter/` 目录下执行），要求 0 error。
- 遵循项目既有分类常量：三维画像 key 依次为 `category`（`TemplateRecord.category`）、`majorStyle`、`style`（来自 `classification` JSON 的 `majorStyle`/`style` 字段）。
- 纯文档改动（本计划文档）不推送。

---

### Task 1：`user_interests` 表 + 迁移 + `InterestDao`

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（追加 `UserInterestsTable`）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（`_kDbVersion` 39→40；`_onCreate` 建表；`_onUpgrade` 追加 `if (oldVersion < 40)`；新增 `userInterestsDaoProvider`）
- Create: `lumira_app_flutter/lib/core/db/dao/user_interests_dao.dart`
- Test: `lumira_app_flutter/test/features/templates/recommend/user_interests_dao_test.dart`

**Interfaces:**
- Consumes: `Tables`、`Database`（sqflite）。
- Produces: `UserInterestsTable`（常量 + createSql），`InterestDao`（`read`/`getAll`/`upsert`），`userInterestsDaoProvider`。

- [ ] **Step 1: 在 `tables.dart` 末尾追加 `UserInterestsTable`**

```dart
/// 用户兴趣画像表（v40 迁移新增，个性推荐反馈闭环信号源）
class UserInterestsTable {
  static const String name = 'user_interests';
  static const String colScope = 'scope';
  static const String colKey = 'key';
  static const String colScore = 'score';
  static const String colLastSignalAt = 'last_signal_at';

  static const String createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      $colScope TEXT NOT NULL,
      $colKey TEXT NOT NULL,
      $colScore REAL NOT NULL DEFAULT 0,
      $colLastSignalAt INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY ($colScope, $colKey)
    )
  ''';
  static const String indexScopeSql =
      'CREATE INDEX IF NOT EXISTS idx_user_interests_scope ON $name ($colScope)';
}
```

- [ ] **Step 2: 创建 `user_interests_dao.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../tables.dart';

/// 用户兴趣画像记录（scope=category|major_style|style，key=对应维度）
class UserInterest {
  final String scope;
  final String key;
  final double score;
  final int lastSignalAt;
  const UserInterest({
    required this.scope,
    required this.key,
    required this.score,
    required this.lastSignalAt,
  });
}

/// 用户兴趣画像 DAO（增量读写，DB 全表仅百余行量级）
class InterestDao {
  final Database _db;
  InterestDao(this._db);

  /// 读单个维度键；无记录返回 null
  Future<UserInterest?> read(String scope, String key) async {
    final rows = await _db.query(
      UserInterestsTable.name,
      where: '${UserInterestsTable.colScope} = ? AND ${UserInterestsTable.colKey} = ?',
      whereArgs: [scope, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return UserInterest(
      scope: r[UserInterestsTable.colScope] as String,
      key: r[UserInterestsTable.colKey] as String,
      score: (r[UserInterestsTable.colScore] as num).toDouble(),
      lastSignalAt: (r[UserInterestsTable.colLastSignalAt] as num).toInt(),
    );
  }

  /// 读全量画像：'{scope}:{key}' -> 记录
  Future<Map<String, UserInterest>> getAll() async {
    final rows = await _db.query(UserInterestsTable.name);
    return {
      for (final r in rows)
        '${r[UserInterestsTable.colScope]}:${r[UserInterestsTable.colKey]}': UserInterest(
          scope: r[UserInterestsTable.colScope] as String,
          key: r[UserInterestsTable.colKey] as String,
          score: (r[UserInterestsTable.colScore] as num).toDouble(),
          lastSignalAt: (r[UserInterestsTable.colLastSignalAt] as num).toInt(),
        ),
    };
  }

  /// 覆盖写某维度键（调用方已完成时间衰减+加权）
  Future<void> upsert({
    required String scope,
    required String key,
    required double score,
    required int at,
  }) async {
    await _db.insert(
      UserInterestsTable.name,
      {
        UserInterestsTable.colScope: scope,
        UserInterestsTable.colKey: key,
        UserInterestsTable.colScore: score,
        UserInterestsTable.colLastSignalAt: at,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

- [ ] **Step 3: 迁移接线（`database_provider.dart`）**

`_kDbVersion` 改为 40：

```dart
const int _kDbVersion = 40;
```

`_onCreate`（在建表 batch 末尾追加建表与索引）：

```dart
  batch.execute(UserInterestsTable.createSql);
  batch.execute(UserInterestsTable.indexScopeSql);
```

`_onUpgrade`（在 `if (oldVersion < 39)` 块之后、函数结束 `}` 之前追加）：

```dart
  if (oldVersion < 40) {
    try {
      await db.execute(UserInterestsTable.createSql);
      await db.execute(UserInterestsTable.indexScopeSql);
    } catch (e) {
      debugPrint('v40 migration failed (silent fallback): $e');
    }
  }
```

并在 `database_provider.dart` 顶部 import：`'./tables.dart'` 已导入；追加 `import 'dao/user_interests_dao.dart';`；同时新增 Provider（放在 `usageDaoProvider` 附近）：

```dart
final userInterestsDaoProvider = FutureProvider<InterestDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return InterestDao(db);
});
```

- [ ] **Step 4: 写 DAO smoke 测试（用真实内存库校验 upsert/getAll/read）**

`test/features/templates/recommend/user_interests_dao_test.dart`：使用 `sqflite_common_ffi` 内存库。若该项目测试尚未引入 ffi，则在 `dev_dependencies` 加 `sqflite_common_ffi` 并在 `test` 的 `setUpAll` 调用 `sqfliteFfiInit()`。

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app/core/db/dao/user_interests_dao.dart';
import 'package:lumira_app/core/db/tables.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upsert then getAll returns portrait; replace overwrites score', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(UserInterestsTable.createSql);
    final dao = InterestDao(db);

    await dao.upsert(scope: 'category', key: 'portrait', score: 3.0, at: 1000);
    await dao.upsert(scope: 'style', key: 'fresh', score: 0.6, at: 1000);

    final all = await dao.getAll();
    expect(all['category:portrait']!.score, 3.0);
    expect(all['style:fresh']!.score, 0.6);

    // replace 语义：同 key 覆盖
    await dao.upsert(scope: 'category', key: 'portrait', score: 5.0, at: 2000);
    final updated = await dao.getAll();
    expect(updated['category:portrait']!.score, 5.0);

    // 无记录 read 返回 null
    expect(await dao.read('category', 'nope'), isNull);
    // 有记录 read 回读
    expect((await dao.read('category', 'portrait'))!.lastSignalAt, 2000);

    await db.close();
  });
}
```

> 注：包名 `package:lumira_app/...` 以项目 `pubspec.yaml` 的 `name` 为准；如不同请替换为实际包名。`user_interests_dao_test.dart` 需 import 镜像本 Task 的 DAO 全部行为（TDD：先让测试失败——DAO 尚未实现——再实现使其通过）。

- [ ] **Step 5: 跑测试确认通过**

Run（在 `lumira_app_flutter/`）：

```bash
flutter test test/features/templates/recommend/user_interests_dao_test.dart
```

Expected: PASS（若 `sqflite_common_ffi` 缺失先 `flutter pub add --dev sqflite_common_ffi`）。

- [ ] **Step 6: `flutter analyze` 0 error**

```bash
flutter analyze
```

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/core/db/dao/user_interests_dao.dart lumira_app_flutter/test/features/templates/recommend/user_interests_dao_test.dart lumira_app_flutter/pubspec.yaml
git commit -m "feat(recommend): add user_interests table, migration v40, InterestDao"
```

---

### Task 2：`InterestService` 反馈闭环（时间衰减 + 三维写入）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/recommend/user_interests.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（追加 `interestServiceProvider`）
- Test: `lumira_app_flutter/test/features/templates/recommend/user_interests_test.dart`

**Interfaces:**
- Consumes: `InterestDao`、`TemplatesDao`（`getById`）。
- Produces: `InterestService`（`static computeNewScore`、`recordSignal(String templateId, double weight)`）、`interestServiceProvider`。

- [ ] **Step 1: 写失败测试（纯衰减计算）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/features/templates/recommend/user_interests.dart';

void main() {
  test('computeNewScore: 无历史 = 仅 weight', () {
    final s = InterestService.computeNewScore(
      existing: null, lastAt: null, nowMs: 0, weight: 3.0, halfLifeDays: 14,
    );
    expect(s, 3.0);
  });

  test('computeNewScore: 半衰期衰减后再加权重', () {
    // existing=10，半个半衰期(7天)后 → 10*0.5^(7/14)=7.07，再加 1
    const day = 24 * 3600 * 1000;
    final s = InterestService.computeNewScore(
      existing: 10.0, lastAt: 0, nowMs: 7 * day, weight: 1.0, halfLifeDays: 14,
    );
    expect(s, closeTo(8.071, 0.001));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/features/templates/recommend/user_interests_test.dart
```

Expected: FAIL（`InterestService` 未定义）。

- [ ] **Step 3: 实现 `user_interests.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/user_interests_dao.dart';

/// 个性化反馈闭环：把用户行为按模板分类写回 user_interests 画像。
/// 时间衰减（半衰期 14 天），近期行为权重更高；失败静默。
class InterestService {
  /// 兴趣分半衰期（天）
  static const double kHalfLifeDays = 14;

  static const String scopeCategory = 'category';
  static const String scopeMajorStyle = 'major_style';
  static const String scopeStyle = 'style';

  final InterestDao _dao;
  final TemplatesDao _templatesDao;
  final Map<String, TemplateRecord> _templateCache = {};

  InterestService(this._dao, this._templatesDao);

  /// 纯函数：计算一次信号后的新兴趣分（便于单测与复用）。
  /// existing/lastAt 为空表示该维度首次出现。
  static double computeNewScore({
    required double? existing,
    required int? lastAt,
    required int nowMs,
    required double weight,
    required double halfLifeDays,
  }) {
    double base = existing ?? 0;
    if (existing != null && lastAt != null) {
      final elapsedDays = (nowMs - lastAt) / (24 * 3600 * 1000.0);
      base = base * math.pow(0.5, elapsedDays / halfLifeDays).toDouble();
    }
    return base + weight;
  }

  /// 记录一次正反馈，按模板分类把 weight 写入 category/majorStyle/style 三维。
  Future<void> recordSignal(String templateId, double weight) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tpl = await _resolveTemplate(templateId);
      if (tpl == null) return;
      await _bump(scopeCategory, tpl.category, weight, now);
      final maj = tpl.classification['majorStyle'];
      if (maj is String) await _bump(scopeMajorStyle, maj, weight, now);
      final sty = tpl.classification['style'];
      if (sty is String) await _bump(scopeStyle, sty, weight, now);
    } catch (e) {
      debugPrint('[interest] recordSignal failed (silent): $e');
    }
  }

  Future<TemplateRecord?> _resolveTemplate(String id) async {
    if (_templateCache.containsKey(id)) return _templateCache[id];
    final t = await _templatesDao.getById(id);
    if (t != null) _templateCache[id] = t;
    return t;
  }

  Future<void> _bump(String scope, String key, double weight, int nowMs) async {
    if (key.trim().isEmpty) return;
    final existing = await _dao.read(scope, key);
    final updated = computeNewScore(
      existing: existing?.score,
      lastAt: existing?.lastSignalAt,
      nowMs: nowMs,
      weight: weight,
      halfLifeDays: kHalfLifeDays,
    );
    await _dao.upsert(scope: scope, key: key, score: updated, at: nowMs);
  }
}
```

- [ ] **Step 4: 补 provider（`database_provider.dart`）**

追加 import 与 Provider：

```dart
final interestServiceProvider = FutureProvider<InterestService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return InterestService(InterestDao(db), TemplatesDao(db));
});
```

- [ ] **Step 5: 跑测试确认通过 + analyze**

```bash
flutter test test/features/templates/recommend/user_interests_test.dart
flutter analyze
```

Expected: PASS + 0 error。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/recommend/user_interests.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/test/features/templates/recommend/user_interests_test.dart
git commit -m "feat(recommend): InterestService feedback loop with time decay"
```

---

### Task 3：`TemplateRanking` 混合排序引擎（纯 Dart）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/recommend/template_ranking.dart`
- Test: `lumira_app_flutter/test/features/templates/recommend/template_ranking_test.dart`

**Interfaces:**
- Consumes: `TemplateRecord`、`RankingContext`。
- Produces: `RankingContext`、`TemplateScore`、`TemplateRanking`（`scoreAll`、`mixExplore`、`interestFor`）。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app/core/db/dao/templates_dao.dart';
import 'package:lumira_app/features/templates/recommend/template_ranking.dart';

TemplateRecord _tpl(String id, String category, {String major = '', String style = ''}) {
  return TemplateRecord(
    id: id,
    name: id,
    author: '',
    version: '1.0.0',
    category: category,
    classification: {'category': category, 'majorStyle': major, 'style': style},
    tags: const [],
    tagIds: const [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: const {},
    pose: null,
    camera: const {},
    sceneGuide: const {},
    postProcess: const {},
    createdAt: 0,
    updatedAt: 0,
    source: 'builtin',
  );
}
```

```dart
void main() {
  final ctx = RankingContext(nowMs: 0, portrait: {'category:portrait': 10, 'style:fresh': 3});

  test('scoreAll: 高兴趣模板 interest 更高、探索更低', () {
    final result = TemplateRanking().scoreAll(
      [_tpl('p1', 'portrait', style: 'fresh'), _tpl('p2', 'landscape', style: 'fog')],
      ctx,
    );
    final p1 = result.firstWhere((s) => s.template.id == 'p1');
    final p2 = result.firstWhere((s) => s.template.id == 'p2');
    expect(p1.interest > p2.interest, isTrue);
    expect(p1.exploration < p2.exploration, isTrue);
  });

  test('mixExplore: 返回全部且不重复', () {
    final tpls = [
      _tpl('a', 'portrait', style: 'fresh'),
      _tpl('b', 'portrait', style: 'fog'),
      _tpl('c', 'landscape', style: 'fresh'),
      _tpl('d', 'object', style: 'fog'),
    ];
    final scores = TemplateRanking().scoreAll(tpls, ctx);
    final out = TemplateRanking().mixExplore(scores);
    expect(out.length, 4);
    expect(out.map((t) => t.id).toSet().length, 4);
  });

  test('favoriteCategories 给问卷首选分类加分', () {
    final ctx2 = RankingContext(nowMs: 0, favoriteCategories: {'portrait'}, portrait: {});
    final scores = TemplateRanking().scoreAll(
      [_tpl('a', 'portrait'), _tpl('b', 'landscape')],
      ctx2,
    );
    final a = scores.firstWhere((s) => s.template.id == 'a');
    final b = scores.firstWhere((s) => s.template.id == 'b');
    expect(a.total > b.total, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/features/templates/recommend/template_ranking_test.dart
```

Expected: FAIL（`TemplateRanking` 未定义）。

- [ ] **Step 3: 实现 `template_ranking.dart`**

```dart
import 'dart:math' as math;

import '../../../core/db/dao/templates_dao.dart';

/// 个性化排序上下文（由各入口从画像/热度/问卷/近期展示组装）
class RankingContext {
  /// 画像：'{scope}:{key}' -> score（来自 user_interests）
  final Map<String, double> portrait;
  /// templateId -> 全站热度（use_shoot*2 + open_detail）
  final Map<String, int> popularity;
  /// 用户问卷首选分类
  final Set<String> favoriteCategories;
  /// 近期已在列表展示过的 templateId（降权防重复）
  final Set<String> recentlyShown;
  final int nowMs;

  const RankingContext({
    this.portrait = const {},
    this.popularity = const {},
    this.favoriteCategories = const {},
    this.recentlyShown = const {},
    required this.nowMs,
  });

  double scoreFor(String scope, String key) => portrait['$scope:$key'] ?? 0;
}

/// 单条模板的排序指标
class TemplateScore {
  final TemplateRecord template;
  final double interest;
  final double exploration;
  final double hot;
  final double total;
  const TemplateScore({
    required this.template,
    required this.interest,
    required this.exploration,
    required this.hot,
    required this.total,
  });
}

/// 个性化模板排序器（纯 Dart，可单元测试）。
/// 三维画像权重 + 60/40 熟/新混合；独立新引擎，不与现有 recommendation_engine.dart 混用。
class TemplateRanking {
  // 三维画像内部权重
  static const double wCategory = 0.50;
  static const double wMajorStyle = 0.30;
  static const double wStyle = 0.20;
  // 总分权重
  static const double wInterest = 0.50;
  static const double wExplore = 0.30;
  static const double wHot = 0.15;
  static const double wQuestionnaire = 0.10;
  static const double penaltyRecent = 0.25;

  /// 对每个模板计算 interest（三维画像加权和）
  double interestFor(TemplateRecord t, RankingContext ctx) {
    final cls = t.classification;
    final c = ctx.scoreFor(InterestScope.category, t.category);
    final maj = cls['majorStyle'];
    final m = maj is String
        ? ctx.scoreFor(InterestScope.majorStyle, maj)
        : 0.0;
    final sty = cls['style'];
    final s = sty is String
        ? ctx.scoreFor(InterestScope.style, sty)
        : 0.0;
    return wCategory * c + wMajorStyle * m + wStyle * s;
  }

  /// 打分全量候选（含归一化与问卷/近期展示加减分）
  List<TemplateScore> scoreAll(List<TemplateRecord> templates, RankingContext ctx) {
    if (templates.isEmpty) return const [];
    var maxInterest = 0.0;
    for (final t in templates) {
      final v = interestFor(t, ctx);
      if (v > maxInterest) maxInterest = v;
    }
    var maxPop = 0;
    for (final t in templates) {
      final p = ctx.popularity[t.id] ?? 0;
      if (p > maxPop) maxPop = p;
    }

    final scores = <TemplateScore>[];
    for (final t in templates) {
      final interest = maxInterest > 0 ? interestFor(t, ctx) / maxInterest : 0.0;
      final exploration = (1.0 - interest).clamp(0.0, 1.0).toDouble();
      final p = ctx.popularity[t.id] ?? 0;
      final hot = maxPop > 0 ? (p / maxPop).clamp(0.0, 1.0).toDouble() : 0.0;
      final q = ctx.favoriteCategories.contains(t.category) ? 1.0 : 0.0;
      final recentPenalty = ctx.recentlyShown.contains(t.id) ? penaltyRecent : 0.0;
      final total =
          (wInterest * interest + wExplore * exploration + wHot * hot + wQuestionnaire * q) -
              recentPenalty;
      scores.add(TemplateScore(
        template: t,
        interest: interest,
        exploration: exploration,
        hot: hot,
        total: total,
      ));
    }
    return scores;
  }

  /// 熟/新 50/50 混合：新鲜 half 与兴趣 half 交替合并（去重后回填）
  List<TemplateRecord> mixExplore(List<TemplateScore> scores) {
    if (scores.isEmpty) return const [];
    final explore = [...scores]..sort((a, b) => b.exploration.compareTo(a.exploration));
    final exploit = [...scores]..sort((a, b) => b.interest.compareTo(a.interest));
    final half = (scores.length / 2).ceil();
    final a = explore.take(half).toList();
    final b = exploit.take(half).toList();
    final out = <TemplateRecord>[];
    final used = <String>{};
    final len = math.max(a.length, b.length);
    for (var i = 0; i < len; i++) {
      if (i < a.length) {
        final t = a[i].template;
        if (used.add(t.id)) out.add(t);
      }
      if (i < b.length) {
        final t = b[i].template;
        if (used.add(t.id)) out.add(t);
      }
    }
    if (out.length < scores.length) {
      final rest = [...explore.skip(half), ...exploit.skip(half)];
      for (final s in rest) {
        if (out.length >= scores.length) break;
        if (used.add(s.template.id)) out.add(s.template);
      }
    }
    return out;
  }
}

/// 画像维度名（与 InterestService 常量对齐，避免散落魔法字符串）
class InterestScope {
  static const category = 'category';
  static const majorStyle = 'major_style';
  static const style = 'style';
}
```

> 说明：`InterestScope` 集中定义维度 key，`InterestService` 侧把 `scopeCategory/majorStyle/style` 改为引用 `InterestScope` 以避免双职。Task 2 实现时可直接用 `InterestScope`（此处新增于 Task 3，Task 2 若已硬编码小写字符串也能编译通过——为保持单测通过建议 Task 2 与 Task 3 实现顺序可互换，最终统一为 `InterestScope`）。

- [ ] **Step 4: 跑测试确认通过 + analyze**

```bash
flutter test test/features/templates/recommend/template_ranking_test.dart
flutter analyze
```

Expected: PASS + 0 error。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/recommend/template_ranking.dart lumira_app_flutter/test/features/templates/recommend/template_ranking_test.dart
git commit -m "feat(recommend): TemplateRanking 50/50 explore-exploit mixer"
```

---

### Task 4：反馈接线（拍摄 / 详情 / 收藏）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（拍摄权重 3.0）
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart`（详情权重 0.6）
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`（收藏权重 1.5；`gallery_edit_page.dart` 同模式补一处）

**Interfaces:**
- Consumes: `interestServiceProvider`、`InterestService.recordSignal(templateId, weight)`。
- Produces: 无（副作用写入画像）。

- [ ] **Step 1: 拍摄回写（`capture_page.dart`）**

定位到保存落库并埋点的代码段（约第 894 行 `_reportAndSync(record.templateId, record.sceneId);`），在其后追加画像回写：

```dart
        // ignore: unawaited_futures
        _reportAndSync(record.templateId, record.sceneId);
        // 个性化反馈：完成拍摄 → 加权写给模板分类画像（失败静默）
        if (record.templateId != null) {
          try {
            final service =
                await ref.read(interestServiceProvider.future);
            // ignore: unawaited_futures
            service.recordSignal(record.templateId!, 3.0);
          } catch (_) {}
        }
```

若 `_reportAndSync` 触发点是方法内部且模板由参数传入，则将上述回写顺延到模板保存成功后的同一代码路径内。

- [ ] **Step 2: 详情回写（`templates_detail_page.dart`）**

在 `_maybeReportOpenDetail` 的 `await recorder.recordTemplate(...)` 之后追加：

```dart
      await recorder.recordTemplate(
        templateId: templateId,
        source: source,
        event: UsageEventType.openDetail,
      );
      // 个性化反馈：查看详情 → 轻量加权（失败静默）
      final interest = await ref.read(interestServiceProvider.future);
      await interest.recordSignal(templateId, 0.6);
```

- [ ] **Step 3: 收藏回写（`gallery_detail_page.dart`）**

定位收藏按钮处理（约第 780 行 `await dao.toggleFavorite(photo.id);`），改为收藏（非取消）时回写。`photo` 为 `GalleryItemRecord`，含 `.isFavorite` 与 `.templateId`：

```dart
          await dao.toggleFavorite(photo.id);
          // 个性化反馈：收藏照片（且照片带模板）→ 回写模板画像（失败静默）
          if (!photo.isFavorite && photo.templateId != null) {
            try {
              final interest =
                  await ref.read(interestServiceProvider.future);
              await interest.recordSignal(photo.templateId!, 1.5);
            } catch (_) {}
          }
          onToggled(!photo.isFavorite);
```

- [ ] **Step 4: `gallery_edit_page.dart` 同模式补一处**

`gallery_edit_page.dart`（约第 701 行同等逻辑）复制 Step 3 的画像回写（同样 `if (!photo.isFavorite && photo.templateId != null)`）。

- [ ] **Step 5: 验证**

```bash
flutter analyze
```

Expected: 0 error（无需新增单测；副作用接线以 analyze 为准）。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/capture/pages/capture_page.dart lumira_app_flutter/lib/features/templates/pages/templates_detail_page.dart lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart
git commit -m "feat(recommend): wire shoot/detail/favorite feedback into InterestService"
```

---

### Task 5：发现页「今日为你推荐」接入 `TemplateRanking`

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/data/templates_providers.dart`

**Interfaces:**
- Consumes: `userInterestsDaoProvider`、`usageDaoProvider`、`templatesDaoProvider`、`TemplateRanking`、`RankingContext`。
- Produces: 无新 provider（直接改造 `recommendedBuiltinTemplatesProvider` 返回个性化排序后列表，尽量减少调用方改动）。

- [ ] **Step 1: 在 `templates_providers.dart` 顶部补齐 import**

```dart
import '../recommend/template_ranking.dart';
import '../../../core/db/dao/user_interests_dao.dart';
```

- [ ] **Step 2: 改造 `recommendedBuiltinTemplatesProvider`**

把原有只读推荐的实现改为：取 `isRecommended` 模板 → 加载画像/热度 → `TemplateRanking` 排序并 `mixExplore` 返回。

```dart
final recommendedBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final base = await dao.getBuiltin(isRecommended: true);
  if (base.isEmpty) return const [];

  // 画像：'{scope}:{key}' -> score
  final interestsDao = await ref.watch(userInterestsDaoProvider.future);
  final portrait = <String, double>{};
  final all = await interestsDao.getAll();
  for (final e in all.entries) {
    portrait[e.key] = e.value.score;
  }

  // 热度：use_shoot*2 + open_detail
  final usageDao = await ref.watch(usageDaoProvider.future);
  final counts =
      await usageDao.countMap('template', base.map((t) => t.id).toList());
  final popularity = <String, int>{
    for (final t in base)
      t.id: ((counts[t.id]?.useShoot ?? 0) * 2 + (counts[t.id]?.openDetail ?? 0)),
  };

  final ctx = RankingContext(
    portrait: portrait,
    popularity: popularity,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );
  final scores = TemplateRanking().scoreAll(base, ctx);
  return TemplateRanking().mixExplore(scores);
});
```

- [ ] **Step 3: 验证**

```bash
flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/templates/data/templates_providers.dart
git commit -m "feat(recommend): rank discovery 'today recommendation' via TemplateRanking"
```

---

### Task 6：首页 Banner 个性化混合

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/services/recommendation_service.dart`

**Interfaces:**
- Consumes: `_interestDao`、`TemplateRanking.interestFor`、`RankingContext`。
- Produces: `_pickUnusedSystemPick` 增加可选 `Map<String,double> interestById` 参数，按「热度 + 个人兴趣」混合取最大。

- [ ] **Step 1: 给服务注入画像读取能力**

`recommendation_service.dart` 顶部 import `TemplateRanking` 与 `InterestDao`，并新增构造字段/方法：

```dart
Future<Map<String, double>> _loadTemplateInterest(
  List<TemplateRecord> picks,
) async {
  final dao = _interestDao;         // 需注入 InterestDao
  if (dao == null || picks.isEmpty) return const {};
  final all = await dao.getAll();
  final portrait = <String, double>{};
  for (final e in all.entries) {
    portrait[e.key] = e.value.score;
  }
  final ctx = RankingContext(nowMs: DateTime.now().millisecondsSinceEpoch, portrait: portrait);
  return {for (final t in picks) t.id: TemplateRanking().interestFor(t, ctx)};
}
```

> 若该服务构造时未持有 `InterestDao`，请在其构造参数中追加一个可空的 `InterestDao?`（对应现有 `_usageDao` 的注入方式）。`_interestDao` 相关判空逻辑与 `_usageDao` 一致。

- [ ] **Step 2: 改造 `_pickUnusedSystemPick` 混合热度+兴趣**

```dart
  TemplateRecord? _pickUnusedSystemPick(
    List<TemplateRecord> systemPicks,
    Set<String> usedTemplateIds,
    Map<String, int> popularity, [
    Map<String, double> interestById = const {},
  ]) {
    final unused =
        systemPicks.where((t) => !usedTemplateIds.contains(t.id)).toList();
    if (unused.isEmpty) return null;
    var best = unused.first;
    var bestScore = _blendScore(best, popularity, interestById);
    for (final t in unused.skip(1)) {
      final s = _blendScore(t, popularity, interestById);
      if (s > bestScore) {
        bestScore = s;
        best = t;
      }
    }
    return best;
  }

  /// 热度(归一化)与个人兴趣(归一化)的 0.5/0.5 混合分
  double _blendScore(TemplateRecord t, Map<String, int> popularity,
      Map<String, double> interestById) {
    return (popularity[t.id] ?? 0).toDouble() * 0.5 + (interestById[t.id] ?? 0) * 0.5;
  }
```

- [ ] **Step 3: 在 `buildBanners()` 中加载兴趣并传入槽位 2/4/5**

在 `buildBanners()` 内已取得 `systemPicks` 后（或各槽调用前）加载一次：

```dart
    final interestById = await _loadTemplateInterest(await _templatesDao.getBuiltin(isRecommended: true));
```

并将槽位 2（`slot2Tpl ??= _pickUnusedSystemPick(...)`）、槽位 4（`slot4Tpl = _pickUnusedSystemPick(...)`）、槽位 5（`_pickUnusedSystemPick(...)`）三处的调用都补充最后一个实参 `interestById`。

- [ ] **Step 4: 验证 + 提交**

```bash
flutter analyze
git add lumira_app_flutter/lib/features/home/services/recommendation_service.dart
git commit -m "feat(recommend): blend personal interest into home banner slots 2/4/5"
```

---

### Task 7：灵感页「今日可拍」叠加个人兴趣

**Files:**
- Modify: `lumira_app_flutter/lib/features/inspiration/data/inspiration_content.dart`
- Modify: `lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart`

**Interfaces:**
- Consumes: 各池 item 的 `templateId`、`TemplateRanking.interestFor`。
- Produces: `pickTodayShoot` 增加可选 `Map<String, double> interestByTemplateId` 参数，加入个人兴趣分。

- [ ] **Step 1: 改造 `pickTodayShoot`（`inspiration_content.dart`）**

给方法签名加可选参数，并在 `scoreOf` 中并入个人兴趣：

```dart
  static List<TodayShootItem> pickTodayShoot(
    String? topCategory,
    DateTime now, {
    int count = 4,
    Map<String, double> interestByTemplateId = const {},
  }) {
    final slot = slotOf(now);
    int scoreOf(TodayShootItem item) {
      var score = 0;
      if (item.slots.contains(slot) || item.slots.contains('any')) score += 2;
      if (topCategory != null && item.categories.contains(topCategory)) {
        score += 3;
      }
      final iv = interestByTemplateId[item.templateId] ?? 0;
      score += (iv * 5).round(); // 0..1 → 0..5，与 slot/category 分同量级
      return score;
    }
    // ...原排序与 take(count) 不变
  }
```

- [ ] **Step 2: 组装 `interestByTemplateId`（`inspiration_providers.dart`）**

在调用 `pickTodayShoot` 的 Provider 内，读取画像并按各 item 的 `templateId` 解析模板后计算个人兴趣：

```dart
      // 并行读取画像与模板唯一索引，计算各池 item 模板的个人兴趣
      final interestsDao = await ref.watch(userInterestsDaoProvider.future);
      final all = await interestsDao.getAll();
      final portrait = <String, double>{ for (final e in all.entries) e.key: e.value.score };
      final templatesDao = await ref.watch(templatesDaoProvider.future);
      final ctx = RankingContext(nowMs: now, portrait: portrait);
      final interestByTemplateId = <String, double>{};
      for (final it in poolItems) {
        final t = await templatesDao.getById(it.templateId);
        if (t != null) interestByTemplateId[it.templateId] = TemplateRanking().interestFor(t, ctx);
      }
      final items = InspirationContent.pickTodayShoot(
        topCategory, now,
        interestByTemplateId: interestByTemplateId,
      );
```

> `poolItems`/`topCategory`/`now` 以 `inspiration_providers.dart` 中调用处实际变量名为准；`RankingContext`/`TemplateRanking`/`userInterestsDaoProvider` 需 import。

- [ ] **Step 3: 验证 + 提交**

```bash
flutter analyze
git add lumira_app_flutter/lib/features/inspiration/data/inspiration_content.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart
git commit -m "feat(recommend): add personal interest bonus to inspiration today-shoot"
```

---

### Task 8：收尾（文档登记 + 全量校验 + 提交）

**Files:**
- Modify: `docs/future-optimizations.md`（登记后续项）

- [ ] **Step 1: 登记未来优化项（半衰期调参、负反馈、详情页同类、分享信号、更更多模板兴趣化）**

在 `docs/future-optimizations.md` 末尾按既有格式追加：

```markdown
- **优先级**：P1
  - **模块**：模板推荐（个性化引擎）
  - **优化点**：`user_interests` 半衰期/权重参数用真实数据 A/B 校准
  - **背景动机**：默认 14 天半衰期、0.50/0.30/0.20 三维权重为经验初始值
  - **目标状态**：基于曝光/完成率埋点回灌调参
  - **状态**：⏳ 待实现

- **优先级**：P1
  - **模块**：模板推荐
  - **优化点**：模板详情页底部新增「为你推荐」同类板块（同 category/majorStyle 用 TemplateRanking 排序）
  - **背景动机**：详情页当前无推荐，浏览后缺乏二次推荐入口
  - **目标状态**：详情页底部展示个性化同类模板
  - **状态**：⏳ 待实现

- **优先级**：P2
  - **模块**：模板推荐
  - **优化点**：「不感兴趣」显式负反馈 + 「分享模板」信号接入
  - **背景动机**：当前仅正反馈（拍摄/详情/收藏），无负反馈剥离；分享未挂接
  - **目标状态**：短期屏蔽同类 + 分享加权
  - **状态**：⏳ 待实现
```

- [ ] **Step 2: 全量校验**

```bash
flutter analyze
flutter test
```

Expected: 0 error + 全绿。

- [ ] **Step 3: Commit**

```bash
git add docs/future-optimizations.md
git commit -m "docs: register template recommendation follow-ups"
```

---

## 范围界定与说明

- **后端零改动、零新增请求**：全部逻辑在 Flutter 端本机完成，后端 QPS 不变。
- **独立新引擎**：本计划新建 `TemplateRanking`，不修改现有 `recommendation_engine.dart`（「为你推荐」页仍用它），无回归风险。
- **详情页「为你推荐」板块**：已登记到 `future-optimizations.md`（涉及新页面区块，需读取详情页 build 树后再实现），本次不强做以减少占位式步骤。
- **负反馈/分享/调参**：登记到 `future-optimizations.md`，后续单独立项。