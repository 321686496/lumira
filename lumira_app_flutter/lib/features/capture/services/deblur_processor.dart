// lib/features/capture/services/deblur_processor.dart
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 去模糊处理器
///
/// 提供基于 Laplacian 方差的模糊度估计，和 Lucy-Richardson 反卷积去模糊。
/// 纯 Dart 实现，三端（Android/iOS/HarmonyOS）通用。
///
/// 算法说明：
/// - 模糊度估计：对图像做 3x3 Laplacian 卷积，计算卷积结果绝对值的方差。
///   方差越大越清晰（边缘多），越小越模糊。
/// - 去模糊：使用 Lucy-Richardson 反卷积迭代恢复，PSF 为水平方向运动模糊核。
class DeblurProcessor {
  DeblurProcessor._();

  /// 清晰阈值：分数 >= 此值认为图像清晰
  static const double kClearThreshold = 600.0;

  /// 估计图像模糊度（Laplacian 方差）
  ///
  /// 对图像做 3x3 Laplacian 卷积 [0,-1,0; -1,4,-1; 0,-1,0]，
  /// 计算卷积结果绝对值的方差。方差越大越清晰（边缘多），越小越模糊。
  /// 图像太小（<3x3）直接返回 [kClearThreshold]+1。
  static double estimateBlur(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w < 3 || h < 3) {
      return kClearThreshold + 1.0;
    }

    // Laplacian 卷积核：[0,-1,0; -1,4,-1; 0,-1,0]
    const laplacian = [0.0, -1.0, 0.0, -1.0, 4.0, -1.0, 0.0, -1.0, 0.0];

