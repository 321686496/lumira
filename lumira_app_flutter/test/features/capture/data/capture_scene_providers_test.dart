import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_scene_providers.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';

ScenePreset _scene(String id) {
  return ScenePreset(
    id: id,
    name: id,
    filter: const SceneFilter(lut: 'none'),
    sceneGuide: const SceneGuide(),
  );
}

void main() {
  group('orderCaptureScenes', () {
    test('puts active first, then recent scenes, then remaining scenes', () {
      final scenes = [
        _scene('scene-a'),
        _scene('scene-b'),
        _scene('scene-c'),
        _scene('scene-d'),
      ];

      final result = orderCaptureScenes(
        allScenes: scenes,
        recentSceneIds: ['scene-c', 'scene-a', 'scene-missing'],
        activeId: 'scene-d',
      );

      expect(result.map((scene) => scene.id).toList(), [
        'scene-d',
        'scene-c',
        'scene-a',
        'scene-b',
      ]);
    });

    test('keeps source order when no active or recent scenes exist', () {
      final scenes = [_scene('scene-a'), _scene('scene-b')];

      final result = orderCaptureScenes(
        allScenes: scenes,
        recentSceneIds: const [],
        activeId: null,
      );

      expect(result.map((scene) => scene.id).toList(), [
        'scene-a',
        'scene-b',
      ]);
    });
  });
}
