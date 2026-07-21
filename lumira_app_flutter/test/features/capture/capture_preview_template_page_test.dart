import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_template_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.9A — CapturePreviewTemplatePage 测试
///
/// 覆盖 brief §5.4 ≥10 项断言 + cross-theme/cross-style smoke test。
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
    String initialLocation = '/capture/preview-template',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.capturePreviewTemplate,
          name: 'capturePreviewTemplate',
          builder: (context, state) {
            final templateId = state.queryParams[RouteNames.paramTemplateId];
            final draftId = state.queryParams['draftId'];
            return CapturePreviewTemplatePage(
              templateId: templateId,
              draftId: draftId,
            );
          },
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.templates,
          name: 'templates',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATES_PAGE'))),
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
        // Bug 12 修复：用占位 widget 替换 CameraAwesomeBuilder，
        // 避免 camera 预览持续渲染导致 pumpAndSettle 超时
        cameraPreviewOverrideProvider.overrideWithValue(
          const ColoredBox(
            color: Color(0xFF181614),
            child: SizedBox.expand(),
          ),
        ),
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
  // 分类 1: 路由参数加载（3 tests）
  // ============================================================
  group('CapturePreviewTemplatePage — route parameter loading', () {
    testWidgets('loads template by templateId and renders nav title',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // existingTemplateForm.meta.name = '咖啡馆人像'
      expect(find.text('咖啡馆人像'), findsOneWidget);
      // 副标题：分类 · aspectRatio（人像 · 3:4）
      expect(find.textContaining('3:4'), findsOneWidget);
    });

    testWidgets('loads draft by draftId and renders nav title', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/preview-template?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // draftForm.meta.name = '咖啡馆人像草稿'
      expect(find.text('咖啡馆人像草稿'), findsOneWidget);
    });

    testWidgets(
        'invalid templateId shows 模板加载失败 SnackBar and pops after 1000ms',
        (tester) async {
      setLargeViewport(tester);
      // 从 home push 到 preview-template，使 canPop() 为 true
      final goRouter = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
          ),
          GoRoute(
            path: RouteNames.capturePreviewTemplate,
            name: 'capturePreviewTemplate',
            builder: (context, state) {
              final templateId = state.queryParams[RouteNames.paramTemplateId];
              final draftId = state.queryParams['draftId'];
              return CapturePreviewTemplatePage(
                templateId: templateId,
                draftId: draftId,
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          // Bug 12 修复：用占位 widget 替换 CameraAwesomeBuilder，避免 pumpAndSettle 超时
          cameraPreviewOverrideProvider.overrideWithValue(
            const ColoredBox(
              color: Color(0xFF181614),
              child: SizedBox.expand(),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: goRouter),
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // push 到 preview-template 页（无效 templateId）
      goRouter.push(
          '/capture/preview-template?${RouteNames.paramTemplateId}=nonexistent-id');
      // 加载失败路径用 addPostFrameCallback + Future.delayed(1000ms)
      await tester.pump();
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 模板加载失败 出现
      expect(find.text('模板加载失败'), findsOneWidget);

      // 推进时间至 1000ms 之后
      await tester.pump(const Duration(milliseconds: 1100));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 已 pop：CapturePreviewTemplatePage 不存在，回到 home
      expect(find.byType(CapturePreviewTemplatePage), findsNothing);
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 基本渲染（3 tests）
  // ============================================================
  group('CapturePreviewTemplatePage — basic rendering', () {
    testWidgets('renders 4 param pills (EV/ISO/SS/WB)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个 pill 标签
      expect(find.text('EV'), findsOneWidget);
      expect(find.text('ISO'), findsOneWidget);
      expect(find.text('SS'), findsOneWidget);
      expect(find.text('WB'), findsOneWidget);
    });

    testWidgets('renders sync button 同步调整到编辑器', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('同步调整到编辑器'), findsOneWidget);
    });

    testWidgets('renders panel header 参数调整 with collapsed state',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('参数调整'), findsOneWidget);
      expect(find.text('实时调整模板参数'), findsOneWidget);
      // 折叠态：键盘箭头朝上（Icons.keyboard_arrow_up）
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 交互（5 tests）
  // ============================================================
  group('CapturePreviewTemplatePage — interactions', () {
    testWidgets('tapping flash toggle changes flashOn state', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始：flash_off
      expect(find.byIcon(Icons.flash_off), findsOneWidget);

      // 点击闪光灯按钮
      await tester.tap(find.byIcon(Icons.flash_off));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换为 flash_on
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('tapping panel header toggles panelExpanded', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 折叠态：键盘箭头朝上
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      // 折叠态：参数调整区段标题（构图 / 相机参数 / 后期调色）不存在
      expect(find.text('构图'), findsNothing);
      expect(find.text('相机参数'), findsNothing);

      // 点击面板标题展开
      await tester.tap(find.text('参数调整'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 展开态：键盘箭头朝下
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      // 展开态：3 个区段标题出现
      expect(find.text('构图'), findsOneWidget);
      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('后期调色'), findsOneWidget);
    });

    testWidgets(
        'expanded panel renders 11 sliders (opacity/EV/ISO/WBK/brightness/contrast/saturation/temperature/smooth/sharpen/vignette)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 展开面板
      await tester.tap(find.text('参数调整'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 11 个 slider 行的 label
      // 构图区
      expect(find.text('叠图透明度'), findsOneWidget);
      // 相机参数区
      expect(find.text('曝光补偿'), findsOneWidget);
      // 'ISO' 同时出现在参数 pill 栏（top）和 slider row label
      expect(find.text('ISO'), findsNWidgets(2));
      expect(find.text('色温 K'), findsOneWidget);
      // 后期调色区
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('对比度'), findsOneWidget);
      expect(find.text('饱和度'), findsOneWidget);
      expect(find.text('色温'), findsOneWidget);
      expect(find.text('磨皮'), findsOneWidget);
      expect(find.text('锐化'), findsOneWidget);
      expect(find.text('暗角'), findsOneWidget);

      // 至少 8 个 slider（实际 11 个）
      expect(find.byType(Slider), findsNWidgets(11));
    });

    testWidgets(
        'expanded panel renders 4 seg-btn groups (WB/Flash/Focus/LUT)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 展开面板
      await tester.tap(find.text('参数调整'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个 seg-btn 组的 label
      expect(find.text('白平衡'), findsOneWidget);
      expect(find.text('闪光'), findsOneWidget);
      expect(find.text('对焦'), findsOneWidget);
      expect(find.text('LUT 预设'), findsOneWidget);

      // 验证部分 seg-btn 选项存在
      // WB 选项
      expect(find.text('日光'), findsOneWidget);
      // Flash 选项
      expect(find.text('关'), findsOneWidget);
      // '自动' 同时出现在 Flash 和 Focus seg-btn 组（两者都有 value='auto' → label='自动'）
      expect(find.text('自动'), findsNWidgets(2));
      // LUT 选项
      expect(find.text('原图'), findsOneWidget);
      expect(find.text('电影感'), findsOneWidget);
    });

    testWidgets(
        'tapping 同步调整到编辑器 shows SnackBar 已同步到编辑器 and pops after 800ms',
        (tester) async {
      setLargeViewport(tester);
      // 从 home push 到 preview-template，使 canPop() 为 true
      final goRouter = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
          ),
          GoRoute(
            path: RouteNames.capturePreviewTemplate,
            name: 'capturePreviewTemplate',
            builder: (context, state) {
              final templateId = state.queryParams[RouteNames.paramTemplateId];
              final draftId = state.queryParams['draftId'];
              return CapturePreviewTemplatePage(
                templateId: templateId,
                draftId: draftId,
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          // Bug 12 修复：用占位 widget 替换 CameraAwesomeBuilder，避免 pumpAndSettle 超时
          cameraPreviewOverrideProvider.overrideWithValue(
            const ColoredBox(
              color: Color(0xFF181614),
              child: SizedBox.expand(),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: goRouter),
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // push 到 preview-template 页（带 templateId）
      goRouter.push(
          '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait');
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(CapturePreviewTemplatePage), findsOneWidget);

      // 点击同步按钮
      await tester.tap(find.text('同步调整到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 已同步到编辑器 出现
      expect(find.text('已同步到编辑器'), findsOneWidget);

      // 推进时间至 800ms 之后
      await tester.pump(const Duration(milliseconds: 900));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 已 pop：CapturePreviewTemplatePage 不存在，回到 home
      expect(find.byType(CapturePreviewTemplatePage), findsNothing);
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 剪影拖动（1 test）
  // ============================================================
  group('CapturePreviewTemplatePage — silhouette dragging', () {
    testWidgets('dragging silhouette updates pose position without error',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 模板有 builtin silhouette 'sitting-cafe'（hasSilhouette = true）
      // 拖动提示应可见
      expect(find.text('拖动调整剪影位置'), findsOneWidget);

      // 在取景器中心拖动剪影（剪影 GestureDetector 覆盖整个 AspectRatio 区域）
      // 使用 dragFrom 从 viewfinder 中心点开始拖动
      final viewfinderCenter = tester.getCenter(find.byType(AspectRatio));
      await tester.dragFrom(viewfinderCenter, const Offset(50, 50));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：拖动后页面仍正常渲染（无异常）
      expect(find.text('咖啡馆人像'), findsOneWidget);
      expect(find.text('同步调整到编辑器'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 5: Cross-theme/cross-style smoke（1 test，12 组合）
  // ============================================================
  group('CapturePreviewTemplatePage — smoke tests', () {
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
        await tester.pumpWidget(wrap(
          themeKey: combo.theme,
          uiStyle: combo.style,
          initialLocation:
              '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
        ));
        await settleOrPump(tester, combo.style);

        // 验证关键元素渲染
        expect(find.text('咖啡馆人像'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('同步调整到编辑器'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('参数调整'), findsOneWidget,
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
