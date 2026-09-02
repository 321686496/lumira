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
          // 用肤色底 + 高频噪声：肤色(215,168,148)±25，确保被肤色掩膜识别、可被平滑
          final r = (215 + random.nextDouble() * 50 - 25).round().clamp(0, 255);
          final g = (168 + random.nextDouble() * 50 - 25).round().clamp(0, 255);
          final b = (148 + random.nextDouble() * 50 - 25).round().clamp(0, 255);
          image.setPixelRgb(x, y, r, g, b);
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

    test('edge preservation: strong edge pixels stay unchanged (not blurred)', () {
      final src = makeNoisyImage(64);
      final before = src.clone();
      final out = SkinSmoother.smooth(src, 100);
      // 强结构（1px 白线，非肤色、高频）应被结构门控完全保护：
      // 边缘整列像素几乎不改动 → 五官/轮廓不糊。
      // 旧实现在此断言"单个噪声像素对比度>30"，但源图该像素本身被随机噪声
      // 拉高(如 r=233)导致即使原图也不满足阈值，属测试断言缺陷，与磨皮无关。
      var maxShift = 0;
      for (var y = 0; y < before.height; y++) {
        final a = before.getPixel(64 ~/ 2, y);
        final b = out.getPixel(64 ~/ 2, y);
        final shift = (a.r - b.r).abs().toInt();
        if (shift > maxShift) maxShift = shift;
      }
      expect(maxShift, lessThanOrEqualTo(3),
          reason: 'edge column pixels must be preserved (max shift <= 3)');
    });

    test('output dimensions match input', () {
      final src = makeTestImage(48);
      final out = SkinSmoother.smooth(src, 50);
      expect(out.width, src.width);
      expect(out.height, src.height);
    });

    test('performance: 768px image under 4000ms', () {
      final src = makeTestImage(768);
      final sw = Stopwatch()..start();
      SkinSmoother.smooth(src, 50);
      sw.stop();
      // 阈值 4000ms：真实设备通常 <100ms，但全量并发测试时共享 CPU 竞争会显著放大耗时
      expect(sw.elapsedMilliseconds, lessThan(4000),
          reason: '768px smoothing must be under 4000ms');
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
