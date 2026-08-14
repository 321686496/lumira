# 灵感页重构实现计划（纯本地拍照灵感流）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把灵感页从"心情统计 + 穿搭日记 + mock 场景"重构成"顶部引导 + 今日可拍 + 拍得更好 + 灵感图集"四个真实可点击区块，并将心情 pill 迁移到拍摄日记页做筛选。

**Architecture:** 所有灵感内容均为 App 内置静态配置（`InspirationContent`）与内置 asset 图片；个性化仅用本地 SQLite 拍摄统计（`GalleryDao.countByCategory`）排序内置条目；页面四个区块各自独立 widget，由一个 provider 提供数据；拍摄日记页通过 `DiaryFilter(tab, mood)` 在本地过滤心情。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁用 records、switch 表达式、Dart 3 语法）、flutter_riverpod 2.3.6、go_router 6.5.7、sqflite 本地库、flutter_test。

## Global Constraints

- 语言/运行时：Dart SDK `>=2.19.6 <3.0.0`，禁止 records、switch 表达式、模式匹配；统一使用传统 if/else 与 switch 语句。
- 纯本地合规：页面新增图片必须来自 `assets/images/**`，禁止新增网络图片（picsum/URL）；不展示、不上传用户或他人生成内容。
- 个性化数据：仅 `galleryDao.countByCategory()` 等本地 SQLite 统计，不调用后端新接口（后端零改动）。
- 复用现有路由：场景跳转 `captureSceneGuide?scene=<id>`（`RouteNames.captureSceneGuide` + `paramScene`）；模板跳转 `templatesDetail?templateId=<id>`（`RouteNames.templatesDetail` + `paramTemplateId`）；课程跳转 `profileAcademyDetail?academyId=<id>`（`RouteNames.profileAcademyDetail` + `paramAcademyId`）。
- 保护用户未提交改动：不得修改 `lib/features/gallery/widgets/diary_timeline_entry.dart` 与 `ohos/build-profile.json5`。
- 测试/分析命令均在 `lumira_app_flutter/` 目录下执行（`cd lumira_app_flutter`）。
- 每个任务结束时必须提交 git；提交信息前缀 `feat(flutter):`。
- 心情 pill 不得删除：迁移到拍摄日记页做筛选，复用 `CapturePreviewMockData.moods` 的 7 个文案。

---

### Task 1: SceneRecoCard 支持本地 asset 封面

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart`
- Test: `lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart`

**Interfaces:**
- Consumes: 现有 `SceneReco.imageSeed`（String）。语义扩展：以 `assets/` 开头时表示本地资源路径，否则维持原 picsum seed。
- Produces: 无新接口；`SceneRecoCard` 图片区域按 `imageSeed` 前缀自动选择 `Image.asset` 或 `Image.network`。

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/widgets/scene_reco_card.dart';

void main() {
  testWidgets('renders local asset image when imageSeed starts with assets/',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SceneRecoCard(
            scene: SceneReco(
              id: 'scene-x',
              name: '本地场景',
              vibe: '本地图片',
              imageSeed: 'assets/images/scenes/scene_cafe.jpg',
              badgeText: '推荐',
              badgeBrand: false,
              photoCount: 0,
            ),
            onTap: _noop,
          ),
        ),
      ),
    ));

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image, isA<AssetImage>());
    expect((images.first.image as AssetImage).assetName,
        'assets/images/scenes/scene_cafe.jpg');
  });
}

void _noop() {}
```

- [ ] **Step 2: 运行测试确认失败**

Run（在 `lumira_app_flutter/` 下）: `flutter test test/features/home/scene_reco_card_asset_test.dart`
Expected: FAIL（`Image.network` 返回 `NetworkImage`，`isA<AssetImage>()` 不通过）。

- [ ] **Step 3: 最小实现**

修改 `lib/features/home/widgets/scene_reco_card.dart`：

```dart
// 文件顶部新增私有图片构建方法（放在 class SceneRecoCard 内、build 方法下方）：
  Widget _buildCoverImage(ThemeTokens tokens) {
    if (scene.imageSeed.startsWith('assets/')) {
      return Image.asset(
        scene.imageSeed,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: tokens.surfaceAlt,
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: tokens.textTertiary,
          ),
        ),
      );
    }
    return Image.network(
      'https://picsum.photos/seed/${scene.imageSeed}/400/600',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: tokens.surfaceAlt,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
```

并把 Stack children 中的原 `Image.network(...)` 整块替换为 `_buildCoverImage(tokens),`。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/home/scene_reco_card_asset_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/home/widgets/scene_reco_card.dart lumira_app_flutter/test/features/home/scene_reco_card_asset_test.dart
git commit -m "feat(flutter): SceneRecoCard 支持本地 asset 封面"
```

---

### Task 2: 灵感页数据层（内置内容 + 本地排序 providers）

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/data/inspiration_content.dart`
- Create: `lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart`
- Test: `lumira_app_flutter/test/features/inspiration/inspiration_providers_test.dart`

