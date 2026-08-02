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

  group('Matrix values', () {
    // Helper: identity-matrix check
    Matcher closeToIdentity() => predicate<List<double>>(
          (m) =>
              m.length == 20 &&
              (m[0] - 1.0).abs() < 1e-9 &&
              (m[6] - 1.0).abs() < 1e-9 &&
              (m[12] - 1.0).abs() < 1e-9 &&
              (m[18] - 1.0).abs() < 1e-9 &&
              m[1].abs() < 1e-9 &&
              m[2].abs() < 1e-9 &&
              m[4].abs() < 1e-9 &&
              m[5].abs() < 1e-9 &&
              m[10].abs() < 1e-9,
          'is the identity matrix',
        );

    test('composeSystemFilterMatrix("none") returns identity', () {
      final m = composeSystemFilterMatrix('none');
      expect(m.length, 20);
      expect(m, closeToIdentity());
    });

    test('composeLutMatrix("none") returns identity', () {
      final m = composeLutMatrix('none');
      expect(m.length, 20);
      expect(m, closeToIdentity());
    });

    test('composePostProcessMatrix with default PostProcess returns identity', () {
      const post = PostProcess(color: PostProcessColor());
      final m = composePostProcessMatrix(post);
      expect(m.length, 20);
      expect(m, closeToIdentity());
    });

    test('brightness: 50 produces 1.5 on R/G/B diagonal', () {
      const post = PostProcess(color: PostProcessColor(brightness: 50));
      final m = composePostProcessMatrix(post);
      // brightness(1.5) → diagonal = 1.5
      expect(m[0], closeTo(1.5, 1e-9)); // R diagonal
      expect(m[6], closeTo(1.5, 1e-9)); // G diagonal
      expect(m[12], closeTo(1.5, 1e-9)); // B diagonal
      // Off-diagonal and translation should be 0
      expect(m[1], closeTo(0.0, 1e-9));
      expect(m[5], closeTo(0.0, 1e-9));
      expect(m[4], closeTo(0.0, 1e-9));
      expect(m[9], closeTo(0.0, 1e-9));
      expect(m[14], closeTo(0.0, 1e-9));
      // Alpha unchanged
      expect(m[18], closeTo(1.0, 1e-9));
    });

    test('contrast: 20 produces expected diagonal (1.2) and translation (-25.5)', () {
      const post = PostProcess(color: PostProcessColor(contrast: 20));
      final m = composePostProcessMatrix(post);
      // contrast(1.2): c=1.2, t=(1-1.2)/2=-0.1, t*255 = -25.5
      expect(m[0], closeTo(1.2, 1e-9));
      expect(m[6], closeTo(1.2, 1e-9));
      expect(m[12], closeTo(1.2, 1e-9));
      expect(m[4], closeTo(-25.5, 1e-9));
      expect(m[9], closeTo(-25.5, 1e-9));
      expect(m[14], closeTo(-25.5, 1e-9));
      expect(m[18], closeTo(1.0, 1e-9));
    });

    test('brightness + contrast composition matches C·B order (catches reversal)', () {
      // CSS: brightness(1.5) contrast(1.2) → brightness applied FIRST, contrast LAST.
      // Correct matrix: C·B → translation = -25.5 (just C's translation, B has none).
      // Reversed (buggy) matrix: B·C → translation = -38.25 (B scales C's translation).
      const post = PostProcess(
        color: PostProcessColor(brightness: 50, contrast: 20),
      );
      final m = composePostProcessMatrix(post);
      // Diagonal is 1.5 * 1.2 = 1.8 in both orders
      expect(m[0], closeTo(1.8, 1e-9));
      expect(m[6], closeTo(1.8, 1e-9));
      expect(m[12], closeTo(1.8, 1e-9));
      // Translation distinguishes the order: -25.5 (correct) vs -38.25 (reversed)
      expect(m[4], closeTo(-25.5, 1e-9));
      expect(m[9], closeTo(-25.5, 1e-9));
      expect(m[14], closeTo(-25.5, 1e-9));
    });

    test('bw LUT produces a grayscale matrix (rows 0-2 identical)', () {
      final m = composeLutMatrix('bw');
      expect(m.length, 20);
      // Row 0: m[0..4], Row 1: m[5..9], Row 2: m[10..14]
      // Grayscale means all three rows are identical (R' = G' = B' = luminance)
      for (int i = 0; i < 5; i++) {
        expect(m[i], closeTo(m[5 + i], 1e-9),
            reason: 'Row 0 != Row 1 at col $i');
        expect(m[5 + i], closeTo(m[10 + i], 1e-9),
            reason: 'Row 1 != Row 2 at col $i');
      }
    });

    test('mono system filter produces a grayscale matrix (rows 0-2 identical)', () {
      final m = composeSystemFilterMatrix('mono');
      for (int i = 0; i < 5; i++) {
        expect(m[i], closeTo(m[5 + i], 1e-9),
            reason: 'Row 0 != Row 1 at col $i');
        expect(m[5 + i], closeTo(m[10 + i], 1e-9),
            reason: 'Row 1 != Row 2 at col $i');
      }
    });

    test('LUT applied after base adjustments (catches LUT/base reversal)', () {
      // PostProcess: brightness: 50, lut: 'bw'
      // CSS order: brightness(1.5) → [bw: grayscale(1) contrast(1.1)]
      // Correct matrix: LUT · B = (C·Grayscale) · B
      //   translation row 0 = -12.75 (just LUT's translation; B has none)
      // Reversed (buggy) matrix: B · LUT = B · (C·Grayscale)
      //   translation row 0 = 1.5 * -12.75 = -19.125
      const post = PostProcess(
        color: PostProcessColor(brightness: 50),
        lut: 'bw',
      );
      final m = composePostProcessMatrix(post);
      // bw LUT contrast(1.1): t = (1-1.1)/2 = -0.05, t*255 = -12.75
      expect(m[4], closeTo(-12.75, 1e-9),
          reason: 'LUT should be applied after base brightness; '
              'got ${m[4]} (expected -12.75, reversed would be -19.125)');
    });

    test('vivid system filter has expected R diagonal and translation after B·S·C', () {
      // vivid: contrast(1.1) saturate(1.25) brightness(1.02) → B·S·C
      final m = composeSystemFilterMatrix('vivid');
      // Rec.709 luminance weights: lumR=0.2126, lumG=0.7152, lumB=0.0722
      // S row 0 = [s + (1-s)*lumR, (1-s)*lumG, (1-s)*lumB] with s=1.25
      //   = [1.19685, -0.1788, -0.01805]
      // R diagonal = 1.02 * 1.19685 * 1.1 ≈ 1.3428657
      // (Same in either order — diagonal is order-independent.)
      expect(m[0], closeTo(1.02 * 1.19685 * 1.1, 1e-6));
      // R translation distinguishes the order:
      //   Correct (B·S·C): 1.02 * (-12.75 * 1.0) = -13.005
      //     where 1.0 = sum of S row 0 first 3 elements
      //     (s + (1-s)*(lumR+lumG+lumB) = s + (1-s) = 1)
      //   Reversed (C·S·B): -12.75 (just C's translation; B and S have no translation)
      expect(m[4], closeTo(1.02 * -12.75 * 1.0, 1e-3),
          reason: 'Got ${m[4]}; correct (B·S·C) = -13.005, reversed (C·S·B) = -12.75');
    });

    test('alpha row is preserved as [0,0,0,1,0] across compositions', () {
      const post = PostProcess(
        color: PostProcessColor(
          brightness: 10,
          contrast: 20,
          saturation: -10,
          temperature: 15,
          tint: -5,
        ),
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      final m = composePostProcessMatrix(post);
      // Alpha row is indices 15..19
      expect(m[15], closeTo(0.0, 1e-9));
      expect(m[16], closeTo(0.0, 1e-9));
      expect(m[17], closeTo(0.0, 1e-9));
      expect(m[18], closeTo(1.0, 1e-9));
      expect(m[19], closeTo(0.0, 1e-9));
    });
  });
}
