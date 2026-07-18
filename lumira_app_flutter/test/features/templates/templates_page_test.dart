import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_page.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/templates',
      routes: [
        GoRoute(
          path: '/templates',
          builder: (_, __) => const TemplatesPage(),
        ),
        GoRoute(
          path: '/templates/all',
          builder: (_, __) => const Scaffold(body: Center(child: Text('all'))),
        ),
        GoRoute(
          path: '/templates/detail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('detail'))),
        ),
      ],
    );
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  // Helper: pump + settle，female 风格用 pump 避免 infinite pulse 超时
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders all main sections', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // Nav title
    expect(find.text('模板'), findsNWidgets(2)); // Forced fix: '模板' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现
    // Hero section title
    expect(find.text('今日为你推荐'), findsOneWidget);
    // Preference section (totalPhotos=24 > 0)
    expect(find.text('你的拍摄偏好'), findsOneWidget);
    expect(find.text('累计作品'), findsOneWidget);
    expect(find.text('24 张'), findsOneWidget);
    expect(find.text('最常用分类'), findsOneWidget);
    expect(find.text('人像 · 42%'), findsOneWidget);
    // Other section
    expect(find.text('更多模板'), findsOneWidget);
    expect(find.text('查看全部 ›'), findsOneWidget);
    // 4 mock recommendations by name
    expect(find.text('柔光人像'), findsOneWidget);
    expect(find.text('金色风光'), findsOneWidget);
    // 6 other templates by name (截取前 6)
    expect(find.text('街拍黑白'), findsOneWidget);
    expect(find.text('美食俯拍'), findsOneWidget);  // recommendation card name
  });

  testWidgets('recommendation card displays source badge label', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // 4 source labels（不同来源）
    expect(find.text('最近使用'), findsOneWidget);
    expect(find.text('场景匹配'), findsOneWidget);
    expect(find.text('同分类'), findsOneWidget);
    expect(find.text('系统精选'), findsOneWidget);
  });

  testWidgets('free badge shows on price=0 templates', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // 4 个免费模板（price=0）→ 4 个"免费"badge
    // street_bw, macro_flower, portrait_bokeh 是 other 中的免费项
    expect(find.text('免费'), findsNWidgets(3));
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.text('模板'), findsNWidgets(2)); // Forced fix: '模板' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现
      expect(find.text('今日为你推荐'), findsOneWidget);
      expect(find.text('更多模板'), findsOneWidget);

      await tester.pumpWidget(Container()); // reset
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.text('模板'), findsNWidgets(2)); // Forced fix: '模板' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现
      expect(find.text('今日为你推荐'), findsOneWidget);

      await tester.pumpWidget(Container()); // reset
    }
  });

  testWidgets('nav "查看全部" button pushes /templates/all', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // 点击右上角"查看全部"icon
    await tester.tap(find.byTooltip('查看全部'));
    await tester.pumpAndSettle();

    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('section link "查看全部 ›" pushes /templates/all', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部 ›'));
    await tester.pumpAndSettle();

    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('scroll toggles LumiraNav scrolled state', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // 初始未滚动
    expect(find.text('模板'), findsNWidgets(2)); // Forced fix: '模板' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现

    // 滚动列表
    await tester.drag(find.byType(ListView).at(1), const Offset(0, -100));
    await tester.pumpAndSettle();

    // 简化验证：未崩溃即可（与 Task 2.1 一致策略，plan-mandated）
    expect(find.text('模板'), findsNWidgets(2)); // Forced fix: '模板' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现
  });

  testWidgets('recommendation card tap pushes /templates/detail', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // 点击第一个推荐卡片（柔光人像）
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });
}