**Interfaces:**
- Produces:
  - `enum TodayShootTarget { scene, template }`
  - `class TodayShootItem { String id; String name; String vibe; String imageAsset; TodayShootTarget target; String targetId; List<String> categories; List<String> slots; }`（const 构造）
  - `class InspirationGalleryItem { String assetPath; String title; String templateId; }`（const 构造）
  - `class InspirationContent`：`static const List<TodayShootItem> todayShootPool`、`static const List<InspirationGalleryItem> galleryItems`、`static String slotOf(DateTime now)`、`static List<TodayShootItem> pickTodayShoot(String? topCategory, DateTime now, {int count = 4})`、`static List<AcademyCourse> pickCourses(String? topCategory, {int count = 3})`
  - `final todayShootProvider = FutureProvider<List<TodayShootItem>>`
  - `final coursePicksProvider = FutureProvider<List<AcademyCourse>>`
  - `final inspirationGalleryProvider = Provider<List<InspirationGalleryItem>>`

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/inspiration/inspiration_providers_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';

void main() {
  group('InspirationContent.slotOf', () {
    test('morning is 05:00-09:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 8)), 'morning');
    });
    test('noon is 10:00-13:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 12)), 'noon');
    });
    test('dusk is 14:00-17:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 16)), 'dusk');
    });
    test('night is otherwise', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 22)), 'night');
    });
  });

  group('InspirationContent.pickTodayShoot', () {
    test('prefers slot matching items', () {
      final items = InspirationContent.pickTodayShoot(
        null,
        DateTime(2026, 8, 14, 16), // dusk
      );
      expect(items.length, 4);
      final topIds = items.take(2).map((e) => e.id).toList();
      expect(topIds, containsAll(['sunset-silhouette', 'golden_landscape']));
    });

    test('prefers category matching items', () {
      final items = InspirationContent.pickTodayShoot(
        'night',
        DateTime(2026, 8, 14, 22),
      );
      expect(items.first.categories, contains('night'));
    });
  });

  group('InspirationContent.pickCourses', () {
    test('returns 3 beginner picks when no category', () {
      final courses = InspirationContent.pickCourses(null);
      expect(courses.length, 3);
      expect(courses.first.id, 'course_01');
    });

    test('maps portrait category to portrait courses', () {
      final courses = InspirationContent.pickCourses('portrait');
      expect(courses.first.topic, AcademyTopic.portrait);
    });
  });

  group('InspirationContent.galleryItems', () {
    test('all items use local assets and known template ids', () {
      expect(InspirationContent.galleryItems.length, 8);
      for (final item in InspirationContent.galleryItems) {
        expect(item.assetPath, startsWith('assets/'));
        expect(item.templateId, isNotEmpty);
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/inspiration/inspiration_providers_test.dart`
Expected: FAIL（`InspirationContent` 不存在）。

- [ ] **Step 3: 创建 `inspiration_content.dart`**

```dart
import '../../academy/data/academy_content.dart';
import '../../academy/data/academy_models.dart';

enum TodayShootTarget { scene, template }

class TodayShootItem {
  const TodayShootItem({
    required this.id,
    required this.name,
    required this.vibe,
    required this.imageAsset,
    required this.target,
    required this.targetId,
    this.categories = const [],
    this.slots = const [],
  });

  final String id;
  final String name;
  final String vibe;
  final String imageAsset;
  final TodayShootTarget target;
  final String targetId;
  final List<String> categories;
  final List<String> slots;
}

class InspirationGalleryItem {
  const InspirationGalleryItem({
    required this.assetPath,
    required this.title,
    required this.templateId,
  });

  final String assetPath;
  final String title;
  final String templateId;
}

class InspirationContent {
  InspirationContent._();

  static const List<TodayShootItem> todayShootPool = [
    TodayShootItem(
      id: 'cafe-window',
      name: '咖啡馆窗边',
      vibe: '午后斜阳，把光调成蜜糖色',
      imageAsset: 'assets/images/scenes/scene_cafe.jpg',
      target: TodayShootTarget.scene,
      targetId: 'cafe-window',
      categories: ['portrait', 'food'],
      slots: ['morning', 'noon'],
    ),
    TodayShootItem(
      id: 'home-cozy',
      name: '居家温暖',
      vibe: '窗边晨光，把日子过成一首慢歌',
      imageAsset: 'assets/images/scenes/scene_home.jpg',
      target: TodayShootTarget.scene,
      targetId: 'home-cozy',
      categories: ['portrait', 'still-life'],
      slots: ['morning'],
    ),
    TodayShootItem(
      id: 'sunset-silhouette',
      name: '黄昏剪影',
      vibe: '逆光之下，把剪影装进落日',
      imageAsset: 'assets/images/templates/sunset_silhouette.jpg',
      target: TodayShootTarget.scene,
      targetId: 'sunset-silhouette',
      categories: ['portrait', 'landscape'],
      slots: ['dusk'],
    ),
    TodayShootItem(
      id: 'night-street',
      name: '霓虹街头',
      vibe: '霓虹与夜，城市的故事',
      imageAsset: 'assets/images/scenes/scene_street.jpg',
      target: TodayShootTarget.scene,
      targetId: 'night-street',
      categories: ['street', 'night'],
      slots: ['night'],
    ),
    TodayShootItem(
      id: 'convenience-store',
      name: '便利店',
      vibe: '深夜便利店，日系生活感',
      imageAsset: 'assets/images/scenes/scene_shop.jpg',
      target: TodayShootTarget.scene,
      targetId: 'convenience-store',
      categories: ['street', 'night'],
      slots: ['night'],
    ),
    TodayShootItem(
      id: 'cafe_portrait',
      name: '咖啡馆人像',
      vibe: '窗边柔光，情绪写真',
      imageAsset: 'assets/images/templates/cafe_portrait.jpg',
      target: TodayShootTarget.template,
      targetId: 'cafe_portrait',
      categories: ['portrait'],
      slots: ['noon'],
    ),
    TodayShootItem(
      id: 'golden_landscape',
      name: '金色风光',
      vibe: '黄金时刻，风光大片',
      imageAsset: 'assets/images/templates/golden_landscape.jpg',
      target: TodayShootTarget.template,
      targetId: 'golden_landscape',
      categories: ['landscape'],
      slots: ['dusk'],
    ),
    TodayShootItem(
      id: 'night_cityscape',
      name: '城市夜景',
      vibe: '蓝调时刻，长曝出片',
      imageAsset: 'assets/images/templates/night_cityscape.jpg',
      target: TodayShootTarget.template,
      targetId: 'night_cityscape',
      categories: ['night'],
      slots: ['night'],
    ),
  ];

  static const List<InspirationGalleryItem> galleryItems = [
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/cafe_portrait.jpg',
      title: '咖啡馆人像 · 窗边柔光',
      templateId: 'cafe_portrait',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/soft_portrait.jpg',
      title: '柔光人像 · 奶油质感',
      templateId: 'soft_portrait',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/golden_landscape.jpg',
      title: '金色风光 · 黄金时刻',
      templateId: 'golden_landscape',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/food_flat_lay.jpg',
      title: '美食俯拍 · 构图美学',
      templateId: 'food_flat_lay',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/night_cityscape.jpg',
      title: '城市夜景 · 蓝调时刻',
      templateId: 'night_cityscape',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/street_bw.jpg',
      title: '街头黑白 · 光影叙事',
      templateId: 'street_bw',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/macro_flower.jpg',
      title: '微距花卉 · 细节之美',
      templateId: 'macro_flower',
    ),
    InspirationGalleryItem(
      assetPath: 'assets/images/templates/still_life_warm.jpg',
      title: '温暖静物 · 光影层次',
      templateId: 'still_life_warm',
    ),
  ];

  /// 与 InspirationService 的时段划分保持一致：5-10 晨 / 10-14 午 / 14-18 暮 / 其余夜
  static String slotOf(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 10) return 'morning';
    if (h >= 10 && h < 14) return 'noon';
    if (h >= 14 && h < 18) return 'dusk';
    return 'night';
  }

  static List<TodayShootItem> pickTodayShoot(
    String? topCategory,
    DateTime now, {
    int count = 4,
  }) {
    final slot = slotOf(now);
    int scoreOf(TodayShootItem item) {
      var score = 0;
      if (item.slots.contains(slot) || item.slots.contains('any')) score += 2;
      if (topCategory != null && item.categories.contains(topCategory)) {
        score += 3;
      }
      return score;
    }

    final items = List<TodayShootItem>.from(todayShootPool);
    items.sort((a, b) {
      final d = scoreOf(b).compareTo(scoreOf(a));
      if (d != 0) return d;
      return a.id.compareTo(b.id);
    });
    return items.take(count).toList();
  }

  static List<AcademyCourse> pickCourses(String? topCategory, {int count = 3}) {
    final List<String> ids;
    switch (topCategory) {
      case 'portrait':
        ids = ['course_01', 'course_02', 'course_08'];
        break;
      case 'landscape':
        ids = ['course_03', 'course_04', 'course_09'];
        break;
      case 'street':
        ids = ['course_06', 'course_12', 'course_16'];
        break;
      case 'food':
      case 'night':
      case 'macro':
      case 'still-life':
        ids = ['course_05', 'course_10', 'course_11'];
        break;
      default:
        ids = ['course_01', 'course_02', 'course_04'];
    }
    final result = <AcademyCourse>[];
    for (final id in ids) {
      final course = AcademyContent.getCourse(id);
      if (course != null) result.add(course);
      if (result.length == count) break;
    }
    return result;
  }
}
```

- [ ] **Step 4: 创建 `inspiration_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../academy/data/academy_models.dart';
import 'inspiration_content.dart';

Future<String?> _topCategoryFromDao(GalleryDao dao) async {
  final counts = await dao.countByCategory();
  if (counts.isEmpty) return null;
  final entries = counts.entries.where((e) => e.value > 0).toList();
  if (entries.isEmpty) return null;
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

/// 今日可拍：本地拍摄统计 + 当前时段排序内置场景/模板
final todayShootProvider = FutureProvider<List<TodayShootItem>>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  String? top;
  try {
    top = await _topCategoryFromDao(dao);
  } catch (_) {}
  return InspirationContent.pickTodayShoot(top, DateTime.now());
});

/// 拍得更好：按主拍类别选择内置学院课程
final coursePicksProvider = FutureProvider<List<AcademyCourse>>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  String? top;
  try {
    top = await _topCategoryFromDao(dao);
  } catch (_) {}
  return InspirationContent.pickCourses(top);
});

