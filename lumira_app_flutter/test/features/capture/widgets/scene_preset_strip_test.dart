import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/scene_preset_strip.dart';

void main() {
  group('ScenePresetStrip', () {
    testWidgets('compact mode renders 6 scene cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ScenePresetStrip(compact: true)),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(6));
    });

    testWidgets('expanded mode renders 18 scene cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Expand the test viewport so the lazy ListView.builder builds all 18 cards
      // (default 800×600 only fits ~10 of the 72px-wide items).
      tester.binding.window.physicalSizeTestValue = const Size(2000, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ScenePresetStrip(compact: false)),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(18));
    });

    testWidgets('tapping a scene card updates activeScenePresetIdProvider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ScenePresetStrip(compact: true)),
          ),
        ),
      );

      expect(container.read(CaptureState.activeScenePresetIdProvider), isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(container.read(CaptureState.activeScenePresetIdProvider), isNotNull);
    });
  });
}
