import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_scene_detail_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.10 — CaptureSceneDetailPage 测试
///
/// 覆盖 brief §5：≥8 项断言，含 UI 渲染 / 路由参数 / 用户交互 / 空状态。
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
    String initialLocation = '/capture/scene-detail?sceneId=cafe-window',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.captureSceneDetail,
          name: 'captureSceneDetail',
          builder: (context, state) {
            final sceneId = state.queryParams[RouteNames.paramSceneId];
            return CaptureSceneDetailPage(sceneId: sceneId);
          },
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (context, state) {
            final scene = state.queryParams[RouteNames.paramScene];
            return _StubPage(text: 'CAPTURE_PAGE:scene=$scene');
          },
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
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
  group('CaptureSceneDetailPage — basic rendering', () {
    testWidgets('renders LumiraNav with scene name as title', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '咖啡馆'), findsOneWidget);
    });

    testWidgets('renders atmosphere section title 氛围', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('氛围'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('推荐滤镜'), findsOneWidget);
      expect(find.text('拍摄小贴士'), findsOneWidget);
      expect(find.text('我的成就'), findsOneWidget);
    });

    testWidgets('renders bottom buttons 用此场景拍照 and 加入组合', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('用此场景拍照'), findsOneWidget);
      expect(find.text('加入组合'), findsOneWidget);
    });

    testWidgets('renders favorite button in nav (favorite_border icon)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe-window 是收藏场景，应显示 favorite（实心）
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('renders scene name and vibe in header', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 标题与 vibe 文本
      expect(find.text('咖啡馆'), findsWidgets); // nav + header 都有
      expect(find.text('慵懒午后，把光调成蜜糖色'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 路由参数
  // ============================================================
  group('CaptureSceneDetailPage — route parameters', () {
    testWidgets('renders empty state when sceneId is unknown', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-detail?sceneId=non_existent',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('场景未找到'), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
    });

    testWidgets('renders default title 场景详情 when sceneId is empty',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-detail',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景详情'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 交互
  // ============================================================
  group('CaptureSceneDetailPage — interactions', () {
    testWidgets('tapping favorite toggles icon and shows SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始：cafe-window 收藏 → favorite icon
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // 点击 favorite
      await tester.tap(find.byIcon(Icons.favorite));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换为 favorite_border
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('已取消收藏'), findsOneWidget);
    });

    testWidgets('tapping 用此场景拍照 navigates to capture page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('用此场景拍照'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('CAPTURE_PAGE:scene=cafe-window'), findsOneWidget);
    });

    testWidgets('tapping 加入组合 opens AddToCompositionSheet', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('加入组合'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 加入组合 现在打开 AddToCompositionSheet 模态底部弹层（之前是 mock
      // SnackBar 显示 "加入组合：${sceneName}"）。验证 sheet 内容已渲染：
      // - sheet 标题 "加入组合" + 表单标签 "套件名称" + 保存按钮 "保存套件"
      // - 默认套件名称 "${sceneName}-自由拍摄" = "咖啡馆-自由拍摄"
      expect(find.text('套件名称'), findsOneWidget);
      expect(find.text('保存套件'), findsOneWidget);
      expect(find.text('咖啡馆-自由拍摄'), findsOneWidget);
    });

    testWidgets(
        'custom scene shows 添加标签 button and toggles tag selector',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-detail?sceneId=custom_demo_001',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 自定义场景显示「添加标签」按钮
      expect(find.text('添加标签'), findsOneWidget);

      // 点击切换标签选择器
      await tester.tap(find.text('添加标签'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择器出现：包含全部 7 个标签（不在卡片中渲染的）
      expect(find.text('暖调'), findsWidgets);
      expect(find.text('咖啡馆'), findsWidgets);
    });
  });

  // ============================================================
  // 分类 4: Cross-theme/cross-style smoke
  // ============================================================
  group('CaptureSceneDetailPage — smoke tests', () {
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

        expect(find.text('氛围'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('用此场景拍照'), findsOneWidget,
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
