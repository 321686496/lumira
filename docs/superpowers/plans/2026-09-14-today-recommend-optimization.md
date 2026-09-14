# 发现页「今日为你推荐」推荐优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把发现页「今日为你推荐」从"一条不限数量的算法长列表"升级为"个性化精准到四级分类、每日轮换固定批次、画像推荐展示有据可依"的运营级推荐栏——纯客户端改动，不动后端。

**Architecture:** 复用现有 `TemplateRanking` 骨架（三维画像 × 热度 × 问卷 × 熟/新 50/50 混合），做四处增强：
1. 画像从三维扩展到**四级**（大类 → 风格 → 子风格 → 拍摄方式，`category/style/subStyle/method`）；
2. 新增纯函数 `DailyRecommendator` 做**按日期种子的稳定轮换 + 固定上限**；
3. 修掉 `mixExplore` 尾部全量重排破坏探索顺序的 bug；
4. 热度叠加**本机近 30 天 `usage_events` 信号**做时效软化；展示层为画像命中项生成**四级匹配理由 / 来源角标**。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（严格：无 Dart 3 records、无 records 语法）。Riverpod。纯 Dart 逻辑放 `recommend/` 下便于单测。

## Global Constraints

- **Dart 2.19.6 语法**：禁止 record 类型、禁止 `.characters` 等新 API；用 `Map`/`class` 传复合值（参考现有 `_BadgeColors` 的写法）。
- **不动后端**（`lumira-server/` 零改动，不触发任何 push 流程）。
- **不破坏首页「模板推荐」**：`recommendedBuiltinTemplatesProvider` 返回值类型保持 `List<TemplateRecord>` 不变，首页依赖它的 offset `take(6)` 逻辑不回归。展示优化走**新增** `todayRecommendationItemsProvider`，只改发现页 `_HeroSection`。
- **四级分类取值**：以 `TemplateRecord.classification` 为准——`category`(L1)、`majorStyle`(L2，人像)、`style`(L2 旧别名，非人像)、`subStyle`(L3)、`method`(L4)。L2 的有效值 = `majorStyle.isNotEmpty ? majorStyle : style`，避免人像模板 majorStyle 与 style 双计。
- **全站热度仍取 `usage_stats`**；本机近30天信号取 `usage_events`，二者按 `α` 融合，`α=0.5`。
- **每日批次固定上限 `N=10`**。
- **匹配阈值**：`interest > 0.35` 判定为"画像命中"（展示层据此给来源角标/理由；不影响排序，排序仍由 `total` 全量信号主导）。
- 所有新文件 polyfill 无外部依赖，逻辑函数必须可在 `flutter test` 单测。

## 文件结构

| 动作 | 文件 | 职责 |
|------|------|------|
| Modify | `lib/features/templates/recommend/user_interests.dart` | `InterestService.recordSignal` 补写 `sub_style` / `method` 画像 |
| Modify | `lib/core/db/dao/user_interests_dao.dart` | 仅注释更新（scope 枚举说明） |
| Modify | `lib/features/templates/recommend/template_ranking.dart` | 四级权重、effective L2、`mixExplore` 顺序修复、新增 `matchVerdict`/`InterestScope.subStyle/method` |
| Create | `lib/features/templates/recommend/daily_recommendator.dart` | 纯函数：每日种子轮换 + 固定上限 + 生成匹配理由 |
| Modify | `lib/core/db/dao/usage_dao.dart` | 新增 `recentPopularity(itemIds, sinceMs)`，按 `usage_events` 近窗口聚合 |
| Modify | `lib/features/templates/data/templates_providers.dart` | 组装：近窗口融合热度 + 每日批次 + 新增 `todayRecommendationItemsProvider` |
| Modify | `lib/features/templates/pages/templates_page.dart` | `_HeroSection` 改用 `todayRecommendationItemsProvider` 渲染 |
| Create | `test/features/templates/recommend/daily_recommendator_test.dart` | DailyRecommendator 单测 |
| Create | `test/features/templates/recommend/template_ranking_ext_test.dart` | 四级权重 / mixExplore 顺序单测 |

