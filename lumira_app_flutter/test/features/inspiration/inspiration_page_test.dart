import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';
import 'package:lumira_app_flutter/features/inspiration/pages/inspiration_page.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_guide_bar.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);

    router = GoRouter(
      initialLocation: RouteNames.inspiration,
      routes: [
        GoRoute(
          path: RouteNames.inspiration,
          name: 'inspiration',
          builder: (_, __) => const InspirationPage(),
        ),
        GoRoute(
          path: RouteNames.captureSceneDetail,
          name: 'captureSceneDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('SCENE_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.templatesDetail,
          name: 'templatesDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATE_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.profileAcademyDetail,
          name: 'profileAcademyDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('ACADEMY_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.scenes,
          name: 'scenes',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SCENES'))),
        ),
        GoRoute(
          path: RouteNames.profileAcademy,
          name: 'profileAcademy',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('ACADEMY'))),
        ),
        GoRoute(
          path: RouteNames.inspirationTutorialDetail,
          name: 'inspirationTutorialDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TUTORIAL_DETAIL'))),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
  });

  tearDown(() async {
    HttpOverrides.global = null;
    await db.close();
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        galleryDaoProvider.overrideWith((ref) async => GalleryDao(db)),
        homeInspirationProvider.overrideWith((ref) async => const HeroInspiration(
              dateText: '8月14日 星期五 · 光线极佳',
              title: '今日灵感',
              description: '适合拍人像',
              weatherText: '28°C 晴 · 黄金时刻 17:00',
            )),
        todayShootProvider.overrideWith((ref) async => const [
              TodayShootItem(
                id: 'cafe-window',
                name: '咖啡馆窗边',
                vibe: '午后斜阳，把光调成蜜糖色',
                imageAsset: 'assets/images/scenes/scene_cafe.jpg',
                target: TodayShootTarget.scene,
                targetId: 'cafe-window',
              ),
              TodayShootItem(
                id: 'night-street',
                name: '霓虹街头',
                vibe: '霓虹与夜，城市的故事',
                imageAsset: 'assets/images/scenes/scene_street.jpg',
                target: TodayShootTarget.scene,
                targetId: 'night-street',
              ),
            ]),
        tutorialPicksProvider.overrideWith((ref) async => const [
              ShootingTutorial(
                id: 'tut_general_premium',
                title: '如何拍出高级感',
                subtitle: '留白与克制',
                coverImage: 'assets/images/scenes/scene_cafe.jpg',
                category: 'general',
                readMinutes: '3分钟',
                tags: [],
                intro: 'i',
                steps: [TutorialStep(title: '减少画面元素', body: 'b')],
                tips: ['tip'],
                cta: TutorialCta(
                    type: TutorialCtaType.scene, targetId: 'cafe-window'),
              ),
              ShootingTutorial(
                id: 'tut_general_vibe',
                title: '氛围感怎么找',
                subtitle: 's',
                coverImage: 'assets/images/scenes/scene_street.jpg',
                category: 'general',
                readMinutes: '2分钟',
                tags: [],
                intro: 'i',
                steps: [TutorialStep(title: 's', body: 'b')],
                tips: ['tip'],
                cta: TutorialCta(
                    type: TutorialCtaType.template, targetId: 'tpl'),
              ),
            ]),
        tutorialReadIdsProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('InspirationPage', () {
    testWidgets('renders LumiraNav with title 灵感', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.byType(InspirationPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '灵感'), findsOneWidget);
    });

    testWidgets('renders 4 sections without legacy blocks', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.textContaining('光线极佳'), findsOneWidget);
      expect(find.text('今日可拍'), findsOneWidget);
      expect(find.text('拍摄小课堂'), findsOneWidget);
      expect(find.text('灵感图集'), findsOneWidget);

      expect(find.text('今日心情'), findsNothing);
      expect(find.text('穿搭日记'), findsNothing);
      expect(find.text('加载更多灵感'), findsNothing);
      expect(find.text('根据你的喜好推荐'), findsNothing);
    });

    testWidgets('tapping guide bar pushes scene detail', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InspirationGuideBar));
      await tester.pumpAndSettle();
      expect(find.text('SCENE_DETAIL'), findsOneWidget);
    });

    testWidgets('tapping a today scene card pushes scene detail',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('咖啡馆窗边'));
      await tester.tap(find.text('咖啡馆窗边'));
      await tester.pumpAndSettle();
      expect(find.text('SCENE_DETAIL'), findsOneWidget);
    });

    testWidgets('tapping a tutorial card pushes tutorial detail',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('如何拍出高级感'));
      await tester.tap(find.text('如何拍出高级感'));
      await tester.pumpAndSettle();
      expect(find.text('TUTORIAL_DETAIL'), findsOneWidget);
    });

    testWidgets('tapping 系统性学习 → 美学院 pushes academy', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('系统性学习 → 美学院'));
      await tester.tap(find.text('系统性学习 → 美学院'));
      await tester.pumpAndSettle();
      expect(find.text('ACADEMY'), findsOneWidget);
    });

    testWidgets('renders across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await tester.pumpAndSettle();
        expect(find.text('今日可拍'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await tester.pumpAndSettle();
        expect(find.text('灵感图集'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}

Future<void> _onCreate(Database d, int v) async {
  await d.execute('''
    CREATE TABLE gallery_items (
      id TEXT PRIMARY KEY,
      data_url TEXT,
      file_path TEXT,
      original_path TEXT,
      transform TEXT,
      post_process TEXT,
      scene_id TEXT,
      template_id TEXT,
      kit_id TEXT,
      mood TEXT,
      lut TEXT,
      is_favorite INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''');
}
