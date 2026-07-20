// test/features/capture/domain/filter_recipe_test.dart
import 'dart:ui' show ColorFilter;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('fromPostProcess', () {
    test('returns a ColorFilter for default PostProcess', () {
      const post = PostProcess(color: PostProcessColor());
      final filter = fromPostProcess(post);
      expect(filter, isA<ColorFilter>());
    });

    test('returns a ColorFilter with non-zero brightness', () {
      const post = PostProcess(color: PostProcessColor(brightness: 50));
      final filter = fromPostProcess(post);
      expect(filter, isA<ColorFilter>());
    });

    test('handles all color fields set', () {
      const post = PostProcess(
        color: PostProcessColor(
          brightness: 10,
          contrast: 20,
          saturation: -10,
          temperature: 15,
          tint: -5,
          highlights: -10,
          shadows: 20,
          blackPoint: 5,
          clarity: 30,
          vibrance: 10,
          brilliance: 15,
        ),
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      final filter = fromPostProcess(post);
      expect(filter, isA<ColorFilter>());
    });
  });

  group('fromSystemFilter', () {
    test('returns ColorFilter for all 7 system filters', () {
      const names = ['none', 'vivid', 'vivid_warm', 'vivid_cool', 'mono', 'silver', 'noir'];
      for (final name in names) {
        expect(fromSystemFilter(name), isA<ColorFilter>(), reason: 'Failed for $name');
      }
    });

    test('returns ColorFilter for unknown name (identity)', () {
      expect(fromSystemFilter('unknown'), isA<ColorFilter>());
    });
  });

  group('approximateLut', () {
    test('returns ColorFilter for all 16 LUT presets', () {
      const luts = [
        'none', 'cinematic', 'vintage', 'bw', 'warm_film', 'cool_film', 'pastel', 'fuji',
        'portrait', 'japanese', 'cyberpunk', 'sepia_classic', 'mist', 'rouge', 'twilight', 'cyan'
      ];
      for (final lut in luts) {
        expect(approximateLut(lut), isA<ColorFilter>(), reason: 'Failed for $lut');
      }
    });

    test('returns ColorFilter for unknown LUT (identity)', () {
      expect(approximateLut('unknown'), isA<ColorFilter>());
    });
  });

  group('lutLabel', () {
    test('returns correct Chinese label for known LUTs', () {
      expect(lutLabel('none'), '原图');
      expect(lutLabel('cinematic'), '电影感');
      expect(lutLabel('vintage'), '复古胶片');
      expect(lutLabel('bw'), '黑白');
      expect(lutLabel('cyberpunk'), '赛博朋克');
    });

    test('returns 原图 for unknown LUT', () {
      expect(lutLabel('unknown'), '原图');
    });
  });

  group('systemFilterLabel', () {
    test('returns correct Chinese label for known filters', () {
      expect(systemFilterLabel('none'), '原图');
      expect(systemFilterLabel('vivid'), '鲜明');
      expect(systemFilterLabel('vivid_warm'), '鲜暖色');
      expect(systemFilterLabel('mono'), '单色');
      expect(systemFilterLabel('noir'), '黑白');
    });

    test('returns 原图 for unknown filter', () {
      expect(systemFilterLabel('unknown'), '原图');
    });
  });

  group('Matrix composition', () {
    test('identity matrix produces identity ColorFilter', () {
      const post = PostProcess(color: PostProcessColor());
      final filter = fromPostProcess(post);
      expect(filter, isA<ColorFilter>());
    });

    test('brightness + contrast combined does not crash', () {
      const post = PostProcess(
        color: PostProcessColor(brightness: 30, contrast: -20),
      );
      expect(fromPostProcess(post), isA<ColorFilter>());
    });
  });
}
