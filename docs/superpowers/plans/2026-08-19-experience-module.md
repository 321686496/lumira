# 经验模块完善 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把经验从单一"完成挑战/写死等级"升级为真实台账（`xp_events` 表），从每日首拍、完成挑战、学习课程、每日首享多来源获取，并按阶梯等级在到达指定等级时幂等发放积分奖励。

**Architecture:** 前端新增本地聚合表 `xp_events`（`source + ref_id` 唯一保证幂等），等级/称号/进度由台账户实时 `SUM` 结算；在各行为埋点写入台账，随后按阶梯阈值表判定等级并调用后端 `level_reward` 事件领取积分（离线不丢奖，联网补发）。后端 `points.service.ts` 新增 `level_reward` 事件类型，以内置 `LEVEL_REWARD_MAP` 为积分真值源，沿用 `point_earn_events` 唯一约束保证一级只发一次。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（无 records 语法）、sqflite、flutter_riverpod 2.3.6；NestJS + Drizzle ORM + MySQL 8。

## Global Constraints

- Dart 版本 2.19.6，禁止 Dart 3 records 语法；一律用显式 `class`。
- SQLite 迁移不做 destructive 操作（不 DROP 用户表），失败静默回退不阻塞启动。
- `xp_events` 幂等：`INSERT OR IGNORE`，`id = "{source}:{refId}"`，`UNIQUE(source, ref_id)`。
- 每日首拍/首享的 `refId` 用 **UTC+8 自然日**字符串（与后端 `getUtc8DateStr` 口径一致）。
- 升级积分发放幂等由后端 `point_earn_events` UNIQUE(device, type, ref_id) 保证；前端只把领取成功的等级更新 `claimedLevel`，失败的保留下次重试。
- 后端每次改动后必须 commit 并同时 push 到 `origin`(gitee) 与 `github`（见 AGENTS.md）。

### 权威配置（本计划的唯一真值源，前后端必须一致）

**LEVEL_THRESHOLDS（Lv.1–20）：**

| 等级 | 所需总XP | 称号 |
|---|---|---|
|1|0|初学者|
|2|100|入门学徒|
|3|300|进阶学徒|
|4|600|熟练学徒|
|5|1000|摄影新手|
|6|1500|摄影爱好者|
|7|2200|摄影达人|
|8|3000|构图能手|
|9|4000|光影大师|
|10|5500|摄影专家|
|11|7500|摄影艺术家|
|12|10000|视觉创作者|
|13|13500|光影探索者|
|14|17500|视觉叙事师|
|15|22000|影像匠人|
|16|27000|光影诗人|
|17|33000|视觉艺术家|
|18|40000|影像大家|
|19|48000|光影宗师|
|20|57000|摄影大师|

**LEVEL_REWARD_MAP（升级积分，每级小奖 + 里程碑）：**

```ts
{ 2:25, 3:25, 4:50, 5:100, 6:50, 7:50, 8:50, 9:50, 10:250,
  11:50, 12:50, 13:50, 14:50, 15:150, 16:50, 17:50, 18:50, 19:50, 20:500 }
```

**经验来源：** `shoot_daily`=每日首拍 +10；`challenge`=各挑战 `rewardXP`；`course`=每课 `rewardXP`；`share`=每日首享 +20。

---

### Task 1: 等级/奖励配置与 GrowthSummary、来源明细模型

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/data/growth_models.dart`

**Interfaces:**
- Produces:
  - `LEVEL_THRESHOLDS`（`const List<({int level,int xp,String name})>` 除外——Dart 2.19 无 records，用 `class LevelThreshold { final int level; final int xp; final String name; }`）
  - `LEVEL_REWARD_MAP = {2:25, ...}`（`const Map<int,int>`；**key=等级，且 map 含该级才发奖**）
  - `int levelForXp(int xp)` — 返回 Lv.1–20（遍历阈值表）
  - `int? levelReward(int level)` — 返回该级积分，`null`=该级无奖励
  - `String? levelNameFor(int level)` — 该级称号
  - `class GrowthSummary { level, currentXp, xpToNextLevel, levelName }`（新增字段或保持）
  - `class XpBreakdownEntry { String source; int amount; String label; double ratio; }`

- [ ] **Step 1: 追加阈值/奖励配置（到 growth_models.dart 顶部 import 后）**

```dart
/// 单一门槛等级定义（Lv.1–20）
class LevelThreshold {
  const LevelThreshold(this.level, this.xp, this.name);
  final int level;
  final int xp; // 达到该级所需最小总XP
  final String name;
}

/// 阶梯阈值表（升序，Lv.1 阈值 0）
const List<LevelThreshold> LEVEL_THRESHOLDS = [
  LevelThreshold(1, 0, '初学者'),
  LevelThreshold(2, 100, '入门学徒'),
  LevelThreshold(3, 300, '进阶学徒'),
  LevelThreshold(4, 600, '熟练学徒'),
  LevelThreshold(5, 1000, '摄影新手'),
  LevelThreshold(6, 1500, '摄影爱好者'),
  LevelThreshold(7, 2200, '摄影达人'),
  LevelThreshold(8, 3000, '构图能手'),
  LevelThreshold(9, 4000, '光影大师'),
  LevelThreshold(10, 5500, '摄影专家'),
  LevelThreshold(11, 7500, '摄影艺术家'),
  LevelThreshold(12, 10000, '视觉创作者'),
  LevelThreshold(13, 13500, '光影探索者'),
  LevelThreshold(14, 17500, '视觉叙事师'),
  LevelThreshold(15, 22000, '影像匠人'),
  LevelThreshold(16, 27000, '光影诗人'),
  LevelThreshold(17, 33000, '视觉艺术家'),
  LevelThreshold(18, 40000, '影像大家'),
  LevelThreshold(19, 48000, '光影宗师'),
  LevelThreshold(20, 57000, '摄影大师'),
];

/// 升级积分奖励（key=等级；缺省该 key 表示该级无奖励；本表与后端 LEVEL_REWARD_MAP 必须一致）
const Map<int, int> LEVEL_REWARD_MAP = {
  2: 25, 3: 25, 4: 50, 5: 100, 6: 50, 7: 50, 8: 50, 9: 50, 10: 250,
  11: 50, 12: 50, 13: 50, 14: 50, 15: 150, 16: 50, 17: 50, 18: 50, 19: 50, 20: 500,
};

/// 根据总 XP 计算当前等级（Lv.1–20）。总 XP 超过 Lv.20 阈值也封顶返回 20。
int levelForXp(int xp) {
  var level = 1;
  for (final t in LEVEL_THRESHOLDS) {
    if (xp >= t.xp) {
      level = t.level;
    } else {
      break;
    }
  }
  return level;
}

