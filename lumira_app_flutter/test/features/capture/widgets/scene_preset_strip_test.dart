import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_scene_providers.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';
import 'package:lumira_app_flutter/features/capture/widgets/scene_preset_strip.dart';

ScenePreset _scene(String id) {
  return ScenePreset(
    id: id,
    name: id,
    filter: const SceneFilter(lut: 'none'),
    sceneGuide: const SceneGuide(),
  );
}

void main() {
  group('ScenePresetStrip', () {
    testWidgets('expanded mode shows 10 scenes and a show-more entry',
        (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(2000, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

      var showMoreTapped = false;
      final scenes = List.generate(12, (index) => _scene('scene-$index'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            captureScenePresetsProvider.overrideWith((ref) async => scenes),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ScenePresetStrip(
                onShowMore: () => showMoreTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('scene-9'), findsOneWidget);
      expect(find.text('scene-10'), findsNothing);
      expect(find.text('查看更多'), findsOneWidget);

      await tester.tap(find.text('查看更多'));
      expect(showMoreTapped, isTrue);
    });

    testWidgets('tapping a scene updates activeScenePresetIdProvider',
        (tester) async {
      final scenes = [_scene('scene-a'), _scene('scene-b')];
      final container = ProviderContainer(
        overrides: [
          captureScenePresetsProvider.overrideWith((ref) async => scenes),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ScenePresetStrip()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(CaptureState.activeScenePresetIdProvider),
        isNull,
      );
      await tester.tap(find.text('scene-a'));
      await tester.pumpAndSettle();

      expect(
        container.read(CaptureState.activeScenePresetIdProvider),
        'scene-a',
      );
    });
  });
}
