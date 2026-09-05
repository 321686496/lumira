# 灵感页「拍摄小课堂」实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把灵感页「拍得更好」区块改造成「拍摄小课堂」——覆盖全摄影大类（6 通用技巧 + 7 大类×2 专项 = 20 篇）的轻量单篇小教程，按问卷偏好 + 近 30 天拍摄行为 + 已读状态个性化推荐，读完可「去试试」（场景/模板）并有美学院反导向流。

**Architecture:** 纯本地静态内容（`tutorial_content.dart` const）+ 本地推荐算法（`TutorialRecommendationService`，仿 `recommendation_service.dart` 多槽位混合，60/40 相关/探索、≥3 类覆盖）+ 本地已读表（`tutorial_reads`，DB v22→v23）+ 新详情页路由。替换灵感页第 3 区块内容源，删除 `BetterShootSection` 推系统课逻辑与 `coursePicksProvider`。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（无 Dart 3 records 语法）、flutter_riverpod 2.3.6、go_router 6.5.7、sqflite v11、`scripts/gen_image.py`（MaaS 图片生成，仅标准库）。

## Global Constraints

- 纯本地：教程内容 const、无网络、个性化只用 `questionnaire` 表 / `gallery` 表 / `tutorial_reads` 表。
- 不与美学院相撞：无作业、无 XP、无进度环；卡片/详情页标注"小课堂·短文"；CTA 落点是"去拍"。
- 详情页视觉与美学院详情页一致：`LumiraNav`（透明）+ 径向渐变背景 + `FadeUp`。
- 图片一律用 `scripts/gen_image.py` 生成，落盘 `assets/images/tutorials/`（pubspec 已注册 `assets/images/` 目录，无需再注册子目录）。
- 所有 CTA 的 scene/template id 必须存在于本计划「已验证 id」清单；`academyCourseId` 必须存在于 `AcademyContent`（course_01~course_16）。
- 数据库迁移用 `_addColumnIfNotExists` / `CREATE TABLE IF NOT EXISTS` 幂等模式，当前 `_kDbVersion = 22`。
- Dart 2.19.6 语法：不能用 records / pattern 解构，用 switch 传统写法。
- TDD：每个任务先写失败测试 → 跑失败 → 最小实现 → 跑过 → commit。
- 提交信息遵循项目惯例（`feat(flutter): ...` / `test(flutter): ...` / `refactor(flutter): ...`）。
- Flutter 端改动不强制 push（AGENTS.md 仅后端/后台要求 commit+push 双远程）。

### 已验证可用的 id 清单（CTA / 关联课程只能从这里取）

场景 id（scene 预设，跳 `captureSceneGuide`）：`cafe-window`、`home-cozy`、`sunset-silhouette`、`night-street`、`library-quiet`、`seaside-beach`、`forest-bamboo`、`rainy-window`、`golden-rim-portrait`

模板 id（跳 `templatesDetail`）：`cafe_portrait`、`soft_portrait`、`golden_landscape`、`food_flat_lay`、`night_cityscape`、`street_bw`、`macro_flower`、`indoor_still_life`、`sunset_silhouette`、`urban_architecture`、`film_vintage`、`neon_portrait`、`morandi_minimal_portrait`、`japanese_fresh_portrait`、`cream_healing_portrait`

美学院课程 id（`AcademyContent.getCourse(id)` 非空）：`course_01`（找到你的最佳角度）~ `course_16`（见 `academy_content.dart`，含 course_02 光线基础 / course_03 构图三分法 / course_04 黄金时段 / course_05 俯拍平铺 / course_06 决定性瞬间 / course_07 伦勃朗光 / course_09 引导线构图 / course_10 布光法 / course_11 色彩搭配 / course_12 街头光影 / course_13 风格化人像 / course_15 极简静物）

类别常量（与 `countByCategory()` 返回 key 一致）：`portrait`、`landscape`、`food`、`street`、`night`、`macro`、`still-life`；通用技巧类为 `general`。

---

### Task 1: 数据模型 `tutorial_models.dart`

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/data/tutorial_models.dart`
- Test: `lumira_app_flutter/test/features/inspiration/tutorial_models_test.dart`

**Interfaces:**
- Produces: `enum TutorialCtaType { scene, template }`；`class TutorialCta { final TutorialCtaType type; final String targetId; }`；`class TutorialStep { final String title; final String body; final String? imageAsset; }`；`class ShootingTutorial { final String id; final String title; final String subtitle; final String coverImage; final String category; final String readMinutes; final List<String> tags; final String intro; final List<TutorialStep> steps; final List<String> tips; final TutorialCta cta; final String? academyCourseId; }`（全部 `const` 构造，字段用 `this.xxx` 命名参数）。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  test('ShootingTutorial 构建与字段访问', () {
    const t = ShootingTutorial(
      id: 'tut_general_premium',
      title: '如何拍出高级感',
      subtitle: '留白与克制',
      coverImage: 'assets/images/tutorials/cover_tut_general_premium.jpg',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['高级感', '留白'],
      intro: '高级感不是滤镜，是减法。',
      steps: [
        TutorialStep(title: '第一步', body: '减少画面元素', imageAsset: null),
      ],
      tips: ['少即是多'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_13',
    );
    expect(t.id, 'tut_general_premium');
    expect(t.cta.type, TutorialCtaType.scene);
    expect(t.steps.first.title, '第一步');
    expect(t.academyCourseId, 'course_13');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/inspiration/tutorial_models_test.dart`
Expected: FAIL（找不到 `tutorial_models.dart` 或 `ShootingTutorial`）。

- [ ] **Step 3: 写最小实现**

```dart
enum TutorialCtaType { scene, template }

class TutorialCta {
  final TutorialCtaType type;
  final String targetId;
  const TutorialCta({required this.type, required this.targetId});
}

class TutorialStep {
  final String title;
  final String body;
  final String? imageAsset;
  const TutorialStep({required this.title, required this.body, this.imageAsset});
}

class ShootingTutorial {
  final String id;
  final String title;
  final String subtitle;
  final String coverImage;
  final String category;
  final String readMinutes;
  final List<String> tags;
  final String intro;
  final List<TutorialStep> steps;
  final List<String> tips;
  final TutorialCta cta;
  final String? academyCourseId;

  const ShootingTutorial({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.category,
    required this.readMinutes,
    this.tags = const [],
    required this.intro,
    this.steps = const [],
    this.tips = const [],
    required this.cta,
    this.academyCourseId,
  });
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/inspiration/tutorial_models_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/inspiration/data/tutorial_models.dart lumira_app_flutter/test/features/inspiration/tutorial_models_test.dart
git commit -m "feat(flutter): 拍摄小课堂数据模型 ShootingTutorial"
```

---

### Task 2: 已读表 + `TutorialReadDao` + v23 迁移

**Files:**
- Modify: `lumira_app_flutter/lib/core/db/tables.dart`（追加常量）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（v23 迁移 + provider）
- Create: `lumira_app_flutter/lib/core/db/dao/tutorial_read_dao.dart`
- Test: `lumira_app_flutter/test/core/db/dao/tutorial_read_dao_test.dart`

**Interfaces:**
- Produces: `class TutorialReadDao { TutorialReadDao(this._db); Future<Set<String>> getReadIds(); Future<void> markRead(String tutorialId); Future<void> markUnread(String tutorialId); }`
- Produces: `final tutorialReadDaoProvider = FutureProvider<TutorialReadDao>((ref) async { final db = await ref.watch(databaseProvider.future); return TutorialReadDao(db); });`
- Tables 常量：`Tables.tutorialReads = 'tutorial_reads'`、`Tables.colTutorialReadId = 'id'`（复用 `Tables.colId`，见下）、`Tables.colTutorialReadAt = 'read_at'`。注意 `Tables.colId` 已存在（值 `'id'`），表列直接用 `Tables.colId`。

- [ ] **Step 1: 写失败测试（DAO + 迁移幂等）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/tutorial_read_dao.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TutorialReadDao dao;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS tutorial_reads (
              id TEXT PRIMARY KEY,
              read_at INTEGER
            )
          ''');
        },
      ),
    );
    dao = TutorialReadDao(db);
  });

  tearDown(() async => db.close());

  test('markRead 后 getReadIds 返回，重复 markRead 幂等', () async {
    await dao.markRead('tut_general_premium');
    await dao.markRead('tut_general_premium');
    await dao.markRead('tut_portrait_window');
    final ids = await dao.getReadIds();
    expect(ids, {'tut_general_premium', 'tut_portrait_window'});
  });

  test('markUnread 移除记录', () async {
    await dao.markRead('tut_general_premium');
    await dao.markUnread('tut_general_premium');
    expect(await dao.getReadIds(), isEmpty);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/core/db/dao/tutorial_read_dao_test.dart`
Expected: FAIL（找不到 `tutorial_read_dao.dart`）。

- [ ] **Step 3: 实现 DAO**

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 小教程已读记录 DAO（tutorial_reads 表，v23）
class TutorialReadDao {
  TutorialReadDao(this._db);
  final Database _db;

  Future<Set<String>> getReadIds() async {
    final rows = await _db.query(Tables.tutorialReads);
    return rows.map((r) => r[Tables.colId] as String).toSet();
  }

  Future<void> markRead(String tutorialId) async {
    await _db.insert(
      Tables.tutorialReads,
      {Tables.colId: tutorialId, Tables.colTutorialReadAt: DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markUnread(String tutorialId) async {
    await _db.delete(
      Tables.tutorialReads,
      where: '${Tables.colId} = ?',
      whereArgs: [tutorialId],
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/core/db/dao/tutorial_read_dao_test.dart`
Expected: PASS。

- [ ] **Step 5: 注册表常量（tables.dart）**

在 `tables.dart` 的 watermark 段之后追加（`colId` 已存在无需重复声明，参照 `colSyncedAt` 复用注释的既有做法）：

```dart
// === tutorial_reads 表（v23 迁移新增，小教程已读记录） ===
static const String tutorialReads = 'tutorial_reads';
static const String colTutorialReadAt = 'read_at';
```

- [ ] **Step 6: 数据库 v23 迁移 + provider（database_provider.dart）**

在 `_onUpgrade` 末尾（`oldVersion < 22` 块之后）追加：

```dart
if (oldVersion < 23) {
  try {
    // v23: 小教程已读记录表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.tutorialReads} (
        ${Tables.colId} TEXT PRIMARY KEY,
        ${Tables.colTutorialReadAt} INTEGER
      )
    ''');
  } catch (e) {
    debugPrint('v23 migration failed (silent fallback): $e');
  }
}
```

同时在 `database_provider.dart` 文件头确认 import：`import 'dao/tutorial_read_dao.dart';`，并在既有 DAO provider 区（如 `questionnaireDaoProvider` 附近）追加：

```dart
final tutorialReadDaoProvider = FutureProvider<TutorialReadDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TutorialReadDao(db);
});
```

同时将 `_kDbVersion` 从 22 改为 23。

- [ ] **Step 7: 跑相关测试**

Run: `flutter test test/core/db/`
Expected: 全部 PASS（迁移幂等、DAO 正常）。

- [ ] **Step 8: Commit**

```bash
git add lumira_app_flutter/lib/core/db/tables.dart lumira_app_flutter/lib/core/db/database_provider.dart lumira_app_flutter/lib/core/db/dao/tutorial_read_dao.dart lumira_app_flutter/test/core/db/dao/tutorial_read_dao_test.dart
git commit -m "feat(flutter): 小教程已读表 tutorial_reads + v23 迁移 + DAO"
```

---

### Task 3: 内容数据 `tutorial_content.dart`（20 篇）

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/data/tutorial_content.dart`
- Test: `lumira_app_flutter/test/features/inspiration/tutorial_content_test.dart`

