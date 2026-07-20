import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_scene_guide_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.10 — CaptureSceneGuidePage 测试
///
/// 覆盖 brief §5：≥8 项断言，含 UI 渲染 / 路由参数 / 用户交互 / 空状态 / 业务逻辑（筛选）。
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
    String initialLocation = '/capture/scene-guide',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.captureSceneGuide,
          name: 'captureSceneGuide',
          builder: (context, state) {
            final scene = state.queryParams[RouteNames.paramScene];
            return CaptureSceneGuidePage(scene: scene);
          },
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
          builder: (_, __) => const _StubPage(text: 'MANAGE_PAGE'),
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
  group('CaptureSceneGuidePage — basic rendering', () {
    testWidgets('renders LumiraNav with title 场景灵感', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景灵感'), findsOneWidget);
    });

    testWidgets('renders 全部 category pill and 4 category pills',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 全部 + 4 个大类：光线氛围 / 室外环境 / 室内空间 / 情绪氛围
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('光线氛围'), findsOneWidget);
      expect(find.text('室外环境'), findsOneWidget);
      expect(find.text('室内空间'), findsOneWidget);
      expect(find.text('情绪氛围'), findsOneWidget);
    });

    testWidgets('renders 7 tag chips', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 7 个标签
      // 注意：「咖啡馆」同时出现在 tag chip（fontSize 12）和场景卡名称（fontSize 15）中，
      // 用 byWidgetPredicate 区分 tag chip 的 Text（fontSize == 12）
      expect(find.text('暖调'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == '咖啡馆' &&
              w.style?.fontSize == 12,
        ),
        findsOneWidget,
      );
      expect(find.text('人像'), findsOneWidget);
      expect(find.text('夜景'), findsOneWidget);
      expect(find.text('户外'), findsOneWidget);
      expect(find.text('柔光'), findsOneWidget);
      expect(find.text('胶片'), findsOneWidget);
    });

    testWidgets('renders scene cards with names and vibes', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认显示全部 7 个场景（1 自定义 + 6 预设）
      // 注意：「咖啡馆」文本同时出现在 tag chip 与场景卡，避免使用
      expect(find.text('黄昏剪影'), findsOneWidget);
      expect(find.text('霓虹街角'), findsOneWidget);
      expect(find.text('海边沙滩'), findsOneWidget);
      expect(find.text('竹海禅意'), findsOneWidget);
      expect(find.text('雨窗静思'), findsOneWidget);
      expect(find.text('我的咖啡馆'), findsOneWidget);
    });

    testWidgets('renders nav settings icon for manage entry', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 右上角 settings 图标
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 路由参数
  // ============================================================
  group('CaptureSceneGuidePage — route parameters', () {
    testWidgets('accepts scene query param without crash', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/scene-guide?scene=cafe-window',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 路由参数仅作为页面标识传递，UI 仍正常渲染
      expect(find.widgetWithText(LumiraNav, '场景灵感'), findsOneWidget);
      // 使用不与 tag chip 冲突的场景名
      expect(find.text('黄昏剪影'), findsOneWidget);
    });

    testWidgets('renders without scene param (default)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景灵感'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 交互
  // ============================================================
  group('CaptureSceneGuidePage — interactions', () {
    testWidgets('tapping a category pill filters scenes', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始全部 7 个场景
      expect(find.text('黄昏剪影'), findsOneWidget);
      expect(find.text('竹海禅意'), findsOneWidget);

      // 点击「室内空间」大类
      await tester.tap(find.text('室内空间'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 室内空间仅有「咖啡馆」（咖啡馆风格）+ 自定义场景「我的咖啡馆」(室内空间)
      // 自定义场景的 category 仍为 SceneCategory.indoor
      expect(find.text('我的咖啡馆'), findsOneWidget);
      // 室外场景应被过滤
      expect(find.text('竹海禅意'), findsNothing);
      expect(find.text('海边沙滩'), findsNothing);
      expect(find.text('黄昏剪影'), findsNothing);
    });

    testWidgets('tapping a tag chip toggles filter', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「暖调」标签 — 仅 custom_demo_001.tagIds 含 tag_warm
      // 预设场景的 recommendedTagIds 均为空数组（与源 uni-app 数据一致），
      // 所以仅自定义场景会匹配
      await tester.tap(find.text('暖调'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('我的咖啡馆'), findsOneWidget);
      // 预设场景被过滤（避免使用「咖啡馆」文本，因其同时是 tag chip 标签）
      expect(find.text('黄昏剪影'), findsNothing);
      expect(find.text('海边沙滩'), findsNothing);
    });

    testWidgets('tapping a scene card navigates to detail page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「黄昏剪影」场景卡 → 路由到 /capture/scene-detail?sceneId=sunset-silhouette
      // 避免使用「咖啡馆」文本，因其同时是 tag chip 标签
      await tester.tap(find.text('黄昏剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('DETAIL_PAGE:sunset-silhouette'), findsOneWidget);
    });

    testWidgets('tapping settings icon navigates to manage page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('MANAGE_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 空状态 / 业务逻辑
  // ============================================================
  group('CaptureSceneGuidePage — empty state', () {
    testWidgets('renders 暂无匹配场景 when filter yields no results',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「情绪氛围」大类
      await tester.tap(find.text('情绪氛围'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 情绪氛围下仅有「雨窗静思」（healing 风格）
      // 再选择「夜景」标签 — 雨窗静思无 tag_night → 空状态
      await tester.tap(find.text('夜景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('暂无匹配场景'), findsOneWidget);
    });

    testWidgets('selecting 全部 category clears category filter',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先点「室内空间」过滤
      await tester.tap(find.text('室内空间'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('海边沙滩'), findsNothing);

      // 再点「全部」恢复
      await tester.tap(find.text('全部'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('海边沙滩'), findsOneWidget);
      expect(find.text('黄昏剪影'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 5: Cross-theme/cross-style smoke
  // ============================================================
  group('CaptureSceneGuidePage — smoke tests', () {
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

        // 避免使用「咖啡馆」文本（与 tag chip 冲突）
        expect(find.text('黄昏剪影'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('全部'), findsOneWidget,
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
