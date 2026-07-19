import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_academy_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileAcademy,
      routes: [
        GoRoute(
          path: RouteNames.profileAcademy,
          name: 'profileAcademy',
          builder: (_, __) => const ProfileAcademyPage(),
        ),
        GoRoute(
          path: RouteNames.profile,
          name: 'profile',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_HOME'))),
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

  group('ProfileAcademyPage', () {
    testWidgets('renders empty state with school icon and coming soon title', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileAcademyPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '摄影美学院'), findsOneWidget);
      // 空状态：图标 + 文本
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.text('摄影美学院即将上线'), findsOneWidget);
    });

    testWidgets('back button pops the page (no canPop → fallback go profile)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 顶部无前页（router 初始就在 academy），按 back 应 fallback 到 profile
      // 找到 _BackButton 中的 GestureDetector（位于 leading 位置）
      // LumiraNav 的 leading 是 _BackButton，点击它
      // 由于初始栈不可 pop，点击 back 应跳到 /profile，渲染 PROFILE_HOME
      final backGesture = find.byIcon(Icons.arrow_back_ios_new);
      expect(backGesture, findsOneWidget);
      await tester.tap(backGesture);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_HOME'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileAcademyPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('摄影美学院即将上线'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileAcademyPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('摄影美学院即将上线'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