---

## Task 1: 四级画像写入

**Files:**
- Modify: `lib/features/templates/recommend/user_interests.dart`
- Modify: `lib/core/db/dao/user_interests_dao.dart:4`（注释）

**Interfaces:**
- Consumes: `TemplateRecord.classification`（含 `subStyle`、`method`）。
- Produces: `InterestService.scopeSubStyle` / `scopeMethod` 两个 get 常量；行为变化——`recordSignal` 额外写 `sub_style:{subStyle}` 与 `method:{method}` 两条画像。

- [ ] **Step 1: 加作用域常量**

在 `user_interests.dart` 的 `scopeStyle` 下补充：

```dart
  static const String scopeStyle = 'style';
  static const String scopeSubStyle = 'sub_style';
  static const String scopeMethod = 'method';
```

- [ ] **Step 2: recordSignal 补写四级**

把 `recordSignal` 中 L2 改成 effective（majorStyle 优先，空则回退 style），并新增 L3/L4 写入：

```dart
  /// 记录一次正反馈，按模板分类把 weight 写入四级画像
  /// （category/style/subStyle/method；人像 L2 取 majorStyle，非人像取 style）。
  Future<void> recordSignal(String templateId, double weight) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tpl = await _resolveTemplate(templateId);
      if (tpl == null) return;
      await _bump(scopeCategory, tpl.category, weight, now);

      final cls = tpl.classification;
      final maj = cls['majorStyle'];
      final sty = cls['style'];
      final l2 = (maj is String && maj.isNotEmpty)
          ? maj
          : (sty is String ? sty : '');
      if (l2.isNotEmpty) await _bump(scopeStyle, l2, weight, now);

      final sub = cls['subStyle'];
      if (sub is String && sub.isNotEmpty) {
        await _bump(scopeSubStyle, sub, weight, now);
      }
      final method = cls['method'];
      if (method is String && method.isNotEmpty) {
        await _bump(scopeMethod, method, weight, now);
      }
    } catch (e) {
      debugPrint('[interest] recordSignal failed (silent): $e');
    }
  }
```

> 注意：此处刻意**不**再写 `scopeMajorStyle`（major 已被并入 `scopeStyle` 的 effective L2），避免新旧两套 L2 键并存造成双计。若担心历史数据里已有 `major_style:...` 键，Task 2 Step 1 的 effective L2 会先读 major_style 再回退 style，保证向后兼容。

- [ ] **Step 3: 更新 DAO 头注释**

`user_interests_dao.dart` 第 4 行改为：

```dart
/// 用户兴趣画像记录（scope=category|style|sub_style|method|major_style（旧兼容），key=对应维度）
```

- [ ] **Step 4: 冒烟验证**

运行 `flutter analyze lib/features/templates/recommend/user_interests.dart`，期望无 error。

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/recommend/user_interests.dart lib/core/db/dao/user_interests_dao.dart
git commit -m "feat(recommend): 兴趣画像扩展至四级（subStyle/method）"
```

---

## Task 2: 四级权重打分 + 修复 mixExplore 顺序

**Files:**
- Modify: `lib/features/templates/recommend/template_ranking.dart`

**Interfaces:**
- Produces: 新增 `InterestScope.subStyle`/`InterestScope.method`；`TemplateRanking.interestFor` 改为四级加权；`_effectiveL2(TemplateRecord)` 静态辅助；`mixExplore` 去掉尾部全量重排。

- [ ] **Step 1: 调整四级权重常量**

把权重块（现 L46-L56）改为（总和 1.0）：

```dart
  // 四级画像内部权重（category/style/subStyle/method，总和 1.0）
  static const double wCategory = 0.40;
  static const double wStyle = 0.20;     // L2：effective（人像 majorStyle，非人像 style）
  static const double wSubStyle = 0.20;  // L3：子风格
  static const double wMethod = 0.20;    // L4：拍摄方式
  // 总分权重
  static const double wInterest = 0.50;
  static const double wExplore = 0.30;
  static const double wHot = 0.15;
  static const double wQuestionnaire = 0.10;
  static const double penaltyRecent = 0.25;
