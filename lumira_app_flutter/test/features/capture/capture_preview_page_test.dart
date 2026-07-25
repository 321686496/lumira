import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.9A — CapturePreviewPage 测试
///
/// 覆盖 brief §5.3 ≥7 项断言 + cross-theme/cross-style smoke test。
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
    String initialLocation = '/capture/preview',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.capturePreview,
          name: 'capturePreview',
          builder: (context, state) {
            final photoUrl = state.queryParams['photoUrl'];
            return CapturePreviewPage(photoUrl: photoUrl);
          },
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.gallery,
          name: 'gallery',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('GALLERY_PAGE'))),
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
  group('CapturePreviewPage — basic rendering', () {
    testWidgets('renders LumiraNav with title 照片预览 and back button',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      // 对比 › 链接
      expect(find.text('对比 ›'), findsOneWidget);
    });

    testWidgets('renders 7 mood pills', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 7 个心情标签
      expect(find.text('开心'), findsOneWidget);
      expect(find.text('甜酷'), findsOneWidget);
      expect(find.text('温柔'), findsOneWidget);
      expect(find.text('复古'), findsOneWidget);
      expect(find.text('清新'), findsOneWidget);
      expect(find.text('文艺'), findsOneWidget);
      expect(find.text('治愈'), findsOneWidget);
      // 心情区标题
      expect(find.text('今天的心情是？'), findsOneWidget);
    });

    testWidgets('renders 8 scene pills + 不标记 pill', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 8 个场景标签
      expect(find.text('咖啡馆'), findsOneWidget);
      expect(find.text('街头'), findsOneWidget);
      expect(find.text('公园'), findsOneWidget);
      expect(find.text('居家'), findsOneWidget);
      expect(find.text('工作室'), findsOneWidget);
      expect(find.text('餐厅'), findsOneWidget);
      expect(find.text('旅行'), findsOneWidget);
      expect(find.text('夜景'), findsOneWidget);
      // 不标记 pill
      expect(find.text('不标记'), findsOneWidget);
      // 场景区标题
      expect(find.text('拍摄场景'), findsOneWidget);
    });

    testWidgets('renders save button 保存到系统相册', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('保存到系统相册'), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    });

    testWidgets('renders 2 action buttons (生成对比图 / 生成 EXIF 卡片)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('生成对比图'), findsOneWidget);
      expect(find.text('生成 EXIF 卡片'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 交互
  // ============================================================
  group('CapturePreviewPage — interactions', () {
    testWidgets('tapping mood pill activates it and deactivates others',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始：开心 active（mock 默认 _moods[0].active = true）
      // 点击 甜酷 切换 active
      await tester.tap(find.text('甜酷'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证 active 状态切换：通过 _Pill 的 BoxDecoration.gradient 判定
      // active → LinearGradient（非 null）；inactive → null
      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(
                  of: find.text(name),
                  matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      final sweetDecoration = pillDecorationOf('甜酷');
      final happyDecoration = pillDecorationOf('开心');

      expect(sweetDecoration.gradient, isA<LinearGradient>(),
          reason: '点击 甜酷 后：甜酷 pill 应为 active（gradient 应为 LinearGradient）');
      expect(happyDecoration.gradient, isNull,
          reason: '点击 甜酷 后：开心 pill 应为 inactive（gradient 应为 null）');
    });

    testWidgets('tapping scene pill updates selectedSceneId', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始：不标记 active（_selectedSceneId == null）
      // 点击 咖啡馆 场景
      await tester.tap(find.text('咖啡馆'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证 active 状态切换：通过 _Pill 的 BoxDecoration.gradient 判定
      // active → LinearGradient（非 null）；inactive → null
      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(
                  of: find.text(name),
                  matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      final cafeDecoration = pillDecorationOf('咖啡馆');
      final unmarkedDecoration = pillDecorationOf('不标记');

      expect(cafeDecoration.gradient, isA<LinearGradient>(),
          reason: '点击 咖啡馆 后：咖啡馆 pill 应为 active（gradient 应为 LinearGradient）');
      expect(unmarkedDecoration.gradient, isNull,
          reason: '点击 咖啡馆 后：不标记 pill 应为 inactive（gradient 应为 null）');
    });

    testWidgets('tapping 跳过 shows SnackBar 已跳过', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('跳过'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('已跳过'), findsOneWidget);
    });

    testWidgets(
        '对比 › press-and-hold switches ColorFilter during hold (no SnackBar)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Compare link is present
      expect(find.text('对比 ›'), findsOneWidget);

      // Tapping no longer shows the old "查看对比" SnackBar (secondary check)
      await tester.tap(find.text('对比 ›'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('查看对比'), findsNothing);

      // Press-and-hold should switch ColorFilter to the transparent
      // (reveal-original) filter DURING the hold
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('对比 ›')));
      await tester.pump(); // allow setState to propagate

      final colorFilteredDuring =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(colorFilteredDuring.colorFilter,
          const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          reason: 'compare mode should reveal original (no filter)');

      // Release — filter should revert to fromPostProcess(...) (NOT transparent)
      await gesture.up();
      await tester.pump();

      final colorFilteredAfter =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(colorFilteredAfter.colorFilter,
          isNot(const ColorFilter.mode(Colors.transparent, BlendMode.dst)),
          reason: 'release should restore the post-process filter');
    });

    testWidgets('tapping 生成对比图 shows SnackBar 生成对比图中', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('生成对比图'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('生成对比图中'), findsOneWidget);
    });

    testWidgets('tapping 生成 EXIF 卡片 shows SnackBar 生成 EXIF 卡片中',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('生成 EXIF 卡片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('生成 EXIF 卡片中'), findsOneWidget);
    });

    testWidgets(
        'tapping 保存 shows SnackBar and pops after delay',
        (tester) async {
      setLargeViewport(tester);
      // 从 home push 到 preview，使 canPop() 为 true
      final goRouter = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
          ),
          GoRoute(
            path: RouteNames.capturePreview,
            name: 'capturePreview',
            builder: (context, state) {
              final photoUrl = state.queryParams['photoUrl'];
              return CapturePreviewPage(photoUrl: photoUrl);
            },
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
        child: MaterialApp.router(routerConfig: goRouter),
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // push 到 preview 页
      goRouter.push(RouteNames.capturePreview);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(CapturePreviewPage), findsOneWidget);

      // 点击保存（mock URL 为网络图，预期显示"网络图片不支持保存到系统相册"）
      await tester.tap(find.text('保存到系统相册'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 出现
      expect(find.text('网络图片不支持保存到系统相册'), findsOneWidget);

      // 推进时间至延迟之后（_onSave 内部使用 1000ms 延迟 pop）
      await tester.pump(const Duration(milliseconds: 1100));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 已 pop：CapturePreviewPage 不存在，回到 home
      expect(find.byType(CapturePreviewPage), findsNothing);
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 路由参数
  // ============================================================
  group('CapturePreviewPage — route parameters', () {
    testWidgets('photoUrl query param is used when provided', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview?photoUrl=https%3A%2F%2Fexample.com%2Ftest.jpg',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 页面正常渲染（photoUrl 已传入）
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
      // 不应显示空态文本 "无照片数据"（photoUrl 非空）
      expect(find.text('无照片数据'), findsNothing);
    });

    testWidgets(
        'no photoUrl falls back to lastCapturedPhotoUrl (not empty)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认使用 mock URL，不应显示空态文本
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
      expect(find.text('无照片数据'), findsNothing);
    });
  });

  // ============================================================
  // 分类 4: Cross-theme/cross-style smoke（1 test，12 组合）
  // ============================================================
  group('CapturePreviewPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      // 8 主题 × 1 风格 (neumorphic) + 1 主题 (warmWhite) × 4 风格 = 12 组合
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

        // 验证关键元素渲染
        expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('今天的心情是？'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('拍摄场景'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('保存到系统相册'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        // 重置 viewport 为下一次迭代
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

/// 主题 × 风格组合（Dart 2.19 兼容：不用 record 类型）
class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

/// 占位页（用于测试 pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
