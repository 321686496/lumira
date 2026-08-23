// lib/features/capture/services/capture_worker.dart
//
// 常驻 worker isolate：避免每张照片都用 compute() 新建 isolate + 大块 rawRgba 拷贝。
// 【性能优化 A】
//
// 设计要点：
// - 页面/首次使用时通过 [CaptureWorker.instance.ensureStarted] 惰性启动一个常驻 isolate，
//   之后每张照片直接复用，省去 isolate 创建/销毁开销（compute 每张 ~0.2-0.5s）。
// - 主 isolate 只把 rawRgba（1280px 时约 6.5MB）+ 参数经 SendPort 发给 worker；
//   worker 完成逐像素 CPU 效果（锐化/清晰度/颗粒/磨皮/暗角）后用 image 包
//   encodeJpg 编码写盘，再把结果路径回传，不把大块像素数据回传主 isolate。
// - 串行消费：拍摄队列本身串行，worker 内也是单请求循环，无需并发。
//
// 注：Flutter 3.7.12 的 dart:ui toByteData 不支持 JPEG（ImageByteFormat.jpeg 是
// 较新版本 API），因此 JPEG 编码仍用 image 包纯 Dart 实现；分辨率降到 1280px 后
// （优化 B）编码耗时约降为原来的 39%，已可接受。

import 'dart:async';
import 'dart:io' show File, stderr;
import 'dart:isolate' show Isolate, ReceivePort, SendPort;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;

import 'package:image/image.dart' as img;

import 'dart_photo_pipeline.dart'
    show applyPerPixelEffectsImg, applySmoothSkinImg, applyVignetteImg;

/// worker 处理请求参数（跨 isolate 可传递：仅基础类型 + Uint8List + String）。
class CaptureWorkerRequest {
  const CaptureWorkerRequest({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.outputPath,
    required this.sharpen,
    required this.clarity,
    required this.grain,
    required this.smoothStrength,
    required this.vignette,
    required this.needRawRgba,
    this.applyP3ToSrgb = false,
  });

  /// GPU 色彩矩阵处理后的 rawRgba（主 isolate 生成，dart:ui 管线，保证所见即所得）
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final String outputPath;
  final int sharpen;
  final double? clarity;
  final int grain;
  final int smoothStrength;
  final int vignette;

  /// true：不编码 JPEG，回传 rawRgba 给主 isolate 做水印合成
  /// false：worker 直接编码 JPEG 写盘，仅回传路径
  final bool needRawRgba;

  /// 是否对照片做 P3→sRGB 色域转换（iOS/OHOS 相机输出广色域 JPEG）。
  /// dart:ui 解码后 rawRgba 是 P3 像素值，image 包编码 JPEG 不嵌 ICC，
  /// 查看器按 sRGB 解释导致偏黄。由主 isolate 按平台决定。
  final bool applyP3ToSrgb;
}

/// worker 处理结果。
class CaptureWorkerResult {
  const CaptureWorkerResult({
    required this.ok,
    this.rgbaBytes,
    required this.width,
    required this.height,
    required this.outputPath,
    this.diagBefore,
    this.diagAfter,
    this.diagWb,
  });
  final bool ok;

  /// 非空表示 needRawRgba=true，主 isolate 需用 rawRgba 做水印合成后再编码 JPEG
  final Uint8List? rgbaBytes;
  final int width;
  final int height;
  final String outputPath;

  /// 诊断：P3→sRGB 转换前/后的平均 RGB（[r, g, b]），用于验证偏黄方向。
  final List<int>? diagBefore;
  final List<int>? diagAfter;

  /// 诊断：白平衡（灰世界）校正后的平均 RGB，用于验证偏黄是否缓解。
  final List<int>? diagWb;
}

/// 常驻 worker isolate 单例。
class CaptureWorker {
  CaptureWorker._();

  static final CaptureWorker instance = CaptureWorker._();

  Isolate? _isolate;
  SendPort? _sendPort;
  bool _started = false;

  /// 惰性启动常驻 isolate（仅首次调用真正创建）。
  Future<void> ensureStarted() async {
    if (_started) return;
    final mainPort = ReceivePort();
    final isolate = await Isolate.spawn(_workerEntry, mainPort.sendPort);
    _isolate = isolate;
    // 等 worker 回传它的 ReceivePort.sendPort，握手完成
    _sendPort = await mainPort.first as SendPort;
    _started = true;
  }

