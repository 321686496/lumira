// test/features/capture/domain/scene_preset_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('ScenePreset', () {
    test('has required fields', () {
      final filter = SceneFilter(lut: 'cinematic', systemFilter: 'vivid', reason: 'warm mood');
      final guide = SceneGuide(lightDirection: '逆光 45°');
      final preset = ScenePreset(id: 'cafe-window', name: '窗边咖啡', filter: filter, sceneGuide: guide);
      expect(preset.id, 'cafe-window');
      expect(preset.filter.lut, 'cinematic');
      expect(preset.filter.systemFilter, 'vivid');
      expect(preset.filter.reason, 'warm mood');
      expect(preset.sceneGuide.lightDirection, '逆光 45°');
    });

    test('defaults are applied', () {
      final filter = SceneFilter(lut: 'none');
      final guide = SceneGuide();
      final preset = ScenePreset(id: 'test', name: 'Test', filter: filter, sceneGuide: guide);
      expect(preset.icon, '');
      expect(preset.category, SceneCategory.light);
      expect(preset.relatedCategory, 'portrait');
      expect(preset.exampleImages, isEmpty);
      expect(preset.tips, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      final filter = SceneFilter(lut: 'vintage');
      final guide = SceneGuide(bestTime: '14:00');
      final preset = ScenePreset(id: 'x', name: 'X', filter: filter, sceneGuide: guide);
      final copy = preset.copyWith(name: 'Y');
      expect(copy.id, 'x');
      expect(copy.name, 'Y');
      expect(copy.filter.lut, 'vintage');
      expect(copy.sceneGuide.bestTime, '14:00');
    });

    test('== compares all fields', () {
      final filter = SceneFilter(lut: 'none');
      final guide = SceneGuide();
      final a = ScenePreset(id: 'x', name: 'X', filter: filter, sceneGuide: guide);
      final b = ScenePreset(id: 'x', name: 'X', filter: filter, sceneGuide: guide);
      expect(a == b, true);
      final c = b.copyWith(name: 'Z');
      expect(a == c, false);
    });
  });

  group('SceneFilter', () {
    test('systemFilter defaults to null', () {
      const f = SceneFilter(lut: 'none');
      expect(f.systemFilter, isNull);
      expect(f.reason, '');
    });
    test('copyWith handles nullable systemFilter', () {
      const f = SceneFilter(lut: 'none');
      final copy = f.copyWith(systemFilter: 'vivid');
      expect(copy.systemFilter, 'vivid');
    });
  });

  group('SceneCategory', () {
    test('all constants are distinct strings', () {
      expect(SceneCategory.light != SceneCategory.outdoor, true);
      expect(SceneCategory.outdoor != SceneCategory.indoor, true);
      expect(SceneCategory.indoor != SceneCategory.mood, true);
    });
  });
}
