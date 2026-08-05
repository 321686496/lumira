import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_settings_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileSettings,
      routes: [
        GoRoute(
          path: RouteNames.profileSettings,
          name: 'profileSettings',
          builder: (_, __) => const ProfileSettingsPage(),
        ),
        GoRoute(
          path: RouteNames.profileSettingsTheme,
          name: 'profileSettingsTheme',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_THEME'))),
        ),
        GoRoute(
          path: RouteNames.profileComplianceAgreement,
          name: 'profileComplianceAgreement',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_AGREEMENT'))),
        ),
        GoRoute(
          path: RouteNames.profileCompliancePrivacy,
          name: 'profileCompliancePrivacy',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_PRIVACY'))),
        ),
        GoRoute(
          path: RouteNames.profileComplianceSdk,
          name: 'profileComplianceSdk',
          builder: (_, __) => const Scaffold(body: Center(child: Text('COMPLIANCE_SDK'))),
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

  group('ProfileSettingsPage', () {
    testWidgets('renders LumiraNav with title 设置', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileSettingsPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '设置'), findsOneWidget);
    });

    testWidgets('renders all 6 setting groups', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 6 个 group title
      expect(find.text('通用'), findsOneWidget);
      expect(find.text('首页标题样式'), findsOneWidget);
      expect(find.text('显示'), findsOneWidget);
      expect(find.text('拍摄'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('合规与法律'), findsOneWidget);
      // 通用组
      expect(find.text('主题选择'), findsOneWidget);
      expect(find.text('风格选择'), findsOneWidget);
      expect(find.text('语言'), findsOneWidget);
      // 显示组
      expect(find.text('网格显示'), findsOneWidget);
      expect(find.text('水平仪'), findsOneWidget);
      // 拍摄组
      expect(find.text('默认分辨率'), findsOneWidget);
      expect(find.text('水印'), findsOneWidget);
      expect(find.text('快门声音'), findsOneWidget);
      // 关于组
      expect(find.text('版本号'), findsOneWidget);
      expect(find.text('清除缓存'), findsOneWidget);
      expect(find.text('关于如画'), findsOneWidget);
      // 合规与法律组
      expect(find.text('用户协议'), findsOneWidget);
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('个人信息清单与第三方SDK目录'), findsOneWidget);
    });

    testWidgets('tapping 隐私政策 pushes compliance privacy page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('隐私政策'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('COMPLIANCE_PRIVACY'), findsOneWidget);
    });

    testWidgets('tapping 用户协议 pushes compliance agreement page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('用户协议'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('COMPLIANCE_AGREEMENT'), findsOneWidget);
    });

    testWidgets('tapping 主题选择 pushes /profile/settings/theme', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('主题选择'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_THEME'), findsOneWidget);
    });

    testWidgets('toggling 网格显示 switches state', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 找到 "网格显示" 行下的 Switch
      final gridRow = find.ancestor(of: find.text('网格显示'), matching: find.byType(GestureDetector));
      final gridSwitch = find.descendant(of: gridRow, matching: find.byType(Switch));
      expect(gridSwitch, findsOneWidget);

      // 初始状态：defaultGridOn=false
      Switch switchWidget = tester.widget<Switch>(gridSwitch);
      expect(switchWidget.value, false);

      // 切换开关
      await tester.tap(gridSwitch);
      await settleOrPump(tester, UIStyle.neumorphic);

      switchWidget = tester.widget<Switch>(gridSwitch);
      expect(switchWidget.value, true);
    });

    testWidgets('tapping version 7 times shows redemption input', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始无 TextField
      expect(find.byType(TextField), findsNothing);

      // 找到版本号行
      final versionRow = find.ancestor(of: find.text('版本号'), matching: find.byType(GestureDetector));
      expect(versionRow, findsOneWidget);

      // 连点 7 次
      for (var i = 0; i < 7; i++) {
        await tester.tap(versionRow);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应该出现 TextField（兑换码输入框）
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileSettingsPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('设置'), findsOneWidget, reason: 'theme=$theme');
      }
    });
  });
}
