import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

// 占位相机预览（避免在测试中触发真实相机）
const _cameraPlaceholder = ColoredBox(
  key: Key('camera_placeholder'),
  color: Color(0xFF333333),
  child: SizedBox.expand(),
);

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
          child: const MaterialApp(
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
          child: const MaterialApp(
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
          child: const MaterialApp(
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
          child: const MaterialApp(
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
          child: const MaterialApp(
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
          child: const MaterialApp(
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
}