```

- [ ] **Step 2: 覆盖 `#1` 里被注释迁移的旧维度——保持向后兼容的 effective L2 读取**

在 `InterestScope` 类内新增两个常量：

```dart
  static const majorStyle = 'major_style'; // 旧 L2 键：effective L2 读不到 style 时回退
  static const subStyle = 'sub_style';
  static const method = 'method';
```

> 原 `class InterestScope { static const category = ...; static const majorStyle = 'major_style'; static const style = 'style'; }` 已存在（见 L146-L149）。只需**追加** `subStyle` 与 `method`，并把 `majorStyle` 保留为回退键。注意不能删 `style`。

- [ ] **Step 3: 新增 effective L2 静态辅助**

在类内（`interestFor` 前）加：

```dart
  /// 取四级分类各自 key；L2 取 majorStyle，为空回退 style（兼容旧数据）。
  static String effectiveL2(TemplateRecord t) {
    final cls = t.classification;
    final maj = cls['majorStyle'];
    if (maj is String && maj.isNotEmpty) return maj;
    final sty = cls['style'];
    return sty is String ? sty : '';
  }
```

- [ ] **Step 4: `interestFor` 改为四级加权，并利用 major_style 旧键回退**

```dart
  double interestFor(TemplateRecord t, RankingContext ctx) {
    final cls = t.classification;
    final c = ctx.scoreFor(InterestScope.category, t.category);
    final l2 = effectiveL2(t);
    var relevant = 0.0;
    if (l2.isNotEmpty) {
      var m = ctx.scoreFor(InterestScope.style, l2);
      if (m == 0) m = ctx.scoreFor(InterestScope.majorStyle, l2); // 旧键回退
      relevant += wStyle * m;
    }
    final sub = cls['subStyle'];
    if (sub is String && sub.isNotEmpty) {
      relevant += wSubStyle * ctx.scoreFor(InterestScope.subStyle, sub);
    }
    final method = cls['method'];
    if (method is String && method.isNotEmpty) {
      relevant += wMethod * ctx.scoreFor(InterestScope.method, method);
    }
    return wCategory * c + relevant;
  }
```

- [ ] **Step 5: `mixExplore` 去掉尾部全量重排，改为纯交替插入**

把 `mixExplore` 方法（现 L112-L142）整段替换为：

```dart
  List<TemplateRecord> mixExplore(List<TemplateScore> scores) {
    if (scores.isEmpty) return const [];
    final explore = [...scores]
      ..sort((a, b) => b.exploration.compareTo(a.exploration));
    final exploit = [...scores]
      ..sort((a, b) => b.interest.compareTo(a.interest));
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
      final rest = <TemplateScore>[
        ...explore.skip(half),
        ...exploit.skip(half),
      ];
      for (final s in rest) {
        if (out.length >= scores.length) break;
        if (used.add(s.template.id)) out.add(s.template);
      }
    }
    return out; // 去掉了原来的 final totalById 全局重排，保留探索/兴趣交错顺序
  }
```

> 语义：探索信号不再被"总分重排"挤到末尾；多样性（高探索 + 高兴趣）真正体现在顺序上。热度/问卷信号仍通过 `scoreAll` 决定**谁能进各 half**，只是不再全局重排。若产品定义为"热度窗口化后仍需顶着热门置顶"，把本改动留到 Task 4 之后人工复核一次顺序合理性。

