import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 皮肤平滑处理器（双边滤波）
///
/// 纯 Dart 实现，三端兼容（OHOS / iOS / Android）。
/// 算法：3x3 双边滤波 + 降采样优化。
/// - 空间权重：exp(-dist² / (2 * spatialSigma²))
/// - 强度权重：exp(-diff² / (2 * intensitySigma²))
/// - 输出 = Σ(weight * pixel) / Σ(weight)
///
/// 性能：768px 长边图 ~250-350ms
class SkinSmoother {
  SkinSmoother._();

  /// 皮肤平滑
  /// [strengthInt] 0-100，来自 PostProcess.smoothStrength
  /// 返回处理后的图像；strength=0 返回原对象（快速路径）
  static img.Image smooth(img.Image src, int strengthInt) {
    if (strengthInt <= 0) return src;
    final strength = (strengthInt / 100.0).clamp(0.0, 1.0);
    if (strength <= 0.01) return src;

    // 1. 降采样到 768px 长边（性能优化）
    final maxLongEdge = 768;
    final small = _downsample(src, maxLongEdge);

    // 2. 3x3 双边滤波
    final smoothed = _bilateralFilter(
      small,
      spatialSigma: 2.0,
      intensitySigma: 25.0,
    );

    // 3. 混合：output = lerp(original, smoothed, strength)
    final blended = _blend(small, smoothed, strength);

    // 4. 上采样回原尺寸
    if (blended.width == src.width && blended.height == src.height) {
      return blended;
    }
    return img.copyResize(blended, width: src.width, height: src.height);
  }

  /// 降采样到指定长边
  static img.Image _downsample(img.Image src, int maxLongEdge) {
    final longEdge = math.max(src.width, src.height);
    if (longEdge <= maxLongEdge) return src;
    final scale = maxLongEdge / longEdge;
    return img.copyResize(
      src,
      width: (src.width * scale).round(),
      height: (src.height * scale).round(),
    );
  }

  /// 3x3 双边滤波
  static img.Image _bilateralFilter(
    img.Image src, {
    required double spatialSigma,
    required double intensitySigma,
  }) {
    // 预计算空间权重（3x3 kernel）
    final spatialWeights = List<double>.filled(9, 0);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final dist = (dx * dx + dy * dy).toDouble();
        spatialWeights[(dy + 1) * 3 + (dx + 1)] =
            math.exp(-dist / (2 * spatialSigma * spatialSigma));
      }
    }

    final out = img.Image(width: src.width, height: src.height);
    final twoIntensitySigmaSq = 2 * intensitySigma * intensitySigma;

    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final center = src.getPixel(x, y);
        double r = 0, g = 0, b = 0, totalWeight = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || nx >= src.width || ny < 0 || ny >= src.height) continue;
            final np = src.getPixel(nx, ny);
            final dr = (np.r - center.r).abs();
            final dg = (np.g - center.g).abs();
            final db = (np.b - center.b).abs();
            final diff = (dr + dg + db) / 3;
            final intensityWeight = math.exp(-diff * diff / twoIntensitySigmaSq);
            final w = spatialWeights[(dy + 1) * 3 + (dx + 1)] * intensityWeight;
            r += np.r * w;
            g += np.g * w;
            b += np.b * w;
            totalWeight += w;
          }
        }
        out.setPixelRgb(
          x,
          y,
          (r / totalWeight).round().clamp(0, 255),
          (g / totalWeight).round().clamp(0, 255),
          (b / totalWeight).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  /// 线性混合：output = lerp(original, smoothed, strength)
  static img.Image _blend(img.Image original, img.Image smoothed, double strength) {
    final out = img.Image(width: original.width, height: original.height);
    for (var y = 0; y < original.height; y++) {
      for (var x = 0; x < original.width; x++) {
        final o = original.getPixel(x, y);
        final s = smoothed.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          (o.r + (s.r - o.r) * strength).round().clamp(0, 255),
          (o.g + (s.g - o.g) * strength).round().clamp(0, 255),
          (o.b + (s.b - o.b) * strength).round().clamp(0, 255),
        );
      }
    }
    return out;
  }
}
