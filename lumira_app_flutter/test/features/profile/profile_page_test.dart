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
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/fragments_providers.dart';
import 'package:lumira_app_flutter/features/profile/providers/profile_providers.dart';
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
        GoRoute(
          path: RouteNames.galleryDiary,
          name: 'galleryDiary',
          builder: (_, __) => const Scaffold(body: Center(child: Text('GALLERY_DIARY'))),
        ),
        GoRoute(
          path: RouteNames.checkinList,
          name: 'checkinList',
          builder: (_, __) => const Scaffold(body: Center(child: Text('CHECKIN_LIST'))),
        ),
        GoRoute(
          path: RouteNames.profileCollections,
          name: 'profileCollections',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_COLLECTIONS'))),
        ),
        GoRoute(
          path: RouteNames.profileEdit,
          name: 'profileEdit',
          builder: (_, __) => const Scaffold(body: Center(child: Text('PROFILE_EDIT'))),
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
        // FragmentCard 数据来自本地库，测试环境无真实 DB，按仓库惯例 override 卡片数据
        fragmentsProvider.overrideWith((ref) async => const [
          FragmentItem(name: '人像', icon: Icons.person_outline, current: 2, max: 5),
          FragmentItem(name: '风光', icon: Icons.landscape_outlined, current: 3, max: 5),
          FragmentItem(name: '美食', icon: Icons.restaurant_outlined, current: 1, max: 5),
          FragmentItem(name: '街拍', icon: Icons.photo_camera_outlined, current: 4, max: 5),
        ]),
        // 本地资料依赖 sqflite DB，测试环境无真实库，按仓库惯例 override 为 null
        profileDataProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// 带自定义 profile 的 wrap，用于验证偏好摘要详情态
  Widget wrapWithProfile(ThemeKey themeKey, UIStyle uiStyle, ProfileData profile) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        profileDataProvider.overrideWith((ref) async => profile),
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

    testWidgets('renders all 6 sections', (tester) async {
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
      // 3. 我的内容（记录功能统一入口）
      expect(find.text('我的内容'), findsOneWidget);
      expect(find.text('我的相册'), findsOneWidget);
      expect(find.text('拍摄日记'), findsOneWidget);
      expect(find.text('探店足迹'), findsOneWidget);
      expect(find.text('我的精选集'), findsOneWidget);
      // 4. FragmentCard（4 项）
      expect(find.text('碎片收集'), findsOneWidget);
      expect(find.text('人像'), findsOneWidget);
      expect(find.text('风光'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
      expect(find.text('街拍'), findsOneWidget);
      // 5. QuickActionsRow
      expect(find.text('成长中心'), findsOneWidget);
      expect(find.text('邀请有礼'), findsOneWidget);
      expect(find.text('摄影美学院'), findsOneWidget);
      // 6. MenuCard
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

    testWidgets('tapping 拍摄日记 pushes /gallery/diary', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('拍摄日记'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('GALLERY_DIARY'), findsOneWidget);
    });

    testWidgets('tapping 探店足迹 pushes /checkin/list', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('探店足迹'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('CHECKIN_LIST'), findsOneWidget);
    });

    testWidgets('tapping 我的精选集 pushes /profile/collections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('我的精选集'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_COLLECTIONS'), findsOneWidget);
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

    testWidgets('prefs card shows empty state when no profile', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('完善摄影偏好'), findsOneWidget);
      expect(find.text('告诉我们你的性别、水平、拍摄场景与频率'), findsOneWidget);
    });

    testWidgets('tapping prefs card empty state pushes /profile/edit', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('完善摄影偏好'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PROFILE_EDIT'), findsOneWidget);
    });

    testWidgets('prefs card shows detail state from real profile', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrapWithProfile(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        const ProfileData(
          username: '小鹿',
          avatarSeed: 'lumira-avatar-01',
          gender: 'male',
          skillLevel: 'beginner',
          shootFrequency: 'weekly',
          commonScenes: ['cafe', 'travel'],
        ),
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // HeroCard 用真实资料昵称
      expect(find.text('小鹿'), findsOneWidget);
      // 偏好摘要详情态
      expect(find.text('摄影偏好'), findsOneWidget);
      expect(find.text('性别'), findsOneWidget);
      expect(find.text('男'), findsOneWidget);
      expect(find.text('摄影水平'), findsOneWidget);
      expect(find.text('新手'), findsOneWidget);
      expect(find.text('拍摄频率'), findsOneWidget);
      expect(find.text('每周'), findsOneWidget);
      expect(find.text('常用场景'), findsOneWidget);
      expect(find.text('咖啡馆 / 旅行'), findsOneWidget);
    });
  });
}
