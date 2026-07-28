import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('TransformParams', () {
    test('default is identity', () {
      const t = TransformParams();
      expect(t.isIdentity, isTrue);
      expect(t.rotation, 0);
      expect(t.flipH, isFalse);
      expect(t.flipV, isFalse);
      expect(t.straighten, 0.0);
    });

    test('non-default is not identity', () {
      const t = TransformParams(rotation: 90);
      expect(t.isIdentity, isFalse);
    });

    test('straighten below threshold is identity', () {
      const t = TransformParams(straighten: 0.005);
      expect(t.isIdentity, isTrue);
    });

    test('toJson round-trip', () {
      const t = TransformParams(rotation: 180, flipH: true, flipV: false, straighten: -7.5);
      final json = t.toJson();
      final restored = TransformParams.fromJson(json);
      expect(restored, t);
    });

    test('fromJson handles missing fields', () {
      final t = TransformParams.fromJson({});
      expect(t.rotation, 0);
      expect(t.flipH, isFalse);
      expect(t.flipV, isFalse);
      expect(t.straighten, 0.0);
    });

    test('fromJson handles num types for rotation/straighten', () {
      final t = TransformParams.fromJson({
        'rotation': 90.0,
        'straighten': 5.0,
      });
      expect(t.rotation, 90);
      expect(t.straighten, 5.0);
    });

    test('copyWith preserves unchanged fields', () {
      const t = TransformParams(rotation: 90, flipH: true, straighten: 5.0);
      final t2 = t.copyWith(flipV: true);
      expect(t2.rotation, 90);
      expect(t2.flipH, isTrue);
      expect(t2.flipV, isTrue);
      expect(t2.straighten, 5.0);
    });

    test('equality', () {
      const a = TransformParams(rotation: 90, flipH: true, straighten: 5.0);
      const b = TransformParams(rotation: 90, flipH: true, straighten: 5.0);
      const c = TransformParams(rotation: 180, flipH: true, straighten: 5.0);
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });
  });
}
