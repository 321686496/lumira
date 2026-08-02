// test/features/capture/domain/photo_template_serialization_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('CameraParams serialization', () {
    test('roundtrip preserves all fields', () {
      const original = CameraParams(
        exposureCompensation: 1.5,
        iso: 400,
        shutterSpeed: '1/125',
        whiteBalance: 'cloudy',
        whiteBalanceK: 6000,
        flashMode: 'auto',
        focusMode: 'continuous',
        lensType: 'wide',
        isoMode: 'manual',
        lensSuggestion: '使用广角',
      );
      final json = original.toJson();
      final restored = CameraParams.fromJson(json);
      expect(restored, equals(original));
    });

    test('default values roundtrip', () {
      const original = CameraParams();
      final json = original.toJson();
      final restored = CameraParams.fromJson(json);
      expect(restored, equals(original));
    });
  });

  group('PostProcessColor serialization', () {
    test('roundtrip preserves all fields including nullables', () {
      const original = PostProcessColor(
        brightness: 10,
        contrast: -5,
        saturation: 30,
        temperature: 15,
        tint: -8,
        highlights: 20,
        shadows: -15,
        blackPoint: 5,
        clarity: 12,
        vibrance: 8,
        brilliance: 3,
      );
      final json = original.toJson();
      final restored = PostProcessColor.fromJson(json);
      expect(restored, equals(original));
    });

    test('null nullable fields preserved as null', () {
      const original = PostProcessColor();
      final json = original.toJson();
      final restored = PostProcessColor.fromJson(json);
      expect(restored.highlights, isNull);
      expect(restored.shadows, isNull);
      expect(restored.blackPoint, isNull);
      expect(restored.clarity, isNull);
      expect(restored.vibrance, isNull);
      expect(restored.brilliance, isNull);
    });
  });

  group('PostProcess serialization', () {
    test('roundtrip preserves all fields', () {
      const original = PostProcess(
        cropRatio: '1:1',
        color: PostProcessColor(brightness: 10, saturation: 20),
        smoothStrength: 15,
        sharpen: 30,
        vignette: 25,
        grain: 10,
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      final json = original.toJson();
      final restored = PostProcess.fromJson(json);
      expect(restored, equals(original));
    });

    test('systemFilter null preserved', () {
      const original = PostProcess(
        color: PostProcessColor(),
        systemFilter: null,
      );
      final json = original.toJson();
      final restored = PostProcess.fromJson(json);
      expect(restored.systemFilter, isNull);
    });
  });

  group('Composition serialization', () {
    test('roundtrip preserves all fields', () {
      const original = Composition(
        overlayType: 'golden_ratio',
        opacity: 0.7,
        aspectRatio: '4:3',
        description: '黄金比例构图',
      );
      final json = original.toJson();
      final restored = Composition.fromJson(json);
      expect(restored, equals(original));
    });
  });
}
