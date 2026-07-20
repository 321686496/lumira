// test/features/capture/data/scene_presets_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_presets_data.dart';
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';

void main() {
  group('ScenePresetsData', () {
    test('has 18 presets', () {
      expect(ScenePresetsData.allScenePresets.length, 18);
    });

    test('all ids are unique', () {
      final ids = ScenePresetsData.allScenePresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all presets are const (identical across accesses)', () {
      final a = ScenePresetsData.allScenePresets;
      final b = ScenePresetsData.allScenePresets;
      expect(identical(a, b), true);
    });

    test('getScenePreset returns preset by id', () {
      final p = ScenePresetsData.getScenePreset('cafe-window');
      expect(p, isNotNull);
      expect(p!.name, '咖啡馆');
      expect(p.filter.lut, 'warm_film');
      expect(p.filter.systemFilter, 'vivid_warm');
    });

    test('getScenePreset returns null for unknown id', () {
      expect(ScenePresetsData.getScenePreset('unknown'), isNull);
    });

    test('categories are distributed across light/outdoor/indoor/mood', () {
      final cats = ScenePresetsData.allScenePresets.map((p) => p.category).toSet();
      expect(cats.contains(SceneCategory.indoor), true);
      expect(cats.contains(SceneCategory.outdoor), true);
      expect(cats.contains(SceneCategory.light), true);
      expect(cats.contains(SceneCategory.mood), true);
    });

    test('cafe-window has expected scene guide data', () {
      final p = ScenePresetsData.getScenePreset('cafe-window')!;
      expect(p.sceneGuide.lightDirectionAngle, 90);
      expect(p.sceneGuide.shootingDistanceM, 2);
      expect(p.sceneGuide.bestTimeFrom, '14:00');
      expect(p.sceneGuide.bestTimeTo, '17:00');
    });

    test('only cafe-window has a non-null systemFilter', () {
      // Per TS source, only cafeWindow has systemFilter: 'vivid_warm'
      final withSystemFilter = ScenePresetsData.allScenePresets
          .where((p) => p.filter.systemFilter != null)
          .map((p) => p.id)
          .toList();
      expect(withSystemFilter, ['cafe-window']);
    });

    test('all presets have non-empty id, name, filter.lut, vibe', () {
      for (final p in ScenePresetsData.allScenePresets) {
        expect(p.id.isNotEmpty, true, reason: 'preset has empty id');
        expect(p.name.isNotEmpty, true, reason: 'preset ${p.id} has empty name');
        expect(p.filter.lut.isNotEmpty, true,
            reason: 'preset ${p.id} has empty filter.lut');
        expect(p.vibe.isNotEmpty, true, reason: 'preset ${p.id} has empty vibe');
      }
    });

    test('all presets have 3 example images', () {
      for (final p in ScenePresetsData.allScenePresets) {
        expect(p.exampleImages.length, 3,
            reason: 'preset ${p.id} should have 3 example images');
      }
    });

    test('all preset ids match the expected 18 ids', () {
      final expectedIds = [
        'cafe-window',
        'library-quiet',
        'home-cozy',
        'sunset-silhouette',
        'golden-rim-portrait',
        'night-street',
        'bar-neon',
        'convenience-store',
        'seaside-beach',
        'seaside-rocks',
        'forest-bamboo',
        'forest-maple',
        'urban-rooftop',
        'urban-subway',
        'bedroom-morning',
        'kitchen-cooking',
        'candle-warm',
        'rainy-window',
      ];
      final ids = ScenePresetsData.allScenePresets.map((p) => p.id).toList();
      expect(ids, expectedIds);
    });

    test('relatedCategory values match TS SCENE_TO_CATEGORY mapping', () {
      final expected = {
        'cafe-window': 'portrait',
        'library-quiet': 'portrait',
        'home-cozy': 'still-life',
        'sunset-silhouette': 'portrait',
        'golden-rim-portrait': 'portrait',
        'night-street': 'night',
        'bar-neon': 'night',
        'convenience-store': 'street',
        'seaside-beach': 'landscape',
        'seaside-rocks': 'landscape',
        'forest-bamboo': 'landscape',
        'forest-maple': 'landscape',
        'urban-rooftop': 'landscape',
        'urban-subway': 'street',
        'bedroom-morning': 'still-life',
        'kitchen-cooking': 'food',
        'candle-warm': 'still-life',
        'rainy-window': 'still-life',
      };
      for (final p in ScenePresetsData.allScenePresets) {
        expect(p.relatedCategory, expected[p.id],
            reason: 'preset ${p.id} relatedCategory mismatch');
      }
    });
  });
}
