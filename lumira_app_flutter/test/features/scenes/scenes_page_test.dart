import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/seeders/builtin_data_seeder.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/scenes/pages/scenes_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.11 + Task A3 — ScenesPage 测试
///
/// 覆盖 brief：≥10 项断言，含 UI 渲染 / 分类导航 / 路由跳转 / 照片数 badge /
/// 搜索 toast / FAB 跳转 / 跨主题 smoke。
///
/// Task A3 适配：页面从 mock scenesListProvider 切换到 scenesDaoProvider，
/// 默认显示分类概览（4 个大卡片），点击分类后才显示场景 grid。
/// 测试使用 sqflite_ffi + BuiltinDataSeeder 在 setUpAll 中种入种子数据。
void main() {
  FlutterExceptionHandler? originalErrorHandler;
  // 共享 DB 实例：在 setUpAll 中创建并种入种子数据，所有测试通过 override 复用。
  // 避免每个测试重新打开 DB 文件导致的文件锁 / 时序问题。
  late Database sharedDb;
  ProviderContainer? seedContainer;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 确保使用全新的 DB 文件并种入种子场景数据
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'lumira.db');
    try {
      await databaseFactory.deleteDatabase(dbPath);
    } catch (_) {
      // 文件可能不存在，忽略
    }
    // 通过临时 container 触发 databaseProvider.onCreate（建表），并种入数据。
    // 不 dispose container，保持 DB 连接存活，供测试通过 override 复用。
    seedContainer = ProviderContainer();
    sharedDb = await seedContainer!.read(databaseProvider.future);
    await BuiltinDataSeeder.seedAll(sharedDb);
  });

  tearDownAll(() {
    seedContainer?.dispose();
  });

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String initialLocation = '/scenes',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.scenes,
          name: 'scenes',
          builder: (_, __) => const ScenesPage(),
        ),
        GoRoute(
          path: RouteNames.captureSceneDetail,
          name: 'captureSceneDetail',
          builder: (context, state) {
            final sceneId = state.queryParams[RouteNames.paramSceneId];
            return _StubPage(text: 'DETAIL_PAGE:$sceneId');
          },
        ),
        GoRoute(
          path: RouteNames.captureSceneManage,
          name: 'captureSceneManage',
          builder: (context, state) {
            final tab = state.queryParams[RouteNames.paramTab];
            return _StubPage(text: 'MANAGE_PAGE:tab=$tab');
          },
        ),
        GoRoute(
          path: RouteNames.home,
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        // 复用 sharedDb，避免每个测试重新打开 DB 文件
        databaseProvider.overrideWith((ref) async => sharedDb),
        // 直接覆盖 scenesDaoProvider，避免 FutureProvider 异步解析时序问题
        scenesDaoProvider.overrideWith((ref) async => ScenesDao(sharedDb)),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    // 使用 pump + runAsync：sqflite_common_ffi 的 DB 查询是真实 async 操作，
    // 在 FakeAsync 环境下 pump(Duration) 无法让真实 Future 完成。
    // 必须用 tester.runAsync 让真实 async 操作（DAO 查询）完成。
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 基本渲染（分类概览模式）
  // ============================================================
  group('ScenesPage — basic rendering', () {
    testWidgets('renders LumiraNav with title 场景库', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景库'), findsOneWidget);
    });

    testWidgets(
        'renders 4 category cards: 光线氛围/室外环境/室内空间/情绪氛围',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个一级分类卡片名称
      expect(find.text('光线氛围'), findsOneWidget);
      expect(find.text('室外环境'), findsOneWidget);
      expect(find.text('室内空间'), findsOneWidget);
      expect(find.text('情绪氛围'), findsOneWidget);
    });

    testWidgets('renders overview summary with total scene count',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 摘要：7 个场景 · 4 个大类等你探索
      expect(find.textContaining('7 个场景'), findsOneWidget);
      expect(find.textContaining('4 个大类'), findsOneWidget);
      // 浏览分类 标题
      expect(find.text('浏览分类'), findsOneWidget);
    });

    testWidgets('renders nav back and search icons', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders FAB with plus icon', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 分类导航（点击分类卡片进入二级页面）
  // ============================================================
  group('ScenesPage — category navigation', () {
    testWidgets('tapping 室内空间 card shows indoor scenes', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「室内空间」分类卡片
      await tester.tap(find.text('室内空间'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // indoor: cafe-window (咖啡馆) + custom_demo_001 (我的咖啡馆)
      expect(find.text('咖啡馆'), findsOneWidget);
      expect(find.text('我的咖啡馆'), findsOneWidget);
      // 其他分类的场景不出现
      expect(find.text('黄昏剪影'), findsNothing);
      expect(find.text('海边沙滩'), findsNothing);
      expect(find.text('雨窗静思'), findsNothing);
    });

    testWidgets('tapping 情绪氛围 card shows mood scenes', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('情绪氛围'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // mood 仅有「雨窗静思」
      expect(find.text('雨窗静思'), findsOneWidget);
      expect(find.text('黄昏剪影'), findsNothing);
      expect(find.text('咖啡馆'), findsNothing);
    });

    testWidgets('tapping back from category returns to overview',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入二级分类
      await tester.tap(find.text('光线氛围'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('黄昏剪影'), findsOneWidget);

      // 点击返回按钮回到分类概览
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 回到概览：应再次看到分类卡片
      expect(find.text('光线氛围'), findsOneWidget);
      expect(find.text('室内空间'), findsOneWidget);
      // 场景名不再显示
      expect(find.text('黄昏剪影'), findsNothing);
    });
  });

  // ============================================================
  // 分类 3: 路由跳转
  // ============================================================
  group('ScenesPage — navigation', () {
    testWidgets('tapping a scene card in category navigates to detail page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先进入「光线氛围」分类
      await tester.tap(find.text('光线氛围'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「黄昏剪影」→ /capture/scene-detail?sceneId=sunset-silhouette
      await tester.tap(find.text('黄昏剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('DETAIL_PAGE:sunset-silhouette'), findsOneWidget);
    });

    testWidgets('tapping FAB navigates to manage page with tab=custom',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.byIcon(Icons.add));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('MANAGE_PAGE:tab=custom'), findsOneWidget);
    });

    testWidgets('tapping search icon shows SnackBar 搜索功能开发中',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.byIcon(Icons.search));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('搜索功能开发中'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 照片数 badge（二级分类页面中）
  // ============================================================
  group('ScenesPage — photo count badge', () {
    testWidgets('renders badge "N 张" for scenes with photos > 0 in category',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入「室内空间」分类
      await tester.tap(find.text('室内空间'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe-window: 8 张, custom_demo_001: 1 张
      expect(find.text('8 张'), findsOneWidget);
      expect(find.text('1 张'), findsOneWidget);
    });

    testWidgets('does not render badge for scene with 0 photos',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入「室外环境」分类
      await tester.tap(find.text('室外环境'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // seaside-beach: 0 张 → 无 badge
      expect(find.text('0 张'), findsNothing);
      // forest-bamboo: 2 张 → 有 badge
      expect(find.text('2 张'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 5: 跨主题/跨风格 smoke
  // ============================================================
  group('ScenesPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      final combinations = <_ThemeStyleCombo>[
        for (final t in ThemeKey.values)
          _ThemeStyleCombo(theme: t, style: UIStyle.neumorphic),
        for (final s in UIStyle.values)
          if (s != UIStyle.neumorphic)
            _ThemeStyleCombo(theme: ThemeKey.warmWhite, style: s),
      ];

      for (final combo in combinations) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: combo.theme, uiStyle: combo.style));
        await settleOrPump(tester, combo.style);

        // 概览模式断言：分类卡片 + 标题
        expect(find.text('光线氛围'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('室内空间'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.widgetWithText(LumiraNav, '场景库'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