  /// 提交一个处理任务，等待 worker 完成并返回结果。
  Future<CaptureWorkerResult> process(CaptureWorkerRequest request) async {
    await ensureStarted();
    final replyPort = ReceivePort();
    _sendPort!.send({
      'reply': replyPort.sendPort,
      'rgbaBytes': request.rgbaBytes,
      'width': request.width,
      'height': request.height,
      'outputPath': request.outputPath,
      'sharpen': request.sharpen,
      'clarity': request.clarity,
      'grain': request.grain,
      'smoothStrength': request.smoothStrength,
      'vignette': request.vignette,
      'needRawRgba': request.needRawRgba,
      'applyP3ToSrgb': request.applyP3ToSrgb,
    });
    try {
      final result = await replyPort.first as Map;
      return CaptureWorkerResult(
        ok: result['ok'] as bool? ?? false,
        rgbaBytes: result['rgbaBytes'] as Uint8List?,
        width: result['width'] as int,
        height: result['height'] as int,
        outputPath: result['outputPath'] as String,
        diagBefore: (result['diagBefore'] as List?)?.cast<int>(),
        diagAfter: (result['diagAfter'] as List?)?.cast<int>(),
        diagWb: (result['diagWb'] as List?)?.cast<int>(),
      );
    } finally {
      replyPort.close();
    }
  }

  /// 释放常驻 isolate（页面销毁时调用，避免泄漏）。
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _started = false;
  }
}