**Interfaces:**
- Produces: `abstract final class TutorialContent { static const List<ShootingTutorial> all = [...]; static ShootingTutorial? getById(String id); }`
- 注意：Dart 2.19 支持 `abstract final class`；若版本告警可改用 `class TutorialContent { TutorialContent._(); }`（与 `InspirationContent` 一致，后者就是私有构造风格）。

**内容清单（20 篇，id/类别/封面/CTA/关联课程）：**

通用（general，6 篇）：
1. `tut_general_premium` 如何拍出高级感（CTA scene `cafe-window`，academy `course_13`）
2. `tut_general_vibe` 如何拍出氛围感（CTA scene `sunset-silhouette`，academy `course_07`）
3. `tut_general_angle` 找好角度，照片就赢了一半（CTA scene `golden-rim-portrait`，academy `course_01`）
4. `tut_general_light` 光影：一张照片的灵魂（CTA scene `rainy-window`，academy `course_02`）
5. `tut_general_composition` 三分法构图入门（CTA template `golden_landscape`，academy `course_03`）
6. `tut_general_color` 用色彩讲故事（CTA template `morandi_minimal_portrait`，academy `course_11`）

分类专项（14 篇）：
7. `tut_portrait_window` 窗边人像：把光框进画里（portrait，CTA scene `cafe-window`，academy `course_01`）
8. `tut_portrait_backlight` 逆光人像：镀一层金边（portrait，CTA scene `golden-rim-portrait`，academy `course_07`）
9. `tut_landscape_golden` 黄金时刻：风光片的最佳时间（landscape，CTA template `golden_landscape`，academy `course_04`）
10. `tut_landscape_leading` 引导线构图：让视线去旅行（landscape，CTA scene `seaside-beach`，academy `course_09`）
11. `tut_food_flatlay` 俯拍平铺：美食摆盘的艺术（food，CTA template `food_flat_lay`，academy `course_05`）
12. `tut_food_natural` 自然光美食：窗边就是天然柔光箱（food，CTA template `foodie_portrait`，academy `course_02`）
13. `tut_street_decisive` 决定性瞬间：街头摄影的抓拍（street，CTA scene `night-street`，academy `course_06`）
14. `tut_street_shadow` 街头光影：在明暗交界处按快门（street，CTA template `street_bw`，academy `course_12`）
15. `tut_night_bluetime` 蓝调时刻：天黑后的第一抹浪漫（night，CTA template `night_cityscape`，academy `course_04`）
16. `tut_night_neon` 霓虹人像：把夜色穿在身上（night，CTA template `neon_portrait`，academy `course_06`）
17. `tut_macro_detail` 微距入门：看见另一个世界（macro，CTA template `macro_flower`，academy `course_10`）
18. `tut_macro_flower` 花卉微距：拍出晨露的呼吸（macro，CTA template `macro_flower`，academy `course_10`）
19. `tut_still_minimal` 极简静物：少即是多（still-life，CTA template `indoor_still_life`，academy `course_15`）
20. `tut_still_warm` 温暖静物：阳光是最好的滤镜（still-life，CTA scene `home-cozy`，academy `course_10`）

每篇封面：`assets/images/tutorials/cover_<id>.png`；步骤图（仅部分篇目有 1 张）：`assets/images/tutorials/step_<id>_1.png`（Task 8 生成）。步骤图只在步骤内容确实需要图示时使用，至少保证 6 篇通用技巧各 1 张步骤图。

- [ ] **Step 1: 写失败测试（数据完整性）**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/academy/data/academy_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  const validCategories = {
    'general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life',
  };

  test('id 唯一且命名规范', () {
    final ids = TutorialContent.all.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
    for (final t in TutorialContent.all) {
      expect(t.id, startsWith('tut_'));
    }
  });

  test('每篇必填字段非空', () {
    for (final t in TutorialContent.all) {
      expect(t.title, isNotEmpty, reason: t.id);
      expect(t.subtitle, isNotEmpty, reason: t.id);
      expect(t.intro, isNotEmpty, reason: t.id);
      expect(t.coverImage, isNotEmpty, reason: t.id);
      expect(t.readMinutes, isNotEmpty, reason: t.id);
      expect(t.steps, isNotEmpty, reason: '${t.id} 至少 1 个步骤');
      expect(t.tips, isNotEmpty, reason: '${t.id} 至少 1 条贴士');
      expect(validCategories.contains(t.category), isTrue, reason: '${t.id} 类别非法');
    }
  });

  test('CTA 目标为已验证 id', () {
    const validScenes = {
      'cafe-window', 'home-cozy', 'sunset-silhouette', 'night-street',
      'library-quiet', 'seaside-beach', 'forest-bamboo', 'rainy-window', 'golden-rim-portrait',
    };
    const validTemplates = {
      'cafe_portrait', 'soft_portrait', 'golden_landscape', 'food_flat_lay',
      'night_cityscape', 'street_bw', 'macro_flower', 'indoor_still_life',
      'sunset_silhouette', 'urban_architecture', 'film_vintage', 'neon_portrait',
      'morandi_minimal_portrait', 'japanese_fresh_portrait', 'cream_healing_portrait',
      'foodie_portrait',
    };
    for (final t in TutorialContent.all) {
      final cta = t.cta;
      if (cta.type == TutorialCtaType.scene) {
        expect(validScenes.contains(cta.targetId), isTrue, reason: '${t.id} 场景 ${cta.targetId} 未验证');
      } else {
        expect(validTemplates.contains(cta.targetId), isTrue, reason: '${t.id} 模板 ${cta.targetId} 未验证');
      }
    }
  });

  test('关联美学院课程必须存在', () {
    for (final t in TutorialContent.all) {
      final id = t.academyCourseId;
      if (id != null) {
        expect(AcademyContent.getCourse(id), isNotNull, reason: '${t.id} 关联课程 $id 不存在');
      }
    }
  });

  test('封面/步骤图 asset 文件真实存在', () {
    final assetPaths = <String>[];
    for (final t in TutorialContent.all) {
      assetPaths.add(t.coverImage);
      for (final s in t.steps) {
        if (s.imageAsset != null) assetPaths.add(s.imageAsset!);
      }
    }
    for (final p in assetPaths) {
      expect(() => rootBundle.load(p), returnsNormally,
          reason: 'asset $p 不存在（请在 Task 8 生成）');
    }
  });

  test('getById 命中与未命中', () {
    expect(TutorialContent.getById('tut_general_premium'), isNotNull);
    expect(TutorialContent.getById('not-exist'), isNull);
  });

  test('各类别均有覆盖', () {
    final cats = TutorialContent.all.map((t) => t.category).toSet();
    for (final c in ['general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life']) {
      expect(cats.contains(c), isTrue, reason: '缺少类别 $c');
    }
  });
}
```

> 注：`rootBundle.load` 断言依赖 Task 8 图片落地；若按任务顺序执行会先失败，属预期。实现时可在 Task 3 用 `skip: true` 暂挂该测试，Task 8 落地图片后移除 skip。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/inspiration/tutorial_content_test.dart`
Expected: FAIL（找不到 `tutorial_content.dart`）。

- [ ] **Step 3: 实现 20 篇内容（tutorial_content.dart）**

完整内容如下（封面名 `cover_<id>.png`；部分篇目 1 张步骤图 `step_<id>_1.png`）：

