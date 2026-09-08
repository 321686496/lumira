import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_template_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_bottom_controls.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_nav.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';
import 'package:lumira_app_flutter/features/templates/data/preview_form_provider.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// CapturePreviewTemplatePage 测试（对齐拍摄页改造后）
///
/// 预览页已复用拍摄页公共组件（CaptureNav / ParamPanel / CaptureBottomBar /
/// ParamPillBar / CapturePoseSwitchButton），故断言以共享组件 + 「完成」写回为主。
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
        // 用占位 widget 替换 CameraAwesomeBuilder，避免 camera 预览持续渲染导致 pumpAndSettle 超时
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

  const tplQuery =
      '/capture/preview-template?${RouteNames.paramTemplateId}=tpl-cafe-portrait';

  // ============================================================
  // 分类 1: 路由参数加载
  // ============================================================
  group('CapturePreviewTemplatePage — route parameter loading', () {
    testWidgets('loads template by templateId and renders capture nav + pills',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 桥接生效后 currentTemplateIdProvider 非空 → CaptureNav 显示「模板拍摄」
      expect(find.text('模板拍摄'), findsOneWidget);
      // 参数 pill 栏（EV / ISO；参数面板提示文案也含 "EV"，故只需 ≥1）
      expect(find.textContaining('EV'), findsWidgets);
      expect(find.textContaining('ISO'), findsWidgets);
    });

    testWidgets('loads draft by draftId', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/preview-template?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板拍摄'), findsOneWidget);
      expect(find.textContaining('EV'), findsWidgets);
    });

    testWidgets(
        'invalid templateId shows 模板加载失败 SnackBar and pops after 1000ms',
        (tester) async {
      setLargeViewport(tester);
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

      goRouter.push(
          '/capture/preview-template?${RouteNames.paramTemplateId}=nonexistent-id');
      await tester.pump();
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板加载失败'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1100));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(CapturePreviewTemplatePage), findsNothing);
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 基本渲染（共享拍摄组件）
  // ============================================================
  group('CapturePreviewTemplatePage — basic rendering', () {
    testWidgets('renders shared capture components (nav / param panel / bottom bar)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(CaptureNav), findsOneWidget);
      expect(find.byType(ParamPanel), findsOneWidget);
      expect(find.byType(CaptureBottomBar), findsOneWidget);
      // 底部工具栏出现（模板/场景/参数/滤镜）
      expect(find.text('参数'), findsOneWidget);
      expect(find.text('滤镜'), findsOneWidget);
    });

    testWidgets('renders 同步到编辑器 confirm capsule', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('同步到编辑器'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 交互
  // ============================================================
  group('CapturePreviewTemplatePage — interactions', () {
    testWidgets('nav flash toggle cycles flash mode', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始：后置摄像头 → flash_off
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      await tester.tap(find.byIcon(Icons.flash_off));
      await settleOrPump(tester, UIStyle.neumorphic);
      // 点击后变为 torch → flashlight_on
      expect(find.byIcon(Icons.flashlight_on), findsOneWidget);
    });

    testWidgets('tapping 参数 tool opens ParamPanel with 5 tabs', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('参数'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ParamPanel Tab 栏展开：相机 / 色彩 / 细节 / 构图 / 场景
      // （"场景" 也出现在底部工具栏按钮，故限定在 ParamPanel 内查找）
      final inPanel = (String t) =>
          find.descendant(of: find.byType(ParamPanel), matching: find.text(t));
      expect(inPanel('相机'), findsOneWidget);
      expect(inPanel('色彩'), findsOneWidget);
      expect(inPanel('构图'), findsOneWidget);
      expect(inPanel('场景'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 同步写回 EditorForm（meta 不变）
  // ============================================================
  group('CapturePreviewTemplatePage — sync write-back', () {
    testWidgets('tapping 同步到编辑器 writes back to previewEditorFormProvider and pops',
        (tester) async {
      setLargeViewport(tester);
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

      goRouter.push(tplQuery);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.byType(CapturePreviewTemplatePage), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CapturePreviewTemplatePage)),
        listen: false,
      );

      // 模拟用户在拍摄页调整参数（EV +1.0），写入 editableTemplateProvider；
      // 预览页点击「同步到编辑器」后应把该改动合并回 EditorForm。
      final editable = container.read(CaptureState.editableTemplateProvider);
      expect(editable, isNotNull);
      container.read(CaptureState.editableTemplateProvider.notifier).state =
          editable!.copyWith(
        camera: editable.camera.copyWith(exposureCompensation: 1.0),
      );

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 已 pop：回到 home
      expect(find.byType(CapturePreviewTemplatePage), findsNothing);
      expect(find.text('HOME_PAGE'), findsOneWidget);

      // 写回：previewEditorFormProvider 非空，且 meta.name 保持不变
      final merged = container.read(previewEditorFormProvider);
      expect(merged, isNotNull);
      expect(merged!.meta.name, '咖啡馆人像');
      // 参数改动已写回 EditorForm（EV 由用户调整为 +1.0）
      expect(merged.camera.exposureCompensation, 1.0);
    });
  });

  // ============================================================
  // 分类 5: Cross-theme/cross-style smoke
  // ============================================================
  group('CapturePreviewTemplatePage — smoke tests', () {
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
          initialLocation: tplQuery,
        ));
        await settleOrPump(tester, combo.style);

        expect(find.text('模板拍摄'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('同步到编辑器'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.byType(ParamPanel), findsOneWidget,
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

/// 占位页（用于测试 pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}