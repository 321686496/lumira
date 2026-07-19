import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_invite_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileInvite,
      routes: [
        GoRoute(
          path: RouteNames.profileInvite,
          name: 'profileInvite',
          builder: (_, __) => const ProfileInvitePage(),
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

  group('ProfileInvitePage', () {
    testWidgets('renders LumiraNav with title 邀请有礼', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileInvitePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '邀请有礼'), findsOneWidget);
    });

    testWidgets('renders all 5 sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 1. HeroCard
      expect(find.text('邀请好友，获得奖励'), findsOneWidget);
      expect(find.text('邀请好友一起记录美好，解锁专属模板'), findsOneWidget);
      // 2. RewardCard
      expect(find.text('奖励阶梯'), findsOneWidget);
      expect(find.text('日系胶片模板'), findsOneWidget);
      expect(find.text('法式复古包'), findsOneWidget);
      expect(find.text('氛围感包'), findsOneWidget);
      expect(find.text('分享达人成就'), findsOneWidget);
      expect(find.text('全部精选模板'), findsOneWidget);
      expect(find.text('裂变之神'), findsOneWidget);
      // 3. ProgressCard
      expect(find.text('当前进度'), findsOneWidget);
      expect(find.text('已邀请 3 位'), findsOneWidget);
      expect(find.text('再邀请 2 人可解锁「氛围感包」'), findsOneWidget);
      // 4. 生成邀请卡片 button
      expect(find.text('生成邀请卡片'), findsOneWidget);
      // 5. CodeCard
      expect(find.text('输入好友邀请码'), findsOneWidget);
      expect(find.text('确认绑定'), findsOneWidget);
      // 6. RecordCard
      expect(find.text('邀请记录'), findsOneWidget);
      expect(find.text('小雅'), findsOneWidget);
      expect(find.text('小琳'), findsOneWidget);
      expect(find.text('小悦'), findsOneWidget);
    });

    testWidgets('tapping 生成邀请卡片 shows SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始无 SnackBar
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('生成邀请卡片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应出现 SnackBar，文本 '生成邀请卡片'
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('生成邀请卡片'), findsNWidgets(2)); // button + snackbar
    });

    testWidgets('tapping 确认绑定 with empty code shows error SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 不输入任何内容直接点击确认绑定
      await tester.tap(find.text('确认绑定'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应出现 SnackBar，文本 '请输入邀请码'
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('请输入邀请码'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileInvitePage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('邀请好友，获得奖励'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileInvitePage), findsOneWidget, reason: 'style=$style');
        expect(find.text('邀请好友，获得奖励'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