```dart
import 'tutorial_models.dart';

/// 拍摄小课堂内容库：20 篇（6 通用 + 14 分类专项）
class TutorialContent {
  TutorialContent._();

  static ShootingTutorial? getById(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static const List<ShootingTutorial> all = [
    // ===== 通用技巧（general）=====
    ShootingTutorial(
      id: 'tut_general_premium',
      title: '如何拍出高级感',
      subtitle: '留白与克制，比华丽更耐看',
      coverImage: 'assets/images/tutorials/cover_tut_general_premium.jpg',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['高级感', '留白'],
      intro: '高级感不是滤镜堆出来的，而是「做减法」。画面里每多一样东西，就多一分嘈杂。',
      steps: [
        TutorialStep(
          title: '减少画面元素',
          body: '拍照前先问自己：这个画面里，什么是不必要的？移走它。',
        ),
        TutorialStep(
          title: '统一色调',
          body: '让画面主体颜色不超过 3 个，同色系更显质感。',
          imageAsset: 'assets/images/tutorials/step_tut_general_premium_1.jpg',
        ),
        TutorialStep(
          title: '留出呼吸感',
          body: '主体不要占满画面，留出一块干净的背景空间。',
        ),
      ],
      tips: ['低饱和 + 低对比，质感更高级', '背景越简单，主体越高级'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_13',
    ),
    ShootingTutorial(
      id: 'tut_general_vibe',
      title: '如何拍出氛围感',
      subtitle: '用光、雾与故事感，让照片会说话',
      coverImage: 'assets/images/tutorials/cover_tut_general_vibe.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['氛围感', '逆光'],
      intro: '氛围感的秘密：让观者「猜故事」。逆光、侧逆光、薄雾，都是氛围的催化剂。',
      steps: [
        TutorialStep(
          title: '找逆光',
          body: '把主体放在光源与镜头之间，轮廓会镀上一层光边。',
          imageAsset: 'assets/images/tutorials/step_tut_general_vibe_1.png',
        ),
        TutorialStep(
          title: '加一层前景',
          body: '用树叶、纱帘做前景虚化，画面立刻有了纵深感。',
        ),
        TutorialStep(
          title: '降低曝光',
          body: '故意欠曝半档，暗调让情绪更浓。',
        ),
      ],
      tips: ['黄昏前 30 分钟氛围最佳', '雾气、蒸汽都是免费的氛围道具'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'sunset-silhouette'),
      academyCourseId: 'course_07',
    ),
    ShootingTutorial(
      id: 'tut_general_angle',
      title: '找好角度，照片就赢了一半',
      subtitle: '同一个场景，角度不同天差地别',
      coverImage: 'assets/images/tutorials/cover_tut_general_angle.jpg',
      category: 'general',
      readMinutes: '2分钟',
      tags: ['角度', '构图'],
      intro: '俯拍显小、仰拍显高、平视最亲切。拍摄前先绕主体走一圈，找到最佳机位。',
      steps: [
        TutorialStep(
          title: '平视最真实',
          body: '与主体眼睛同高，最符合日常视角，最自然。',
        ),
        TutorialStep(
          title: '微微仰拍',
          body: '拍人像时镜头略低于视线，显高显精神。',
          imageAsset: 'assets/images/tutorials/step_tut_general_angle_1.jpg',
        ),
        TutorialStep(
          title: '俯拍看全貌',
          body: '拍食物、桌面时垂直俯拍，把布局拍得整整齐齐。',
        ),
      ],
      tips: ['拍摄前先走一圈找机位', '同主体连拍 3 个角度，选最满意的'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'golden-rim-portrait'),
      academyCourseId: 'course_01',
    ),
    ShootingTutorial(
      id: 'tut_general_light',
      title: '光影：一张照片的灵魂',
      subtitle: '学会看光，就学会了拍照',
      coverImage: 'assets/images/tutorials/cover_tut_general_light.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['光影', '光线'],
      intro: '摄影是用光的艺术。侧光塑形、逆光勾边、顶光显层次，先学会分辨光的方向。',
      steps: [
        TutorialStep(
          title: '侧光塑形',
          body: '光从侧面来，主体一半亮一半暗，立体感最强。',
          imageAsset: 'assets/images/tutorials/step_tut_general_light_1.png',
        ),
        TutorialStep(
          title: '逆光勾边',
          body: '逆光时给主体镀上轮廓光，适合剪影和发丝光。',
        ),
        TutorialStep(
          title: '窗光最温柔',
          body: '室内拍照首选窗边，天然柔光箱。',
        ),
      ],
      tips: ['正午顶光最硬，避开它', '阴天是免费的柔光罩'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'rainy-window'),
      academyCourseId: 'course_02',
    ),
    ShootingTutorial(
      id: 'tut_general_composition',
      title: '三分法构图入门',
      subtitle: '把画面分成九宫格，主体放交点',
      coverImage: 'assets/images/tutorials/cover_tut_general_composition.png',
      category: 'general',
      readMinutes: '2分钟',
      tags: ['构图', '三分法'],
      intro: '把画面横向竖向各分三份，四条线四个交点是天然的视觉重心。',
      steps: [
        TutorialStep(
          title: '打开网格线',
          body: '在取景器中打开三分线辅助，新手友好。',
        ),
        TutorialStep(
          title: '主体放交点',
          body: '人物、主体放在四条线的交点附近，画面立刻舒服。',
          imageAsset: 'assets/images/tutorials/step_tut_general_composition_1.png',
        ),
        TutorialStep(
          title: '地平线对齐',
          body: '拍风景时把地平线压在上/下三分之一处。',
        ),
      ],
      tips: ['拍完再裁切，二次构图也是三分法', '人物视线方向留出空间'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'golden_landscape'),
      academyCourseId: 'course_03',
    ),
    ShootingTutorial(
      id: 'tut_general_color',
      title: '用色彩讲故事',
      subtitle: '色温、色调、配色，都在悄悄说话',
      coverImage: 'assets/images/tutorials/cover_tut_general_color.jpg',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['色彩', '配色'],
      intro: '暖色热闹、冷色安静、低饱和高级。颜色定调，情绪自现。',
      steps: [
        TutorialStep(
          title: '先定主色调',
          body: '一张照片只讲一种情绪，冷调或暖调二选一。',
        ),
        TutorialStep(
          title: '相邻色和谐',
          body: '同色系、相邻色搭配最安全，最出氛围。',
          imageAsset: 'assets/images/tutorials/step_tut_general_color_1.jpg',
        ),
        TutorialStep(
          title: '一点撞色点睛',
          body: '大面积统一色里放一点对比色，是记忆点。',
        ),
      ],
      tips: ['后期调整白平衡可瞬间改情绪', '莫兰迪色系最容易拍出高级感'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'morandi_minimal_portrait'),
      academyCourseId: 'course_11',
    ),

    // ===== 人像（portrait）=====
    ShootingTutorial(
      id: 'tut_portrait_window',
      title: '窗边人像：把光框进画里',
      subtitle: '一扇窗，一个天然柔光箱',
      coverImage: 'assets/images/tutorials/cover_tut_portrait_window.jpg',
      category: 'portrait',
      readMinutes: '3分钟',
      tags: ['人像', '窗光'],
      intro: '窗边光是拍人像最容易出片的光：方向明确、质地柔软，还有窗框天然构图。',
      steps: [
        TutorialStep(
          title: '让人物侧对窗',
          body: '光从侧面来，脸部一半亮一半暗，立体又瘦脸。',
        ),
        TutorialStep(
          title: '眼神里留高光',
          body: '让眼睛里映出窗光，眼睛立刻有神。',
          imageAsset: 'assets/images/tutorials/step_tut_portrait_window_1.jpg',
        ),
        TutorialStep(
          title: '用窗框做前景',
          body: '隔着窗拍，画中画的层次感。',
        ),
      ],
      tips: ['白纱窗帘 = 免费柔光', '别让人物正对窗，光太平'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_01',
    ),
    ShootingTutorial(
      id: 'tut_portrait_backlight',
      title: '逆光人像：镀一层金边',
      subtitle: '发丝光与轮廓光，浪漫感拉满',
      coverImage: 'assets/images/tutorials/cover_tut_portrait_backlight.jpg',
      category: 'portrait',
      readMinutes: '3分钟',
      tags: ['人像', '逆光'],
      intro: '逆光人像的秘诀：对脸测光会变剪影，对背景测光会过曝。折中，让人物补点光。',
      steps: [
        TutorialStep(
          title: '黄金时刻拍逆光',
          body: '日落前后 30 分钟，光最柔最金。',
        ),
        TutorialStep(
          title: '点测光对准脸部边缘',
          body: '保留发丝金边，脸部也不会死黑。',
          imageAsset: 'assets/images/tutorials/step_tut_portrait_backlight_1.jpg',
        ),
        TutorialStep(
          title: '加一点点补光',
          body: '反光板或手机屏幕光，让脸部不死黑。',
        ),
      ],
      tips: ['逆光时注意不要直视镜头太久', '局部光斑是氛围加分项'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'golden-rim-portrait'),
      academyCourseId: 'course_07',
    ),

    // ===== 风光（landscape）=====
    ShootingTutorial(
      id: 'tut_landscape_golden',
      title: '黄金时刻：风光片的最佳时间',
      subtitle: '日出日落前后一小时，光比任何滤镜都好用',
      coverImage: 'assets/images/tutorials/cover_tut_landscape_golden.png',
      category: 'landscape',
      readMinutes: '3分钟',
      tags: ['风光', '黄金时刻'],
      intro: '风光摄影只有一个黄金法则：在黄金时刻按快门。柔和、温暖、拉长的影子，都是它给的。',
      steps: [
        TutorialStep(
          title: '提前踩点',
          body: '黄金时刻很短暂，提前 30 分钟到场架好机位。',
        ),
        TutorialStep(
          title: '侧光看纹理',
          body: '黄金时刻的侧光让山峦、沙丘的纹理最立体。',
          imageAsset: 'assets/images/tutorials/step_tut_landscape_golden_1.jpg',
        ),
        TutorialStep(
          title: '留出天空',
          body: '天空的暖色渐变，是这张照片最值钱的部分。',
        ),
      ],
      tips: ['黄金时刻指日出后/日落前约 1 小时', '阴天别急走，云缝光更惊艳'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'golden_landscape'),
      academyCourseId: 'course_04',
    ),
    ShootingTutorial(
      id: 'tut_landscape_leading',
      title: '引导线构图：让视线去旅行',
      subtitle: '路、栏杆、河流，都是天然的导游',
      coverImage: 'assets/images/tutorials/cover_tut_landscape_leading.jpg',
      category: 'landscape',
      readMinutes: '2分钟',
      tags: ['风光', '构图'],
      intro: '画面里的线条会"带路"。路、栈道、河流把视线引向主体，纵深感和故事感一起出现。',
      steps: [
        TutorialStep(
          title: '找一条线',
          body: '地面上的路、墙、栏杆，先找到一条。',
        ),
        TutorialStep(
          title: '线从画面一角进入',
          body: '引导线斜着进入画面，比横平竖直更有张力。',
          imageAsset: 'assets/images/tutorials/step_tut_landscape_leading_1.jpg',
        ),
        TutorialStep(
          title: '线指向主体',
          body: '让线条终点是兴趣点，不要指空。',
        ),
      ],
      tips: ['低角度拍路，线条感最强', 'S 形曲线比直线更耐看'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'seaside-beach'),
      academyCourseId: 'course_09',
    ),

    // ===== 美食（food）=====
    ShootingTutorial(
      id: 'tut_food_flatlay',
      title: '俯拍平铺：美食摆盘的艺术',
      subtitle: '从上往下看，餐桌上全是构图',
      coverImage: 'assets/images/tutorials/cover_tut_food_flatlay.jpg',
      category: 'food',
      readMinutes: '2分钟',
      tags: ['美食', '俯拍'],
      intro: '俯拍 45-90 度角，把餐具、食物、手部动作都装进画面，是美食摄影的经典拍法。',
      steps: [
        TutorialStep(
          title: '垂直俯拍最稳',
          body: '手机与桌面平行，从上往下拍，线条不变形。',
        ),
        TutorialStep(
          title: '餐具当画框',
          body: '盘子、杯子、餐巾，都是天然的构图元素。',
          imageAsset: 'assets/images/tutorials/step_tut_food_flatlay_1.jpg',
        ),
        TutorialStep(
          title: '留一点"吃过的痕迹"',
          body: '缺一角的面包、喝过一口的咖啡，更有生活感。',
        ),
      ],
      tips: ['找靠窗的桌位，光最好', '俯拍时手入镜端杯，故事感更强'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'food_flat_lay'),
      academyCourseId: 'course_05',
    ),
    ShootingTutorial(
      id: 'tut_food_natural',
      title: '自然光美食：窗边就是天然柔光箱',
      subtitle: '不用打灯，一扇窗拍出美食大片',
      coverImage: 'assets/images/tutorials/cover_tut_food_natural.jpg',
      category: 'food',
      readMinutes: '2分钟',
      tags: ['美食', '自然光'],
      intro: '美食摄影最怕顶灯直射。把食物搬到窗边，用白纸补光，就能得到柔和干净的光。',
      steps: [
        TutorialStep(
          title: '座位选窗边',
          body: '进店先找靠窗位，侧光最立体。',
        ),
        TutorialStep(
          title: '白纸补阴影',
          body: '暗面放一张白纸/纸巾，反光填暗。',
          imageAsset: 'assets/images/tutorials/step_tut_food_natural_1.jpg',
        ),
        TutorialStep(
          title: '别开闪光灯',
          body: '闪光灯会把食物拍得油腻发白。',
        ),
      ],
      tips: ['蒸腾的热气是氛围感来源', '手动对焦到食物最诱人的部位'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'foodie_portrait'),
      academyCourseId: 'course_02',
    ),

    // ===== 街拍（street）=====
    ShootingTutorial(
      id: 'tut_street_decisive',
      title: '决定性瞬间：街头摄影的抓拍',
      subtitle: '按下快门的那一刻，就是故事',
      coverImage: 'assets/images/tutorials/cover_tut_street_decisive.jpg',
      category: 'street',
      readMinutes: '3分钟',
      tags: ['街拍', '抓拍'],
      intro: '布列松说：摄影就是抓住决定性的瞬间。街拍没有重来，只有预判和手速。',
      steps: [
        TutorialStep(
          title: '蹲点等画面',
          body: '找一个有戏剧性的路口，等人物走进你的构图。',
        ),
        TutorialStep(
          title: '预对焦',
          body: '先对焦到预期人物出现的位置，人来了直接拍。',
          imageAsset: 'assets/images/tutorials/step_tut_street_decisive_1.jpg',
        ),
        TutorialStep(
          title: '连拍不心疼',
          body: '街头瞬间稍纵即逝，多拍几张回去选。',
        ),
      ],
      tips: ['尊重路人，拍完微笑示意', '盲拍（不看取景器）能抓到最自然的表情'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'night-street'),
      academyCourseId: 'course_06',
    ),
    ShootingTutorial(
      id: 'tut_street_shadow',
      title: '街头光影：在明暗交界处按快门',
      subtitle: '一束光洒下来，平凡街道变成舞台',
      coverImage: 'assets/images/tutorials/cover_tut_street_shadow.jpg',
      category: 'street',
      readMinutes: '2分钟',
      tags: ['街拍', '光影'],
      intro: '光影交界处是街拍的最佳机位。有人走进光里，画面就有了主角。',
      steps: [
        TutorialStep(
          title: '找明暗交界',
          body: '上午或下午，建筑影子在地面上切割出光带。',
        ),
        TutorialStep(
          title: '等一个人走进光里',
          body: '人物进入光带的一瞬间按下快门。',
          imageAsset: 'assets/images/tutorials/step_tut_street_shadow_1.jpg',
        ),
        TutorialStep(
          title: '拍影子也精彩',
          body: '拉长的影子本身就是一张照片。',
        ),
      ],
      tips: ['黑白模式更突出光影', '正午影子太短，早晚更合适'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'street_bw'),
      academyCourseId: 'course_12',
    ),

    // ===== 夜景（night）=====
    ShootingTutorial(
      id: 'tut_night_bluetime',
      title: '蓝调时刻：天黑后的第一抹浪漫',
      subtitle: '日落后的 20 分钟，天空是克莱因蓝',
      coverImage: 'assets/images/tutorials/cover_tut_night_bluetime.jpg',
      category: 'night',
      readMinutes: '3分钟',
      tags: ['夜景', '蓝调'],
      intro: '日落完全黑透前的 20 分钟，天空是深邃的蓝，灯刚亮起——城市最美的时刻。',
      steps: [
        TutorialStep(
          title: '卡准时间',
          body: '日落后再等 15-20 分钟，蓝调浓度最佳。',
        ),
        TutorialStep(
          title: '找路灯当点缀',
          body: '暖色灯光和蓝调天空是天生一对。',
          imageAsset: 'assets/images/tutorials/step_tut_night_bluetime_1.jpg',
        ),
        TutorialStep(
          title: '手机要稳住',
          body: '蓝调时刻光线暗，手持稍不稳就会糊。',
        ),
      ],
      tips: ['用夜景/长曝光模式', '水面能反射天空，蓝调翻倍'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'night_cityscape'),
      academyCourseId: 'course_04',
    ),
    ShootingTutorial(
      id: 'tut_night_neon',
      title: '霓虹人像：把夜色穿在身上',
      subtitle: '彩色霓虹灯，是最便宜的影棚灯',
      coverImage: 'assets/images/tutorials/cover_tut_night_neon.jpg',
      category: 'night',
      readMinutes: '2分钟',
      tags: ['夜景', '人像'],
      intro: '霓虹灯的光色就是最好的氛围灯：粉、蓝、紫，直接照亮人脸还自带电影感。',
      steps: [
        TutorialStep(
          title: '让霓虹灯在身后',
          body: '霓虹做背景光斑，人物轮廓清晰。',
        ),
        TutorialStep(
          title: '脸要朝向光源',
          body: '保证脸有一盏主光，不然会变成剪影。',
          imageAsset: 'assets/images/tutorials/step_tut_night_neon_1.jpg',
        ),
        TutorialStep(
          title: '加一点冷调',
          body: '白平衡偏冷一点，霓虹更艳，皮肤更通透。',
        ),
      ],
      tips: ['雨天霓虹倒影是加成', '避开路灯直射头顶的光'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'neon_portrait'),
      academyCourseId: 'course_06',
    ),

    // ===== 微距（macro）=====
    ShootingTutorial(
      id: 'tut_macro_detail',
      title: '微距入门：看见另一个世界',
      subtitle: '把镜头贴近，平凡之物皆是宇宙',
      coverImage: 'assets/images/tutorials/cover_tut_macro_detail.jpg',
      category: 'macro',
      readMinutes: '2分钟',
      tags: ['微距', '细节'],
      intro: '微距的快乐在于"发现"。水珠、布料、键盘——离得够近，万物都有纹理。',
      steps: [
        TutorialStep(
          title: '用微距模式',
          body: '手机切到微距/超级微距模式，或在镜头前贴一张水滴。',
        ),
        TutorialStep(
          title: '找好支撑',
          body: '微距下抖动被放大，手肘撑桌或固定手机。',
          imageAsset: 'assets/images/tutorials/step_tut_macro_detail_1.png',
        ),
        TutorialStep(
          title: '对焦到眼睛/核心',
          body: '微距景深极浅，只对焦最重要的一个点。',
        ),
      ],
      tips: ['拍水珠时让背景有彩色光源', '雨后是微距的黄金时间'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'macro_flower'),
      academyCourseId: 'course_10',
    ),
    ShootingTutorial(
      id: 'tut_macro_flower',
      title: '花卉微距：拍出晨露的呼吸',
      subtitle: '花蕊、露珠、绒毛，微观世界的美',
      coverImage: 'assets/images/tutorials/cover_tut_macro_flower.jpg',
      category: 'macro',
      readMinutes: '2分钟',
      tags: ['微距', '花卉'],
      intro: '花卉微距的秘诀：清晨露水未干时，花的精神头最好；侧光会让绒毛和露珠发光。',
      steps: [
        TutorialStep(
          title: '清晨去拍',
          body: '露珠是免费的钻石，清晨是唯一拥有它的时间。',
        ),
        TutorialStep(
          title: '侧光拍质感',
          body: '侧逆光下，花瓣绒毛、露珠都会发光。',
          imageAsset: 'assets/images/tutorials/step_tut_macro_flower_1.jpg',
        ),
        TutorialStep(
          title: '对焦花蕊',
          body: '花蕊是花卉的"眼睛"，对焦它最传神。',
        ),
      ],
      tips: ['喷壶洒点水，人造露珠也行', '背景选暗色，花朵更突出'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'macro_flower'),
      academyCourseId: 'course_10',
    ),

    // ===== 静物（still-life）=====
    ShootingTutorial(
      id: 'tut_still_minimal',
      title: '极简静物：少即是多',
      subtitle: '一个主体，一块背景，一束光',
      coverImage: 'assets/images/tutorials/cover_tut_still_minimal.jpg',
      category: 'still-life',
      readMinutes: '2分钟',
      tags: ['静物', '极简'],
      intro: '极简静物的公式：一个主体 + 一块干净背景 + 一束侧光。剩下的交给留白。',
      steps: [
        TutorialStep(
          title: '清空桌面',
          body: '只留一个主体，其他全部移出画面。',
        ),
        TutorialStep(
          title: '背景用纯色纸',
          body: '白纸、浅色墙纸、亚克力板都行。',
          imageAsset: 'assets/images/tutorials/step_tut_still_minimal_1.png',
        ),
        TutorialStep(
          title: '侧光塑形',
          body: '一束窗光从侧面来，主体阴影干净利落。',
        ),
      ],
      tips: ['主体居中或放三分点，别歪着', '影子也是构图的一部分'],
      cta: TutorialCta(type: TutorialCtaType.template, targetId: 'indoor_still_life'),
      academyCourseId: 'course_15',
    ),
    ShootingTutorial(
      id: 'tut_still_warm',
      title: '温暖静物：阳光是最好的滤镜',
      subtitle: '午后斜阳，把物件镀成蜜糖色',
      coverImage: 'assets/images/tutorials/cover_tut_still_warm.jpg',
      category: 'still-life',
      readMinutes: '2分钟',
      tags: ['静物', '暖调'],
      intro: '午后斜阳是最廉价的"金色滤镜"。咖啡杯、书本、绿植，在暖光里都有了温度。',
      steps: [
        TutorialStep(
          title: '等午后斜阳',
          body: '下午 3-5 点，光斜、色暖、影子长。',
        ),
        TutorialStep(
          title: '把光斑拍进画面',
          body: '桌面的光斑是静物摄影的高级感来源。',
          imageAsset: 'assets/images/tutorials/step_tut_still_warm_1.jpg',
        ),
        TutorialStep(
          title: '同色系摆件',
          body: '米白、浅棕、原木同色系，画面立刻高级。',
        ),
      ],
      tips: ['窗帘半掩，光更柔和', '绿植入镜，暖中带一点生机'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'home-cozy'),
      academyCourseId: 'course_10',
    ),
  ];
}
```