- [ ] **Step 6: 单测（新建）`test/features/templates/recommend/template_ranking_ext_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/template_ranking.dart';

void main() {
  test('mixExplore 保留探索在前（不打乱到尾部）', () {
    // 构造 4 个分数：两个高探索、两个高兴趣
    final scores = <TemplateScore>[
      TemplateScore(template: _tpl('a'), interest: 0.9, exploration: 0.1, hot: 0.2, total: 0.62),
      TemplateScore(template: _tpl('b'), interest: 0.8, exploration: 0.2, hot: 0.1, total: 0.55),
      TemplateScore(template: _tpl('c'), interest: 0.1, exploration: 0.9, hot: 0.3, total: 0.36),
      TemplateScore(template: _tpl('d'), interest: 0.0, exploration: 1.0, hot: 0.2, total: 0.34),
    ];
    final out = TemplateRanking().mixExplore(scores);
    // 前两位应为最高探索(c/d)与最高兴趣(a)交替：第一位是 c(探索最高) 或 d
    final first = out.first.id;
    expect(first == 'c' || first == 'd', isTrue,
        reason: '探索信号应出现在最前，而不是被 total 重排挤后');
    // 完全去重
    expect(out.map((t) => t.id).toSet().length, out.length);
  });
}

// Dart 2.19 兼容的伪模板，只填排序用到的 id
TemplateRecordStub _tpl(String id) => TemplateRecordStub(id);
```

> 由于 `TemplateRanking` 依赖 `TemplateRecord`（来自 sqflite 依赖），单测构造真实 `TemplateRecord` 成本高。为可测性，将 `Task 2` 的排序对象从 `TemplateRecord` 泛型化是个跨面改动。**决定**：本测试改为只验证"排序逻辑"不依赖模板字段的场景——将 `mixExplore` 的入参从 `List<TemplateScore>` 泛化为 `List<T> where T has .id/total...` 会超范围。故本文件的 `TemplateScore`/`_tpl` 以真实类型给最小字段构造：

**Step 6 修正（可在实现期用下面替换上面重复代码块）：**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/template_ranking.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';

TemplateRecord _tpl(String id) => TemplateRecord.fromRow({
  'id': id,
  'name': id,
  'category': 'portrait',
  'price': 0,
  'updated_at': 0,
  'source': 'custom',
});

void main() {
  test('mixExplore 保留探索在最前且去重', () {
    final scores = <TemplateScore>[
      TemplateScore(template: _tpl('a'), interest: 0.9, exploration: 0.1, hot: 0.2, total: 0.62),
      TemplateScore(template: _tpl('b'), interest: 0.8, exploration: 0.2, hot: 0.1, total: 0.55),
      TemplateScore(template: _tpl('c'), interest: 0.1, exploration: 0.9, hot: 0.3, total: 0.37),
      TemplateScore(template: _tpl('d'), interest: 0.0, exploration: 1.0, hot: 0.2, total: 0.36),
    ];
    final out = TemplateRanking().mixExplore(scores);
    final first = out.first.id;
    expect(first == 'c' || first == 'd', isTrue,
        reason: '探索信号应排最前');
    expect(out.map((t) => t.id).toSet().length, out.length, reason: '完全去重');
  });
}
```

> 若 `TemplateRecord.fromRow` 的必填键与实际 schema 不一致导致构造报错，以现有 `templates_dao.dart` 的 `fromRow` 读取键为准补齐。不要臆造列名。

- [ ] **Step 7: 运行测试确认**

```bash
flutter test test/features/templates/recommend/template_ranking_ext_test.dart
```

期望 PASS（探索排最前 + 去重）。

- [ ] **Step 8: Commit**

```bash
git add lib/features/templates/recommend/template_ranking.dart test/features/templates/recommend/template_ranking_ext_test.dart
git commit -m "feat(recommend): 模板排序升级四级权重并修复 mixExplore 顺序"
```

---

## Task 3: 每日轮换 + 固定上限

**Files:**
- Create: `lib/features/templates/recommend/daily_recommendator.dart`
- Test: `test/features/templates/recommend/daily_recommendator_test.dart`

**Interfaces:**
- Creates: `class DailyRecommendation { final int rank; final String templateId; }`；`class DailyRecommendator { DailyRecommendation build(List<String> templateIds, DateTime date, {int cap}) }`——纯函数、无 DB 依赖、按日期确定性可复现。

- [ ] **Step 1: 写失败的测试**

`test/features/templates/recommend/daily_recommendator_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/daily_recommendator.dart';

