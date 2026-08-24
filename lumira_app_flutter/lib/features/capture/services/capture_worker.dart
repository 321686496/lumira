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
    this.applyDeYellow = false,
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

  /// 是否对 iOS 成片做固定去黄校色（压低红、抬蓝，匹配取景器观感）。
  /// 由主 isolate 按平台决定：仅 iOS 启用。
  final bool applyDeYellow;
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
      'applyDeYellow': request.applyDeYellow,
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
      final applyDeYellow = msg['applyDeYellow'] as bool? ?? false;

      // 1. 从 rawRgba 创建 img.Image
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // 1.5. 诊断：去黄校色前/后的平均 RGB（用于验证偏黄方向）
      final diagBefore = _sampleAvgRgb(image);

      // 1.6. iOS 成片去黄校色（固定增益，压低红 / 抬亮蓝，匹配取景器观感）
      if (applyDeYellow) {
        _applyYellowCast(image);
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
// 成片去黄校色（worker isolate 内部）
// ─────────────────────────────────────────────────────────────────────────

/// iOS 相机 ISP 成片比取景器更暖（color_diag 中性灰实测 R>G>B，如 diagBefore=[128,108,100]）。
/// 成片在 sRGB 语境下比取景器偏黄：raw_src（P3+ICC，系统相册正确校色）与 final_out（无 ICC
/// 按 sRGB）都会被我们的渲染管线解释成偏暖。用固定增益压低红、抬蓝，把成片拉回与取景器一致。
///
/// 注意：这是**固定校色**，不是灰世界自适应（不做逐图平均校正，避免把暖调场景误漂白）；
/// 仅 iOS 启用，OHOS 走原生管线不走此 worker 路径。
/// 调参：参考 diagBefore=[128,108,100]，R×0.90→115、B×1.10→110，可将 R−B 从 +28 压到约 +5。
const double kDeYellowR = 0.90; // 压低红（应对实测 R 偏高）
const double kDeYellowG = 1.00; // 保持绿
const double kDeYellowB = 1.10; // 抬蓝（应对实测 B 偏低）

/// 对整图应用固定去黄校色（就地修改 [image] 像素）。
void _applyYellowCast(img.Image image) {
  for (final p in image) {
    p
      ..r = (p.r * kDeYellowR).clamp(0, 255).toInt()
      ..b = (p.b * kDeYellowB).clamp(0, 255).toInt();
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