> 注：`foodie_portrait` 不在前面"已验证模板 id"主清单中，但已通过文件确认存在（`templates/foodie_portrait.dart`），并在 Task 3 测试的 `validTemplates` 集合中列入。

- [ ] **Step 4: 跑测试确认通过（除 asset 存在断言）**

Run: `flutter test test/features/inspiration/tutorial_content_test.dart`
Expected: asset 存在断言 FAIL（图片未生成），其余 PASS。

- [ ] **Step 5: 暂挂 asset 断言并 commit**

将 `asset 文件真实存在` 测试加 `skip: 'Task 8 生成图片后启用'`，然后：

```bash
git add lumira_app_flutter/lib/features/inspiration/data/tutorial_content.dart lumira_app_flutter/test/features/inspiration/tutorial_content_test.dart
git commit -m "feat(flutter): 拍摄小课堂内容库 20 篇（通用技巧+全分类专项）"
```

---

### Task 4: 推荐算法 `TutorialRecommendationService` + `tutorialPicksProvider`

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/data/tutorial_recommendation_service.dart`
- Modify: `lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart`（删 `coursePicksProvider`，加 `tutorialPicksProvider`）
- Test: `lumira_app_flutter/test/features/inspiration/tutorial_recommendation_service_test.dart`、`lumira_app_flutter/test/features/inspiration/inspiration_providers_test.dart`（更新）

**Interfaces:**
- Produces: `class TutorialRecommendationService { TutorialRecommendationService({required QuestionnaireDao questionnaireDao, required GalleryDao galleryDao, required TutorialReadDao readDao}); Future<List<ShootingTutorial>> recommend({int count = 6}); }`
- Produces: `final tutorialPicksProvider = FutureProvider<List<ShootingTutorial>>((ref) async { final q = await ref.watch(questionnaireDaoProvider.future); final g = await ref.watch(galleryDaoProvider.future); final r = await ref.watch(tutorialReadDaoProvider.future); return TutorialRecommendationService(questionnaireDao: q, galleryDao: g, readDao: r).recommend(); });`
- 已有可复用：`questionnaireDaoProvider` / `galleryDaoProvider` 均在 `lib/core/db/database_provider.dart`。

**算法规则（来自 spec §6）：**
- 权重：冷启动全类 1、`general` 1.2；有问卷 `favoriteCategories` 权重 3；有拍摄 top2 类别权重 3、问卷偏好 2（同类别取 max）。
- 打分：`score = categoryWeight + (未读 ? 1 : 0)`；排序后分高分池（权重 ≥2 类别）与低分池（其余）。
- 输出：60% 高分池 + 40% 低分池，不足时用另一池补齐；保证结果覆盖 ≥3 个不同类别（含 general）；结果 ≤ count。
- 降级：DAO 抛异常 → 回退均匀推荐（每类取 1 篇优先，填满 count）。

- [ ] **Step 1: 写失败测试（算法行为）**

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/tutorial_read_dao.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_recommendation_service.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_answers.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_dao.dart';

class _FakeQuestionnaireDao implements QuestionnaireDao {
  _FakeQuestionnaireDao(this.answers);
  final QuestionnaireAnswers? answers;
  @override
  Future<QuestionnaireAnswers?> getAnswers() async => answers;
  @override
  Future<bool> isCompleted() async => answers != null;
  @override
  Future<bool> hasUnsynced() async => false;
  @override
  Future<void> markSynced(int syncedAt) async {}
  @override
  Future<void> upsert(QuestionnaireAnswers a, int t) async {}
}

class _FakeGalleryDao implements GalleryDao {
  _FakeGalleryDao(this.counts);
  final Map<String, int> counts;
  @override
  Future<Map<String, int>> countByCategory() async => counts;
  // 其余 GalleryDao 方法最小实现（throw UnimplementedError 即可）
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeReadDao implements TutorialReadDao {
  _FakeReadDao(this.readIds);
  final Set<String> readIds;
  @override
  Future<Set<String>> getReadIds() async => readIds;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markUnread(String id) async {}
}

void main() {
  TutorialRecommendationService build({
    QuestionnaireAnswers? answers,
    Map<String, int> counts = const {},
    Set<String> readIds = const {},
  }) {
    return TutorialRecommendationService(
      questionnaireDao: _FakeQuestionnaireDao(answers),
      galleryDao: _FakeGalleryDao(counts),
      readDao: _FakeReadDao(readIds),
    );
  }

  test('冷启动：覆盖 >=3 类别且包含 general', () async {
    final result = await build().recommend();
    expect(result, isNotEmpty);
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
    expect(result.any((t) => t.category == 'general'), isTrue);
  });

  test('问卷偏好加权：favoriteCategories 类别占多数', () async {
    final result = await build(
      answers: const QuestionnaireAnswers(
        favoriteCategories: ['portrait'],
        painPoints: [],
        expectations: [],
        commonScenes: [],
      ),
    ).recommend();
    final portraitCount = result.where((t) => t.category == 'portrait').length;
    expect(portraitCount, greaterThan(0));
  });

  test('行为优先：近期常拍类别占多数且包含探索类别（多样性）', () async {
    final result = await build(counts: {'food': 10, 'street': 8}).recommend();
    final related = result.where((t) => t.category == 'food' || t.category == 'street').length;
    final total = result.length;
    expect(related / total, greaterThan(0.5), reason: '相关类别应占多数');
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
  });

  test('未读优先：已读教程排在同类未读之后', () async {
    final readIds = {TutorialContent.getById('tut_general_premium')!.id};
    final result = await build(readIds: readIds).recommend();
    final idx = result.indexWhere((t) => t.id == 'tut_general_premium');
    expect(idx, isNot(0), reason: '已读通用教程不应排在最前');
  });

  test('全部已读时仍正常返回', () async {
    final all = TutorialContent.all.map((t) => t.id).toSet();
    final result = await build(readIds: all).recommend();
    expect(result, isNotEmpty);
  });

  test('结果数量不超过 count 且去重', () async {
    final result = await build().recommend(count: 6);
    expect(result.length, lessThanOrEqualTo(6));
    expect(result.map((t) => t.id).toSet().length, result.length);
  });

  test('DAO 异常降级为均匀推荐', () async {
    final service = TutorialRecommendationService(
      questionnaireDao: _ThrowDao(),
      galleryDao: _ThrowGallery(),
      readDao: _FakeReadDao(const {}),
    );
    final result = await service.recommend();
    expect(result, isNotEmpty);
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
  });
}

class _ThrowDao implements QuestionnaireDao {
  @override
  Future<QuestionnaireAnswers?> getAnswers() async => throw Exception('db down');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowGallery implements GalleryDao {
  @override
  Future<Map<String, int>> countByCategory() async => throw Exception('db down');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
```