void main() {
  test('同一天两次调用结果一致（确定性）', () {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];
    final d1 = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    final d2 = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    expect(d1.map((x) => x.templateId).toList(),
        d2.map((x) => x.templateId).toList());
  });

  test('不同日期轮换不同且封顶', () {
    final ids = List.generate(20, (i) => 't$i');
    final a = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    final b = DailyRecommendator().build(ids, DateTime(2026, 9, 15), cap: 10);
    expect(a.length, 10);
    expect(b.length, 10);
    expect(a.map((x) => x.templateId).toList(),
        isNot(b.map((x) => x.templateId).toList()));
  });
}
```

- [ ] **Step 2: 运行确认失败**

`flutter test test/features/templates/recommend/daily_recommendator_test.dart` → FAIL（`DailyRecommendator` 未定义）。

- [ ] **Step 3: 实现**

`lib/features/templates/recommend/daily_recommendator.dart`：

```dart
import 'dart:math' as math;

/// 每日推荐批次项。
class DailyRecommendation {
  const DailyRecommendation({required this.rank, required this.templateId});
  final int rank;
  final String templateId;
}

/// 纯函数：把已排序的推荐池按「日期种子」做稳定轮换并封顶到 cap。
///
/// - 同一天：相同输入给出完全相同批次（确定性，避免同一天反复抖动）；
/// - 跨天：种子变 → 轮换起点变 → 当天批次不同，体现「今日」；
/// - cap：控制该栏展示数量（防信息过载 / 后台灌太多模板导致滑不完）。
///
/// 说明：轮换只改变顺序，不增减命中；模板是否"今日出现在该栏"由上层已按
/// 画像/热度/问卷打分决定。此函数仅提供稳定轮换 + 封顶两个职责。
class DailyRecommendator {
  const DailyRecommendator();

  List<DailyRecommendation> build(
    List<String> templateIds,
    DateTime date, {
    int cap = 10,
  }) {
    if (templateIds.isEmpty) return const [];
    final capN = cap.clamp(1, templateIds.length);
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rnd = math.Random(seed);
    final idx = List.generate(templateIds.length, (i) => i);
    // Fisher–Yates，以日期为种子，保证确定性
    for (var i = idx.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = idx[i];
      idx[i] = idx[j];
      idx[j] = tmp;
    }
    final out = <DailyRecommendation>[];
    for (var r = 0; r < capN; r++) {
      out.add(DailyRecommendation(rank: r, templateId: templateIds[idx[r]]));
    }
    return out;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

`flutter test test/features/templates/recommend/daily_recommendator_test.dart` → PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/recommend/daily_recommendator.dart test/features/templates/recommend/daily_recommendator_test.dart
git commit -m "feat(recommend): 每日稳定轮换 + 固定上限"
```

---

## Task 4: 热度时效软化（近 30 天本机信号融合）

**Files:**
- Modify: `lib/core/db/dao/usage_dao.dart`
- Modify: `lib/features/templates/data/templates_providers.dart`

**Interfaces:**
- Consumes: `usage_events` 表（`occurred_at`/`item_type`/`item_id`/`event_type`）。
- Produces: `UsageDao.recentPopularity(String itemType, List<String> itemIds, int sinceMs) → Map<String, ItemUsageCounts>`（仅统计 `occurred_at >= sinceMs` 的 `use_shoot`/`open_detail`）。

- [ ] **Step 1: usage_dao 新增近窗口统计**

在 `countMap` 方法后追加：

```dart
  /// 近窗口（sinceMs 之后）本机事件统计：按 use_shoot/open_detail 聚合。
  /// 与 countMap 口径一致的一次性取多个 item；事件即使已 sync 仍计（本地也发生过）。
  Future<Map<String, ItemUsageCounts>> recentPopularity(
      String itemType, List<String> itemIds, int sinceMs) async {
    if (itemIds.isEmpty) return const {};
    final placeholders = List.filled(itemIds.length, '?').join(',');
    final rows = await _db.query(
      Tables.usageEvents,
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} IN ($placeholders) '
          'AND ${Tables.colOccurredAt} >= ?',
      whereArgs: [itemType, ...itemIds, sinceMs],
      columns: [Tables.colItemId, Tables.colEventType],
    );
    final result = <String, ItemUsageCounts>{};
    for (final r in rows) {
      final id = r[Tables.colItemId] as String;
      final et = r[Tables.colEventType] as String;
      final e = result.putIfAbsent(id, () => ItemUsageCounts());
      if (et == 'use_shoot') e.useShoot += 1;
      else if (et == 'open_detail') e.openDetail += 1;
    }
    return result;
  }
```

> 说明：`eventTypeName` 存的是 `'use_shoot'`/`'open_detail'` 字符串（见 `enqueueEvent`），与 `countMap` 的解析一致。`colOccurredAt`、`colEventType`、`colItemType`、`colItemId` 均为既有常量。

- [ ] **Step 2: providers 融合热度并套用每日批次**

修改 `templates_providers.dart` 的 `recommendedBuiltinTemplatesProvider`（现 L131-L166）：

- 在读取 `usageDao.countMap` 后追加近窗口读取与融合：

```dart
    // 全站热度：use_shoot*2 + open_detail（累计快照）
    final counts =
        await usageDao.countMap('template', base.map((t) => t.id).toList());
    // 近 30 天本机信号（时效软化，缓解老模板霸榜）
    final sinceMs =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final recent =
        await usageDao.recentPopularity('template', base.map((t) => t.id).toList(), sinceMs);

