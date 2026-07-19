import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profile,
      routes: [
        GoRoute(
          path: RouteNames.profile,
          name: 'profile',
          builder: (_, __) => const ProfilePage(),
        ),
        GoRoute(
          path: RouteNames.profileGrowth,
          name: 'profileGrowth',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_GROWTH'))),
        ),
        GoRoute(
          path: RouteNames.profileInvite,
          name: 'profileInvite',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_INVITE'))),
        ),
        GoRoute(
          path: RouteNames.profileAcademy,
          name: 'profileAcademy',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_ACADEMY'))),
        ),
        GoRoute(
          path: RouteNames.profileSettings,
          name: 'profileSettings',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_SETTINGS'))),
        ),
        GoRoute(
          path: RouteNames.profileMyTemplates,
          name: 'profileMyTemplates',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_MY_TEMPLATES'))),
        ),
        GoRoute(
          path: RouteNames.gallery,
          name: 'gallery',
          builder: (_, __) => const Scaffold(body: Center(child: Text('GALLERY'))),
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

  group('ProfilePage', () {
    testWidgets('renders LumiraNav with title 我的', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我的'), findsOneWidget);
    });

    testWidgets('renders all 5 sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 1. HeroCard
      expect(find.text('小美'), findsOneWidget);
      expect(find.text('Lv.12 入门学徒'), findsOneWidget);
      expect(find.text('经验'), findsOneWidget);
      expect(find.text('还差 720 XP 升级至进阶学徒'), findsOneWidget);
      // 2. StatsCard（3 列）
      expect(find.text('拍摄作品'), findsOneWidget);
      expect(find.text('使用模板'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      // 3. FragmentCard（4 项）
      expect(find.text('碎片收集'), findsOneWidget);
      expect(find.text('人像'), findsOneWidget);
      expect(find.text('风光'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
      expect(find.text('街拍'), findsOneWidget);
      // 4. QuickActionsRow
      expect(find.text('成长中心'), findsOneWidget);
      expect(find.text('邀请有礼'), findsOneWidget);
      expect(find.text('摄影美学院'), findsOneWidget);
      // 5. MenuCard
      expect(find.text('我的相册'), findsOneWidget);
      expect(find.text('我的模板'), findsOneWidget);
      expect(find.text('场景管理'), findsOneWidget);
      expect(find.text('导入模板'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于如画'), findsOneWidget);
    });

    testWidgets('tapping 成长中心 pushes /profile/growth', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('成长中心'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_GROWTH'), findsOneWidget);
    });

    testWidgets('tapping 邀请有礼 pushes /profile/invite', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('邀请有礼'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_INVITE'), findsOneWidget);
    });

    testWidgets('tapping 设置 pushes /profile/settings', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('设置'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_SETTINGS'), findsOneWidget);
    });

    testWidgets('tapping 我的相册 pushes /gallery', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('我的相册'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('GALLERY'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfilePage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('小美'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfilePage), findsOneWidget, reason: 'style=$style');
        expect(find.text('小美'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