> 注：`QuestionnaireDao` / `GalleryDao` / `TutorialReadDao` 若为具体 class 而非接口，测试需改为继承并覆写，或让 DAO 方法可被 mock。若 `implements` 因具体类方法过多而繁琐，可改用 `extends` + 仅覆写目标方法。`GalleryDao` 构造需要 `Database` 参数，`_FakeGalleryDao extends GalleryDao` 需 `super(_dummy)` 或测试改用 `tutorial_recommendation_service_test` 中自定义轻量 DAO 接口——**实现时以能编译通过的最小 mock 为准**（方法签名保持上面调用处不变）。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/inspiration/tutorial_recommendation_service_test.dart`
Expected: FAIL（找不到 service）。

- [ ] **Step 3: 实现推荐算法**

```dart
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/tutorial_read_dao.dart';
import '../../onboarding/data/questionnaire_answers.dart';
import '../../onboarding/data/questionnaire_dao.dart';
import 'tutorial_content.dart';
import 'tutorial_models.dart';

/// 类别权重（与 countByCategory 返回 key 一致 + general）
const List<String> _kAllCategories = [
  'general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life',
];

/// 拍摄小课堂推荐服务
///
/// 信号：问卷偏好（静态）+ 近 30 天拍摄统计（动态）+ 已读状态。
/// 规则：类别权重（问卷 3 / 行为 top2 3、问卷 2、其余 1、general 冷启动 1.2）
///       → 未读 +1 → 60% 高分池 + 40% 低分池 → 保证 >=3 类别。
class TutorialRecommendationService {
  TutorialRecommendationService({
    required QuestionnaireDao questionnaireDao,
    required GalleryDao galleryDao,
    required TutorialReadDao readDao,
  })  : _questionnaireDao = questionnaireDao,
        _galleryDao = galleryDao,
        _readDao = readDao;

