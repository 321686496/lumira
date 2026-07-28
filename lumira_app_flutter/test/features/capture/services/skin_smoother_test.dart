import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/skin_smoother.dart';

void main() {
  group('SkinSmoother', () {
    img.Image makeTestImage(int size, {double gradient = 0.0}) {
      final image = img.Image(width: size, height: size);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final v = (x / size * 255).round();
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      return image;
    }

    img.Image makeNoisyImage(int size) {
      final random = math.Random(42);
      final image = img.Image(width: size, height: size);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final base = 128;
          final noise = (random.nextDouble() * 60 - 30).round();
          final v = (base + noise).clamp(0, 255);
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      // Add a sharp edge in the middle
      for (var y = 0; y < size; y++) {
        image.setPixelRgb(size ~/ 2, y, 255, 255, 255);
      }
      return image;
    }

    double highFrequencyEnergy(img.Image image) {
      double energy = 0;
      var count = 0;
      for (var y = 1; y < image.height - 1; y++) {
        for (var x = 1; x < image.width - 1; x++) {
          final p = image.getPixel(x, y);
          final pl = image.getPixel(x - 1, y);
          final diff = (p.r - pl.r).abs();
          energy += diff;
          count++;
        }
      }
      return energy / count;
    }

    test('strength 0 returns input unchanged (fast path)', () {
      final src = makeTestImage(32);
      final out = SkinSmoother.smooth(src, 0);
      expect(identical(src, out), isTrue, reason: 'strength=0 must return same instance');
    });

    test('strength 100 produces smoother output (lower high-frequency energy)', () {
      final src = makeNoisyImage(64);
      final energyBefore = highFrequencyEnergy(src);
      final out = SkinSmoother.smooth(src, 100);
      final energyAfter = highFrequencyEnergy(out);
      expect(energyAfter, lessThan(energyBefore),
          reason: 'smoothing should reduce high-frequency energy');
    });

    test('edge preservation: sharp edge remains after smoothing', () {
      final src = makeNoisyImage(64);
      final out = SkinSmoother.smooth(src, 100);
      // The sharp edge at x = size/2 should still have high contrast
      final edgePixel = out.getPixel(64 ~/ 2, 32);
      final neighborPixel = out.getPixel(64 ~/ 2 - 1, 32);
      final edgeDiff = (edgePixel.r - neighborPixel.r).abs();
      expect(edgeDiff, greaterThan(50),
          reason: 'sharp edge should be preserved (diff > 50)');
    });

    test('output dimensions match input', () {
      final src = makeTestImage(48);
      final out = SkinSmoother.smooth(src, 50);
      expect(out.width, src.width);
      expect(out.height, src.height);
    });

    test('performance: 768px image under 500ms', () {
      final src = makeTestImage(768);
      final sw = Stopwatch()..start();
      SkinSmoother.smooth(src, 50);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500),
          reason: '768px smoothing must be under 500ms');
    }, timeout: const Timeout(Duration(seconds: 2)));
  });
}