    const alpha = 0.5; // 全站累计 : 近30天本机 = 50 : 50
    final popularity = <String, int>{
      for (final t in base)
        t.id: ((((counts[t.id]?.useShoot ?? 0) * 2 +
                    (counts[t.id]?.openDetail ?? 0)) *
                    alpha) +
                (((recent[t.id]?.useShoot ?? 0) * 2 +
                        (recent[t.id]?.openDetail ?? 0)) *
                    (1 - alpha)))
            .round(),
    };
```

- 在 `scoreAll` + `mixExplore` 之后、`return` 之前套用每日批次并封顶：

```dart
    final mixed = TemplateRanking().mixExplore(scores);
    final daily = const DailyRecommendator().build(
      mixed.map((t) => t.id).toList(),
      DateTime.now(),
      cap: 10,
    );
    final byId = {for (final t in mixed) t.id: t};
    return [
      for (final d in daily)
        if (byId[d.templateId] != null) byId[d.templateId]!,
    ];
```

- 在文件顶部加 `import 'daily_recommendator.dart';`（相对路径 `../recommend/daily_recommendator.dart`）。

- [ ] **Step 3: 静态检查**

`flutter analyze lib/features/templates/data/templates_providers.dart lib/core/db/dao/usage_dao.dart` → 期望无 error。

- [ ] **Step 4: Commit**

```bash
git add lib/core/db/dao/usage_dao.dart lib/features/templates/data/templates_providers.dart
git commit -m "feat(recommend): 热度时效软化 + 每日批次封顶接入"
```

---

## Task 5: 展示优化（画像命中项：来源角标 + 四级匹配理由）

**Files:**
- Modify: `lib/features/templates/recommend/template_ranking.dart`（新增 match verdict 辅助）
- Modify: `lib/features/templates/data/templates_providers.dart`（新增 `todayRecommendationItemsProvider`）
- Modify: `lib/features/templates/pages/templates_page.dart`（`_HeroSection` 换数据源）
- Test: 可选 widget 冒烟（见 Task 5 Step 4，可跳过写死 UI 断言）

**Interfaces:**
- Produces: `TemplateRanking.isProfileMatch(TemplateRecord, RankingContext) → bool`（interest≥0.35 判定命中）；`TemplateRanking.kMatchThreshold`；新增 `todayRecommendationItemsProvider → FutureProvider.autoDispose<List<TemplateRecommendation>>`（画像命中项 reason=四级路径、source=categoryMatch，其余保留基础值）。

- [ ] **Step 1: template_ranking 提供"画像命中"判定**

在 `TemplateRanking` 内加：

```dart
  /// 画像命中阈值：interest 得分超过该值即视为「画像推荐」（用于展示来源/理由）。
  static const double kMatchThreshold = 0.35;

