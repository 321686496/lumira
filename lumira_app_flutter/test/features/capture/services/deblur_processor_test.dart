import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/deblur_processor.dart';

void main() {
  group('DeblurProcessor.estimateBlur', () {
    test('clear image (sharp edges) returns score > 600', () {
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final isWhite = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
          image.setPixelRgb(x, y, isWhite ? 255 : 0, isWhite ? 255 : 0, isWhite ? 255 : 0);
        }
      }
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, greaterThan(600.0), reason: '棋盘格图像边缘丰富，应为清晰图像');
    });

    test('blurred image (smooth gradient) returns score < 100', () {
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final v = ((x + y) * 2).clamp(0, 255);
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, lessThan(100.0), reason: '平滑渐变无边缘，应为模糊图像');
    });

    test('solid color image returns score near 0', () {
      final image = img.Image(width: 64, height: 64);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, lessThan(10.0), reason: '纯色图像方差约为 0');
    });
  });

  group('DeblurProcessor.strengthForScore', () {
    test('score < 100 returns 0.8', () => expect(DeblurProcessor.strengthForScore(50.0), equals(0.8)));
    test('score 100-300 returns 0.5', () => expect(DeblurProcessor.strengthForScore(200.0), equals(0.5)));
    test('score 300-600 returns 0.3', () => expect(DeblurProcessor.strengthForScore(400.0), equals(0.3)));
    test('score > 600 returns 0.0', () => expect(DeblurProcessor.strengthForScore(800.0), equals(0.0)));
  });

  group('DeblurProcessor.deblur', () {
    test('strength=0 returns identical image', () async {
      final image = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          image.setPixelRgb(x, y, x * 8 % 256, y * 8 % 256, 128);
        }
      }
      final result = await DeblurProcessor.deblur(image, strength: 0.0);
      expect(result.width, equals(32));
      expect(result.height, equals(32));
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final orig = image.getPixel(x, y);
          final res = result.getPixel(x, y);
          expect(res.r, closeTo(orig.r, 1.0));
          expect(res.g, closeTo(orig.g, 1.0));
          expect(res.b, closeTo(orig.b, 1.0));
        }
      }
    });

    test('blurred image becomes sharper after deblur', () async {
      final blurred = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final v = ((x + y) / 2).round().clamp(0, 255);
          blurred.setPixelRgb(x, y, v, v, v);
        }
      }
      final origScore = DeblurProcessor.estimateBlur(blurred);
      final result = await DeblurProcessor.deblur(blurred, strength: 0.5);
      final newScore = DeblurProcessor.estimateBlur(result);
      expect(newScore, greaterThan(origScore), reason: '去模糊后图像应更清晰');
    });
  });
}
