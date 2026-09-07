import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/compare_photo_button.dart';
import 'package:lumira_app_flutter/shared/widgets/common/lumira_surface.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// 拍摄预览页改版后测试：底部工具条 + 滑出面板 + 右上角对比按钮 + pill 行。
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
    EdgeInsets pageInsets = EdgeInsets.zero,
  }) {
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
            Widget page = CapturePreviewPage(photoUrl: photoUrl);
            // 模拟真机系统 inset（状态栏 / 手势导航 home 指示条）：
            // 注入非零 MediaQuery.padding 到预览页子树（测试视口默认零 inset，
            // 真机上 SafeArea 依赖此值避开系统栏）。
            if (pageInsets != EdgeInsets.zero) {
              page = MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: pageInsets),
                child: page,
              );
            }
            return page;
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        CaptureState.aspectRatioProvider.overrideWith((ref) => '1:1'),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> openPreview(WidgetTester tester,
      {UIStyle style = UIStyle.neumorphic,
      EdgeInsets pageInsets = EdgeInsets.zero}) async {
    await tester.pumpWidget(wrap(
      themeKey: ThemeKey.warmWhite,
      uiStyle: style,
      pageInsets: pageInsets,
    ));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('HOME_PAGE')))
        .push(RouteNames.capturePreview);
    await tester.pumpAndSettle();
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 基本渲染（无抽屉，工具条/pill 行直接可见）
  // ============================================================
  group('CapturePreviewPage — basic rendering', () {
    testWidgets('renders nav with title and new action icons', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      // 顶栏新增：删除、保存到系统相册；保留：分享
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    });

    testWidgets('renders 5 tool bar items', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.text('色彩'), findsOneWidget);
      expect(find.text('细节'), findsOneWidget);
      expect(find.text('滤镜'), findsOneWidget);
      expect(find.text('裁剪'), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);
    });

    testWidgets('renders mood and scene pills immediately (no drawer)',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      // 心情 pill
      expect(find.text('开心'), findsOneWidget);
      expect(find.text('甜酷'), findsOneWidget);
      // 场景 pill + 不标记
      expect(find.text('不标记'), findsOneWidget);
      expect(find.text('咖啡馆'), findsOneWidget);
    });

    testWidgets('renders compare button on photo (top-right)', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.byType(ComparePhotoButton), findsOneWidget);
    });

    testWidgets(
        'real-device insets: compare button below nav, dock above home indicator',
        (tester) async {
      setLargeViewport(tester);
      // 模拟真机 inset（iOS 手势导航：状态栏 44 + home 指示条 34）；
      // 测试视口默认零 inset 时布局与真机不同，需显式注入才能复现重叠/遮挡问题。
      await openPreview(tester,
          pageInsets: const EdgeInsets.fromLTRB(0, 44, 0, 34));

      // 1) 对比按钮整体位于顶栏下方（不与右侧 删除/保存/分享 图标区域重叠）
      final navRect = tester.getRect(find.widgetWithText(LumiraNav, '照片预览'));
      final compareRect = tester.getRect(find.byType(ComparePhotoButton));
      expect(compareRect.top, greaterThanOrEqualTo(navRect.bottom),
          reason: '对比按钮应位于顶栏之下（含状态栏 inset）');

      // 2) 底部编辑 dock 下缘避开系统 home 指示条（bottom inset 之上）
      final dockRect = tester.getRect(find.byType(LumiraSurface));
      expect(dockRect.bottom, lessThanOrEqualTo(2400.0 - 34.0),
          reason: 'dock 应避开底部安全区（home 指示条）');
    });

    testWidgets('no floating button group / no drawer handle', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      // 旧悬浮组「编辑」按钮与抽屉拖拽条已删除
      expect(find.text('编辑'), findsNothing);
      expect(find.byKey(const ValueKey('sheet_handle')), findsNothing);
      expect(find.text('保存到相册'), findsNothing); // 顶栏用图标替代
    });
  });

  // ============================================================
  // 分类 2: 交互
  // ============================================================
  group('CapturePreviewPage — interactions', () {
    testWidgets('tapping mood pill activates it, tapping again deactivates',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(of: find.text(name), matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      await tester.tap(find.text('甜酷'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('甜酷').gradient, isA<LinearGradient>());

      // 再点一次 = 取消（等同旧「跳过」）
      await tester.tap(find.text('甜酷'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('甜酷').gradient, isNull);
    });

    testWidgets('tapping scene pill activates it', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      BoxDecoration pillDecorationOf(String name) {
        final container = tester.widget<Container>(
          find.ancestor(of: find.text(name), matching: find.byType(Container))
              .first,
        );
        return container.decoration as BoxDecoration;
      }

      await tester.tap(find.text('咖啡馆'));
      await tester.pumpAndSettle();
      expect(pillDecorationOf('咖啡馆').gradient, isA<LinearGradient>());
      expect(pillDecorationOf('不标记').gradient, isNull);
    });

    testWidgets('compare button toggles ColorFilter on/off', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      // 初始：非透明滤镜（应用后期参数）
      final colorFilteredBefore =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredBefore.colorFilter,
          isNot(const ColorFilter.mode(Colors.transparent, BlendMode.dst)));

      // 点击对比按钮 → 显示修改前（透明滤镜 = 无后期）
      await tester.tap(find.byType(ComparePhotoButton));
      await tester.pumpAndSettle();
      final colorFilteredDuring =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredDuring.colorFilter,
          const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          reason: '对比模式应显示修改前（无滤镜）');
      // 对比状态徽标短暂显示
      expect(find.text('查看修改前'), findsOneWidget);

      // 再点一次 → 恢复修改后
      await tester.tap(find.byType(ComparePhotoButton));
      await tester.pumpAndSettle();
      final colorFilteredAfter =
          tester.widget<ColorFiltered>(find.byType(ColorFiltered).first);
      expect(colorFilteredAfter.colorFilter,
          isNot(const ColorFilter.mode(Colors.transparent, BlendMode.dst)));
    });

    testWidgets('tool tap opens panel, photo tap closes it', (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      await tester.tap(find.text('色彩'));
      await tester.pumpAndSettle();
      // 色彩面板包含「调节项 chip 行」与「滑块行」两处 亮度 文本
      expect(find.text('亮度'), findsWidgets);

      // 点击照片区（PhotoView 中下部，避开顶栏/对比按钮/dock）
      final photoRect = tester.getRect(find.byType(PhotoView).first);
      await tester.tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      // PhotoView 同时注册单击/双击手势：单击需等双击窗口（300ms）超时才触发
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('亮度'), findsNothing);
    });

    testWidgets('photo tap toggles pure mode (hides nav and dock)',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);

      final photoRect = tester.getRect(find.byType(PhotoView).first);
      await tester
          .tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      // PhotoView 同时注册单击/双击手势：单击需等双击窗口（300ms）超时才触发
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      // 纯净模式：导航、工具条、pill 行、对比按钮全部隐藏
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsNothing);
      expect(find.text('色彩'), findsNothing);
      expect(find.text('不标记'), findsNothing);
      expect(find.byType(ComparePhotoButton), findsNothing);

      await tester
          .tapAt(Offset(photoRect.center.dx, photoRect.center.dy + 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget);
    });

    testWidgets('share sheet contains 生成对比图 and EXIF 海报',
        (tester) async {
      setLargeViewport(tester);
      await openPreview(tester);

      await tester.tap(find.byIcon(Icons.ios_share_outlined));
      await tester.pumpAndSettle();
      expect(find.text('分享到系统'), findsOneWidget);
      expect(find.text('生成对比图'), findsOneWidget);
      expect(find.text('生成 EXIF 海报'), findsOneWidget);
      expect(find.text('保存到相册'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: smoke（8 主题 × 4 风格，无需展开抽屉）
  // ============================================================
  group('CapturePreviewPage — smoke tests', () {
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
        await tester.pumpWidget(wrap(
          themeKey: combo.theme,
          uiStyle: combo.style,
        ));
        await tester.pumpAndSettle();
        if (combo.style == UIStyle.female) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        GoRouter.of(tester.element(find.text('HOME_PAGE')))
            .push(RouteNames.capturePreview);
        await tester.pumpAndSettle();
        if (combo.style == UIStyle.female) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        expect(find.widgetWithText(LumiraNav, '照片预览'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('色彩'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('不标记'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
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

/// 占位页（用于测试 push/pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
