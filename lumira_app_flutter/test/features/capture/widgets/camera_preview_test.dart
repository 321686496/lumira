import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';

// 占位相机预览（避免在测试中触发真实相机）
const _cameraPlaceholder = ColoredBox(
  key: Key('camera_placeholder'),
  color: Color(0xFF333333),
  child: SizedBox.expand(),
);

void main() {
  group('CameraPreview', () {
    testWidgets('returns override widget directly (no ColorFiltered wrapping)',
        (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CameraPreview(onCaptured: _noop)),
          ),
        ),
      );

      expect(find.byKey(const Key('camera_placeholder')), findsOneWidget);
      // Override path MUST NOT wrap in ColorFiltered or Stack
      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('applies ColorFiltered when a template is selected', (tester) async {
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
            home: Scaffold(body: CameraPreview(onCaptured: _noop)),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('does NOT apply ColorFiltered when rawMode is true', (tester) async {
      final container = ProviderContainer(overrides: [
        cameraPreviewOverrideProvider.overrideWith((ref) => _cameraPlaceholder),
      ]);
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';
      container.read(CaptureState.rawModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CameraPreview(onCaptured: _noop)),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsNothing);
    });

    testWidgets('shows CompositionOverlay when template selected and showTemplate is true',
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
            home: Scaffold(body: CameraPreview(onCaptured: _noop)),
          ),
        ),
      );

      expect(find.byType(CompositionOverlay), findsOneWidget);
    });

    testWidgets('hides CompositionOverlay when showTemplate is false', (tester) async {
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
            home: Scaffold(body: CameraPreview(onCaptured: _noop)),
          ),
        ),
      );

      expect(find.byType(CompositionOverlay), findsNothing);
    });
  });
}

void _noop(String _) {}
