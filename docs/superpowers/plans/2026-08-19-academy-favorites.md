# 摄影美学院收藏功能完善 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让摄影美学院课程收藏真正持久化、新增「我的收藏」总览页（课程+知识卡）、并统一收藏图标为爱心。

**Architecture:** 沿用现有「一张内容一张收藏表」模式：新增 `academy_course_favorite` 表镜像 `academy_knowledge_favorite`；DAO → Repository → Provider 三层各加课程收藏方法；课程详情页的假收藏改为 provider 驱动真收藏；新建总览页统合两类收藏，入口放学院首页 AppBar。纯 Flutter 本地，无后端。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records 语法）、flutter_riverpod 2.3.6、sqflite v11、GoRouter 6.5.7。

设计文档：`docs/superpowers/specs/2026-08-19-academy-favorites-design.md`

## Global Constraints

- Dart 2.19.6，**禁止 Dart 3 records / 新语法**（沿用项目现有写法）。
- 所有改动仅在 `lumira_app_flutter/lib/features/academy/` 与 `lumira_app_flutter/lib/core/router/`、`lumira_app_flutter/lib/app/router.dart`；**不改后端**、**改 uni-app**、也**不重构无关代码**。
- 数据库版本 `_kDbVersion` 由 `24` 升到 `25`；新表建表 SQL 同时写入 `_onCreate` 与 `_onUpgrade(oldVersion < 25)`（幂等）。
- 收藏/取消统一经 `AcademyActionNotifier`，操作后 invalidate 相关 provider，保证多页状态同步。
- 词法/风格沿用现有：theme tokens、`LumiraNav`、`GlassBackground(profile)`、`NeuCard`、`FadeUp`。
- 本仓库无单测基础设施（无 `test/` 目录），验证门禁 = `flutter analyze`（与该仓库 CI 一致）+ 手工路径。不为此搭建 sqflite mock 测试框架（超范围）。

---

### Task 1: 数据层 — 课程收藏表 + DAO 方法

**Files:**
- Modify: `lumira_app_flutter/lib/features/academy/data/academy_dao.dart`（`AcademyTables` 常量区约 L59-69；`AcademyDao` 卡片收藏方法区 L200-231 之后）
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart`（`_kDbVersion` L24；`_onCreate` academy 建表处约 L301-303；`_onUpgrade` 末尾新增 `<25` 分块）

**Interfaces:**
- Produces: `AcademyTables.courseFavorite` / `kfColCourseId`→`cfColCourseId` / `cfColFavoritedAt` / `cfCreateSql`；`AcademyDao.isCourseFavorited(String)` → `Future<bool>`、`getFavoriteCourseIds()` → `Future<Set<String>>`、`addCourseFavorite(String,int)` → `Future<void>`、`removeCourseFavorite(String)` → `Future<void>`。

- [ ] **Step 1: 在 `AcademyTables` 新增课程收藏表常量**

在 `academy_dao.dart` 的 `academy_knowledge_favorite` 常量（L59-69）之后插入：

```dart
  // === academy_course_favorite ===
  static const courseFavorite = 'academy_course_favorite';
  static const cfColCourseId = 'course_id';
  static const cfColFavoritedAt = 'favorited_at';

  static const cfCreateSql = '''
    CREATE TABLE IF NOT EXISTS $courseFavorite (
      $cfColCourseId TEXT PRIMARY KEY,
      $cfColFavoritedAt INTEGER NOT NULL
    )
  ''';
```

- [ ] **Step 2: 在 `_onCreate` 注册建表**

在 `database_provider.dart` L303 `await db.execute(AcademyTables.kfCreateSql);` 之后加一行：

```dart
  await db.execute(AcademyTables.cfCreateSql);
```

同时把 `_kDbVersion`（L24）改为 `25`。

- [ ] **Step 3: 在 `_onUpgrade` 新增 `<25` 分块**

在 `_onUpgrade` 末尾（L879 的旧 `oldVersion < 24` 块结束之后、`}` 之前）追加：

```dart
  if (oldVersion < 25) {
    try {
      await db.execute(AcademyTables.cfCreateSql);
    } catch (e) {
      debugPrint('v25 migration failed (silent fallback): $e');
    }
  }
```

- [ ] **Step 4: 在 `AcademyDao` 新增课程收藏方法**

在 `academy_dao.dart` 的 `removeFavorite`（L225-231）之后、`// === 枚举序列化辅助 ===`（L233）之前插入（镜像卡片收藏实现，仅换表名/列名/方法名）：