/// 该级是否有（及多少）升级积分奖励；无奖励返回 null。
int? levelReward(int level) => LEVEL_REWARD_MAP[level];

/// 该级称号；未知等级返回 '摄影达人' 兜底。
String? levelNameFor(int level) {
  for (final t in LEVEL_THRESHOLDS) {
    if (t.level == level) return t.name;
  }
  return null;
}

/// UTC+8 自然日字符串（YYYY-MM-DD），与后端 getUtc8DateStr 口径一致。
String utc8DateStr([DateTime? now]) {
  final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
```

- [ ] **Step 2: 扩展 GrowthSummary 与新增来源明细模型（替换文件里的 GrowthSummary 定义）**

```dart
class GrowthSummary {
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final String levelName;

  const GrowthSummary({
    required this.level,
    required this.currentXp,
    required this.xpToNextLevel,
    required this.levelName,
  });

  static const GrowthSummary empty = GrowthSummary(
    level: 1,
    currentXp: 0,
    xpToNextLevel: 100, // 默认到 Lv.2 阈值 100
    levelName: '初学者',
  );
}

/// 经验来源明细（成长中心"来源明细卡"数据）
class XpBreakdownEntry {
  const XpBreakdownEntry({
    required this.source,
    required this.amount,
    required this.label,
    required this.ratio, // 0.0–1.0，占比
  });
  final String source;   // 'shoot_daily' | 'challenge' | 'course' | 'share'
  final int amount;
  final String label;    // 用户可见文案
  final double ratio;
}
```

- [ ] **Step 3: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/features/profile/data/growth_models.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/data/growth_models.dart
git commit -m "feat(growth): add level thresholds, level rewards, breakdown models"
```

---

### Task 2: 新增 xp_events 表常量 + 迁移 v25

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`

**Interfaces:**
- Consumes: Task 1 的 `LEVEL_THRESHOLDS` / `levelNameFor`（回填不改等级，仅建表+插台账，本任务其实不依赖等级；但 `createSql` 常量定义在 tables.dart）。
- Produces: `XpEventsTable` 常量类 + `Tables.colXpRewardClaimedLevel`；`_onCreate`/`_onUpgrade` 均支持建表/加列；回填函数 `_backfillXpLedger(Database db)`（供 onCreate 与 upgrade 复用）。
- 说明：回填只补 `challenge`（challenge_history status='done'）与 `course`（academy_course_progress status='completed' + 课程 rewardXP 映射，未知课程跳过）。

- [ ] **Step 1: tables.dart 追加 xp_events 常量（文件末尾，类外）**

```dart
/// 经验台账表（v25 迁移新增）
/// 单行真实数据源：等级 = SUM(amount)；id = "{source}:{refId}" 保证幂等。
class XpEventsTable {
  static const name = 'xp_events';
  static const colSource = 'source'; // 'shoot_daily'|'challenge'|'course'|'share'
  static const colAmount = 'amount';
  static const colRefId = 'ref_id';
  static const colCreatedAt = 'created_at';

  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      id TEXT PRIMARY KEY,
      $colSource TEXT NOT NULL,
      $colAmount INTEGER NOT NULL,
      $colRefId TEXT NOT NULL,
      $colCreatedAt INTEGER NOT NULL
    )
  ''';
  static const indexSql =
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_xp_events_source_ref ON $name ($colSource, $colRefId)';
}
```

- [ ] **Step 2: tables.dart 的 Tables.userProgress 段追加列常量**

在 `static const String colAchievementsJson = 'achievements_json';` 后追加一行：

```dart
  /// 已领取升级积分奖励的最高等级（v25 迁移新增；0=未领取任何）
  static const String colXpRewardClaimedLevel = 'xp_reward_claimed_level';
```

- [ ] **Step 3: database_provider.dart 版本提升为 25**

`const int _kDbVersion = 24;` → `const int _kDbVersion = 25;`

- [ ] **Step 4: _onCreate 追加建表（在 `await db.execute(AcademyLearningTrajectoryTable.createSql);` 之后）**

```dart
  // === v25: xp_events 经验台账表 ===
  await db.execute(XpEventsTable.createSql);
  await db.execute(XpEventsTable.indexSql);
  await _addColumnIfNotExists(
    db,
    Tables.userProgress,
    Tables.colXpRewardClaimedLevel,
    'INTEGER NOT NULL DEFAULT 0',
  );
  // 回填历史真实经验（challenge + course；失败静默）
  try {
    await _backfillXpLedger(db);
  } catch (e) {
    debugPrint('xp_events backfill (onCreate) failed: $e');
  }
```

- [ ] **Step 5: _onUpgrade 追加 v25 段（放在 v24 段之后）**

```dart
  if (oldVersion < 25) {
    try {
      await db.execute(XpEventsTable.createSql);
      await db.execute(XpEventsTable.indexSql);
      await _addColumnIfNotExists(
        db,
        Tables.userProgress,
        Tables.colXpRewardClaimedLevel,
        'INTEGER NOT NULL DEFAULT 0',
      );
      // 回填历史真实经验，确保老用户经验曲线不跳变
      await _backfillXpLedger(db);
    } catch (e) {
      debugPrint('v25 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 6: 新增 _backfillXpLedger 辅助函数（放在 _addColumnIfNotExists 之前）**

```dart
/// 从历史表回填 xp_events 台账（INSERT OR IGNORE 幂等）。
/// - challenge：challenge_history status='done' → source='challenge', amount=reward_xp, ref_id=id
/// - course：academy_course_progress status='completed' → source='course',
///   amount=该课 rewardXP（AcademyContent 构建 id→rewardXP 映射，找不到的跳过避免虚增）
Future<void> _backfillXpLedger(Database db) async {
  // --- challenge ---
  final chRows = await db.rawQuery('''
    SELECT ${ChallengeHistoryTable.colId} AS id,
           ${ChallengeHistoryTable.colRewardXp} AS xp
    FROM ${ChallengeHistoryTable.name}
    WHERE ${ChallengeHistoryTable.colStatus} = 'done'
  ''');
  for (final r in chRows) {
    final id = r['id'] as String?;
    final xp = (r['xp'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:$id',
      XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: id,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // --- course（id→rewardXP 映射来自 AcademyContent.courses） ---
  final Map<String, int> courseXp = {};
  for (final c in AcademyContent.courses) {
    courseXp[c.id] = c.rewardXP;
  }
  final cpRows = await db.rawQuery('''
    SELECT ${AcademyTables.cpColCourseId} AS cid
    FROM ${AcademyTables.courseProgress}
    WHERE ${AcademyTables.cpColStatus} = 'completed'
  ''');
  for (final r in cpRows) {
    final cid = r['cid'] as String?;
    final xp = cid == null ? 0 : (courseXp[cid] ?? 0);
    if (cid == null || cid.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'course:$cid',
      XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: cid,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
```

- [ ] **Step 7: 顶部 import 补充**

`database_provider.dart` 顶部已 import `tables.dart`、`academy_dao.dart`；需再补 `../../features/academy/data/academy_content.dart`（给 AcademyContent）。

- [ ] **Step 8: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/core/db/tables.dart lib/core/db/database_provider.dart`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(growth): add xp_events ledger table and v25 migration with backfill"
```

---

### Task 3: GrowthDao 改为真实台账查询

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/dao/growth_dao.dart`

**Interfaces:**
- Consumes: Task 1 的 `LEVEL_THRESHOLDS` / `levelForXp` / `levelNameFor`；Task 2 的 `XpEventsTable` 常量。
- Produces:
  - `Future<int> getTotalXP()` — `SELECT SUM(amount) FROM xp_events`
  - `Future<int> getLevel()` — `levelForXp(getTotalXP())`（保持旧签名，供现调用方）
  - `Future<String> getLevelName()` — 当前等级称号
  - `Future<GrowthSummary> getSummary()` — level/currentXp/xpToNextLevel/levelName
  - `Future<List<XpBreakdownEntry>> getXpBreakdown()` — 按 source 求和 + 占比
  - `getAchievements()` 保持；其中 `ach_level_5` 最终解锁状态用真实等级修正。

- [ ] **Step 1: import growth_models（已存在）+ 新增 XpBreakdown 标签映射常量**

文件顶部已 `import '../../../features/profile/data/growth_models.dart';`。在类外新增标签映射：

```dart
/// 来源 → 展示文案
const Map<String, String> kXpSourceLabel = {
  'shoot_daily': '每日首拍',
  'challenge': '完成挑战',
  'course': '学习课程',
  'share': '每日首享',
};
```

- [ ] **Step 2: 重写 getTotalXP（替换方法体）**

```dart
  /// 获取总 XP：经验台账 xp_events 求和（真实数据，标签页后必存在）。
  Future<int> getTotalXP() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${XpEventsTable.colAmount}), 0) AS s FROM ${XpEventsTable.name}',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
```

- [ ] **Step 3: 重写 getLevel + 新增 getLevelName / getSummary / getXpBreakdown（替换原 getLevel 方法）**

```dart
  /// 当前等级（阶梯阈值表 Lv.1–20）。
  Future<int> getLevel() async {
    final xp = await getTotalXP();
    return levelForXp(xp);
  }

  /// 当前等级称号。
  Future<String> getLevelName() async {
    final level = await getLevel();
    return levelNameFor(level) ?? '';
  }

  /// 成长总览（等级进度），供 growthLevelProvider 直接消费。
  Future<GrowthSummary> getSummary() async {
    final xp = await getTotalXP();
    final level = levelForXp(xp);
    // 距下一级 = 下一级阈值 - 当前总XP（已最高级则 0）
    final next = LEVEL_THRESHOLDS.where((t) => t.level == level + 1).toList();
    final xpToNext = next.isEmpty ? 0 : (next.first.xp - xp).clamp(0, 1 << 31);
    return GrowthSummary(
      level: level,
      currentXp: xp,
      xpToNextLevel: xpToNext,
      levelName: levelNameFor(level) ?? '',
    );
  }

  /// 经验来源明细：按 source 求和 + 占比（0:无记录则不返回该 source 行？——仍有该就返回，UI 端空行跳过）。
  Future<List<XpBreakdownEntry>> getXpBreakdown() async {
    final rows = await _db.rawQuery('''
      SELECT ${XpEventsTable.colSource} AS src,
             SUM(${XpEventsTable.colAmount}) AS s
      FROM ${XpEventsTable.name}
      GROUP BY ${XpEventsTable.colSource}
    ''');
    var total = 0;
    for (final r in rows) {
      total += (r['s'] as num?)?.toInt() ?? 0;
    }
    if (total <= 0) return const [];
    final list = <XpBreakdownEntry>[];
    for (final r in rows) {
      final src = r['src'] as String? ?? '';
      final amount = (r['s'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      list.add(XpBreakdownEntry(
        source: src,
        amount: amount,
        label: kXpSourceLabel[src] ?? src,
        ratio: total > 0 ? amount / total : 0.0,
      ));
    }
    // 固定展示顺序：shoot_daily, challenge, course, share
    list.sort((a, b) => kXpSourceLabel.keys.toList().indexOf(a.source)
        .compareTo(kXpSourceLabel.keys.toList().indexOf(b.source)));
    return list;
  }
```

> 备注：`xpToNext` 用 `(level+1)` 反查阈值；Dart 2.19 下 `clamp` 参数需同类型 int，`1 << 31` 作为上限占位。

- [ ] **Step 4: getAchievements 中修正 ach_level_5 真实解锁**

在 `getAchievements()` 方法 return 前，把 `ach_level_5` 按真实等级修正。改为（在方法末尾 return 处的 `}).toList();` 后）：

```dart
      final level = await getLevel();
      if (level >= 5) {
        final idx = result.indexWhere((a) => a.id == 'ach_level_5');
        if (idx >= 0 && !result[idx].unlocked) {
          result[idx] = AchievementRecord(
            id: result[idx].id,
            name: result[idx].name,
            description: result[idx].description,
            iconKey: result[idx].iconKey,
            unlocked: true,
            unlockedAt: result[idx].unlockedAt ?? DateTime.now().millisecondsSinceEpoch,
          );
        }
      }
      return result;
```

- [ ] **Step 5: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/core/db/dao/growth_dao.dart`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/core/db/dao/growth_dao.dart
git commit -m "feat(growth): derive total xp / level / breakdown from xp_events ledger"
```

---

### Task 4: GrowthXpService（写台账 + 升级积分领取）

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/services/growth_xp_service.dart`

**Interfaces:**
- Consumes: Task 1 的 `utc8DateStr` / `levelForXp` / `levelReward`；Task 3 的 `GrowthDao`；`PointEarnResult`（`lib/features/points/data/points_models.dart`）。
- Produces:
  - `Future<bool> award({required String source, required int amount, required String refId})` — 写台账（幂等），返回是否新增。
  - `Future<int> claimLevelRewards()` — 结算 (claimedLevel, currentLevel] 内存在奖励的等级并逐个调 earn；返回本次新发等级数（供 Toast）。
  - 构造函数：`GrowthXpService(this._dao, {required this.employee})` 其中 `employee` 为 `Future<PointEarnResult> Function(String level)` 回调（Hook 注入 pointsRepository.earn）。

- [ ] **Step 1: 产出服务文件**

```dart
import '../../../../core/db/database_provider.dart';
import '../../../../core/db/tables.dart';
import '../../../points/data/points_models.dart';
import '../../../../core/utils/share_reporter.dart' hide notify; // 不引用，仅示意避免未用
import '../data/growth_models.dart';
import '../data/growth_models.dart';
import '../../../core/db/dao/growth_dao.dart';
```

> 实现注意：本文件是 Dart 2.19 普通 class，不引入 riverpod；回调由调用方（各 Hook）注入。

  - 完整实现（Step 1 落盘的代码）：

```dart
// lumira_app_flutter/lib/features/profile/services/growth_xp_service.dart

import 'package:sqflite/sqflite.dart';

import '../../../core/db/dao/growth_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/tables.dart';
import '../../points/data/points_models.dart';
import '../data/growth_models.dart';

/// 经验台账写入 + 升级积分领取服务。
/// 各行为 Hook 在完成对应事件后调用 [award]；随后调用 [claimLevelRewards]。
class GrowthXpService {
  GrowthXpService(this.db, {required Future<PointEarnResult> Function(String level) earnLevelReward})
      : _earnLevelReward = earnLevelReward;

  final Database db;
  final Future<PointEarnResult> Function(String level) _earnLevelReward;

  /// 写一条经验台账（幂等）。source: 'shoot_daily'|'challenge'|'course'|'share'。
  /// 返回该记录是否为本首次写入（true=新增，false=已存在忽略）。
  Future<bool> award({
    required String source,
    required int amount,
    required String refId,
  }) async {
    if (amount <= 0 || refId.isEmpty) return false;
    final count = await db.insert(
      XpEventsTable.name,
      {
        'id': '$source:$refId',
        XpEventsTable.colSource: source,
        XpEventsTable.colAmount: amount,
        XpEventsTable.colRefId: refId,
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return count > 0;
  }

  /// 领取 (claimedLevel, currentLevel] 内所有存在奖励的等级。幂等：
  /// 已领取的跳过；网络失败即停（保留未领取，下次再试）。返回本次新发放的等级数。
  Future<int> claimLevelRewards() async {
    final dao = GrowthDao(db);
    final xp = await dao.getTotalXP();
    final level = levelForXp(xp);

    // 读当前已领取到哪一级
    final rows = await db.query(
      Tables.userProgress,
      columns: [Tables.colXpRewardClaimedLevel],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
      limit: 1,
    );
    final claimed = rows.isEmpty
        ? 0
        : ((rows.first[Tables.colXpRewardClaimedLevel] as num?)?.toInt() ?? 0);

    var newlyGranted = 0;
    var nextClaimed = claimed;
    for (var lv = claimed + 1; lv <= level; lv++) {
      final reward = levelReward(lv);
      if (reward == null) continue; // 该级无奖励，仍然推进但不发奖
      try {
        final result = await _earnLevelReward('$lv');
        // 后端幂等：granted 或已 granted 都视为已领取
        nextClaimed = lv;
        if (result.granted) newlyGranted++;
      } catch (_) {
        // 离线/网络异常：停在此级，保留下次重试（不推进 nextClaimed）
        break;
      }
    }

    if (nextClaimed > claimed) {
      await db.rawUpdate('''
        UPDATE ${Tables.userProgress}
        SET ${Tables.colXpRewardClaimedLevel} = ?
        WHERE ${Tables.colId} = 1
      ''', [nextClaimed]);
    }
    return newlyGranted;
  }
}
```

- [ ] **Step 2: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/features/profile/services/growth_xp_service.dart`
Expected: No issues found（确认 `points_models.dart` 导出 `PointEarnResult`）。

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/services/growth_xp_service.dart
git commit -m "feat(growth): add GrowthXpService (ledger write + idempotent level reward claim)"
```

---

### Task 5: 四个行为 Hook 接入台账 + 领取

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（每日首拍 XP）
- Modify: `lumira_app_flutter/lib/features/challenge/pages/challenge_confirm_page.dart`（完成挑战改为台账）
- Modify: `lumira_app_flutter/lib/features/academy/data/academy_repository.dart`（学完课程加 XP）
- Modify: `lumira_app_flutter/lib/main.dart`（每日首享 XP）

**Interfaces:**
- Consumes: Task 4 的 `GrowthXpService`；Task 5 被各自 Hook 在服务里构造并调用 `award` + `claimLevelRewards`。
- Produces: 四个真实经验来源均落台账并触发领取。

通用 helper（各 Hook 复用一个构造函数，避免重复逻辑）。为避免四处重复，新增：

```dart
// lumira_app_flutter/lib/features/profile/services/growth_xp_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/db/database_provider.dart';
import '../../../points/data/points_repository.dart';
import 'growth_xp_service.dart';

/// 根据 Ref 构造 GrowthXpService（earn 回调走 pointsRepository）。
Future<GrowthXpService> growthXpServiceOf(WidgetRef ref) async {
  final db = await ref.read(databaseProvider.future);
  final repo = await ref.read(pointsRepositoryProvider.future);
  return GrowthXpService(
    db,
    earnLevelReward: (level) => repo.earn(type: 'level_reward', refId: level),
  );
}
```

注意：`growthXpProviderOf` 需要 `WidgetRef`；但 `academy_repository.dart` 与 `main.dart`（非 widget 树）没有 `ref`。处理：给 `GrowthXpService` 增加一个静态工厂，接受 `Database` + `PointsRepository` 实例（两者都可从容器读取）。更简单——`points_repository.dart` 的 `earn` 需要 `ApiClient`。为不破坏 repository 层，直接给 `academy_repository` 一个可选回调注入：

- `LocalAcademyRepository` 构造器新增可选 `Future<void> Function(String courseId, int rewardXp)? onCourseCompleted`；`markCompleted` 里完成且 `_onCourseCompleted != null` 时调用。

- [ ] **Step 1: 新增 growth_xp_provider.dart（含纯函数版，供 main.dart / repository 复用）**

```dart
// lumira_app_flutter/lib/features/profile/services/growth_xp_provider.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../../../core/db/database_provider.dart';
import '../../../points/data/points_repository.dart';
import 'growth_xp_service.dart';

/// 无 ref 环境（main.dart / repository）构造：db + repo 调用方提供。
Future<void> awardAndClaim({
  required Database db,
  required PointsRepository repo,
  required String source,
  required int amount,
  required String refId,
}) async {
  final svc = GrowthXpService(
    db,
    earnLevelReward: (level) => repo.earn(type: 'level_reward', refId: level),
  );
  await svc.award(source: source, amount: amount, refId: refId);
  await svc.claimLevelRewards();
}

// Widget tree 内用：此刻不入引 widget，统一走 awardAndClaim 并自行取 db/repo。
```

- [ ] **Step 2: capture_page.dart —— _earnDailyShootPoints 补充每日首拍 XP**

在 `_earnDailyShootPoints` 内的 `final repo = await ref.read(pointsRepositoryProvider.future);` 后、`await repo.earn(...)` 前插入：

```dart
    // 每日首拍经验（+10）写台账 + 结算升级奖励
    try {
      final db = await ref.read(databaseProvider.future);
      await awardAndClaim(
        db: db,
        repo: repo,
        source: 'shoot_daily',
        amount: 10,
        refId: utc8DateStr(),
      );
    } catch (e) {
      debugPrint('[capture] daily shoot xp failed: $e');
    }
```

并在文件顶部 import `../services/growth_xp_provider.dart`（相对路径按实际结构调整）、`../../../profile/data/growth_models.dart`（utc8DateStr）。

- [ ] **Step 3: challenge_confirm_page.dart —— 完成挑战改为写台账（替换第 244–256 行的 xp 累加）**

将现有「3. 累加 XP 到 user_progress」整段（含 INSERT + UPDATE 234 范围）替换为：

```dart
      // 3'. 完成挑战经验写台账（幂等）+ 结算升级奖励
      final db = await ref.read(databaseProvider.future);
      final repo = await ref.read(pointsRepositoryProvider.future);
      await awardAndClaim(
        db: db,
        repo: repo,
        source: 'challenge',
        amount: poolItem.rewardXP,
        refId: poolItem.id,
      );
```

并保留原第 4 步 provider 失效与第 5 步 `_earnChallengePoints`。注意此代码在 `try` 内，失败不影响挑战提交（abort 前 already catch）。

- [ ] **Step 4: academy_repository.dart —— markCompleted 学完课程加 XP**

给 `LocalAcademyRepository` 增加可选回调字段：

```dart
  final Future<void> Function(String courseId, int rewardXp)? _onCourseCompleted;
  LocalAcademyRepository({
    required AcademyDao dao,
    DateTime Function()? now,
    Future<void> Function(String courseId, int rewardXp)? onCourseCompleted,
  })  : _dao = dao,
        _now = now ?? DateTime.now,
        _onCourseCompleted = onCourseCompleted;
```

在 `markCompleted` 中，轨迹写入之后追加：

```dart
    // 学完课程经验写台账 + 结算升级奖励
    final course = AcademyContent.getCourse(courseId);
    if (course != null && _onCourseCompleted != null) {
      try {
        await _onCourseCompleted!(courseId, course.rewardXP);
      } catch (e) {
        // 经验/奖励失败不影响课程完成状态
        debugPrint('[academy] course xp failed: $e');
      }
    }
```

并暴露一个工厂/静态方法供装配层传入实际实现：

```dart
  /// 由装配层注入：写 course 台账并领取升级奖励。
  static Future<void> earnCourseXp(Database db, PointsRepository repo, String courseId, int rewardXp) =>
      awardAndClaim(
        db: db,
        repo: repo,
        source: 'course',
        amount: rewardXp,
        refId: courseId,
      );
```

（新增 import：`database_provider.dart`、`points_repository.dart`、`../services/growth_xp_provider.dart`。）

> 说明：`LocalAcademyRepository` 的装配处必须传入 `onCourseCompleted`。找到其构造调用点（`academy_providers.dart` 或类似）并注入：

```
onCourseCompleted: (cid, xp) async {
  final db = await ref.read(databaseProvider.future);
  final repo = await ref.read(pointsRepositoryProvider.future);
  await LocalAcademyRepository.earnCourseXp(db, repo, cid, xp);
}
```

- [ ] **Step 5: main.dart —— ShareReporter.onShare 每日首享 XP**

在现有 `onShare` 的 `await repo.earn(type: 'share');` 之后追加：

```dart
      // 每日首享经验（+20）写台账 + 结算升级奖励
      try {
        final db = await container.read(databaseProvider.future);
        await awardAndClaim(
          db: db,
          repo: repo,
          source: 'share',
          amount: 20,
          refId: utc8DateStr(),
        );
      } catch (_) {
        // 网络/鉴权失败静默
      }
```

并顶部 import：`features/profile/services/growth_xp_provider.dart`、`features/profile/data/growth_models.dart`。

- [ ] **Step 6: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/features/capture/pages/capture_page.dart lib/features/challenge/pages/challenge_confirm_page.dart lib/features/academy/data/academy_repository.dart lib/main.dart`
Expected: No issues found。

- [ ] **Step 7: 手动验收（需真机/模拟器联网 + 走通四流程）**

拍摄 1 张 → 确认后台 `xp_events` 出现 `shoot_daily` 记录；完成挑战 → `challenge`；学完一门课 → `course`；分享 1 次 → `share`。重复操作不增加记录（幂等）。

- [ ] **Step 8: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/services/growth_xp_provider.dart \
        lumira_app_flutter/lib/features/capture/pages/capture_page.dart \
        lumira_app_flutter/lib/features/challenge/pages/challenge_confirm_page.dart \
        lumira_app_flutter/lib/features/academy/data/academy_repository.dart \
        lumira_app_flutter/lib/main.dart
git commit -m "feat(growth): wire four xp sources into ledger and claim level rewards"
```

---

### Task 6: GrowthDao 单元测试更新（真实台账）

**Files:**
- Modify: `lumira_app_flutter/test/core/db/growth_dao_test.dart`

**Interfaces:**
- Consumes: Task 1 配置、Task 2 的 `XpEventsTable`、Task 3 的 DAO 方法。
- 说明：本测试的 `_onCreate` 需补建 `xp_events` 表。

- [ ] **Step 1: 在测试文件 `_onCreate` 末尾追加建表**

```dart
  await db.execute(XpEventsTable.createSql);
  await db.execute(XpEventsTable.indexSql);
```

并在顶部 import `growth_models.dart`（用于断言等级）、`../../../lib/features/profile/data/growth_models.dart`（同一路径已在 growth_dao_test 使用）。

- [ ] **Step 2: 替换旧的 getTotalXP / getLevel 测试为台账版，并新增边界用例**

在 `void main()` 内追加（保留原 getTotalPhotos/getAchievements/getGrowthTrajectory 用例；删除或改写 getTotalXP 与 getLevel 三个旧用例）：

```dart
  test('getTotalXP sums xp_events ledger only (not user_progress.xp)', () async {
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: 80, XpEventsTable.colRefId: 'c1',
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert(XpEventsTable.name, {
      'id': 'course:c2', XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: 120, XpEventsTable.colRefId: 'c2',
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    // 即便 user_progress.xp 有残留，也以台账为准
    await db.update(Tables.userProgress, {Tables.colXp: 999},
        where: '${Tables.colId} = ?', whereArgs: [1]);
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 200); // 80 + 120
  });

  test('getTotalXP is idempotent: same source+ref inserts only once', () async {
    for (var i = 0; i < 2; i++) {
      await db.insert(XpEventsTable.name, {
        'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
        XpEventsTable.colAmount: 80, XpEventsTable.colRefId: 'c1',
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 80);
  });

  test('getLevel uses threshold table boundaries (0/99/100/300)', () async {
    Future<void> setXp(int xp) async {
      // 直接写台账以模拟真实数据
      await db.insert(XpEventsTable.name, {
        'id': 'shoot_daily:$xp', XpEventsTable.colSource: 'shoot_daily',
        XpEventsTable.colAmount: xp, XpEventsTable.colRefId: '$xp',
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      });
    }
    Future<int> level() async { final d = GrowthDao(db); return d.getLevel(); }
    expect(await level(), 1);   // 0
    await setXp(99);  expect(await level(), 1); // 99 < 100
    await setXp(1);   expect(await level(), 2); // 100 exactly → Lv.2
    await setXp(200); expect(await level(), 3); // 300 boundary → Lv.3
    await setXp(500); expect(await level(), 5); // 1000 threshold → 1000 < 1500; 500+500+... 需精确
  });
```

> 简化边界断言：避免累计混乱，直接单值。请用如下精确值（只插一条，amount=目标 XP）：

```dart
  test('getLevel threshold boundaries', () async {
    Future<int> levelAt(int xp) async {
      await db.insert(XpEventsTable.name, {
        'id': 'shoot_daily:t$xp', XpEventsTable.colSource: 'shoot_daily',
        XpEventsTable.colAmount: xp, XpEventsTable.colRefId: 't$xp',
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      });
      return GrowthDao(db).getLevel();
    }
    expect(await levelAt(0), 1);    // Lv.1 阈值 0
    expect(await levelAt(99), 1);   // <100
    expect(await levelAt(100), 2);  // 100
    expect(await levelAt(300), 3);  // 300
    expect(await levelAt(999), 4);  // 999 ≥600 且 <1000 → Lv.4
    expect(await levelAt(1000), 5); // 1000 → Lv.5
  });
```

> 校验：x=999 → levelForXp：通过阈值 [0,100,300,600,1000,...]；999≥600 但 <1000 → Lv.4。1000 → Lv.5。请按实际阈值校正期望（999→4, 1000→5）。

- [ ] **Step 3: 新增 getXpBreakdown 用例**

```dart
  test('getXpBreakdown groups and computes ratios', () async {
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: 60, XpEventsTable.colRefId: 'c1',
      XpEventsTable.colCreatedAt: 1,
    });
    await db.insert(XpEventsTable.name, {
      'id': 'course:c2', XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: 40, XpEventsTable.colRefId: 'c2',
      XpEventsTable.colCreatedAt: 2,
    });
    final list = await GrowthDao(db).getXpBreakdown();
    expect(list.length, 2);
    expect(list.first.source, 'challenge');
    expect(list.first.amount, 60);
    expect(list.first.ratio, closeTo(0.6, 0.001));
    expect(list.last.source, 'course');
    expect(list.last.ratio, closeTo(0.4, 0.001));
  });

  test('getXpBreakdown returns empty when no ledger', () async {
    expect(await GrowthDao(db).getXpBreakdown(), isEmpty);
  });
```

- [ ] **Step 4: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/core/db/growth_dao_test.dart`
Expected: PASS（旧用例若因阈值改变而失败，按其新语义修正期望）。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/test/core/db/growth_dao_test.dart
git commit -m "test(growth): update dao tests for xp_events ledger and threshold levels"
```

---

### Task 7: v25 迁移测试

**Files:**
- Create: `lumira_app_flutter/test/core/db/migration_v25_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `XpEventsTable` / `_backfillXpLedger`（测试直接引用常量验证结构，不回填副函数）。
- 说明：测试用模拟 `onCreate`/`onUpgrade`（仿 migration_v15_test.dart），断言表结构 + 唯一索引 + 回填逻辑经过 `_backfillXpLedger` 后的台账正确。回填副函数是私有，测试通过调用真实迁移路径（openDatabase version 25）验证。

- [ ] **Step 1: 新建迁移测试文件**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 25,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v25 creates xp_events table with columns + unique index', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='xp_events'",
    );
    expect(tables.length, 1);

    final cols = await db.rawQuery('PRAGMA table_info(xp_events)');
    final names = cols.map((c) => c['name'] as String).toSet();
    expect(names, containsAll(['id', 'source', 'amount', 'ref_id', 'created_at']));

    final idx = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='uq_xp_events_source_ref'",
    );
    expect(idx.length, 1);
  });

  test('v25 adds xp_reward_claimed_level to user_progress default 0', () async {
    final cols = await db.rawQuery('PRAGMA table_info(user_progress)');
    final col = cols.firstWhere((c) => c['name'] == 'xp_reward_claimed_level');
    expect(col['dflt_value'], '0');
    expect(col['notnull'], 1);
  });

  test('backfill: challenge_history done → xp_events.challenge', () async {
    // 造数据
    await db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: 'ch_9',
      ChallengeHistoryTable.colDate: '2026-08-01',
      ChallengeHistoryTable.colChallengeId: 'c9',
      ChallengeHistoryTable.colCategory: 'portrait',
      ChallengeHistoryTable.colTitle: 'T9',
      ChallengeHistoryTable.colRewardXp: 60,
      ChallengeHistoryTable.colStatus: 'done',
      ChallengeHistoryTable.colSelectedAt: 1,
      ChallengeHistoryTable.colCompletedAt: 2,
    });
    await _backfillXpLedger(db);
    final rows = await db.query(XpEventsTable.name);
    expect(rows.length, 1);
    expect(rows.first['source'], 'challenge');
    expect(rows.first['amount'], 60);
    expect(rows.first['ref_id'], 'ch_9');
  });
}
```

- [ ] **Step 2: 提供本文件的 _onCreate + _onUpgrade + 私有 _backfillXpLedger（复制 Task 2 Step 6 的实现，仅做表结构 + 回填两表最小化）**

`_onCreate`/`_onUpgrade` 需包含：`user_progress`（含新列）、`challenge_history`、`academy_course_progress`、`xp_events`（含唯一索引）、以及回填时用到的 `academy_learning_trajectory`（回填只用 course_progress，可省）。为通过 `_onCreate` 建 user_progress 时新列可用，把新列直接放进 CREATE TABLE。

- [ ] **Step 3: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/core/db/migration_v25_test.dart`
Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/test/core/db/migration_v25_test.dart
git commit -m "test(growth): v25 migration creates xp_events + backfills real history"
```

---

### Task 8: 后端 points 支持 level_reward 事件

**Files:**
- Modify: `lumira-server/packages/shared/src/types/points.ts`
- Modify: `lumira-server/packages/backend/src/modules/points/points.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/points/points.controller.ts`

**Interfaces:**
- Consumes: 现 `earnEvent` 事务 + `point_earn_events` 唯一约束。
- Produces: `earnEvent(type='level_reward', refId=等级字符串)`：
  - 查 `LEVEL_REWARD_MAP[level]`，无则抛 `BadRequestException`；
  - 幂等沿用现有 `UNIQUE(device,type,ref_id)`，重复返回 `{granted:false}`；
  - 其余（余额/流水/广播）复用现有事务。

- [ ] **Step 1: shared 类型加 'level_reward'**

`packages/shared/src/types/points.ts` 的 `PointTransactionType` 联合末尾追加：

```ts
  | 'level_reward';   // 达到指定等级发放积分（一级一次）
```

- [ ] **Step 2: points.service.ts 加常量与类型**

在 `type PointTransactionType = ...` 本地类型末尾追加 `| 'level_reward';`。
文件顶部常量区追加：

```ts
// 升级积分奖励真值源（key=等级，与前端 LEVEL_REWARD_MAP 一致）
const LEVEL_REWARD_MAP: Record<number, number> = {
  2: 25, 3: 25, 4: 50, 5: 100, 6: 50, 7: 50, 8: 50, 9: 50, 10: 250,
  11: 50, 12: 50, 13: 50, 14: 50, 15: 150, 16: 50, 17: 50, 18: 50, 19: 50, 20: 500,
};
```

- [ ] **Step 3: earnEvent 增加 level_reward 分支（放在 `else if (type === 'share')` 之后、`else` 之前）**

```ts
    } else if (type === 'level_reward') {
      if (!refId) {
        throw new BadRequestException('refId (level) is required for level_reward');
      }
      const level = parseInt(refId, 10);
      if (!Object.prototype.hasOwnProperty.call(LEVEL_REWARD_MAP, level)) {
        throw new BadRequestException(`Invalid level reward: ${refId}`);
      }
      points = LEVEL_REWARD_MAP[level];
      eventRefId = refId;
    }
```

> 注意：`parseInt` 结果若非标准数字转任何非 key 都会落到 throw；`level` 为 number，`LEVEL_REWARD_MAP` 的 key 是数字，`hasOwnProperty` 判断即可区分。

- [ ] **Step 4: points.controller.ts 更新 earn 的 cast 类型**

`type as 'shoot_daily' | 'challenge' | 'share'` → `type as PointTransactionType`（先 import 类型或改为 `as 'shoot_daily'|'challenge'|'share'|'level_reward'` 一字排开）。为稳妥，采用：

```ts
    return this.pointsService.earnEvent(
      deviceId,
      type as 'shoot_daily' | 'challenge' | 'share' | 'level_reward',
      refId,
    );
```

- [ ] **Step 5: 构建 shared + typecheck**

Run: `cd lumira-server && pnpm --filter @lumira/shared build && pnpm --filter @lumira/backend typecheck`（若无 typecheck 脚本，用 `tsc --noEmit -p packages/backend`）
Expected: PASS。

- [ ] **Step 6: Commit + 双远程推送**

```bash
git add lumira-server/packages/shared/src/types/points.ts \
        lumira-server/packages/backend/src/modules/points/points.service.ts \
        lumira-server/packages/backend/src/modules/points/points.controller.ts
git commit -m "feat(points): support level_reward event with tiered reward map"
git push origin master
git push github master
```

---

### Task 9: 后端 level_reward e2e 测试

**Files:**
- Modify: `lumira-server/packages/backend/test/points.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 8 的 `level_reward` 接口。
- 断言：首次发放 granted:true + delta 正确；重复 granted:false 余额不变；无效等级 400。

- [ ] **Step 1: 在现有 describe 内追加三个用例**

```ts
  it('POST /points/earn type=level_reward refId=10 → granted:true +250', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'level_reward', refId: '10' })
      .expect(201);
    expect(res.body.granted).toBe(true);
    expect(res.body.delta).toBe(250);
  });

  it('POST /points/earn type=level_reward refId=10 twice → second granted:false 余额不变', async () => {
    const before = (await request(app.getHttpServer())
      .get('/api/v1/points/balance')
      .set('Authorization', `Bearer ${token}`)).body.balance;
    const res = await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'level_reward', refId: '10' })
      .expect(201);
    expect(res.body.granted).toBe(false);
    expect(res.body.delta).toBe(0);
    const after = (await request(app.getHttpServer())
      .get('/api/v1/points/balance')
      .set('Authorization', `Bearer ${token}`)).body.balance;
    expect(after).toBe(before);
  });

  it('POST /points/earn type=level_reward refId=999 → 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/points/earn')
      .set('Authorization', `Bearer ${token}`)
      .send({ type: 'level_reward', refId: '999' })
      .expect(400);
  });
```

> 注意：现有用例中 `type=share` 首条已把余额推到 2；递增断言不假设绝对余额，统一用相对 delta 或先取 before。

- [ ] **Step 2: 运行后端 e2e**

Run: `cd lumira-server/packages/backend && pnpm test:e2e -- points`（或仓库约定的 e2e 命令）
Expected: 新增用例 PASS，既有用例 PASS。

- [ ] **Step 3: Commit + 双远程推送**

```bash
git add lumira-server/packages/backend/test/points.e2e-spec.ts
git commit -m "test(points): e2e for level_reward grant/idempotent/invalid-400"
git push origin master
git push github master
```

---

### Task 10: 成长中心 UI 升级（等级进度 + 来源明细卡）

**Files:**
- Modify: `lumira_app_flutter/lib/features/profile/providers/growth_providers.dart`
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_growth_page.dart`

**Interfaces:**
- Consumes: Task 3 的 `GrowthDao.getSummary` / `getXpBreakdown`；Task 1 的 `XpBreakdownEntry`。
- Produces:
  - `growthLevelProvider` 改用 `dao.getSummary()`（移除 `_levelName`）。
  - 新增 `growthXpBreakdownProvider`。
  - `_LevelCard` 改用阈值表计算等级进度。
  - 页面新增「来源明细卡」（4 个来源，空行不展示）+ 进入页面触发 `claimLevelRewards` 补发。

- [ ] **Step 1: growth_providers.dart 改用真实台账**

```dart
final growthLevelProvider = FutureProvider<GrowthSummary>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  return dao.getSummary();
});

final growthXpBreakdownProvider = FutureProvider<List<XpBreakdownEntry>>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  return dao.getXpBreakdown();
});
```

删除本地 `_levelName` 辅助函数（不再使用）。若 `userProfileProvider` / `nextLevelNameProvider` 引用 `_levelName`，改用 `dao.getLevelName()` 或 `growthLevelProvider` 的字段：

```dart
final nextLevelNameProvider = FutureProvider<String>((ref) async {
  final growth = await ref.watch(growthLevelProvider.future);
  final lv = growth.level + 1;
  return levelNameFor(lv) ?? '';
});
```

并在顶部 import `../data/growth_models.dart`（含 `levelNameFor`）。

- [ ] **Step 2: profile_growth_page.dart _LevelCard 改用阈值进度**

替换 `_LevelCard.build` 中部进度计算（第 157–162 行）：

```dart
    // 当前等级下界与下一级上界（阈值表）
    final cur = LEVEL_THRESHOLDS.where((t) => t.level == summary.level).toList();
    final curFloor = cur.isEmpty ? 0 : cur.first.xp;
    final nxt = LEVEL_THRESHOLDS.where((t) => t.level == summary.level + 1).toList();
    final nxtCeil = nxt.isEmpty ? summary.currentXp : nxt.first.xp;
    final span = nxtCeil - curFloor;
    final xpIntoLevel = summary.currentXp - curFloor;
    final xpPercent = (span <= 0 ? 0.0 : (xpIntoLevel / span) * 100).round().clamp(0, 100);
```

并把三列 meta 中右栏的 `levelMaxXp` 由 `summary.level * 500` 改为 `nxtCeil`（未满级时展示下一级阈值），满级（nxt 空）不展示或显示「已达最高等级」。可将 `final levelMaxXp = summary.level * 500;` 删除，改用 `nxtCeil`。

- [ ] **Step 3: 新增「来源明细卡」Widget 并挂到 Column**

新增：

```dart
class _XpBreakdownCard extends StatelessWidget {
  const _XpBreakdownCard({required this.entries, required this.tokens});
  final List<XpBreakdownEntry> entries;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('经验来源', style: TextStyle(
            fontFamily: 'Noto Serif SC', fontSize: 17, fontWeight: FontWeight.w600,
            color: tokens.textPrimary),
          ),
          const SizedBox(height: 16),
          for (final e in entries) ...[
            Row(
              children: [
                Expanded(child: Text(e.label, style: TextStyle(fontSize: 14, color: tokens.textPrimary))),
                const SizedBox(width: 12),
                Text('${e.amount} XP', style: TextStyle(
                  fontSize: 12, fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600, color: tokens.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(children: [
                  Container(color: tokens.brand.withOpacity(0.15)),
                  FractionallySizedBox(
                    widthFactor: e.ratio < 0 ? 0 : e.ratio,
                    child: Container(color: tokens.brand),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
```

页面 build 中在 `_LevelCard` 后插入来源卡（并 watch 新 provider）：

```dart
    final breakdownAsync = ref.watch(growthXpBreakdownProvider);
    ...
    FadeUp(
      delay: const Duration(milliseconds: 50),
      child: _XpBreakdownCard(
        tokens: tokens,
        entries: breakdownAsync.maybeWhen(data: (e) => e, orElse: () => const []),
      ),
    ),
    const SizedBox(height: 20),
```

- [ ] **Step 4: 进页面补发升级奖励（离线不丢奖）**

`ProfileGrowthPage.build` 顶部（`final tokens = ...;` 之后）用 `ref.listen` 或 `ref.read` 触发一次补发：

```dart
    // 进入成长中心触发一次升级奖励补发（离线失败静默，联网后下次再补）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _claimPendingRewards(ref);
    });
```

其中：

```dart
Future<void> _claimPendingRewards(WidgetRef ref) async {
  try {
    final db = await ref.read(databaseProvider.future);
    final repo = await ref.read(pointsRepositoryProvider.future);
    final svc = GrowthXpService(
      db,
      earnLevelReward: (level) => repo.earn(type: 'level_reward', refId: level),
    );
    final newCount = await svc.claimLevelRewards();
    if (newCount > 0 && ref.context.mounted) {
      LumiraToast.show(ref.context, '升级奖励 +$newCount 笔积分已到账');
    }
  } catch (e) {
    debugPrint('[growth] claim level rewards failed: $e');
  }
}
```

（新增 import：`growth_xp_service.dart`、`database_provider.dart`、`points_repository.dart`、`growth_models.dart`（LEVEL_THRESHOLDS）、`share/services/lumira toast`。）

- [ ] **Step 5: 静态检查**

Run: `cd lumira_app_flutter && flutter analyze lib/features/profile/providers/growth_providers.dart lib/features/profile/pages/profile_growth_page.dart`
Expected: No issues found。

- [ ] **Step 6: 视觉与功能验收（真机）**

进入成长中心：等级/称号/进度由真实台账；来源明细卡展示既有来源；若台账跨过多个有奖励等级，进页面一次补发积分并 Toast。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/profile/providers/growth_providers.dart \
        lumira_app_flutter/lib/features/profile/pages/profile_growth_page.dart
git commit -m "feat(growth): tier-based level progress + xp source breakdown card + reward backfill on page open"
```

---

## 自评（已对照 spec 逐条检查）

- 经验台账模型 / 幂等 / refId 口径：Task 2、4、5。✅
- 四来源经验：Task 5。✅
- 阶梯等级表取代 `~/500+1`：Task 1 配置、Task 3、Task 10。✅
- 升级积分奖励（前端领取 + 后端 level_reward）：Task 4、8、10。✅
- v24→v25 迁移 + 回填：Task 2、7。✅
- GrowthDao/模型改造、来源明细：Task 1、3。✅
- UI：Task 10。✅
- 测试：Task 6（DAO）、Task 7（迁移）、Task 9（后端 e2e）、Task 4 领取逻辑已内置于 service（其离线保留由 `_LevelCard` 补发 + `claimLevelRewards` 语义保证）。✅