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
}

/// worker 处理结果。
class CaptureWorkerResult {
  const CaptureWorkerResult({
    required this.ok,
    this.rgbaBytes,
    required this.width,
    required this.height,
    required this.outputPath,
  });
  final bool ok;

  /// 非空表示 needRawRgba=true，主 isolate 需用 rawRgba 做水印合成后再编码 JPEG
  final Uint8List? rgbaBytes;
  final int width;
  final int height;
  final String outputPath;
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
    });
    try {
      final result = await replyPort.first as Map;
      return CaptureWorkerResult(
        ok: result['ok'] as bool? ?? false,
        rgbaBytes: result['rgbaBytes'] as Uint8List?,
        width: result['width'] as int,
        height: result['height'] as int,
        outputPath: result['outputPath'] as String,
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

      // 1. 从 rawRgba 创建 img.Image
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

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