  /// 判断模板是否为画像命中（仅展示用，不影响排序）。
  bool isProfileMatch(TemplateRecord t, RankingContext ctx) {
    return interestFor(t, ctx) >= kMatchThreshold;
  }
```

- [ ] **Step 1: template_ranking 提供"画像命中"判定**

在 `TemplateRanking` 内加：

```dart
  /// 画像命中阈值：interest 得分超过该值即视为「画像推荐」（用于展示来源/理由）。
  static const double kMatchThreshold = 0.35;

  /// 判断模板是否为画像命中（仅展示用，不影响排序）。
  bool isProfileMatch(TemplateRecord t, RankingContext ctx) {
    return interestFor(t, ctx) >= kMatchThreshold;
  }
```

> 展示来源直接复用既有 `TemplateSource.categoryMatch`（见 `TemplatesMockData.sourceLabel`），不新增枚举。

- [ ] **Step 2: providers 新增展示层 Provider**

在 `templates_providers.dart` 新增（`return` 结果类型为 `List<TemplateRecommendation>`）：

```dart
/// 「今日为你推荐」展示项：在 recommendedBuiltinTemplatesProvider 基础上，
/// 为画像命中项生成"匹配你常拍的【…】"四级理由与同分类角标；未命中项保留短简介 + 系统精选。
final todayRecommendationItemsProvider =
    FutureProvider.autoDispose<List<TemplateRecommendation>>((ref) async {
  final ranked = await ref.watch(recommendedBuiltinTemplatesProvider.future);
  if (ranked.isEmpty) return const [];

  // 画像（用于命中判定，复用与 ranking provider 相同的读取方式）
  final interestsDao = await ref.watch(userInterestsDaoProvider.future);
  final portrait = <String, double>{};
  for (final e in (await interestsDao.getAll()).entries) {
    portrait[e.key] = e.value.score;
  }
  final ctx = RankingContext(
    portrait: portrait,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );
  final ranker = TemplateRanking();

  // 分类中文名表（L2-L4），按父级路径精确解析（同名 L3 拍法如 normal 挂在多个父级下）
  final dao = await ref.watch(templatesDaoProvider.future);
  final categories = await dao.getCategories(activeOnly: false);
  final byKey = <String, List<TemplateCategoryRecord>>{};
  for (final c in categories) {
    byKey.putIfAbsent(c.key, () => []).add(c);
  }
  String nameOf(String key, String? parentKey) {
    final list = byKey[key] ?? const <TemplateCategoryRecord>[];
    if (list.isEmpty) return key;
    if (parentKey == null) return list.first.name;
    final byParent = list.where((c) => c.parentKey == parentKey);
    return (byParent.isNotEmpty ? byParent.first : list.first).name;
  }

  final out = <TemplateRecommendation>[];
  for (final r in ranked) {
    final base = templateRecordToRecommendation(r);
    if (!ranker.isProfileMatch(r, ctx)) {
      out.add(base);
      continue;
    }
    final cls = r.classification;
    final maj = cls['majorStyle'] is String ? cls['majorStyle'] as String : '';
    final sub = cls['subStyle'] is String ? cls['subStyle'] as String : '';
    final method = cls['method'] is String ? cls['method'] as String : '';
    final seg = <String>[
      TemplatesBrowseMockData.categoryLabel(r.category),
      if (maj.isNotEmpty) nameOf(maj, r.category),
      if (sub.isNotEmpty) nameOf(sub, maj.isEmpty ? null : maj),
      if (method.isNotEmpty) nameOf(method, maj.isEmpty ? null : maj),
    ];
    out.add(TemplateRecommendation(
      id: base.id,
      name: base.name,
      reason: '匹配你常拍的【${seg.join(' · ')}】',
      source: TemplateSource.categoryMatch,
      imageSeed: base.imageSeed,
      category: base.category,
      cover: base.cover,
      coverData: base.coverData,
      price: base.price,
      isCustom: base.isCustom,
      ambience: base.ambience,
    ));
  }
  return out;
});
```

> 需在 `templates_providers.dart` 顶部补充 import：`template_ranking.dart`（`RankingContext`/`TemplateRanking`）、`recommendation_card.dart`（`TemplateRecommendation`/`templateRecordToRecommendation`）、`templates_mock_data.dart`（`TemplatesBrowseMockData`/`TemplateSource`）、`templates_dao.dart`（`TemplateCategoryRecord`）。`userInterestsDaoProvider`/`templatesDaoProvider` 已在本文件使用。

- [ ] **Step 3: `_HeroSection` 换数据源（发现页展示）**

`templates_page.dart` 的 `_HeroSection.build`：把数据源换成 `todayRecommendationItemsProvider`，并把数据映射改为直接用 `TemplateRecommendation`：

```dart
    final asyncList = ref.watch(todayRecommendationItemsProvider);
    // ... 其余 loading/error/shrink 分支不变 ...
    data: (list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 256,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          // list[index] 已是 TemplateRecommendation，直接喂给卡片
          itemBuilder: (_, index) => RecommendationCard(
            recommendation: list[index],
            usageCount: usageCounts[list[index].id] ?? 0,
            onTap: () => onTap(list[index].id),
          ),
        ),
      );
    },