```dart
  // === 课程收藏 ===

  Future<bool> isCourseFavorited(String courseId) async {
    final rows = await _db.query(
      AcademyTables.courseFavorite,
      where: '${AcademyTables.cfColCourseId} = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getFavoriteCourseIds() async {
    final rows = await _db.query(AcademyTables.courseFavorite);
    return rows.map((r) => r[AcademyTables.cfColCourseId] as String).toSet();
  }

  Future<void> addCourseFavorite(String courseId, int timestamp) async {
    await _db.insert(
      AcademyTables.courseFavorite,
      {AcademyTables.cfColCourseId: courseId, AcademyTables.cfColFavoritedAt: timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeCourseFavorite(String courseId) async {
    await _db.delete(
      AcademyTables.courseFavorite,
      where: '${AcademyTables.cfColCourseId} = ?',
      whereArgs: [courseId],
    );
  }
```

- [ ] **Step 5: 验证编译**

Run（在 `lumira_app_flutter/` 目录）: `flutter analyze`
Expected: 无新增 error。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_dao.dart lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(academy): 新增课程收藏表与 DAO 方法"
```

---

### Task 2: 仓储层 — Repository 课程收藏方法

**Files:**
- Modify: `lumira_app_flutter/lib/features/academy/data/academy_repository.dart`（抽象接口 L29-31 之后；`LocalAcademyRepository` 卡片方法 L236-251 之后）

**Interfaces:**
- Consumes: Task 1 的 `AcademyDao.isCourseFavorited / getFavoriteCourseIds / addCourseFavorite / removeCourseFavorite`。
- Produces: 接口 + 实现的 `isCourseFavorited(String)`、`toggleCourseFavorite(String)`、`getFavoriteCourseIds()`。

- [ ] **Step 1: 抽象接口新增 3 个方法**

在 `academy_repository.dart` 抽象接口的 `Future<Set<String>> getFavoriteCardIds();`（L31）之后插入：

```dart

  // 课程收藏
  Future<bool> isCourseFavorited(String courseId);
  Future<void> toggleCourseFavorite(String courseId);
  Future<Set<String>> getFavoriteCourseIds();
```

- [ ] **Step 2: 实现类新增 3 个方法**

在 `LocalAcademyRepository` 的 `getFavoriteCardIds`（L251）之后插入（镜像卡片实现，`_now().millisecondsSinceEpoch` 生成时间戳）：

```dart
  @override
  Future<bool> isCourseFavorited(String courseId) =>
      _dao.isCourseFavorited(courseId);

  @override
  Future<void> toggleCourseFavorite(String courseId) async {
    final isFav = await _dao.isCourseFavorited(courseId);
    if (isFav) {
      await _dao.removeCourseFavorite(courseId);
    } else {
      await _dao.addCourseFavorite(courseId, _now().millisecondsSinceEpoch);
    }
  }

  @override
  Future<Set<String>> getFavoriteCourseIds() => _dao.getFavoriteCourseIds();
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_repository.dart
git commit -m "feat(academy): Repository 新增课程收藏方法"
```

---

### Task 3: Provider 层 — 课程收藏 provider + 通知器

**Files:**
- Modify: `lumira_app_flutter/lib/features/academy/providers/academy_providers.dart`（`favoriteCardIdsProvider` 之后 L141；`AcademyActionNotifier` L177-198）

**Interfaces:**
- Consumes: Task 2 的 `repo.getFavoriteCourseIds()` / `repo.toggleCourseFavorite(courseId)`。
- Produces: `favoriteCourseIdsProvider`（`FutureProvider<Set<String>>`）、`AcademyActionNotifier.toggleCourseFavorite(String)`。

- [ ] **Step 1: 新增 `favoriteCourseIdsProvider`**

在 `academy_providers.dart` 的 `favoriteCardIdsProvider` 定义（L138-141）之后插入：

```dart
/// 收藏课程 ID 集合
final favoriteCourseIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getFavoriteCourseIds();
});
```

- [ ] **Step 2: 新增通知器 `toggleCourseFavorite` 并刷新**

在 `AcademyActionNotifier` 的 `toggleFavorite`（L177-181）之后插入方法：

```dart
  Future<void> toggleCourseFavorite(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.toggleCourseFavorite(courseId);
    _refresh();
  }
```

在 `_refresh()`（L197）的 `_ref.invalidate(favoriteCardIdsProvider);` 之后补一行：

```dart
    _ref.invalidate(favoriteCourseIdsProvider);
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无新增 error。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/providers/academy_providers.dart
git commit -m "feat(academy): Provider 新增课程收藏状态与通知器"
```

---

### Task 4: 课程详情页 — 假收藏改为持久化爱心收藏

**Files:**
- Modify: `lumira_app_flutter/lib/features/academy/pages/academy_detail_page.dart`

**Interfaces:**
- Consumes: `favoriteCourseIdsProvider`、`academyActionsProvider.notifier.toggleCourseFavorite`（Task 3）。

- [ ] **Step 1: 删除本地假收藏状态**

删除 `_AcademyDetailPageState` 中 L26 字段 `bool _bookmarked = false;` 和 L33-41 的 `_toggleBookmark()` 方法。

- [ ] **Step 2: 读取收藏态并替换 AppBar 按钮**

在 `build` 中（L64 `final academyId = ...` 之后）插入：

```dart
    final courseFavAsync = ref.watch(favoriteCourseIdsProvider);
    final isFav = courseFavAsync.maybeWhen(
      data: (ids) => ids.contains(academyId),
      orElse: () => false,
    );
