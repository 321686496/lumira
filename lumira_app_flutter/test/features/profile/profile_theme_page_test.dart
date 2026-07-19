import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_theme_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileSettingsTheme,
      routes: [
        GoRoute(
          path: RouteNames.profileSettingsTheme,
          name: 'profileSettingsTheme',
          builder: (_, __) => const ProfileThemePage(),
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

  Widget wrapWithContainer(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

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

  group('ProfileThemePage', () {
    testWidgets('renders LumiraNav with title 主题与风格', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileThemePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '主题与风格'), findsOneWidget);
    });

    testWidgets('renders all sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 2 个 section title
      expect(find.text('UI 风格'), findsOneWidget);
      expect(find.text('颜色主题'), findsOneWidget);
      // 4 个 style cards
      expect(find.text('新拟态'), findsOneWidget);
      expect(find.text('扁平化'), findsOneWidget);
      expect(find.text('玻璃拟态'), findsOneWidget);
      expect(find.text('女性美学'), findsOneWidget);
      // 8 个 theme cards
      expect(find.text('暖米白'), findsOneWidget);
      expect(find.text('浓墨'), findsOneWidget);
      expect(find.text('胶片复古'), findsOneWidget);
      expect(find.text('日系清新'), findsOneWidget);
      expect(find.text('温馨粉'), findsOneWidget);
      expect(find.text('马卡龙'), findsOneWidget);
      expect(find.text('莫兰迪'), findsOneWidget);
      expect(find.text('玫瑰金'), findsOneWidget);
      // 跟随系统
      expect(find.text('跟随系统'), findsOneWidget);
      // 底部说明
      expect(find.text('风格与主题可任意组合，切换即时生效'), findsOneWidget);
    });

    testWidgets('tapping a theme card updates themeKeyProvider', (tester) async {
      setLargeViewport(tester);
      final container = ProviderContainer(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
      );
      addTearDown(container.dispose);

      // 初始 themeKeyProvider 默认 warmWhite
      expect(container.read(themeKeyProvider), ThemeKey.warmWhite);

      await tester.pumpWidget(wrapWithContainer(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '浓墨' 主题卡
      await tester.tap(find.text('浓墨'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证 themeKeyProvider 已更新
      expect(container.read(themeKeyProvider), ThemeKey.ink);
    });

    testWidgets('tapping a style card updates uiStyleProvider', (tester) async {
      setLargeViewport(tester);
      final container = ProviderContainer(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(uiStyleProvider), UIStyle.neumorphic);

      await tester.pumpWidget(wrapWithContainer(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '扁平化' 风格卡
      await tester.tap(find.text('扁平化'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证 uiStyleProvider 已更新
      expect(container.read(uiStyleProvider), UIStyle.flat);
    });

    testWidgets('tapping 玻璃拟态 style updates uiStyleProvider to glass', (tester) async {
      setLargeViewport(tester);
      final container = ProviderContainer(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapWithContainer(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('玻璃拟态'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(container.read(uiStyleProvider), UIStyle.glass);
    });

    testWidgets('tapping 莫兰迪 theme updates themeKeyProvider to morandi', (tester) async {
      setLargeViewport(tester);
      final container = ProviderContainer(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(wrapWithContainer(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('莫兰迪'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(container.read(themeKeyProvider), ThemeKey.morandi);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileThemePage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('颜色主题'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileThemePage), findsOneWidget, reason: 'style=$style');
        expect(find.text('颜色主题'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