    // 仅对内部像素计算卷积（避免边界零填充导致纯色图像方差偏高）
    final values = <double>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final v = _convolveLaplacian(image, x, y, laplacian);
        values.add(v.abs());
      }
    }

    return _variance(values);
  }

  /// 根据模糊分数返回去模糊强度
  ///
  /// - score < 100 → 0.8（很模糊）
  /// - 100 ≤ score < 300 → 0.5
  /// - 300 ≤ score < 600 → 0.3
  /// - score ≥ 600 → 0.0（清晰，无需处理）
  static double strengthForScore(double score) {
    if (score < 100.0) return 0.8;
    if (score < 300.0) return 0.5;
    if (score < 600.0) return 0.3;
    return 0.0;
  }

  /// Lucy-Richardson 反卷积去模糊
  ///
  /// [strength] 去模糊强度（0.0-1.0），≤0 时返回原图深拷贝。
  /// 根据 [strength] 生成水平方向运动模糊 PSF（核大小 3-15），
  /// 提取 RGB 三通道，迭代 3 次 Lucy-Richardson，合并返回。
  static Future<img.Image> deblur(img.Image image,
      {required double strength}) async {
    if (strength <= 0.0) {
      return img.Image.from(image);
    }

    final w = image.width;
    final h = image.height;
    final sw = Stopwatch()..start();

    // 根据 strength 生成 PSF 核大小（3-15）
    final psfSize = (3 + (strength * 12).round()).clamp(3, 15);
    final psf = _generateMotionPsf(psfSize, 0.0);

    debugPrint(
        '[deblur] 开始: ${w}x$h, strength=$strength, psfSize=$psfSize');

    // 提取 RGB 三通道
    var rChannel = _extractChannel(image, 'r');
    var gChannel = _extractChannel(image, 'g');
    var bChannel = _extractChannel(image, 'b');

    // 迭代 3 次 Lucy-Richardson
    for (var i = 0; i < 3; i++) {
      rChannel = _lucyRichardsonIter(rChannel, psf, w, h);
      gChannel = _lucyRichardsonIter(gChannel, psf, w, h);
      bChannel = _lucyRichardsonIter(bChannel, psf, w, h);
    }

    // 合并回 img.Image
    final result = _mergeChannels(rChannel, gChannel, bChannel, w, h);
    sw.stop();
    debugPrint('[deblur] 完成: ${sw.elapsedMilliseconds}ms');
    return result;
  }

  // ===== 私有辅助方法 =====

  /// 计算像素亮度：0.299*R + 0.587*G + 0.114*B
  static double _luminance(img.Pixel p) {
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }

  /// 对单个像素做 3x3 Laplacian 卷积（仅在内部像素调用，无需处理边界）
  static double _convolveLaplacian(
      img.Image image, int x, int y, List<double> kernel) {
    double sum = 0.0;
    for (var ky = -1; ky <= 1; ky++) {
      for (var kx = -1; kx <= 1; kx++) {
        final lum = _luminance(image.getPixel(x + kx, y + ky));
        final k = kernel[(ky + 1) * 3 + (kx + 1)];
        sum += lum * k;
      }
    }
    return sum;
  }

  /// 计算方差
  static double _variance(List<double> values) {
    if (values.isEmpty) return 0.0;
    double sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    final mean = sum / values.length;
    double sumSqDiff = 0.0;
    for (final v in values) {
      final diff = v - mean;
      sumSqDiff += diff * diff;
    }
    return sumSqDiff / values.length;
  }

  /// 生成水平方向运动模糊 PSF（归一化）
  ///
  /// 返回长度为 [size] 的 1D 核，每个元素 = 1/size。
  /// [angle] 预留参数（当前仅实现水平方向）。
  static List<double> _generateMotionPsf(int size, double angle) {
    return List<double>.filled(size, 1.0 / size);
  }

  /// 翻转 PSF（180度旋转，对 1D 即反转）
  static List<double> _flipPsf(List<double> psf, int size) {
    return psf.reversed.toList();
  }

  /// 提取指定颜色通道为 2D double 数组
  ///
  /// [channel] 取值 'r' / 'g' / 'b'
  static List<List<double>> _extractChannel(
      img.Image image, String channel) {
    final w = image.width;
    final h = image.height;
    final result =
        List<List<double>>.generate(h, (_) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        double val;
        switch (channel) {
          case 'r':
            val = p.r.toDouble();
            break;
          case 'g':
            val = p.g.toDouble();
            break;
          case 'b':
            val = p.b.toDouble();
            break;
          default:
            val = 0.0;
        }
        result[y][x] = val;
      }
    }
    return result;
  }

  /// 合并 RGB 三通道回 img.Image
  static img.Image _mergeChannels(List<List<double>> r, List<List<double>> g,
      List<List<double>> b, int w, int h) {
    final image = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final rv = r[y][x].round().clamp(0, 255);
        final gv = g[y][x].round().clamp(0, 255);
        final bv = b[y][x].round().clamp(0, 255);
        image.setPixelRgb(x, y, rv, gv, bv);
      }
    }
    return image;
  }

  /// 一次 Lucy-Richardson 迭代
  ///
  /// f_{k+1} = f_k * (h* ⊗ (g / (h ⊗ f_k)))
  /// - [observed] 观测图像 g（即当前通道数据，也作为 f_0 初始估计）
  /// - [psf] 点扩散函数 h
  /// - h* 为 h 的 180 度翻转
  static List<List<double>> _lucyRichardsonIter(
    List<List<double>> observed,
    List<double> psf,
    int w,
    int h,
  ) {
    final psfSize = psf.length;
    final flippedPsf = _flipPsf(psf, psfSize);

    // h ⊗ f_k（PSF 对当前估计做卷积）
    final convFk = _convolve2D(observed, psf, psfSize, w, h);

    // g / (h ⊗ f_k)
    final ratio =
        List<List<double>>.generate(h, (y) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final denom = convFk[y][x];
        ratio[y][x] = denom > 1e-10 ? observed[y][x] / denom : 0.0;
      }
    }

    // h* ⊗ ratio
    final convRatio = _convolve2D(ratio, flippedPsf, psfSize, w, h);

    // f_{k+1} = f_k * convRatio（逐元素相乘）
    final result =
        List<List<double>>.generate(h, (y) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        result[y][x] = observed[y][x] * convRatio[y][x];
      }
    }
    return result;
  }

  /// 1D 水平卷积（边界零填充）
  ///
  /// [image] 2D 输入数组，[kernel] 1D 卷积核，[kernelSize] 核长度，
  /// [w] [h] 图像宽高。返回与输入同尺寸的 2D 数组。
  static List<List<double>> _convolve2D(
    List<List<double>> image,
    List<double> kernel,
    int kernelSize,
    int w,
    int h,
  ) {
    final result =
        List<List<double>>.generate(h, (y) => List<double>.filled(w, 0.0));
    final half = kernelSize ~/ 2;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        double sum = 0.0;
        for (var k = 0; k < kernelSize; k++) {
          final nx = x + k - half;
          if (nx < 0 || nx >= w) continue; // 边界零填充
          sum += image[y][nx] * kernel[k];
        }
        result[y][x] = sum;
      }
    }
    return result;
  }
}