```

把 AppBar `actions`（L92-105）整体替换为（图标改爱心、走真收藏）：

```dart
        actions: [
          GestureDetector(
            onTap: () {
              if (academyId == null) return;
              ref
                  .read(academyActionsProvider.notifier)
                  .toggleCourseFavorite(academyId!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFav ? '已取消收藏' : '已收藏'),
                  duration: const Duration(milliseconds: 1000),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: isFav ? tokens.danger : tokens.textPrimary,
              ),
            ),
          ),
        ],
```

- [ ] **Step 3: 验证编译**

Run: `flutter analyze`
Expected: 无新增 error；确认无对已删除 `_bookmarked` / `_toggleBookmark` 的引用。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_detail_page.dart
git commit -m "fix(academy): 课程详情收藏改为持久化爱心收藏"
```

---

### Task 5: 新总览页 + 路由 + 学院首页入口

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/pages/academy_favorites_page.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`（L72 `academyTrajectory` 后加一常量）
- Modify: `lumira_app_flutter/lib/app/router.dart`（import + GoRoute）
- Modify: `lumira_app_flutter/lib/features/academy/pages/academy_page.dart`（AppBar actions）

**Interfaces:**
- Consumes: `favoriteCourseIdsProvider`、`favoriteCardIdsProvider`、`coursesProvider(null)`、`knowledgeCardsProvider`、`academyActionsProvider.notifier.toggleCourseFavorite/toggleFavorite`、`RouteNames.academyFavorites`。
- Produces: `AcademyFavoritesPage` Widget；`RouteNames.academyFavorites = '/academy/favorites'`。

- [ ] **Step 1: 新增路由常量**

在 `route_names.dart` 的 `academyTrajectory`（L72）之后插入：

```dart
  static const String academyFavorites = '/academy/favorites';
```

- [ ] **Step 2: 新增总览页**

创建 `academy_favorites_page.dart`，完整内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraProgress, LumiraButton, ButtonVariant;
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 我的收藏：单页双分区展示已收藏课程 + 已收藏知识卡
class AcademyFavoritesPage extends ConsumerWidget {
  const AcademyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final courseFavAsync = ref.watch(favoriteCourseIdsProvider);
    final cardFavAsync = ref.watch(favoriteCardIdsProvider);
    final allCourses = ref.watch(coursesProvider(null));
    final allCards = ref.watch(knowledgeCardsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '我的收藏',
        transparent: true,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
              child: GlassBackground(variant: GlassBackgroundVariant.profile)),
          SafeArea(
            top: false,
            child: courseFavAsync.when(
              loading: () => const Center(child: LumiraProgress.circular()),
              error: (_, __) => Center(
                child: Text('加载失败', style: TextStyle(color: tokens.textTertiary)),
              ),
              data: (courseIds) => _buildContent(
                context,
                ref,
                tokens,
                courseIds: courseIds,
                cardIds: cardFavAsync.maybeWhen(
                    data: (s) => s, orElse: () => <String>{}),
                allCourses: allCourses,
                allCards: allCards,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeTokens tokens, {
    required Set<String> courseIds,
    required Set<String> cardIds,
    required List<AcademyCourse> allCourses,
    required List<KnowledgeCard> allCards,
  }) {
    final favCourses =
        allCourses.where((c) => courseIds.contains(c.id)).toList();
    final favCards =
        allCards.where((c) => cardIds.contains(c.id)).toList();

    if (favCourses.isEmpty && favCards.isEmpty) {
      return _EmptyState(tokens: tokens);
    }

    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return ListView(
      padding: EdgeInsets.only(top: topPadding, bottom: 24),
      children: [
        if (favCourses.isNotEmpty) ...[
          _SectionTitle(title: '已收藏课程', tokens: tokens),
          for (final c in favCourses) _CourseRow(course: c, tokens: tokens),
        ],
        if (favCards.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionTitle(title: '已收藏知识卡', tokens: tokens),
          for (final kc in favCards) _KnowledgeRow(card: kc, tokens: tokens),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.tokens});
  final String title;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Noto Serif SC',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.tokens});
  final AcademyCourse course;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: _FavoriteRow(
        cover: course.coverImage,
        title: '第${course.lessonNumber}课 · ${course.title}',
        subtitle: course.meta,
        tokens: tokens,
        onTap: () => GoRouter.of(context).push(
          RouteNames.build(
            RouteNames.profileAcademyDetail,
            {RouteNames.paramAcademyId: course.id},
          ),
        ),
      ),
    );
  }
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({required this.card, required this.tokens});
  final KnowledgeCard card;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: _FavoriteRow(
        cover: card.coverImage,
        title: card.title,
        subtitle: card.subtitle,
        tokens: tokens,
        onTap: () => GoRouter.of(context).push(
          RouteNames.build(
            RouteNames.profileAcademyKnowledge,
            {RouteNames.paramAcademyId: card.id},
          ),
        ),
      ),
    );
  }
}

/// 总览页统一行卡片：封面 + 标题 + 副标题 + 取消收藏爱心
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.tokens,
    required this.onTap,
  });
  final String cover;
  final String title;
  final String subtitle;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 54,
                child: Image.asset(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text('还没有收藏内容',
              style: TextStyle(fontSize: 14, color: tokens.textTertiary)),
          const SizedBox(height: 4),
          Text('进入课程或知识卡片点心形图标即可收藏',
              style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('返回摄影美学院'),
          ),
        ],
      ),
    );
  }
}
```

