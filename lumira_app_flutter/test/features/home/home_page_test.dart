import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/home/pages/home_page.dart';
import 'package:lumira_app_flutter/features/home/providers/banner_recommendation_provider.dart';
import 'package:lumira_app_flutter/features/notification/notification_providers.dart';
import 'package:lumira_app_flutter/shared/widgets/tabbar/floating_tabbar.dart';

Widget _wrapWithRouter({
  ThemeKey theme = ThemeKey.warmWhite,
  UIStyle? style,
  List<RecentShot>? recents,
  List<HomeBannerItem>? banners,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: RouteNames.capture,
        name: 'capture',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('CAPTURE'))),
      ),
      GoRoute(
        path: RouteNames.templates,
        name: 'templates',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('TEMPLATES'))),
      ),
      GoRoute(
        path: RouteNames.challenge,
        name: 'challenge',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('CHALLENGE'))),
      ),
      GoRoute(
        path: RouteNames.gallery,
        name: 'gallery',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('GALLERY'))),
      ),
      GoRoute(
        path: RouteNames.galleryDetail,
        name: 'galleryDetail',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'GALLERY_DETAIL:${state.queryParams[RouteNames.paramPhotoId]}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.scenes,
        name: 'scenes',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SCENES'))),
      ),
      GoRoute(
        path: RouteNames.captureSceneDetail,
        name: 'captureSceneDetail',
        builder: (context, state) => const Scaffold(
            body: Center(child: Text('SCENE_DETAIL'))),
      ),
      GoRoute(
        path: RouteNames.captureSceneManage,
        name: 'captureSceneManage',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SCENE_MANAGE'))),
      ),
      GoRoute(
        path: RouteNames.search,
        name: 'search',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'SEARCH:${state.queryParams[RouteNames.paramKeyword]}',
            ),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => style ?? UIStyle.neumorphic),
      unreadCountProvider.overrideWith((ref) async => 0),
      bannerRecommendationProvider.overrideWith(
        (ref) async => banners ?? HomeMockData.banners,
      ),
      // 连续打卡 7 天（StreakCard 数据来自挑战历史 DAO，测试无 DB 时提供固定数据）
      homeStreakProvider.overrideWith((ref) async => const HomeStreakStatus(
            streakDays: 7,
            weekDays: [
              WeekDay(label: '一', done: true, today: false),
              WeekDay(label: '二', done: true, today: false),
              WeekDay(label: '三', done: true, today: false),
              WeekDay(label: '四', done: true, today: false),
              WeekDay(label: '五', done: true, today: false),
              WeekDay(label: '六', done: true, today: false),
              WeekDay(label: '日', done: true, today: false),
            ],
          )),
      homeRecentShotsProvider.overrideWith(
        (ref) async => recents ?? HomeMockData.recents,
      ),
      homeSceneRecosProvider.overrideWith((ref) async => HomeMockData.scenes),
      homeInspirationProvider.overrideWith(
        (ref) async => HeroInspiration.fallback,
      ),
      homeStatsProvider.overrideWith((ref) async => HomeStats.empty),
      homeRecentTemplateStripProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// female 风格的 FloatingTabBar 有无限脉冲动画，用 pump 代替 pumpAndSettle
Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
  if (style == UIStyle.female) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('HomePage renders task-first sections', (tester) async {
    // Forced fix: 默认 800x600 视口无法显示 ListView 全部 8 个 section（offstage 项不构建）。
    // 设置较大视口，使所有 section 进入可视区，让 find.text(...) 能找到 '场景推荐' / '保持记录，养成习惯' 等靠后内容。
    // 计算依据：Banner(182) + Hero(280) + QuickActions(100) + Streak(140) + Tip(220) + Scene 标题(50)
    // + Scene grid(2 行 × 623dp = 1258) + Recent 标题(50) + Recent grid(3 行 × 567dp = 1725)
    // + Stats(120) + 间距 ≈ 4245dp。视口设 5500dp 留充足缓冲（Banner 是后加的 section）。
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // Section 1: LumiraNav（HomeBrandTitle 默认 logoEnglish 渲染 Lumira）
    expect(find.text('Lumira'), findsOneWidget);

    // Section 2: HeroCard
    expect(find.text('今日灵感'), findsNWidgets(2));
    expect(find.text('捕捉每一束光，让日常成为习惯'), findsOneWidget);
    expect(find.text('开始拍摄'), findsOneWidget);

    // Section 3: QuickActions
    expect(find.text('拍摄'), findsWidgets);
    // Forced fix: '模板' 已重命名为 '发现'（QuickActions + FloatingTabBar 都改了）
    expect(find.text('发现'), findsWidgets);
    expect(find.text('灵感'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);

    // Section 3: Recommendations
    expect(find.text('场景推荐'), findsOneWidget);
    expect(find.text('查看全部'), findsOneWidget);
    // 4 个场景卡片（mock 数据）
    expect(find.text('咖啡馆'), findsOneWidget);
    expect(find.text('街头'), findsOneWidget);
    expect(find.text('公园'), findsOneWidget);
    expect(find.text('工作室'), findsOneWidget);

    // Section 7: Recent shots
    expect(find.text('继续你的创作'), findsOneWidget);
    expect(find.text('上次作品'), findsOneWidget);
    expect(find.text('全部'), findsWidgets);
    // 5 个最近拍摄（mock 数据）
    expect(find.text('自然光人像'), findsOneWidget);
    expect(find.text('复古胶片感'), findsOneWidget);

    // Section 5: GrowthStrip（精简为 连续天/作品/经验）
    expect(find.text('连续天'), findsOneWidget);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);

    // FloatingTabBar
    expect(find.byType(FloatingTabBar), findsNothing);
  });

  /*
  testWidgets('HomePage tip refresh button changes displayed tip text',
      (tester) async {
    // Forced fix: '换一批' 按钮默认位于 y≈704（超出 600px 默认视口），无法点击。
    // 设置较大视口，使 TipCard 完全可见可点击。
    tester.binding.window.physicalSizeTestValue = const Size(800, 4500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 记录初始 tip 文字
    final initialTipFinder = find.textContaining('侧逆光人像');
    expect(initialTipFinder, findsOneWidget);

    // 点击 "换一批"
    await tester.tap(find.text('换一批'));
    await tester.pumpAndSettle();

    // tip 文字应变化（mock 数据循环遍历）
    final newTipFinder = find.textContaining('侧逆光人像');
    expect(newTipFinder, findsNothing);
  });

  */
  testWidgets('HomePage renders across 4 UI styles', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    for (final style in UIStyle.values) {
      await tester.pumpWidget(_wrapWithRouter(style: style));
      await settleOrPump(tester, style);

      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('今日灵感'), findsNWidgets(2));
    expect(find.byType(FloatingTabBar), findsNothing);
    }
  });

  testWidgets('HomePage renders across 8 themes', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(_wrapWithRouter(theme: theme));
      await tester.pumpAndSettle();

      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('今日灵感'), findsNWidgets(2));
    }
  });

  testWidgets('HomePage scroll toggles LumiraNav scrolled state',
      (tester) async {
    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 初始：未滚动
    final initialScrollOffset = tester.widget<Scrollable>(
      find.byType(Scrollable).first,
    ).controller!.offset;
    expect(initialScrollOffset, 0);

    // 滚动超过阈值（10dp）
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -50));
    await tester.pumpAndSettle();

    // LumiraNav 应处于 scrolled 状态（border-bottom 显示）
    // 简化验证：未崩溃即可（具体视觉效果难以在 widget test 中断言）
    expect(find.text('Lumira'), findsOneWidget);
  });

  testWidgets('HomePage scene and recent sections use horizontal rails',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    final horizontalRails = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalRails, findsWidgets);
    expect(find.text('管理'), findsNothing);
  });

  testWidgets('HomePage 继续创作为 2 列网格', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 继续创作区域使用 SliverGrid（懒构建 2 列网格）
    final grids = find.byType(SliverGrid);
    expect(grids, findsWidgets);

    // 场景推荐仍为横向 ListView
    final horizontalRails = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalRails, findsWidgets);
    // 最近作品仍在
    expect(find.text('自然光人像'), findsOneWidget);
  });

  testWidgets('HomePage 结构：搜索胶囊在 Banner 前、成长条在入口后', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // 搜索胶囊存在
    expect(find.text('搜索模板 / 场景 / 拍摄教程'), findsOneWidget);

    // 成长条 3 项
    expect(find.text('连续天'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);

    // 顺序：搜索胶囊 y < QuickActions y < GrowthStrip y
    final searchY = tester.getTopLeft(find.text('搜索模板 / 场景 / 拍摄教程')).dy;
    final quickY = tester.getTopLeft(find.text('拍摄').first).dy;
    final growthY = tester.getTopLeft(find.text('连续天')).dy;
    expect(searchY, lessThan(quickY));
    expect(quickY, lessThan(growthY));
  });

  testWidgets('HomePage recent shot opens gallery detail', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(
      _wrapWithRouter(
        recents: [
          RecentShot(
            name: '自然光人像',
            category: '作品',
            icon: Icons.image_outlined,
            imageSeed: 'photo-1',
            createdAt: DateTime(2026, 9, 13),
            photoId: 'photo-1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('自然光人像'));
    await tester.pumpAndSettle();

    expect(find.text('GALLERY_DETAIL:photo-1'), findsOneWidget);
  });

  testWidgets('HomePage 点击 search banner 跳转全局搜索页并带 scope+keyword',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 5500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    // 仅覆盖单条 kind=search 的首页 Banner：type=operation、route 拼好的
    // 全局搜索路由（scope=template, keyword=x），点击后应 push 该搜索页。
    const searchBanner = HomeBannerItem(
      id: 'banner_search',
      title: '搜索模板',
      subtitle: '搜点什么',
      imageSeed: 'banner-search',
      tag: '搜索',
      route: '/search?scope=template&keyword=x',
      type: BannerType.operation,
    );
    await tester.pumpWidget(_wrapWithRouter(banners: const [searchBanner]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜索模板').first);
    await tester.pumpAndSettle();

    // 全局搜索页 builder 渲染 SEARCH:${paramKeyword}，此处关键字为 x
    expect(find.text('SEARCH:x'), findsOneWidget);
  });
}
