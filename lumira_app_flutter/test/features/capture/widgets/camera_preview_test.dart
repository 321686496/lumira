import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/services/camera_service.dart';
import 'package:lumira_app_flutter/features/capture/services/camera_service_provider.dart';
import 'package:lumira_app_flutter/features/capture/services/white_balance.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

// 占位相机预览（避免在测试中触发真实相机）
const _cameraPlaceholder = ColoredBox(
  key: Key('camera_placeholder'),
  color: Color(0xFF333333),
  child: SizedBox.expand(),
);

/// 测试用 spy 相机服务：记录方法调用、捕获 onTapFocus 回调以便单测点击对焦路径。
class _FakeCameraService implements CameraService {
  final List<String> calls = [];

  /// 由 buildPreview 捕获的 config.onTapFocus（真实路径中由 camerawesome 点击触发）。
  void Function(Offset, Size)? capturedOnTapFocus;

  @override
  Widget buildPreview({required CameraPreviewConfig config}) {
    capturedOnTapFocus = config.onTapFocus;
    return const ColoredBox(
      key: Key('fake_camera_preview'),
      color: Color(0xFF222222),
      child: SizedBox.expand(),
    );
  }

  @override
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize) {
    calls.add('focusOnPoint');
  }

  @override
  void setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  }) {
    calls.add('setFocusAndExposureLock:$locked');
  }

  @override
  void setZoomMultiplier(double multiplier) {
    calls.add('setZoomMultiplier');
  }

  @override
  Future<void> initialize({required String facing}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<CaptureResult> capture({required CaptureConfig config}) async =>
      throw UnimplementedError();

  @override
  Future<void> switchCamera(String facing) async {}

  @override
  Future<String?> captureFrameForAnimation() async => null;

  @override
  void setZoom(double normalized) {}

  @override
  void setFlashMode(CameraFlashMode mode) {}

  @override
  void setBrightness(double brightness) {}

  @override
  void setWhiteBalance(WhiteBalanceSettings settings) {}

  @override
  Stream<bool> get readyStream => const Stream.empty();

  @override
  Future<double> getMaxZoomMultiplier() async => 10.0;

  @override
  Future<double> getMinZoomMultiplier() async => 1.0;

  @override
  Future<bool> supportsUltraWide() async => false;
}

/// 以注入 spy 相机服务（不覆写占位预览，走真实 _PinchZoomCamera/_FocusOverlay 路径）渲染 CameraPreview。
Future<_FakeCameraService> _pumpWithFakeCamera(WidgetTester tester) async {
  final fake = _FakeCameraService();
  final container = ProviderContainer(overrides: [
    cameraServiceProvider.overrideWith((ref) => fake),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: CameraPreview()),
      ),
    ),
  );
  return fake;
}

void main() {
  group('CameraPreview', () {
    testWidgets(
        'returns override widget wrapped in ColorFiltered (default filter)',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      expect(find.byKey(const Key('camera_placeholder')), findsOneWidget);
      // Override path wraps in ColorFiltered with identity matrix by default.
      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('applies ColorFiltered when a template is selected',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      // soft_portrait is a real template in TemplateRegistry
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('does NOT apply ColorFiltered when rawMode is true',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';
      container.read(CaptureState.rawModeProvider.notifier).state = true;
      // 关闭剪影层：builtin SVG 剪影内部使用 ColorFiltered 着色，
      // 与本测试要验证的"rawMode 不套滤镜"无关，避免误报
      container.read(CaptureState.showSilhouetteProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets(
        'shows CompositionOverlay when template selected and showTemplate is true',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';
      // showTemplateProvider defaults to true

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      expect(find.byType(CompositionOverlay), findsOneWidget);
    });

    testWidgets('hides CompositionOverlay when showTemplate is false',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';
      container.read(CaptureState.showTemplateProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      expect(find.byType(CompositionOverlay), findsNothing);
    });

    testWidgets(
        'renders SilhouetteLayer with template pose when a template is selected',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: CameraPreview()),
          ),
        ),
      );

      final layer =
          tester.widget<SilhouetteLayer>(find.byType(SilhouetteLayer));
      // soft_portrait: silhouette 'soft-portrait', position (0.5, 0.45)
      expect(layer.silhouetteData, 'soft-portrait');
      expect(layer.positionX, 0.5);
      expect(layer.positionY, 0.45);
      expect(layer.scale, 1.0);
      expect(layer.rotation, 0);
    });
  });

  group('CameraPreview focus overlay & AE/AF lock', () {
    testWidgets(
        'A: tap triggers focusOnPoint and golden focus frame auto-hides',
        (tester) async {
      final fake = await _pumpWithFakeCamera(tester);

      // 模拟相机层点击对焦（真实路径：camerawesome onPreviewTap → config.onTapFocus）
      fake.capturedOnTapFocus!(const Offset(200, 200), const Size(800, 600));
      await tester.pump();

      // 金色对焦框出现，且相机对焦被调用
      expect(find.byKey(const Key('focus_frame')), findsOneWidget);
      expect(fake.calls, contains('focusOnPoint'));

      // 1.5s 后自动消失
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('focus_frame')), findsNothing);
    });

    testWidgets('B: long-press locks AE/AF and shows persistent lock badge',
        (tester) async {
      final fake = await _pumpWithFakeCamera(tester);

      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 600)); // 超过 500ms 长按阈值
      await gesture.up();
      await tester.pump();

      expect(fake.calls, contains('setFocusAndExposureLock:true'));
      expect(find.byKey(const Key('focus_lock_badge')), findsOneWidget);
      // 锁定常驻，抬手后标签不消失
      expect(find.byKey(const Key('focus_frame')), findsOneWidget);
    });

    testWidgets(
        'C: tap while locked unlocks first then refocuses on new point',
        (tester) async {
      final fake = await _pumpWithFakeCamera(tester);

      // 先长按进入锁定态
      final gesture = await tester.startGesture(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('focus_lock_badge')), findsOneWidget);

      // 锁定态下点击其他位置 → 先解锁（setFocusAndExposureLock(false)）再重新对焦
      fake.calls.clear();
      fake.capturedOnTapFocus!(const Offset(500, 200), const Size(800, 600));
      await tester.pump();

      expect(fake.calls, ['setFocusAndExposureLock:false', 'focusOnPoint']);
      // 解锁后锁定标签消失（对焦框为新触点重新出现）
      expect(find.byKey(const Key('focus_lock_badge')), findsNothing);
      expect(find.byKey(const Key('focus_frame')), findsOneWidget);
    });

    testWidgets('D: pinch still drives setZoomMultiplier (zoom regression)',
        (tester) async {
      final fake = await _pumpWithFakeCamera(tester);

      final g1 = await tester.startGesture(const Offset(200, 300));
      final g2 = await tester.startGesture(const Offset(600, 300));
      await tester.pump();
      // 双指张开（放大）
      await g1.moveBy(const Offset(-80, 0));
      await g2.moveBy(const Offset(80, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      expect(fake.calls, contains('setZoomMultiplier'));
    });
  });
}