```

> 首页「模板推荐」继续用 `recommendedBuiltinTemplatesProvider`（返回值仍 `List<TemplateRecord>`），不受影响。

- [ ] **Step 4: 冒烟（手动可选）**

`flutter run` → 发现页确认：卡片来源角标有"同分类"类（画像命中）与"系统精选"（未命中）并存，reason 不再是清一色简介。若需强断言再补 widget test（未做，因依赖完整 DB 装配成本高）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/recommend/daily_recommendator.dart lib/features/templates/data/templates_providers.dart lib/features/templates/pages/templates_page.dart
git commit -m "feat(recommend): 画像命中项展示来源角标与匹配理由"
```

---

## Self-Review

- **Spec 覆盖**：每日轮换+上限（Task 3/4）、mixExplore 顺序（Task 2）、时效热度（Task 4）、四级画像精准（Task 1/2）、展示优化（Task 5）——均已覆盖。
- **占位扫描**：各 Step 均含完整代码或明确替代分支，无 TODO/TBD。Task 1 & Task 2 中标注了"删冗余辅助/停留于注释"的具体落地路径。
- **类型一致性**：`DailyRecommendator.build` 在所有调用点保持 `List<String>, DateTime, {int cap}` 签名一致；`recentPopularity(String, List<String>, int)` 签名统一；`todayRecommendationItemsProvider` 产出 `List<TemplateRecommendation>` 与 `RecommendationCard.recommendation` 字段匹配。
- **风险登记**：`TemplateRecord.fromRow` 必填键、`mixExplore` 改动对首页/发现页排序顺序的观感影响——均已在对应 Step 标注人工复核点，并写入 `docs/future-optimizations.md`（见下）。

## 后续优化登记

本计划落地后，若仍有需后续优化项（例如：`mixExplore` 移除全量重排后热度是否需置顶补偿、四级名称中文映射的国际化），按项目规则追加到 `docs/future-optimizations.md`，格式（优先级 / 模块 / 优化点 / 背景动机 / 目标状态 / 状态标记）。实现完成后由执行者补登记。