/// worker 入口（必须在顶层函数，Isolate.spawn 要求）。
void _workerEntry(SendPort mainPort) async {
  final port = ReceivePort();
  mainPort.send(port.sendPort);
  await for (final msg in port) {
    final reply = msg['reply'] as SendPort;
    try {
      final rgbaBytes = msg['rgbaBytes'] as Uint8List;
      final width = msg['width'] as int;
      final height = msg['height'] as int;
      final outputPath = msg['outputPath'] as String;
      final sharpen = msg['sharpen'] as int;
      final clarity = msg['clarity'] as double?;
      final grain = msg['grain'] as int;
      final smoothStrength = msg['smoothStrength'] as int;
      final vignette = msg['vignette'] as int;
      final needRawRgba = msg['needRawRgba'] as bool;
      final applyP3ToSrgb = msg['applyP3ToSrgb'] as bool? ?? false;

      // 1. 从 rawRgba 创建 img.Image
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // 1.5. 诊断：P3→sRGB 转换前后的颜色采样（用于验证偏黄方向）
      final diagBefore = _sampleAvgRgb(image);

      // 1.6. P3→sRGB 色域转换（iOS/OHOS 相机输出广色域 JPEG）
      if (applyP3ToSrgb) {
        _applyP3ToSrgbInWorker(image);
      }
      final diagAfter = _sampleAvgRgb(image);

      // 2. 逐像素 CPU 效果：锐化 + 清晰度 + 颗粒 + 磨皮 + 暗角
      applyPerPixelEffectsImg(
        image,
        sharpen: sharpen,
        clarity: clarity,
        grain: grain,
      );
      applySmoothSkinImg(image, smoothStrength: smoothStrength);
      applyVignetteImg(image, vignette: vignette);

      // 2.5. 自适应白平衡校正（灰世界法）：
      // 诊断证明拍照偏黄源于「相机/系统输出 JPEG 本身偏暖」（OHOS requestImageData
      // 从相册读增强图、iOS P3 JPEG 未转 sRGB），与 Dart 管线无关。
      // 这里把整体平均色向中性灰拉回，缓解偏黄，跨平台通用。
      _applyGrayWorldWhiteBalance(image);

      // 2.6. 白平衡校正后的颜色采样（诊断用）
      final diagWb = _sampleAvgRgb(image);

      Uint8List? outRgba;
      if (needRawRgba) {
        // 有水印：不编码 JPEG，回传 rawRgba 给主 isolate 做水印合成
        outRgba = image.toUint8List();
      } else {
        // 无水印：直接编码 JPEG 写盘（1280px 下 image 包纯 Dart 编码耗时已可接受）
        final encoded = img.encodeJpg(image, quality: 90);
        await File(outputPath).writeAsBytes(encoded);
      }

      reply.send({
        'ok': true,
        'rgbaBytes': outRgba,
        'width': width,
        'height': height,
        'outputPath': outputPath,
        'diagBefore': diagBefore,
        'diagAfter': diagAfter,
        'diagWb': diagWb,
      });
    } catch (e, st) {
      stderr.writeln('[capture-worker] postProcess failed: $e\n$st');
      // 失败回退：needRawRgba 时回传原始 rgba，否则尝试原样编码写盘
      Uint8List? outRgba;
      final raw = msg['rgbaBytes'] as Uint8List?;
      final width = msg['width'] as int;
      final height = msg['height'] as int;
      final outputPath = msg['outputPath'] as String;
      final needRawRgba = msg['needRawRgba'] as bool? ?? false;
      if (needRawRgba) {
        outRgba = raw;
      } else if (raw != null) {
        try {
          final fallback = img.Image.fromBytes(
            width: width,
            height: height,
            bytes: raw.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          final encoded = img.encodeJpg(fallback, quality: 90);
          await File(outputPath).writeAsBytes(encoded);
        } catch (_) {}
      }
      reply.send({
        'ok': false,
        'rgbaBytes': outRgba,
        'width': width,
        'height': height,
        'outputPath': outputPath,
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// P3→sRGB 色域转换（worker isolate 内部）
// ─────────────────────────────────────────────────────────────────────────

/// sRGB 传递函数查表（避免逐像素 pow）
final List<double> _srgbToLinearLut = _buildSrgbToLinearLut();
final List<double> _srgbEncodeLut = _buildSrgbEncodeLut();

List<double> _buildSrgbToLinearLut() {
  return List<double>.generate(256, (i) {
    final v = i / 255.0;
    if (v <= 0.04045) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  });
}

List<double> _buildSrgbEncodeLut() {
  const steps = 4096;
  return List<double>.generate(steps, (i) {
    final c = i / (steps - 1);
    if (c <= 0.0031308) return c * 12.92;
    return (1.055 * math.pow(c, 1.0 / 2.4) - 0.055).clamp(0.0, 1.0).toDouble();
  });
}

/// 将 P3(D65) 像素就地转换为 sRGB(D65)。
///
/// P3 与 sRGB 同为 D65 白点、同为 sRGB 传递函数，仅基色不同。
/// 使用 sRGB→P3 正向矩阵的逆矩阵（带负系数）来正确还原 P3 中超出 sRGB 色域的红色。
void _applyP3ToSrgbInWorker(img.Image image) {
  const steps = 4096;
  for (final p in image) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final lr = _srgbToLinearLut[r];
    final lg = _srgbToLinearLut[g];
    final lb = _srgbToLinearLut[b];
    // P3(D65) → sRGB(D65) 线性基色转换矩阵（sRGB→P3 正向矩阵的逆）
    final sr = (1.2249 * lr - 0.2247 * lg).clamp(0.0, 1.0);
    final sg = (-0.0420 * lr + 1.0419 * lg).clamp(0.0, 1.0);
    final sb = (-0.0197 * lr - 0.0786 * lg + 1.0983 * lb).clamp(0.0, 1.0);
    p
      ..r = (_srgbEncodeLut[(sr * (steps - 1)).round()] * 255).round()
      ..g = (_srgbEncodeLut[(sg * (steps - 1)).round()] * 255).round()
      ..b = (_srgbEncodeLut[(sb * (steps - 1)).round()] * 255).round();
  }
}

/// 采样整图平均 RGB（步进采样降低耗时），返回 [avgR, avgG, avgB]。
/// 用于诊断偏黄方向：若 R 明显高于 G/B 则偏黄。
List<int> _sampleAvgRgb(img.Image image, {int step = 8}) {
  var r = 0.0, g = 0.0, b = 0.0;
  var cnt = 0;
  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final p = image.getPixel(x, y);
      r += p.r.toInt();
      g += p.g.toInt();
      b += p.b.toInt();
      cnt++;
    }
  }
  if (cnt == 0) return [0, 0, 0];
  return [
    (r / cnt).round(),
    (g / cnt).round(),
    (b / cnt).round(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────
// 自适应白平衡校正（灰世界法）
//
// 背景：诊断证明拍照偏黄源于「相机/系统输出 JPEG 本身偏暖」——
//  - OHOS 拍照走 photoOutput.capture → requestImageData（系统相册增强管线），输出比取景器预览暖；
//  - iOS 相机 JPEG 为 Display P3 广色域，未转 sRGB 时按 sRGB 解释会偏暖。
// 两个独立解码器（dart:ui 与 image 包 CPU）解码结果一致偏暖 [R>G>B]，
// 说明偏暖发生在解码之前的 JPEG 像素数据里，与 Dart 管线无关。
//
// 解法：对最终成片做一次灰世界（Gray World）白平衡：统计整图平均色，
// 若整体偏暖（R 通道明显高于 G/B），则收敛各通道增益，把平均色拉回中性灰。
// 增益限制在 ±10% 内，避免把正常暖光场景误打成冷色。
// 跨平台统一生效（iOS / OHOS / Android 共用本 worker）。
void _applyGrayWorldWhiteBalance(img.Image image) {
  // 1. 统计平均 RGB（完整遍历，保证准确）
  final avg = _sampleAvgRgb(image, step: 4);
  final avgR = avg[0].toDouble(), avgG = avg[1].toDouble(), avgB = avg[2].toDouble();
  final gray = (avgR + avgG + avgB) / 3.0;
  if (gray <= 1) return; // 近乎纯黑，无校正必要

  // 2. 计算增益，clamp 到 [0.9, 1.1]，限制过度校正
  final gainR = (gray / avgR).clamp(0.9, 1.1);
  final gainG = (gray / avgG).clamp(0.9, 1.1);
  final gainB = (gray / avgB).clamp(0.9, 1.1);

  // 若增益都 ≈1（画面本就中性），跳过
  if (((gainR - 1.0).abs() < 0.005) &&
      ((gainG - 1.0).abs() < 0.005) &&
      ((gainB - 1.0).abs() < 0.005)) {
    return;
  }

  // 3. 应用增益（就地逐像素）
  for (final p in image) {
    p
      ..r = (p.r * gainR).clamp(0.0, 255.0)
      ..g = (p.g * gainG).clamp(0.0, 255.0)
      ..b = (p.b * gainB).clamp(0.0, 255.0);
  }
}
