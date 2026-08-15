// test/features/capture/domain/post_process_delta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/post_process_delta.dart';

PostProcess _pp({
  double brightness = 0,
  double saturation = 0,
  int smooth = 0,
  String lut = 'none',
  String? sf,
}) =>
    PostProcess(
      color: PostProcessColor(brightness: brightness, saturation: saturation),
      smoothStrength: smooth,
      lut: lut,
      systemFilter: sf,
    );

void main() {
  group('fullOf', () {
    test('合并加法字段', () {
      final baked = _pp(brightness: 20, smooth: 10);
      final local = _pp(brightness: 5, smooth: 3);
      final full = fullOf(baked, local);
      expect(full.color.brightness, 25);
      expect(full.smoothStrength, 13);
    });

    test('lut 未改动保留 baked', () {
      final baked = _pp(lut: 'fuji');
      final local = _pp(lut: 'none');
      expect(fullOf(baked, local).lut, 'fuji');
    });
  });

  group('deltaOf', () {
    test('加法字段反推增量', () {
      final baked = _pp(brightness: 20, smooth: 10);
      final full = _pp(brightness: 25, smooth: 13);
      final delta = deltaOf(baked, full);
      expect(delta.color.brightness, 5);
      expect(delta.smoothStrength, 3);
    });

    test('lut 与 baked 相同则 local 为 none，还原后仍为 baked', () {
      final baked = _pp(lut: 'fuji');
      final full = _pp(lut: 'fuji');
      final delta = deltaOf(baked, full);
      expect(delta.lut, 'none');
      expect(fullOf(baked, delta).lut, 'fuji');
    });

    test('lut 与 baked 不同则 eq full', () {
      final baked = _pp(lut: 'fuji');
      final full = _pp(lut: 'vintage');
      final delta = deltaOf(baked, full);
      expect(delta.lut, 'vintage');
      expect(fullOf(baked, delta).lut, 'vintage');
    });

    test('systemFilter 与 baked 相同则 local 为 null', () {
      final baked = _pp(sf: 'vivid');
      final full = _pp(sf: 'vivid');
      final delta = deltaOf(baked, full);
      expect(delta.systemFilter, isNull);
      expect(fullOf(baked, delta).systemFilter, 'vivid');
    });
  });
}