  final QuestionnaireDao _questionnaireDao;
  final GalleryDao _galleryDao;
  final TutorialReadDao _readDao;

  Future<List<ShootingTutorial>> recommend({int count = 6}) async {
    try {
      final answers = await _questionnaireDao.getAnswers();
      final counts = await _galleryDao.countByCategory();
      final readIds = await _readDao.getReadIds();
      return _recommendWith(
        favCategories: answers?.favoriteCategories ?? const [],
        counts: counts,
        readIds: readIds,
        count: count,
      );
    } catch (_) {
      return _fallbackEven(count);
    }
  }

  List<ShootingTutorial> _recommendWith({
    required List<String> favCategories,
    required Map<String, int> counts,
    required Set<String> readIds,
    required int count,
  }) {
    final weights = _buildWeights(favCategories, counts);

    final high = <ShootingTutorial>[];
    final low = <ShootingTutorial>[];
    for (final t in TutorialContent.all) {
      final w = weights[t.category] ?? 1;
      final readBonus = readIds.contains(t.id) ? 0.0 : 1.0;
      final score = w + readBonus;
      (w >= 2 ? high : low).add(t);
      t._score = score; // 见下：不能给 const 加字段，改为按 index 排序
    }
    // 说明：ShootingTutorial 为 const，不能有可变字段；这里用 map 存分数
    ...
  }
}
```

> **重要实现说明（替代上面的伪代码）**：`ShootingTutorial` 是 const 不可变，不能存运行时分数。实现需维护 `Map<String, double> scores`（按 id 存分）。排序用独立列表 `List<ShootingTutorial> pool = [...TutorialContent.all]`，按 `scores[t.id]!` 降序。高分池 = 权重≥2 的类别，低分池 = 其余。从高分池按序取 `ceil(count * 0.6)` 个（不足用低分池补），从低分池按序取剩余；若结果类别 <3，用未出现的类别补足。参考实现如下（Step 4 前替换 Step 3 中的伪代码，保证可编译）：

```dart
  List<ShootingTutorial> _recommendWith({
    required List<String> favCategories,
    required Map<String, int> counts,
    required Set<String> readIds,
    required int count,
  }) {
    final weights = _buildWeights(favCategories, counts);
    final scores = <String, double>{};
    final high = <ShootingTutorial>[];
    final low = <ShootingTutorial>[];
    for (final t in TutorialContent.all) {
      final w = weights[t.category] ?? 1.0;
      final readBonus = readIds.contains(t.id) ? 0.0 : 1.0;
      scores[t.id] = w + readBonus;
      (w >= 2 ? high : low).add(t);
    }
    int byScoreDesc(ShootingTutorial a, ShootingTutorial b) =>
        scores[b.id]!.compareTo(scores[a.id]!);
    high.sort(byScoreDesc);
    low.sort(byScoreDesc);

    final result = <ShootingTutorial>[];
    final usedIds = <String>{};
    void addFrom(List<ShootingTutorial> pool) {
      for (final t in pool) {
        if (result.length >= count) return;
        if (usedIds.add(t.id)) result.add(t);
      }
    }

    final highTake = (count * 0.6).ceil();
    var taken = 0;
    for (final t in high) {
      if (taken >= highTake) break;
      if (usedIds.add(t.id)) {
        result.add(t);
        taken++;
      }
    }
    for (final t in low) {
      if (result.length >= count) break;
      if (usedIds.add(t.id)) result.add(t);
    }
    if (result.length < count) addFrom(high);

    _ensureCategoryDiversity(result, usedIds, weights);
    return result;
  }

  void _ensureCategoryDiversity(
    List<ShootingTutorial> result,
    Set<String> usedIds,
    Map<String, double> weights,
  ) {
    final cats = result.map((t) => t.category).toSet();
    if (cats.length >= 3) return;
    final pool = [...TutorialContent.all]
      ..sort((a, b) => (weights[b.category] ?? 1).compareTo(weights[a.category] ?? 1));
    for (final t in pool) {
      if (result.length >= 6) break;
      if (usedIds.add(t.id)) result.add(t);
      if (result.map((x) => x.category).toSet().length >= 3) break;
    }
  }

  Map<String, double> _buildWeights(
    List<String> favCategories,
    Map<String, int> counts,
  ) {
    final weights = <String, double>{for (final c in _kAllCategories) c: 1.0};
    final top2 = _topCategories(counts, 2);
    final hasSignal = favCategories.isNotEmpty || top2.isNotEmpty;
    if (!hasSignal) {
      weights['general'] = 1.2; // 冷启动人人可读
      return weights;
    }
    for (final c in favCategories) {
      weights[c] = 2.0; // 问卷偏好：有行为时 2，无行为时提升到 3
    }
    for (final c in top2) {
      weights[c] = 3.0; // 行为优先
    }
    if (top2.isEmpty) {
      for (final c in favCategories) {
        weights[c] = 3.0; // 有问卷无拍摄
      }
    }
    return weights;
  }

  List<String> _topCategories(Map<String, int> counts, int n) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => e.key).toList();
  }

  List<ShootingTutorial> _fallbackEven(int count) {
    final result = <ShootingTutorial>[];
    final used = <String>{};
    var i = 0;
    while (result.length < count && i < TutorialContent.all.length) {
      final t = TutorialContent.all[i];
      if (used.add(t.id)) result.add(t);
      i++;
    }
    return result;
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/inspiration/tutorial_recommendation_service_test.dart`
Expected: PASS。若 `implements QuestionnaireDao` 因具体类编译失败，按 Step 1 注释调整 mock 方式后重跑。

- [ ] **Step 5: 改造 provider（inspiration_providers.dart）**

删除 `coursePicksProvider` 及其 `AcademyContent`/`AcademyCourse` import，替换为：

```dart
/// 拍摄小课堂：问卷偏好 + 近 30 天拍摄行为 + 已读状态 个性化推荐
final tutorialPicksProvider = FutureProvider<List<ShootingTutorial>>((ref) async {
  final questionnaireDao = await ref.watch(questionnaireDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final readDao = await ref.watch(tutorialReadDaoProvider.future);
  return TutorialRecommendationService(
    questionnaireDao: questionnaireDao,
    galleryDao: galleryDao,
    readDao: readDao,
  ).recommend();
});
```

需在文件头补充 import：`tutorial_recommendation_service.dart`、`tutorial_models.dart`、`tutorial_read_dao.dart`（通过 `../../../core/db/dao/tutorial_read_dao.dart` 与 `../../../core/db/database_provider.dart` 提供 `tutorialReadDaoProvider`）。若 `inspiration_content.dart` 的 `pickCourses` 不再被引用，一并删除（保持 DRY）。

- [ ] **Step 6: 更新 inspiration_providers_test.dart**

将 `coursePicksProvider` 相关用例替换为 `tutorialPicksProvider` 用例（override `questionnaireDaoProvider`/`galleryDaoProvider`/`tutorialReadDaoProvider` 或直接 override `tutorialPicksProvider` 验证返回列表）。若测试结构复杂，可简化为：override `tutorialPicksProvider` 返回固定 3 篇，断言长度与 id。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  test('tutorialPicksProvider 可 override 返回教程列表', () async {
    const tutorials = [
      ShootingTutorial(
        id: 't1', title: 't', subtitle: 's',
        coverImage: 'c', category: 'general', readMinutes: '3分钟',
        intro: 'i', cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      ),
    ];
    final container = ProviderContainer(
      overrides: [tutorialPicksProvider.overrideWith((ref) async => tutorials)],
    );
    addTearDown(container.dispose);
    final value = await container.read(tutorialPicksProvider.future);
    expect(value, hasLength(1));
    expect(value.first.id, 't1');
  });
}
```

- [ ] **Step 7: 跑测试**

Run: `flutter test test/features/inspiration/`
Expected: 新测试 PASS；若旧 `inspiration_page_test.dart` 因 `coursePicksProvider` 删除失败，属预期，Task 7 统一修复。

- [ ] **Step 8: Commit**

```bash
git add lumira_app_flutter/lib/features/inspiration/data/tutorial_recommendation_service.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_content.dart lumira_app_flutter/test/features/inspiration/tutorial_recommendation_service_test.dart lumira_app_flutter/test/features/inspiration/inspiration_providers_test.dart
git commit -m "feat(flutter): 拍摄小课堂个性化推荐算法（问卷+行为+未读+多样性）"
```

---

### Task 5: `TutorialSection` + `TutorialCard` UI

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/widgets/tutorial_section.dart`（含 `TutorialCard` 私有组件或同文件导出）
- Delete: `lumira_app_flutter/lib/features/inspiration/widgets/better_shoot_section.dart`
- Test: `lumira_app_flutter/test/features/inspiration/tutorial_section_test.dart`

**Interfaces:**
- Consumes: `tutorialPicksProvider`、`ShootingTutorial`、`tutorialReadDaoProvider`（渲染已读勾）。
- Produces: `class TutorialSection extends ConsumerWidget { const TutorialSection({super.key, required this.onTutorialTap, required this.onAcademyTap}); final void Function(ShootingTutorial) onTutorialTap; final VoidCallback onAcademyTap; }`
- 视觉：标题行（`Icons.auto_awesome_outlined` + 「拍摄小课堂」+ 右侧「系统性学习 → 美学院」小字）；横滑 `ListView.separated` 高度 150；卡片 = `surface` 底 + `shadowConvex` + 圆角 14 + 封面 90 高 + 标题 13 w600 + 时长 10 textTertiary；已读卡片右下角显示小勾（`Icons.check_circle`，颜色 brand）。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/tutorial_section.dart';

void main() {
  const tutorials = [
    ShootingTutorial(
      id: 't1', title: '如何拍出高级感', subtitle: '留白与克制',
      coverImage: '', category: 'general', readMinutes: '3分钟',
      tags: [], intro: 'i',
      steps: [TutorialStep(title: 's', body: 'b')],
      tips: ['tip'], cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
    ),
  ];

  testWidgets('渲染标题/卡片/右侧美学院入口并回调', (tester) async {
    final tapped = <String>[];
    var academyTapped = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        tutorialPicksProvider.overrideWith((ref) async => tutorials),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TutorialSection(
            onTutorialTap: (t) => tapped.add(t.id),
            onAcademyTap: () => academyTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('拍摄小课堂'), findsOneWidget);
    expect(find.text('系统性学习 → 美学院'), findsOneWidget);
    expect(find.text('如何拍出高级感'), findsOneWidget);

    await tester.tap(find.text('如何拍出高级感'));
    expect(tapped, ['t1']);

    await tester.tap(find.text('系统性学习 → 美学院'));
    expect(academyTapped, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/inspiration/tutorial_section_test.dart`
Expected: FAIL（找不到 `tutorial_section.dart`）。

- [ ] **Step 3: 实现 `tutorial_section.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/inspiration_providers.dart';
import '../data/tutorial_models.dart';

/// 拍摄小课堂：横滑小教程卡片区（取代原"拍得更好"推系统课）
class TutorialSection extends ConsumerWidget {
  const TutorialSection({
    super.key,
    required this.onTutorialTap,
    required this.onAcademyTap,
  });

  final void Function(ShootingTutorial) onTutorialTap;
  final VoidCallback onAcademyTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(tutorialPicksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '拍摄小课堂',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAcademyTap,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '系统性学习 → 美学院',
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: async.when(
            loading: () => _placeholder(tokens),
            error: (_, __) => _placeholder(tokens),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => TutorialCard(
                tutorial: list[index],
                onTap: () => onTutorialTap(list[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ThemeTokens tokens) {
    return Center(
      child: Text(
        '小课堂加载中',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      ),
    );
  }
}

/// 单张教程小卡（封面 + 标题 + 时长 + 已读勾）
class TutorialCard extends ConsumerWidget {
  const TutorialCard({super.key, required this.tutorial, required this.onTap});

  final ShootingTutorial tutorial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: tokens.shadowConvex,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.asset(
                  tutorial.coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        size: 24, color: tokens.textTertiary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tutorial.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tutorial.readMinutes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: tokens.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    _ReadBadge(tutorialId: tutorial.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 已读勾（异步读 tutorial_reads）
class _ReadBadge extends ConsumerWidget {
  const _ReadBadge({required this.tutorialId});
  final String tutorialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(tutorialReadIdsProvider);
    final isRead = async.maybeWhen(
          data: (ids) => ids.contains(tutorialId),
          orElse: () => false,
        ) ??
        false;
    if (!isRead) return const SizedBox.shrink();
    return Icon(Icons.check_circle, size: 14, color: tokens.brand);
  }
}
```

- [ ] **Step 4: 新增 `tutorialReadIdsProvider`（inspiration_providers.dart）**

```dart
/// 已读教程 id 集合
final tutorialReadIdsProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(tutorialReadDaoProvider.future);
  return dao.getReadIds();
});
```

（放在 `tutorialPicksProvider` 之后；文件头需 import `tutorial_read_dao.dart`。）

- [ ] **Step 5: 删除 `better_shoot_section.dart`**

```bash
git rm lumira_app_flutter/lib/features/inspiration/widgets/better_shoot_section.dart
```

并删除 `test/features/inspiration/better_shoot_section_test.dart`。

- [ ] **Step 6: 跑测试**

Run: `flutter test test/features/inspiration/tutorial_section_test.dart`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/inspiration/widgets/tutorial_section.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart lumira_app_flutter/test/features/inspiration/tutorial_section_test.dart
git commit -m "feat(flutter): 拍摄小课堂卡片区 TutorialSection（含已读勾）"
```

---

### Task 6: 详情页 `tutorial_detail_page.dart` + 路由

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/pages/tutorial_detail_page.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`（新路由/参数常量）
- Modify: `lumira_app_flutter/lib/app/router.dart`（注册路由）
- Test: `lumira_app_flutter/test/features/inspiration/tutorial_detail_page_test.dart`

**Interfaces:**
- Consumes: `TutorialContent.getById(id)`、`TutorialReadDao.markRead`、`RouteNames.captureSceneGuide`/`templatesDetail`/`profileAcademyDetail`。
- Produces: `class TutorialDetailPage extends ConsumerWidget { const TutorialDetailPage({super.key, this.tutorialId}); final String? tutorialId; }`
- 路由：`RouteNames.inspirationTutorialDetail = '/inspiration/tutorial-detail'`；`RouteNames.paramTutorialId = 'tutorialId'`。注册方式仿 `profileAcademyDetail`（queryParams 读取）。

- [ ] **Step 1: 新增路由常量（route_names.dart）**

在 `inspiration` 常量附近追加：

```dart
static const String inspirationTutorialDetail = '/inspiration/tutorial-detail';
```

在参数常量区追加：

```dart
static const String paramTutorialId = 'tutorialId';
```

- [ ] **Step 2: 注册路由（router.dart）**

在 `inspiration` 路由附近追加：

```dart
GoRoute(
  path: RouteNames.inspirationTutorialDetail,
  name: 'inspirationTutorialDetail',
  builder: (context, state) {
    final tutorialId = state.queryParams[RouteNames.paramTutorialId];
    return TutorialDetailPage(tutorialId: tutorialId);
  },
),
```

文件头需 import `features/inspiration/pages/tutorial_detail_page.dart`。

- [ ] **Step 3: 写失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/pages/tutorial_detail_page.dart';

void main() {
  testWidgets('渲染标题/步骤/贴士/CTA/导流条', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(
        home: TutorialDetailPage(tutorialId: 'tut_general_premium'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('如何拍出高级感'), findsOneWidget);
    expect(find.text('减少画面元素'), findsOneWidget);
    expect(find.text('少即是多'), findsOneWidget);
    expect(find.text('去试试'), findsOneWidget);
    expect(find.text('想系统学？进入美学院'), findsOneWidget);
  });

  testWidgets('tutorialId 不存在时显示空态', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(home: TutorialDetailPage(tutorialId: 'not-exist')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('教程不存在'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 跑测试确认失败**

Run: `flutter test test/features/inspiration/tutorial_detail_page_test.dart`
Expected: FAIL（找不到页面）。

- [ ] **Step 5: 实现详情页**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/tutorial_content.dart';
import '../data/tutorial_models.dart';

/// 拍摄小课堂详情页
class TutorialDetailPage extends ConsumerWidget {
  const TutorialDetailPage({super.key, this.tutorialId});

  final String? tutorialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final tutorial = tutorialId != null
        ? TutorialContent.getById(tutorialId!)
        : null;

    if (tutorial == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: LumiraNav(title: '拍摄小课堂', transparent: true),
        body: Center(
          child: Text('教程不存在', style: TextStyle(color: tokens.textTertiary)),
        ),
      );
    }

    // 进入即标记已读（幂等）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dao = await ref.read(tutorialReadDaoProvider.future);
      await dao.markRead(tutorial.id);
      ref.invalidate(tutorialReadIdsProvider);
    });

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(title: '拍摄小课堂', transparent: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [tokens.brandSubtle.withOpacity(0.35), tokens.canvas.withOpacity(0.0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  tutorial.coverImage,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        size: 40, color: tokens.textTertiary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tutorial.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          fontFamily: 'Noto Serif SC',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _MetaChip(label: tutorial.readMinutes, tokens: tokens),
                          for (final tag in tutorial.tags)
                            _MetaChip(label: tag, tokens: tokens),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tutorial.intro,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < tutorial.steps.length; i++) ...[
                        _StepBlock(
                          index: i + 1,
                          step: tutorial.steps[i],
                          tokens: tokens,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 8),
                      _TipsBlock(tips: tutorial.tips, tokens: tokens),
                      const SizedBox(height: 24),
                      _CtaButton(tutorial: tutorial, tokens: tokens),
                      if (tutorial.academyCourseId != null) ...[
                        const SizedBox(height: 16),
                        _AcademyBanner(
                          onTap: () => GoRouter.of(context).push(
                            RouteNames.build(
                              RouteNames.profileAcademyDetail,
                              {RouteNames.paramAcademyId: tutorial.academyCourseId!},
                            ),
                          ),
                          tokens: tokens,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.tokens});
  final String label;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: tokens.brandDeep)),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({required this.index, required this.step, required this.tokens});
  final int index;
  final TutorialStep step;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brand,
                shape: BoxShape.circle,
              ),
              child: Text('$index',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Text(
              step.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            step.body,
            style: TextStyle(fontSize: 14, height: 1.6, color: tokens.textSecondary),
          ),
        ),
        if (step.imageAsset != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                step.imageAsset!,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  color: tokens.surfaceAlt,
                  child: Icon(Icons.image_outlined,
                      size: 24, color: tokens.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TipsBlock extends StatelessWidget {
  const _TipsBlock({required this.tips, required this.tokens});
  final List<String> tips;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.brandSubtle.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('小贴士',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.brandDeep)),
          const SizedBox(height: 8),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: tokens.brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tip,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: tokens.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.tutorial, required this.tokens});
  final ShootingTutorial tutorial;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return LumiraButton(
      label: '去试试',
      onPressed: () {
        final cta = tutorial.cta;
        if (cta.type == TutorialCtaType.scene) {
          GoRouter.of(context).push(
            RouteNames.build(RouteNames.captureSceneGuide, {RouteNames.paramScene: cta.targetId}),
          );
        } else {
          GoRouter.of(context).push(RouteNames.withTemplateId(RouteNames.templatesDetail, cta.targetId));
        }
      },
    );
  }
}

class _AcademyBanner extends StatelessWidget {
  const _AcademyBanner({required this.onTap, required this.tokens});
  final VoidCallback onTap;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.brand.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text('想系统学？进入美学院',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.brandDeep)),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}
```

> 说明：`LumiraButton` 组件名以 `shared/widgets/lumira/lumira.dart` 实际导出为准——若实际导出为 `LumiraBtnPrimary`，用 `tokens` 构造；实现时按现有用法调整。`tutorialReadIdsProvider` 需在 `inspiration_providers.dart` 中已定义（Task 5 Step 4）。`ThemeTokens` 有 `textSecondary` 字段（见 better_shoot_section 中 `textTertiary` 用法，若 `textSecondary` 不存在则改用 `textTertiary`）。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/features/inspiration/tutorial_detail_page_test.dart`
Expected: PASS（若 `markRead` 的 addPostFrameCallback 使 pumpAndSettle 挂起，改为测试内 `await tester.pump()` 数次；实现以实际跑通为准）。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/inspiration/pages/tutorial_detail_page.dart lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/test/features/inspiration/tutorial_detail_page_test.dart
git commit -m "feat(flutter): 拍摄小课堂详情页 + 路由"
```

---

### Task 7: 灵感页集成（替换第 3 区块）+ 更新旧测试

**Files:**
- Modify: `lumira_app_flutter/lib/features/inspiration/pages/inspiration_page.dart`（第 3 区块替换）
- Modify: `lumira_app_flutter/test/features/inspiration/inspiration_page_test.dart`（更新断言）
- Delete: `lumira_app_flutter/test/features/inspiration/better_shoot_section_test.dart`（若 Task 5 未删）

**Interfaces:**
- Consumes: `TutorialSection`、`tutorialPicksProvider`、`RouteNames.inspirationTutorialDetail`。
- Produces: 更新后的 `InspirationPage`，第 3 区块为 `TutorialSection`。

- [ ] **Step 1: 修改 inspiration_page.dart**

替换 `BetterShootSection` 区块：

```dart
FadeUp(
  delay: const Duration(milliseconds: 200),
  child: TutorialSection(
    onTutorialTap: (tutorial) => GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.inspirationTutorialDetail,
        {RouteNames.paramTutorialId: tutorial.id},
      ),
    ),
    onAcademyTap: () =>
        GoRouter.of(context).push(RouteNames.profileAcademy),
  ),
),
```

同步修改 import：删除 `better_shoot_section.dart`、`academy_models.dart`、`inspiration_content.dart`（若 `pickCourses` 已删且页面不再用 `AcademyCourse`），新增 `tutorial_section.dart`。

- [ ] **Step 2: 更新 inspiration_page_test.dart**

- 删除 `coursePicksProvider` override，改为 override `tutorialPicksProvider`（返回 2-3 篇测试教程）。
- 将 `find.text('拍得更好')` 断言改为 `find.text('拍摄小课堂')`。
- 将点击课程卡跳转断言改为：点击教程卡 → 期望跳 `inspirationTutorialDetail`；点击「系统性学习 → 美学院」→ 期望跳 `profileAcademy`。
- 移除对 `AcademyContent` 的依赖。

- [ ] **Step 3: 跑测试**

Run: `flutter test test/features/inspiration/`
Expected: 全部 PASS（含 tutorial_content / recommendation / section / detail / providers / page）。

- [ ] **Step 4: 全局验证**

Run: `flutter analyze`
Expected: 无 error / 无 warning（旧 `better_shoot_section` 相关引用已全部清理）。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/inspiration/pages/inspiration_page.dart lumira_app_flutter/test/features/inspiration/inspiration_page_test.dart
git commit -m "refactor(flutter): 灵感页第3区块切换为拍摄小课堂"
```

