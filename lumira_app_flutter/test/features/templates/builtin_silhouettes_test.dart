import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/builtin_silhouettes.dart';

void main() {
  group('builtin_silhouettes', () {
    test('kBuiltinSilhouetteKeys has exactly 12 keys (no none)', () {
      expect(kBuiltinSilhouetteKeys.length, 12);
      expect(kBuiltinSilhouetteKeys, isNot(contains('none')));
    });

    test('kBuiltinSilhouettes has all 12 keys mapped to non-empty asset paths', () {
      for (final key in kBuiltinSilhouetteKeys) {
        final assetPath = kBuiltinSilhouettes[key];
        expect(assetPath, isNotNull, reason: 'key $key missing from map');
        expect(assetPath!, isNotEmpty, reason: 'key $key has empty asset path');
        expect(assetPath, startsWith('assets/images/silhouettes/'),
            reason: 'key $key path should be in silhouettes directory');
        expect(assetPath, endsWith('.png'),
            reason: 'key $key should be a PNG file');
      }
    });

    test('contains all expected keys', () {
      const expected = [
        'standing-profile', 'sitting-cafe', 'walking-street', 'soft-portrait',
        'neon-pose', 'vintage-portrait', 'peace-sign-girl', 'food-overhead',
        'cityscape-tripod', 'landscape-wide', 'macro-flower', 'still-life-table',
      ];
      for (final k in expected) {
        expect(kBuiltinSilhouetteKeys, contains(k), reason: 'missing key $k');
      }
    });
  });
}