> 说明：本页为「总览 + 导航」，取消收藏入口沿用各条目的详情/卡片页（详情页已有爱心按钮；知识卡页已有收藏按钮）。若希望总览页内直接取消收藏，此处不在本计划范围（避免范围蔓延）——设计已涵盖两端各自可取消。

- [ ] **Step 3: 注册路由**

在 `router.dart` 顶部 import 区（L39 `academy_trajectory_page.dart` 之后）加：

```dart
import '../features/academy/pages/academy_favorites_page.dart';
```

在 L508 `const AcademyTrajectoryPage()` 的 GoRoute 之后插入：

```dart
      GoRoute(
        path: RouteNames.academyFavorites,
        name: 'academyFavorites',
        builder: (context, state) => const AcademyFavoritesPage(),
      ),
```

- [ ] **Step 4: 学院首页 AppBar 加入口图标**

把 `academy_page.dart` L57 的 AppBar：

```dart
      appBar: const LumiraNav(title: '摄影美学院', transparent: true),
```

替换为：

```dart
      appBar: LumiraNav(
        title: '摄影美学院',
        transparent: true,
        actions: [
          GestureDetector(
            onTap: () => GoRouter.of(context).push(RouteNames.academyFavorites),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.favorite_border, size: 22, color: tokens.textPrimary),
            ),
          ),
        ],
      ),
```

- [ ] **Step 5: 验证编译**

Run: `flutter analyze`
Expected: 无新增 error。

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_favorites_page.dart lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/academy/pages/academy_page.dart
git commit -m "feat(academy): 新增我的收藏总览页与入口"
```

---

### Task 6: 全量验证与手工路径

**Files:** 无新增/改动。

- [ ] **Step 1: 全量静态检查**

Run: `flutter analyze`
Expected: 0 issues（无 error）。

- [ ] **Step 2: 手工验证路径**

1. 课程详情页点 AppBar 爱心 → 变红心 + 提示「已收藏」→ 退出重进仍是红心。
2. 摄影美学院首页右上爱心 → 打开「我的收藏」→ 课程区/知识卡区显示已收藏项。
3. 从课程详情页取消收藏 → 红心复原；总览页对应课程条目消失。
4. 知识卡页收藏/取消 → 首页卡片与总览页知识卡区状态同步。
5. 无任何收藏时进总览页 → 空态引导 + 「返回摄影美学院」可点。

- [ ] **Step 3: Commit（如有遗漏改动）**

```bash
git status --short
# 仅将本功能相关遗漏文件加入并提交；勿带入无关的既有改动（如 profile_settings_page.dart / ohos/build-profile.json5 / 未跟踪目录）
```

## Self-Review

- **Spec coverage：** 数据模型(Task1)、DAO(Task1)、仓储(Task2)、Provider(Task3)、课程详情改造(Task4)、总览页(Task5)、路由+入口(Task5)、错误/加载态(_EmptyState/LumiraProgress，含在 Task5)、验证(Task6) 全部覆盖。图标统一爱心给到 Task4。
- **Placeholder scan：** 无 TBD/TODO；Task5 页面为完整代码。
- **Type consistency：** 各 task 使用的常量名（`cfColCourseId`/`cfColFavoritedAt`/`courseFavorite`）、方法名（`isCourseFavorited`/`getFavoriteCourseIds`/`addCourseFavorite`/`removeCourseFavorite`/`toggleCourseFavorite`）、provider（`favoriteCourseIdsProvider`）跨 task 一致。