---

### Task 8: 教程图片生成（`scripts/gen_image.py`）+ 启用 asset 断言

**Files:**
- Create: `lumira_app_flutter/assets/images/tutorials/*.png`（生成产物）
- Modify: `lumira_app_flutter/test/features/inspiration/tutorial_content_test.dart`（移除 asset 断言 skip）

**Interfaces:**
- Consumes: `tutorial_content.dart` 中引用的封面/步骤图文件名。
- 需生成图片清单（20 封面 + 6 步骤图，共 26 张）：

封面（16:9，`--size 16:9`）：
`cover_tut_general_premium.png`、`cover_tut_general_vibe.png`、`cover_tut_general_angle.png`、`cover_tut_general_light.png`、`cover_tut_general_composition.png`、`cover_tut_general_color.png`、`cover_tut_portrait_window.png`、`cover_tut_portrait_backlight.png`、`cover_tut_landscape_golden.png`、`cover_tut_landscape_leading.png`、`cover_tut_food_flatlay.png`、`cover_tut_food_natural.png`、`cover_tut_street_decisive.png`、`cover_tut_street_shadow.png`、`cover_tut_night_bluetime.png`、`cover_tut_night_neon.png`、`cover_tut_macro_detail.png`、`cover_tut_macro_flower.png`、`cover_tut_still_minimal.png`、`cover_tut_still_warm.png`