/// 灵感图集：内置静态素材（无个性化、无网络）
final inspirationGalleryProvider = Provider<List<InspirationGalleryItem>>(
  (ref) => InspirationContent.galleryItems,
);
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/inspiration/inspiration_providers_test.dart`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/data/inspiration_content.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_providers.dart lumira_app_flutter/test/features/inspiration/inspiration_providers_test.dart
git commit -m "feat(flutter): 灵感页内置内容与本地排序 providers"
```

---

### Task 3: 顶部引导条组件

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/widgets/inspiration_guide_bar.dart`
- Test: `lumira_app_flutter/test/features/inspiration/inspiration_guide_bar_test.dart`

**Interfaces:**
- Consumes: `homeInspirationProvider`（`FutureProvider<HeroInspiration>`，来自 `lib/features/home/data/home_providers.dart`）、`HeroInspiration`（来自 `lib/features/home/data/inspiration_models.dart`）。
- Produces: `class InspirationGuideBar extends ConsumerWidget`，构造参数 `{required VoidCallback onTap}`；点击整条触发 `onTap`。

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/inspiration/inspiration_guide_bar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_guide_bar.dart';

void main() {
  testWidgets('renders inspiration text from provider and triggers onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        homeInspirationProvider.overrideWith((ref) async => const HeroInspiration(
              dateText: '8月14日 星期五 · 光线极佳',
              title: '今日灵感',
              description: '适合拍人像',
              weatherText: '28°C 晴 · 黄金时刻 17:00',
            )),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InspirationGuideBar(
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('8月14日 星期五 · 光线极佳'), findsOneWidget);
    expect(find.textContaining('适合拍人像'), findsOneWidget);

    await tester.tap(find.byType(InspirationGuideBar));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/inspiration/inspiration_guide_bar_test.dart`
