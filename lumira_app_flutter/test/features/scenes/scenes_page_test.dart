import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/scenes/data/scenes_mock_data.dart';
import 'package:lumira_app_flutter/features/scenes/pages/scenes_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.11 — ScenesPage 测试
///
/// 覆盖 brief：≥10 项断言，含 UI 渲染 / 分类切换 / 路由跳转 / 空状态 / 照片数 badge /
/// 搜索 toast / FAB 跳转 / 跨主题 smoke。
void main() {
  FlutterExceptionHandler? originalErrorHandler;

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
    List<Override> overrides = const [],
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
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: goRouter),
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

  // ============================================================
  // 分类 1: 基本渲染
  // ============================================================
  group('ScenesPage — basic rendering', () {
    testWidgets('renders LumiraNav with title 场景库', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景库'), findsOneWidget);
    });

    testWidgets('renders 5 category pills: 全部/光线/室外/室内/情绪',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('全部'), findsOneWidget);
      expect(find.text('光线'), findsOneWidget);
      expect(find.text('室外'), findsOneWidget);
      expect(find.text('室内'), findsOneWidget);
      expect(find.text('情绪'), findsOneWidget);
    });

    testWidgets('renders scene cards with names and vibes', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认显示全部 7 个场景（1 自定义 + 6 预设）
      expect(find.text('黄昏剪影'), findsOneWidget);
      expect(find.text('霓虹街角'), findsOneWidget);
      expect(find.text('海边沙滩'), findsOneWidget);
      expect(find.text('竹海禅意'), findsOneWidget);
      expect(find.text('雨窗静思'), findsOneWidget);
      expect(find.text('我的咖啡馆'), findsOneWidget);
      // vibe 文本（不与其它组件冲突）
      expect(find.text('把人放进夕阳里，剪成一帧诗'), findsOneWidget);
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
  // 分类 2: 分类切换
  // ============================================================
  group('ScenesPage — category filter', () {
    testWidgets('tapping 室内 filters to indoor scenes only', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始全部 7 个场景
      expect(find.text('黄昏剪影'), findsOneWidget);
      expect(find.text('海边沙滩'), findsOneWidget);

      // 点击「室内」
      await tester.tap(find.text('室内'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // indoor: cafe-window + custom_demo_001（共 2 个）
      expect(find.text('我的咖啡馆'), findsOneWidget);
      // 室外 / 光线类被过滤
      expect(find.text('黄昏剪影'), findsNothing);
      expect(find.text('海边沙滩'), findsNothing);
      expect(find.text('竹海禅意'), findsNothing);
    });

    testWidgets('tapping 全部 restores all scenes after filter',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先点「光线」过滤
      await tester.tap(find.text('光线'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('海边沙滩'), findsNothing);

      // 再点「全部」恢复
      await tester.tap(find.text('全部'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('海边沙滩'), findsOneWidget);
      expect(find.text('黄昏剪影'), findsOneWidget);
    });

    testWidgets('tapping 情绪 filters to mood scenes (rainy-window)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('情绪'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // mood 仅有「雨窗静思」
      expect(find.text('雨窗静思'), findsOneWidget);
      expect(find.text('黄昏剪影'), findsNothing);
      expect(find.text('我的咖啡馆'), findsNothing);
    });
  });

  // ============================================================
  // 分类 3: 路由跳转
  // ============================================================
  group('ScenesPage — navigation', () {
    testWidgets('tapping a scene card navigates to detail page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
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
  // 分类 4: 照片数 badge
  // ============================================================
  group('ScenesPage — photo count badge', () {
    testWidgets('renders badge "N 张" for scenes with photos > 0',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe-window: 8 张, rainy-window: 12 张, sunset-silhouette: 3 张
      expect(find.text('8 张'), findsOneWidget);
      expect(find.text('12 张'), findsOneWidget);
      expect(find.text('3 张'), findsOneWidget);
    });

    testWidgets('does not render badge for scene with 0 photos',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // seaside-beach: 0 张 → 无 badge
      expect(find.text('0 张'), findsNothing);
    });
  });

  // ============================================================
  // 分类 5: 空状态
  // ============================================================
  group('ScenesPage — empty state', () {
    testWidgets('renders 暂无场景 when scenesListProvider returns []',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        overrides: [
          scenesListProvider.overrideWith((ref) => const []),
        ],
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('暂无场景'), findsOneWidget);
      // 不应渲染任何场景卡
      expect(find.text('黄昏剪影'), findsNothing);
    });
  });

  // ============================================================
  // 分类 6: 跨主题/跨风格 smoke
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

        expect(find.text('黄昏剪影'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('全部'), findsOneWidget,
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