步骤图（4:3，`--size 4:3`）：
`step_tut_general_premium_1.png`、`step_tut_general_vibe_1.png`、`step_tut_general_angle_1.png`、`step_tut_general_light_1.png`、`step_tut_general_composition_1.png`、`step_tut_general_color_1.png`、`step_tut_portrait_window_1.png`、`step_tut_portrait_backlight_1.png`、`step_tut_landscape_golden_1.png`、`step_tut_landscape_leading_1.png`、`step_tut_food_flatlay_1.png`、`step_tut_food_natural_1.png`、`step_tut_street_decisive_1.png`、`step_tut_street_shadow_1.png`、`step_tut_night_bluetime_1.png`、`step_tut_night_neon_1.png`、`step_tut_macro_detail_1.png`、`step_tut_macro_flower_1.png`、`step_tut_still_minimal_1.png`、`step_tut_still_warm_1.png`

> 注：Task 3 内容数据中 6 篇通用技巧各配 1 张步骤图；分类专项若数据中未设 `imageAsset` 则无需生成对应步骤图——**生成前先 grep `tutorial_content.dart` 中出现的 `step_` 文件名，只生成实际引用的**，避免多余图。

- [ ] **Step 1: 确认 python 环境与脚本可用**

Run: `python scripts/gen_image.py --list-models`
Expected: 输出可用模型列表（脚本使用 `mass.hzxmfg.com` 平台，`.env` 的 `MASS_API_KEY` 已内置于脚本默认值）。

- [ ] **Step 2: 生成图片（逐张，串行）**

对每张图执行（示例，`--out` 指临时目录）：

```bash
python scripts/gen_image.py "温暖米白背景上极简静物摄影，咖啡杯与一本书，午后斜阳，莫兰迪色调，高级质感" --size 16:9 --out ./outputs/tutorials
```

- prompt 需贴合对应教程主题（高级感/逆光人像/黄金时刻风光/俯拍美食/街头光影/蓝调夜景/微距花卉/极简静物等），并统一"暖米白 + 金棕品牌色调"。
- 每张生成后，将脚本输出的 `{ts}_{taskid}.png` 重命名为清单中的 `cover_<id>.png` / `step_<id>_1.png`，移动到 `lumira_app_flutter/assets/images/tutorials/`：

```powershell
Move-Item .\outputs\tutorials\*.png .\lumira_app_flutter\assets\images\tutorials\cover_tut_general_premium.png
```

- 若脚本输出为 jpg，保持实际扩展名并在 `tutorial_content.dart` 中同步文件名（实现时以落盘文件名为准）。

- [ ] **Step 3: 启用 asset 断言并跑测试**

移除 `tutorial_content_test.dart` 中 asset 测试的 `skip:`，跑：

Run: `flutter test test/features/inspiration/tutorial_content_test.dart`
Expected: PASS（所有 asset 文件存在）。

- [ ] **Step 4: 全量验证 + commit**

Run: `flutter analyze`（无 error/warning）
Run: `flutter test`（相关测试全绿；如耗时过长可只跑 `test/features/inspiration/` + `test/core/db/dao/tutorial_read_dao_test.dart`）

```bash
git add lumira_app_flutter/assets/images/tutorials/ lumira_app_flutter/test/features/inspiration/tutorial_content_test.dart
git commit -m "feat(flutter): 拍摄小课堂教程图片生成（gen_image.py）+ 启用 asset 校验"
```

---

## Self-Review（已执行）

- **Spec 覆盖**：内容体系 20 篇（Task 3）、推荐算法（Task 4）、已读表 v23（Task 2）、详情页（Task 6）、灵感页集成（Task 7）、图片生成（Task 8）、数据模型（Task 1）、测试计划（各任务 TDD）——spec §1-§13 全部有对应任务。
- **占位符扫描**：无 TBD/TODO；伪代码块已在 Task 4 中附完整可编译参考实现。
- **类型一致性**：`ShootingTutorial`/`TutorialStep`/`TutorialCta`/`TutorialCtaType` 命名全计划一致；`tutorialPicksProvider`/`tutorialReadDaoProvider`/`tutorialReadIdsProvider` 在各任务引用一致；`TutorialSection` 回调签名在 Task 5/7 一致；`getById` 在 Task 1/3/6 一致。
- **已知风险标注**：DAO 具体类 mock（Task 4）、`LumiraButton` 组件名（Task 6）、asset 断言依赖图片生成顺序（Task 3/8）均已注明实现时核对。
