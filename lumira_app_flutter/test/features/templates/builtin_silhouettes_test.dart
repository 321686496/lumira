import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/builtin_silhouettes.dart';

void main() {
  group('builtin_silhouettes', () {
    test('kBuiltinSilhouetteKeys has exactly 12 keys (no none)', () {
      expect(kBuiltinSilhouetteKeys.length, 12);
      expect(kBuiltinSilhouetteKeys, isNot(contains('none')));
    });

    test('kBuiltinSilhouettes has all 12 keys mapped to non-empty SVGs', () {
      for (final key in kBuiltinSilhouetteKeys) {
        final svg = kBuiltinSilhouettes[key];
        expect(svg, isNotNull, reason: 'key $key missing from map');
        expect(svg!, isNotEmpty, reason: 'key $key has empty SVG');
      }
    });

    test('all SVGs use viewBox="0 0 100 200" and fill="currentColor"', () {
      for (final entry in kBuiltinSilhouettes.entries) {
        expect(entry.value, contains('viewBox="0 0 100 200"'),
            reason: '${entry.key} missing viewBox');
        expect(entry.value, contains('fill="currentColor"'),
            reason: '${entry.key} missing currentColor');
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
