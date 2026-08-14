import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_page.dart';
// Forced fix: brief 漏写以下 3 个 import，但测试用例中使用了 CaptureButton /
// CaptureNav 类型与 cameraPreviewOverrideProvider
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_button.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_nav.dart';
// Task 13: 集成测试新增 import —— 验证所有 widget 都在 widget tree 中
import 'package:lumira_app_flutter/features/capture/widgets/filter_picker.dart';
import 'package:lumira_app_flutter/features/capture/widgets/level_indicator.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_pill_bar.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_strip.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    // TemplateStrip/ScenePresetStrip use Image.network(picsum.photos) for covers.
    // Mock HTTP to avoid NetworkImageLoadException in tests.
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
    // Mock permission_handler method channel so Permission.camera.request()
    // does not throw MissingPluginException under tester.runAsync.
    // Returns granted (1) so CapturePage renders its full capture UI instead
    // of _CameraPermissionGuide. Without this, the page is stuck on the
    // permission guide and all capture UI assertions fail.
    const permChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(permChannel, (MethodCall call) async {
      if (call.method == 'requestPermissions') {
        final permissions = call.arguments as List;
        // 1 = PermissionStatus.granted for all requested permissions
        return {for (final p in permissions) p: 1};
      }
      if (call.method == 'checkPermissionStatus' ||
          call.method == 'shouldShowRequestPermissionRationale') {
        // 1 = granted; for shouldShowRationale, returns int bool 1 (true)
        return 1;
      }
      return null;
    });
    router = GoRouter(
      initialLocation: '/capture',
      routes: [
        // Forced fix: brief 漏写 /home 路由，导致 'back button pops the capture
        // page' 测试中 `router.go('/home')` 进入未知路由错误状态，后续
        // `router.push('/capture')` 无法正确压栈。补 /home 占位路由。
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/capture',
          name: 'capture',
          builder: (_, state) {
            final templateId = state.queryParams['templateId'];
            return CapturePage(templateId: templateId);
          },
        ),
        GoRoute(
          path: '/capture/preview',
          name: 'capturePreview',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('preview'))),
        ),
        GoRoute(
          path: '/capture/scene-guide',
          name: 'captureSceneGuide',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('scene-guide'))),
        ),
      ],
    );
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
    const permChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(permChannel, null);
  });

  Widget wrap(
    ThemeKey themeKey,
    UIStyle uiStyle, {
    Widget? cameraOverride,
  }) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        if (cameraOverride != null)
          cameraPreviewOverrideProvider.overrideWith((ref) => cameraOverride),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // 占位相机预览（避免在测试中触发真实相机）
  const cameraPlaceholder = ColoredBox(
    key: Key('camera_placeholder'),
    color: Color(0xFF333333),
    child: SizedBox.expand(),
  );

  /// Pump that allows CapturePage's async _requestCameraPermission() to
  /// complete by pumping inside tester.runAsync (FakeAsync otherwise blocks
  /// platform channel calls). After permission is granted, settles normally.
  /// For UIStyle.female, uses a bounded pump because some animations never
  /// settle.
  Future<void> pumpWithPermission(
    WidgetTester tester, {
    UIStyle? style,
  }) async {
    // First pump triggers addPostFrameCallback which invokes
    // _requestCameraPermission() (async, fire-and-forget).
    await tester.pump();
    // runAsync lets the platform channel permission request complete.
    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 100));
    });
    // Render the post-permission state (permission granted).
    await tester.pump();
    // Settle any remaining animations.
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders capture page with camera placeholder', (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    expect(find.byType(CapturePage), findsOneWidget);
    expect(find.byKey(const Key('camera_placeholder')), findsOneWidget);
    expect(find.text('自由调参'), findsOneWidget);
    expect(find.byType(CaptureButton), findsOneWidget);
  });

  testWidgets('shows template title when templateId provided', (tester) async {
    router.go('/capture?templateId=tpl_123');
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    expect(find.text('模板拍摄'), findsOneWidget);
    expect(find.text('点击调整参数'), findsOneWidget);
    // 模板叠图 / 剪影显隐按钮应出现
    expect(find.byIcon(Icons.crop_free), findsOneWidget);
    expect(find.byIcon(Icons.accessibility_new), findsOneWidget);
  });

  testWidgets('does not show template/silhouette toggles in free mode',
      (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    expect(find.byIcon(Icons.crop_free), findsNothing);
    expect(find.byIcon(Icons.accessibility_new), findsNothing);
  });

  testWidgets('flash button toggles flash mode', (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    // 初始 off
    expect(find.byIcon(Icons.flash_off), findsOneWidget);

    // 点击切换为 torch
    await tester.tap(find.byIcon(Icons.flash_off));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.flashlight_on), findsOneWidget);
  });

  testWidgets('fullscreen button toggles isFullscreen state', (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    // 初始非全屏：CaptureNav 可见
    expect(find.byType(CaptureNav), findsOneWidget);
    expect(find.text('自由调参'), findsOneWidget);

    // 点击全屏按钮
    // 用 descendant 限定到 CaptureNav 内的全屏切换按钮；
    // AspectRatioSelector 也用 Icons.fullscreen 作为"全屏"比例选项的图标，
    // 直接 find.byIcon 会找到两个，tap() 会因歧义报错。
    await tester.tap(find.descendant(
      of: find.byType(CaptureNav),
      matching: find.byIcon(Icons.fullscreen),
    ));
    await tester.pumpAndSettle();

    // 修复 Bug 10：全屏后 CaptureNav 仍然显示（含退出全屏按钮），
    // 确保用户可以退出全屏。装饰性内容（ParamPillBar、模板条）会隐藏。
    expect(find.byType(CaptureNav), findsOneWidget);
    // 退出全屏按钮可见
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

    // 点击退出全屏按钮
    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pumpAndSettle();

    // 退出全屏后：恢复全屏按钮图标（限定到 CaptureNav 内，
    // AspectRatioSelector 中也有一个 Icons.fullscreen 图标）
    expect(
      find.descendant(
        of: find.byType(CaptureNav),
        matching: find.byIcon(Icons.fullscreen),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(
        wrap(ThemeKey.warmWhite, style, cameraOverride: cameraPlaceholder),
      );
      await pumpWithPermission(tester, style: style);

      expect(find.byType(CapturePage), findsOneWidget);
      expect(find.byKey(const Key('camera_placeholder')), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(
        wrap(theme, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
      );
      await pumpWithPermission(tester);

      expect(find.byType(CapturePage), findsOneWidget);
      expect(find.byKey(const Key('camera_placeholder')), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('back button pops the capture page', (tester) async {
    router.go('/home');
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    // 导航到 capture
    router.push('/capture');
    await tester.pumpAndSettle();

    expect(find.byType(CapturePage), findsOneWidget);

    // 点击返回
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // 应返回 home（_PlaceholderPage 或 HomePage）
    expect(find.byType(CapturePage), findsNothing);
  });

  testWidgets('camera switch button toggles facing', (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CapturePage)),
    );

    expect(container.read(CaptureState.cameraFacingProvider), 'back');

    await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
    await tester.pumpAndSettle();

    expect(container.read(CaptureState.cameraFacingProvider), 'front');
  });

  // ── Task 13 集成测试 ──

  testWidgets('renders all integration widgets', (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    expect(find.byType(ParamPillBar), findsOneWidget);
    // 默认抽屉收起，TemplateStrip 不渲染；展开后才会渲染
    expect(find.byType(ParamPanel), findsOneWidget);
    // FilterPicker 仅在 activeTool == 'filter' 时由 _AnimatedToolDrawer 渲染，
    // 默认 activeTool=null，故不在 widget tree 中
    expect(find.byType(FilterPicker), findsNothing);
    expect(find.byType(LevelIndicator), findsOneWidget);
  });

  testWidgets('capture toolbar shows 4 tools on back camera (fillLight is front-only)',
      (tester) async {
    await tester.pumpWidget(
      wrap(ThemeKey.warmWhite, UIStyle.neumorphic, cameraOverride: cameraPlaceholder),
    );
    await pumpWithPermission(tester);

    // 默认后置摄像头：工具栏含 4 个工具（模板/场景/参数/滤镜），补光仅前摄显示
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget); // 模板
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget); // 场景
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget); // 滤镜
    expect(find.text('参数'), findsOneWidget); // 参数 tab 文字
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing); // 后置无补光
  });

}