Expected: FAIL（widget 不存在）。

- [ ] **Step 3: 创建 widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../home/data/home_providers.dart';
import '../../home/data/inspiration_models.dart';

class InspirationGuideBar extends ConsumerWidget {
  const InspirationGuideBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(homeInspirationProvider);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle,
              tokens.brandLight.withOpacity(0.45),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: async.when(
          loading: () => _content(tokens, HeroInspiration.fallback),
          error: (_, __) => _content(tokens, HeroInspiration.fallback),
          data: (insp) => _content(tokens, insp),
        ),
      ),
    );
  }

  Widget _content(ThemeTokens tokens, HeroInspiration insp) {
    final line1 = insp.dateText.isNotEmpty ? insp.dateText : '今天 · 适合拍照';
    final line2 = insp.weatherText.isNotEmpty
        ? '${insp.weatherText} · ${insp.description}'
        : insp.description;

    return Row(
      children: [
        Icon(Icons.wb_twilight_outlined, size: 22, color: tokens.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 14, color: tokens.brand),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/inspiration/inspiration_guide_bar_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/widgets/inspiration_guide_bar.dart lumira_app_flutter/test/features/inspiration/inspiration_guide_bar_test.dart
git commit -m "feat(flutter): 灵感页顶部引导条"
```

---

### Task 4: 今日可拍区块

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/widgets/today_shoot_section.dart`
- Test: `lumira_app_flutter/test/features/inspiration/today_shoot_section_test.dart`

**Interfaces:**
- Consumes: `todayShootProvider`（Task 2）。
- Produces: `class TodayShootSection extends ConsumerWidget`，构造参数 `{required void Function(TodayShootItem) onItemTap, required VoidCallback onMoreScenes}`；内部渲染 2 列网格与「查看全部场景」链接。

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/inspiration/today_shoot_section_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/today_shoot_section.dart';

void main() {
  const items = [
    TodayShootItem(
      id: 'cafe-window',
      name: '咖啡馆窗边',
      vibe: '午后斜阳',
      imageAsset: 'assets/images/scenes/scene_cafe.jpg',
      target: TodayShootTarget.scene,
      targetId: 'cafe-window',
    ),
    TodayShootItem(
      id: 'night-street',
      name: '霓虹街头',
      vibe: '城市的故事',
      imageAsset: 'assets/images/scenes/scene_street.jpg',
      target: TodayShootTarget.scene,
      targetId: 'night-street',
    ),
  ];

  testWidgets('renders item cards and triggers callbacks', (tester) async {
    final tapped = <String>[];
    var moreTapped = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        todayShootProvider.overrideWith((ref) async => items),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TodayShootSection(
            onItemTap: (item) => tapped.add(item.id),
            onMoreScenes: () => moreTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('今日可拍'), findsOneWidget);
    expect(find.text('咖啡馆窗边'), findsOneWidget);
    expect(find.text('霓虹街头'), findsOneWidget);
    expect(find.text('查看全部场景'), findsOneWidget);

    await tester.tap(find.text('咖啡馆窗边'));
    expect(tapped, ['cafe-window']);

    await tester.tap(find.text('查看全部场景'));
    expect(moreTapped, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/inspiration/today_shoot_section_test.dart`
Expected: FAIL（widget 不存在）。

- [ ] **Step 3: 创建 widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/inspiration_content.dart';
import '../data/inspiration_providers.dart';

class TodayShootSection extends ConsumerWidget {
  const TodayShootSection({
    super.key,
    required this.onItemTap,
    required this.onMoreScenes,
  });

  final void Function(TodayShootItem) onItemTap;
  final VoidCallback onMoreScenes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(todayShootProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(tokens: tokens),
        const SizedBox(height: 12),
        async.when(
          loading: () => _Grid(items: InspirationContent.todayShootPool.take(4).toList(), onItemTap: onItemTap),
          error: (_, __) => _Grid(items: InspirationContent.pickTodayShoot(null, DateTime.now()), onItemTap: onItemTap),
          data: (items) => _Grid(items: items, onItemTap: onItemTap),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: onMoreScenes,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '查看全部场景',
                  style: TextStyle(fontSize: 13, color: tokens.brand),
                ),
                Icon(Icons.arrow_right_alt, size: 14, color: tokens.brand),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.explore_outlined, size: 18, color: tokens.brand),
        const SizedBox(width: 8),
        Text(
          '今日可拍',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'Noto Serif SC',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: Text(
            '为你而选',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.brandText,
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onItemTap});
  final List<TodayShootItem> items;
  final void Function(TodayShootItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.62,
      children: items.map((item) => _Card(item: item, onTap: () => onItemTap(item))).toList(),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.item, required this.onTap});
  final TodayShootItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    item.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: tokens.surfaceAlt,
                      child: Icon(Icons.image_outlined, size: 28, color: tokens.textTertiary),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.vibe,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                    ),
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/inspiration/today_shoot_section_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/widgets/today_shoot_section.dart lumira_app_flutter/test/features/inspiration/today_shoot_section_test.dart
git commit -m "feat(flutter): 灵感页今日可拍区块"
```

---

### Task 5: 拍得更好区块

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/widgets/better_shoot_section.dart`
- Test: `lumira_app_flutter/test/features/inspiration/better_shoot_section_test.dart`

**Interfaces:**
- Consumes: `coursePicksProvider`（Task 2）、`AcademyCourse`。
- Produces: `class BetterShootSection extends ConsumerWidget`，构造参数 `{required void Function(AcademyCourse) onCourseTap, required VoidCallback onMoreCourses}`；渲染横向课程小卡与「全部课程」入口。

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/inspiration/better_shoot_section_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/better_shoot_section.dart';

void main() {
  testWidgets('renders course cards and triggers callbacks', (tester) async {
    final courses = [
      AcademyContent.getCourse('course_01')!,
      AcademyContent.getCourse('course_02')!,
      AcademyContent.getCourse('course_04')!,
    ];
    final tapped = <String>[];
    var moreTapped = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        coursePicksProvider.overrideWith((ref) async => courses),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BetterShootSection(
            onCourseTap: (course) => tapped.add(course.id),
            onMoreCourses: () => moreTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('拍得更好'), findsOneWidget);
    expect(find.text('找到你的最佳角度'), findsOneWidget);
    expect(find.text('全部课程'), findsOneWidget);

    await tester.tap(find.text('找到你的最佳角度'));
    expect(tapped, ['course_01']);

    await tester.tap(find.text('全部课程'));
    expect(moreTapped, isTrue);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/inspiration/better_shoot_section_test.dart`
Expected: FAIL（widget 不存在）。

- [ ] **Step 3: 创建 widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../academy/data/academy_models.dart';
import '../data/inspiration_providers.dart';

class BetterShootSection extends ConsumerWidget {
  const BetterShootSection({
    super.key,
    required this.onCourseTap,
    required this.onMoreCourses,
  });

  final void Function(AcademyCourse) onCourseTap;
  final VoidCallback onMoreCourses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(coursePicksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '拍得更好',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onMoreCourses,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '全部课程',
                style: TextStyle(fontSize: 13, color: tokens.textTertiary),
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
            data: (courses) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CourseCard(
                course: courses[index],
                onTap: () => onCourseTap(courses[index]),
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
        '精选课程加载中',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.onTap});
  final AcademyCourse course;
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
                  course.coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.menu_book_outlined, size: 24, color: tokens.textTertiary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
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
                      course.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: tokens.textTertiary),
                    ),
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
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/inspiration/better_shoot_section_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/widgets/better_shoot_section.dart lumira_app_flutter/test/features/inspiration/better_shoot_section_test.dart
git commit -m "feat(flutter): 灵感页拍得更好区块"
```

---

### Task 6: 灵感图集区块

**Files:**
- Create: `lumira_app_flutter/lib/features/inspiration/widgets/inspiration_gallery_section.dart`
- Test: `lumira_app_flutter/test/features/inspiration/inspiration_gallery_section_test.dart`

**Interfaces:**
- Consumes: `inspirationGalleryProvider`（Task 2）。
- Produces: `class InspirationGallerySection extends ConsumerWidget`，构造参数 `{required void Function(InspirationGalleryItem) onItemTap}`；渲染 2 列内置图集网格。

- [ ] **Step 1: 写失败测试**

创建 `lumira_app_flutter/test/features/inspiration/inspiration_gallery_section_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_gallery_section.dart';

void main() {
  testWidgets('renders local gallery grid and triggers onItemTap',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InspirationGallerySection(
            onItemTap: (item) => tapped.add(item.templateId),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('灵感图集'), findsOneWidget);
    expect(find.text('咖啡馆人像 · 窗边柔光'), findsOneWidget);
    expect(find.text('柔光人像 · 奶油质感'), findsOneWidget);

    await tester.tap(find.text('咖啡馆人像 · 窗边柔光'));
    expect(tapped, ['cafe_portrait']);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/inspiration/inspiration_gallery_section_test.dart`
Expected: FAIL（widget 不存在）。

- [ ] **Step 3: 创建 widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/inspiration_content.dart';
import '../data/inspiration_providers.dart';

class InspirationGallerySection extends ConsumerWidget {
  const InspirationGallerySection({super.key, required this.onItemTap});

  final void Function(InspirationGalleryItem) onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final items = ref.watch(inspirationGalleryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '灵感图集',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.successSubtle,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Text(
                '内置精选',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tokens.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: items
              .map((item) => _GalleryCard(item: item, onTap: () => onItemTap(item)))
              .toList(),
        ),
      ],
    );
  }
}

class _GalleryCard extends ConsumerWidget {
  const _GalleryCard({required this.item, required this.onTap});
  final InspirationGalleryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              item.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: tokens.surfaceAlt,
                child: Icon(Icons.image_outlined, size: 28, color: tokens.textTertiary),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/inspiration/inspiration_gallery_section_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/widgets/inspiration_gallery_section.dart lumira_app_flutter/test/features/inspiration/inspiration_gallery_section_test.dart
git commit -m "feat(flutter): 灵感页灵感图集区块"
```

---

### Task 7: 重写灵感页骨架并更新页面测试

**Files:**
- Rewrite: `lumira_app_flutter/lib/features/inspiration/pages/inspiration_page.dart`
- Rewrite: `lumira_app_flutter/test/features/inspiration/inspiration_page_test.dart`

**Interfaces:**
- Consumes: Task 3-6 的四个区块组件、`RouteNames`、`InspirationContent.slotOf`。
- Produces: 组装完成的 `InspirationPage`（四个区块 + 全部可点击跳转）。

- [ ] **Step 1: 重写页面**

替换 `lib/features/inspiration/pages/inspiration_page.dart` 全部内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../academy/data/academy_models.dart';
import '../data/inspiration_content.dart';
import '../widgets/better_shoot_section.dart';
import '../widgets/inspiration_gallery_section.dart';
import '../widgets/inspiration_guide_bar.dart';
import '../widgets/today_shoot_section.dart';

class InspirationPage extends ConsumerWidget {
  const InspirationPage({super.key});

  void _goSceneGuide(BuildContext context, String sceneId) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.captureSceneGuide,
        {RouteNames.paramScene: sceneId},
      ),
    );
  }

  void _goTemplateDetail(BuildContext context, String templateId) {
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesDetail, templateId),
    );
  }

  void _goAcademyDetail(BuildContext context, String courseId) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.profileAcademyDetail,
        {RouteNames.paramAcademyId: courseId},
      ),
    );
  }

  String _defaultSceneForSlot() {
    final slot = InspirationContent.slotOf(DateTime.now());
    switch (slot) {
      case 'morning':
        return 'home-cozy';
      case 'noon':
        return 'cafe-window';
      case 'dusk':
        return 'sunset-silhouette';
      default:
        return 'night-street';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '灵感', transparent: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeUp(
                  child: InspirationGuideBar(
                    onTap: () => _goSceneGuide(context, _defaultSceneForSlot()),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: TodayShootSection(
                    onItemTap: (item) {
                      if (item.target == TodayShootTarget.scene) {
                        _goSceneGuide(context, item.targetId);
                      } else {
                        _goTemplateDetail(context, item.targetId);
                      }
                    },
                    onMoreScenes: () =>
                        GoRouter.of(context).push(RouteNames.scenes),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 200),
                  child: BetterShootSection(
                    onCourseTap: (AcademyCourse course) =>
                        _goAcademyDetail(context, course.id),
                    onMoreCourses: () =>
                        GoRouter.of(context).push(RouteNames.profileAcademy),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: InspirationGallerySection(
                    onItemTap: (item) => _goTemplateDetail(context, item.templateId),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 重写页面测试**

替换 `test/features/inspiration/inspiration_page_test.dart` 全部内容：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/inspiration/pages/inspiration_page.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_guide_bar.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);

    router = GoRouter(
      initialLocation: RouteNames.inspiration,
      routes: [
        GoRoute(
          path: RouteNames.inspiration,
          name: 'inspiration',
          builder: (_, __) => const InspirationPage(),
        ),
        GoRoute(
          path: RouteNames.captureSceneGuide,
          name: 'captureSceneGuide',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SCENE_GUIDE'))),
        ),
        GoRoute(
          path: RouteNames.templatesDetail,
          name: 'templatesDetail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('TEMPLATE_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.profileAcademyDetail,
          name: 'profileAcademyDetail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('ACADEMY_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.scenes,
          name: 'scenes',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SCENES'))),
        ),
        GoRoute(
          path: RouteNames.profileAcademy,
          name: 'profileAcademy',
          builder: (_, __) => const Scaffold(body: Center(child: Text('ACADEMY'))),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await db.close();
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        galleryDaoProvider.overrideWith((ref) async => GalleryDao(db)),
        homeInspirationProvider.overrideWith((ref) async => const HeroInspiration(
              dateText: '8月14日 星期五 · 光线极佳',
              title: '今日灵感',
              description: '适合拍人像',
              weatherText: '28°C 晴 · 黄金时刻 17:00',
            )),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('InspirationPage', () {
    testWidgets('renders LumiraNav with title 灵感', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.byType(InspirationPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '灵感'), findsOneWidget);
    });

    testWidgets('renders 4 sections without legacy blocks', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.textContaining('光线极佳'), findsOneWidget);
      expect(find.text('今日可拍'), findsOneWidget);
      expect(find.text('拍得更好'), findsOneWidget);
      expect(find.text('灵感图集'), findsOneWidget);

      expect(find.text('今日心情'), findsNothing);
      expect(find.text('穿搭日记'), findsNothing);
      expect(find.text('加载更多灵感'), findsNothing);
      expect(find.text('根据你的喜好推荐'), findsNothing);
    });

    testWidgets('tapping guide bar pushes scene guide', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InspirationGuideBar));
      await tester.pumpAndSettle();
      expect(find.text('SCENE_GUIDE'), findsOneWidget);
    });

    testWidgets('tapping a today scene card pushes scene guide',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('咖啡馆窗边'));
      await tester.tap(find.text('咖啡馆窗边'));
      await tester.pumpAndSettle();
      expect(find.text('SCENE_GUIDE'), findsOneWidget);
    });

    testWidgets('renders across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await tester.pumpAndSettle();
        expect(find.text('今日可拍'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await tester.pumpAndSettle();
        expect(find.text('灵感图集'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}

Future<void> _onCreate(Database d, int v) async {
  await d.execute('''
    CREATE TABLE gallery_items (
      id TEXT PRIMARY KEY,
      data_url TEXT,
      file_path TEXT,
      original_path TEXT,
      transform TEXT,
      post_process TEXT,
      scene_id TEXT,
      template_id TEXT,
      kit_id TEXT,
      mood TEXT,
      lut TEXT,
      is_favorite INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''');
}
```

- [ ] **Step 3: 运行页面测试并修复跳转断言**

Run: `flutter test test/features/inspiration/inspiration_page_test.dart`
Expected: PASS。若卡片/图集 tap 断言失败（视图外元素），用 `tester.ensureVisible(find.text(...))` 后再 tap。

- [ ] **Step 4: 运行全部灵感页测试**

Run: `flutter test test/features/inspiration`
Expected: PASS（Task 2-6 与页面测试全绿）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/inspiration/pages/inspiration_page.dart lumira_app_flutter/test/features/inspiration/inspiration_page_test.dart
git commit -m "feat(flutter): 灵感页四区块骨架落地"
```

---

### Task 8: 拍摄日记心情筛选（心情 pill 迁移）

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/providers/gallery_diary_providers.dart`
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_diary_page.dart`
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`（仅 invalidate 行）
- Modify: `lumira_app_flutter/test/features/gallery/gallery_diary_page_test.dart`

**Interfaces:**
- Produces: `class DiaryFilter { const DiaryFilter({required this.tab, this.mood}); String tab; String? mood; bool get isAllMood => mood == null; }`
- Changes: `diaryEntriesProvider` 由 `FutureProvider.family<List<DiaryEntry>, String>` 改为 `FutureProvider.family<List<DiaryEntry>, DiaryFilter>`；`outfitDiaryCardProvider` 及 `OutfitPhoto/OutfitDiaryCardData` 引用删除（Task 9 清理文件）。

- [ ] **Step 1: 修改 providers（含失败测试前置）**

在 `lib/features/gallery/providers/gallery_diary_providers.dart` 顶部新增：

```dart
class DiaryFilter {
  const DiaryFilter({required this.tab, this.mood});

  final String tab;
  final String? mood;

  bool get isAllMood => mood == null;
}
```

将 `diaryEntriesProvider` 签名与过滤逻辑改为：

```dart
final diaryEntriesProvider =
    FutureProvider.family<List<DiaryEntry>, DiaryFilter>((ref, filter) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  final records = await dao.getRecent(limit: 50);

  var filtered = filter.tab == kDiaryTabOutfit
      ? records.where((r) => r.sceneId != null && r.sceneId!.isNotEmpty).toList()
      : records;
  if (!filter.isAllMood) {
    filtered = filtered.where((r) => r.mood == filter.mood).toList();
  }
```

（后续 `filtered` 的 scene/template 名称预取、按天分组逻辑不变，仍使用 `filtered`。）

删除文件末尾 `outfitDiaryCardProvider` 整块，并移除文件顶部 `import '../../../features/inspiration/data/inspiration_mock_data.dart';`。

- [ ] **Step 2: 更新调用点**

`lib/features/gallery/pages/gallery_diary_page.dart`：
- 状态：`String? _selectedMood;`
- `_pickDate` 中：`final entries = ref.read(diaryEntriesProvider(DiaryFilter(tab: _viewTab, mood: _selectedMood))).valueOrNull;`
- 删除回调中：`ref.invalidate(diaryEntriesProvider(DiaryFilter(tab: _viewTab, mood: _selectedMood)));`
- build 中：`final entriesAsync = ref.watch(diaryEntriesProvider(DiaryFilter(tab: _viewTab, mood: _selectedMood)));`
- `_DiaryViewToggle` 下方插入心情筛选行（紧接 toggle 的 FadeUp 之后）：

```dart
FadeUp(
  delay: const Duration(milliseconds: 50),
  child: _MoodFilterRow(
    selectedMood: _selectedMood,
    onSelect: (mood) => setState(() => _selectedMood = mood),
    tokens: tokens,
  ),
),
```

文件底部新增 `_MoodFilterRow` 组件：

```dart
class _MoodFilterRow extends StatelessWidget {
  const _MoodFilterRow({
    required this.selectedMood,
    required this.onSelect,
    required this.tokens,
  });

  final String? selectedMood;
  final void Function(String?) onSelect;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final moods = CapturePreviewMockData.moods;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mood = moods[index];
          final active = selectedMood == mood.name;
          return GestureDetector(
            onTap: () => onSelect(active ? null : mood.name),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(
                  color: active ? tokens.brand : tokens.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mood.icon, size: 14, color: active ? tokens.textInverse : tokens.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    mood.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: active ? tokens.textInverse : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

在文件 import 区新增：
`import '../../capture/data/capture_preview_mock_data.dart';`

`lib/features/gallery/pages/gallery_detail_page.dart` 第 286 行附近：

```dart
ref.invalidate(diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabOutfit)));
```

- [ ] **Step 3: 更新现有日记测试**

`test/features/gallery/gallery_diary_page_test.dart` 中所有 `diaryEntriesProvider(kDiaryTabOutfit)` / `diaryEntriesProvider(kDiaryTabShoot)` 改为：

```dart
await container.read(
    diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabOutfit)).future);
await container.read(
    diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabShoot)).future);
```

- [ ] **Step 4: 新增心情筛选测试**

在 `test/features/gallery/gallery_diary_page_test.dart` 的 `seedData()` 末尾追加一张带 `mood: '开心'` 的照片：

```dart
await dao.insert(GalleryItemRecord(
  id: 'p4',
  dataUrl: 'https://example.com/p4.jpg',
  mood: '开心',
  createdAt: today.millisecondsSinceEpoch + 2,
));
```

并在 group 内新增用例：

```dart
testWidgets('filters diary by mood pill and clears on re-tap', (tester) async {
  setViewport(tester);
  await seedData();

  await pumpDiaryPage(tester);
  await tester.pumpAndSettle();

  // 未筛选：4 张照片分布在 2 天（p1/p4 今天，p3 昨天，p2 仅 shoot tab）
  expect(find.text('时间轴'), findsOneWidget);
  expect(find.text('2篇'), findsOneWidget);

  // 点击心情 pill「开心」→ 仅 p4（今天）可见
  await tester.tap(find.text('开心'));
  await tester.pumpAndSettle();
  expect(find.text('1篇'), findsOneWidget);

  // 再次点击取消 → 恢复全部
  await tester.tap(find.text('开心'));
  await tester.pumpAndSettle();
  expect(find.text('2篇'), findsOneWidget);
});
```

（若「开心」pill 不在视口内，先 `await tester.ensureVisible(find.text('开心'));` 再 tap；`seedData()` 中的旧照片 mood `'放松'` 不在 pill 列表，不影响筛选断言。）

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/gallery/gallery_diary_page_test.dart test/features/gallery/gallery_detail_page_test.dart`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/gallery/providers/gallery_diary_providers.dart lumira_app_flutter/lib/features/gallery/pages/gallery_diary_page.dart lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart lumira_app_flutter/test/features/gallery/gallery_diary_page_test.dart
git commit -m "feat(flutter): 拍摄日记支持心情筛选，心情 pill 迁移完成"
```

---

### Task 9: 清理旧 mock 与死代码，全量验证

**Files:**
- Delete: `lumira_app_flutter/lib/features/inspiration/widgets/mood_card.dart`
- Delete: `lumira_app_flutter/lib/features/inspiration/widgets/outfit_diary_card.dart`
- Delete: `lumira_app_flutter/lib/features/inspiration/data/inspiration_mock_data.dart`

**Interfaces:**
- Consumes: 无新接口；删除 Task 8 后已无引用的旧模型与组件。

- [ ] **Step 1: 确认无引用后删除文件**

Run: `rg -n "inspiration_mock_data|MoodCard|OutfitDiaryCard|outfitDiaryCardProvider|OutfitDiaryCardData|OutfitPhoto" lumira_app_flutter/lib lumira_app_flutter/test`
Expected: 仅剩上述三个待删除文件自身。若有残留引用，先按 Task 8 的清理意图修正，再删除：

```bash
git rm lumira_app_flutter/lib/features/inspiration/widgets/mood_card.dart lumira_app_flutter/lib/features/inspiration/widgets/outfit_diary_card.dart lumira_app_flutter/lib/features/inspiration/data/inspiration_mock_data.dart
```

- [ ] **Step 2: 运行全量 Flutter 测试**

Run: `flutter test`
Expected: 全部 PASS（含灵感页、拍摄日记、首页回归）。

- [ ] **Step 3: 运行静态分析**

Run: `flutter analyze`
Expected: 无 error（既有 warning/info 如与本次改动无关可保留）。

- [ ] **Step 4: 确认未触碰用户未提交文件**

Run: `git status --short`
Expected: 仅本计划相关文件与之前用户已有的 `lumira_app_flutter/lib/features/gallery/widgets/diary_timeline_entry.dart`、`lumira_app_flutter/ohos/build-profile.json5` 改动；不得出现这两个文件的额外改动。

- [ ] **Step 5: 提交**

```bash
git add -A lumira_app_flutter/lib/features/inspiration
git commit -m "refactor(flutter): 清理灵感页旧 mock 与死代码"
```

---

## 验收对照（来自设计文档 §9）

1. 灵感页首屏无 mock 心情统计、无穿搭日记、无死"加载更多"按钮 → Task 7 测试断言 `findsNothing`。
2. 四个区块全部有真实可点击去向 → Task 7 组装跳转 + Task 3-6 组件回调测试。
3. 断网/天气失败正常渲染 → `InspirationGuideBar` 使用 `HeroInspiration.fallback` 降级；今日可拍无数据时回退 `pickTodayShoot(null, now)`。
4. 心情 pill 保留并迁移到拍摄日记筛选 → Task 8。
5. 所有"看什么"图片来自 `assets/images/**` → Task 2 图集断言 + 各卡片 `Image.asset`。
6. 后端零改动 → 本计划无 `lumira-server` 文件。
7. 不动用户未提交文件 → Task 9 Step 4 校验。

## 风险提示（执行时注意）

- `flutter test` 中 `Image.asset` 若资源声明缺失会触发异常：如遇 `Unable to load asset`，先确认 `assets/images/**` 已在 `pubspec.yaml` 的 `flutter.assets` 中声明（当前已声明 `assets/images`）。
- Dart 2.19 不支持 switch 表达式与 records：本计划代码均使用传统 switch 语句与 if/else。
- `gallery_diary_page.dart` 已有用户未提交改动：Task 8 只做增量编辑（状态 + 筛选行 + provider 调用），不得整文件覆盖。
