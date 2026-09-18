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
import 'package:lumira_app_flutter/features/capture/services/white_balance.dart';
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

  /// 从 /home push 进入预览页，返回页面所在 ProviderContainer（用于直接写 provider
  /// 模拟用户调整 + 读取回写结果）。
  Future<ProviderContainer> openPreviewAndGetContainer(
    WidgetTester tester,
  ) async {
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

    return ProviderScope.containerOf(
      tester.element(find.byType(CapturePreviewTemplatePage)),
      listen: false,
    );
  }

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
      // 参数 pill 栏（EV；参数面板提示文案也含 "EV"，故只需 ≥1）
      expect(find.textContaining('EV'), findsWidgets);
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
      expect(find.byType(ParamPanel), findsNothing);
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

    testWidgets('tapping 参数 tool opens ParamPanel toolbar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('参数'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ParamPanel 工具条展开：曝光/白平衡/闪光/色彩/细节/构图/场景
      // （"场景" 也出现在底部工具栏按钮，故限定在 ParamPanel 内查找）
      final inPanel = (String t) =>
          find.descendant(of: find.byType(ParamPanel), matching: find.text(t));
      expect(inPanel('曝光'), findsOneWidget);
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
  // 分类 5: 松散会话参数（比例/前后置/闪光灯/白平衡/补光）同步写回
  // ============================================================
  group('CapturePreviewTemplatePage — session params sync write-back', () {
    testWidgets('aspect ratio change syncs to composition.aspectRatio and cropRatio',
        (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 模拟用户在预览页切换比例（写 aspectRatioProvider，与 CaptureTopPillBar 一致）
      container.read(CaptureState.aspectRatioProvider.notifier).state = '1:1';

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.byType(CapturePreviewTemplatePage), findsNothing);

      final merged = container.read(previewEditorFormProvider);
      expect(merged, isNotNull);
      expect(merged!.composition.aspectRatio, '1:1');
      expect(merged.postProcess.cropRatio, '1:1');
    });

    testWidgets('flash mode change syncs to camera.flashMode', (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 模拟用户开启常亮闪光（写 flashModeProvider，与顶部导航切换一致）
      container
          .read(CaptureState.flashModeProvider.notifier)
          .state = CaptureFlashMode.torch;

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      final merged = container.read(previewEditorFormProvider);
      expect(merged!.camera.flashMode, 'torch');
    });

    testWidgets('white balance change syncs mode and temperatureK',
        (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 模拟用户把白平衡从 daylight 切到 cloudy（写 whiteBalanceSessionProvider）
      container.read(whiteBalanceSessionProvider.notifier).state =
          const WhiteBalanceSettings(
        mode: WhiteBalanceMode.cloudy,
        temperatureK: 6500,
      );

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      final merged = container.read(previewEditorFormProvider);
      expect(merged!.camera.whiteBalance, 'cloudy');
      expect(merged.camera.whiteBalanceK, 6500);
    });

    testWidgets('fill light enable syncs color and intensity', (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 模拟用户在预览页开启补光并调色/调强度
      container.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
      container.read(CaptureState.fillLightColorProvider.notifier).state =
          const Color(0xFFFFB3C1);
      container
          .read(CaptureState.fillLightIntensityProvider.notifier)
          .state = 1.0;

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      final merged = container.read(previewEditorFormProvider);
      expect(merged!.fillLight, isNotNull);
      expect(merged.fillLight!.enabled, isTrue);
      expect(merged.fillLight!.color, 0xFFFFB3C1);
      expect(merged.fillLight!.intensity, 1.0);
    });

    testWidgets('manual camera switch syncs current pose cameraDirection',
        (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 点击底部工具栏的摄像头切换按钮（走页面 _switchCamera，记录手动切换）
      await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(container.read(CaptureState.cameraFacingProvider), 'front');

      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      final merged = container.read(previewEditorFormProvider);
      expect(merged!.poses, isNotEmpty);
      expect(merged.poses.first.cameraDirection, 'front');
    });

    testWidgets('sync without touching keeps template baseline values',
        (tester) async {
      final container = await openPreviewAndGetContainer(tester);

      // 不做任何调整直接同步：比例/闪光/白平衡应保持表单原值
      await tester.tap(find.text('同步到编辑器'));
      await settleOrPump(tester, UIStyle.neumorphic);

      final merged = container.read(previewEditorFormProvider);
      expect(merged, isNotNull);
      expect(merged!.camera.whiteBalance, 'daylight');
      expect(merged.camera.whiteBalanceK, 5500);
      expect(merged.camera.flashMode, 'off');
      expect(merged.composition.aspectRatio, '3:4');
      expect(merged.postProcess.cropRatio, '3:4');
      // 姿势方向未被手动切换 → 保持表单原值（null）
      expect(merged.poses.first.cameraDirection, isNull);
    });
  });

  // ============================================================
  // 分类 6: Cross-theme/cross-style smoke
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
