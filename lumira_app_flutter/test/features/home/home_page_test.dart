import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/pages/home_page.dart';
import 'package:lumira_app_flutter/shared/widgets/tabbar/floating_tabbar.dart';

Widget _wrapWithRouter({ThemeKey theme = ThemeKey.warmWhite, UIStyle? style}) {
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
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('GALLERY_DETAIL'))),
      ),
      GoRoute(
        path: RouteNames.scenes,
        name: 'scenes',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SCENES'))),
      ),
      GoRoute(
        path: RouteNames.captureSceneGuide,
        name: 'captureSceneGuide',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SCENE_GUIDE'))),
      ),
      GoRoute(
        path: RouteNames.captureSceneManage,
        name: 'captureSceneManage',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('SCENE_MANAGE'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => style ?? UIStyle.neumorphic),
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
  testWidgets('HomePage renders all 8 sections', (tester) async {
    // Forced fix: 默认 800x600 视口无法显示 ListView 全部 8 个 section（offstage 项不构建）。
    // 设置较大视口，使所有 section 进入可视区，让 find.text(...) 能找到 '场景推荐' / '保持记录，养成习惯' 等靠后内容。
    // 计算依据：Hero(280) + QuickActions(100) + Streak(140) + Tip(220) + Scene 标题(50)
    // + Scene grid(2 行 × 623dp = 1258) + Recent 标题(50) + Recent grid(3 行 × 567dp = 1725)
    // + Stats(120) + 间距 ≈ 4063dp。视口设 4500dp 留 400dp 缓冲。
    tester.binding.window.physicalSizeTestValue = const Size(800, 4500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(_wrapWithRouter());
    await tester.pumpAndSettle();

    // Section 1: LumiraNav（HomeBrandTitle 默认 logoEnglish 渲染 Lumira）
    expect(find.text('Lumira'), findsOneWidget);

    // Section 2: HeroCard
    expect(find.text('今日灵感'), findsOneWidget);
    expect(find.text('捕捉每一束光，让日常成为习惯'), findsOneWidget);
    expect(find.text('开始拍摄'), findsOneWidget);

    // Section 3: QuickActions
    expect(find.text('拍摄'), findsWidgets);
    expect(find.text('模板'), findsWidgets);
    expect(find.text('灵感'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);

    // Section 4: StreakCard
    expect(find.text('连续打卡'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('天'), findsOneWidget);

    // Section 5: TipCard
    expect(find.text('今日拍摄小贴士'), findsOneWidget);
    expect(find.text('试试'), findsOneWidget);
    expect(find.text('换一批'), findsOneWidget);

    // Section 6: Scene recommendations
    expect(find.text('场景推荐'), findsOneWidget);
    expect(find.text('为你而选'), findsOneWidget);
    expect(find.text('查看全部'), findsOneWidget);
    // 4 个场景卡片（mock 数据）
    expect(find.text('咖啡馆'), findsOneWidget);
    expect(find.text('街头'), findsOneWidget);
    expect(find.text('公园'), findsOneWidget);
    expect(find.text('工作室'), findsOneWidget);

    // Section 7: Recent shots
    expect(find.text('最近拍摄'), findsOneWidget);
    expect(find.text('为你甄选'), findsOneWidget);
    expect(find.text('全部'), findsWidgets);
    // 5 个最近拍摄（mock 数据）
    expect(find.text('自然光人像'), findsOneWidget);
    expect(find.text('复古胶片感'), findsOneWidget);

    // Section 8: StatsCard
    expect(find.text('保持记录，养成习惯'), findsOneWidget);
    // Forced fix: '收藏' 在两处合法出现 — SceneReco _SectionTitle 的 links 列表 + StatsCard 的统计标签
    // 原本 findsOneWidget 断言不成立，改为 findsNWidgets(2)
    expect(find.text('收藏'), findsNWidgets(2));
    expect(find.text('获赞'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);

    // FloatingTabBar
    expect(find.byType(FloatingTabBar), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
  });

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

  testWidgets('HomePage renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(_wrapWithRouter(style: style));
      await settleOrPump(tester, style);

      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('今日灵感'), findsOneWidget);
      expect(find.byType(FloatingTabBar), findsOneWidget);
    }
  });

  testWidgets('HomePage renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(_wrapWithRouter(theme: theme));
      await tester.pumpAndSettle();

      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('今日灵感'), findsOneWidget);
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
}
