import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_growth_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileGrowth,
      routes: [
        GoRoute(
          path: RouteNames.profileGrowth,
          name: 'profileGrowth',
          builder: (_, __) => const ProfileGrowthPage(),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) return;
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileGrowthPage', () {
    testWidgets('renders LumiraNav with title 成长中心', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileGrowthPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '成长中心'), findsOneWidget);
    });

    testWidgets('renders all 4 sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 1. LevelCard
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.text('入门学徒'), findsOneWidget);
      // 2. AchievementCard
      expect(find.text('成就'), findsOneWidget);
      expect(find.text('4 / 6'), findsOneWidget);
      // 3. TrajectoryCard
      expect(find.text('成长轨迹'), findsOneWidget);
      // 4. CalendarCard
      expect(find.text('拍摄日历'), findsOneWidget);
      expect(find.text('本月 42 张'), findsOneWidget);
      expect(find.text('少'), findsOneWidget);
      expect(find.text('多'), findsOneWidget);
    });

    testWidgets('renders 6 achievement items', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 6 个成就名
      expect(find.text('初露锋芒'), findsOneWidget);
      expect(find.text('快门达人'), findsOneWidget);
      expect(find.text('模板收藏家'), findsOneWidget);
      expect(find.text('构图大师'), findsOneWidget);
      expect(find.text('后期魔法师'), findsOneWidget);
      expect(find.text('百变达人'), findsOneWidget);
    });

    testWidgets('renders all heatmap cells', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 热力图色块数 = ProfileMockData.heatmap.length
      // Forced fix: brief 注释说「112 格」但 verbatim 数据数组实际有 114 项
      // （10 列 × 11 行 + 4 项 = 114），用 mock 数据真实长度断言
      final expected = ProfileMockData.heatmap.length;
      var cellCount = 0;
      for (var i = 0; i < expected + 10; i++) {
        final key = ValueKey<String>('heatmap_cell_$i');
        if (find.byKey(key).evaluate().isNotEmpty) {
          cellCount++;
        }
      }
      expect(ProfileMockData.heatmap.length, greaterThanOrEqualTo(100),
          reason: '热力图至少应有 100 格数据');
      expect(cellCount, expected);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileGrowthPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('LEVEL'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileGrowthPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('LEVEL'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
