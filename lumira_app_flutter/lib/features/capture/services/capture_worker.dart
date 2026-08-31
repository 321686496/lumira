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
    show
        applyPerPixelEffectsImg,
        applySmoothSkinImg,
        applyVignetteImg,
        legStretchRgba;

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

      // 1. 从 rawRgba 创建 img.Image
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // 1.5. 诊断：worker 收到像素的平均 RGB（P3→sRGB 已在主链路解码时完成，
      //       iOS 宽色域原片此时已是 sRGB，此处不再做任何校色）。
      final diagBefore = _sampleAvgRgb(image);
      const diagAfter = <int>[];

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
// 诊断采样
// ─────────────────────────────────────────────────────────────────────────

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
// 拉腿实时预览 worker（LegStretchWorker）
// ─────────────────────────────────────────────────────────────────────────
// 与 CaptureWorker 同源的常驻 isolate：把拉腿预览的逐像素拉伸移出 UI 主线程。
// 主 isolate 只做 GPU 抓帧（toImage/toByteData）与结果 codec 解码显示，
// 拉伸（legStretchRgba，600px 时约 40 万像素的字节级快速循环）在后台 isolate
// 执行，避免拍摄页 UI 被逐像素循环阻塞而卡顿。

/// 拉腿预览拉伸结果。
class LegStretchResult {
  const LegStretchResult({
    required this.ok,
    this.rgbaBytes,
    required this.width,
    required this.height,
  });
  final bool ok;
  final Uint8List? rgbaBytes;
  final int width;
  final int height;
}

/// 常驻拉腿预览 worker isolate 单例。
class LegStretchWorker {
  LegStretchWorker._();

  static final LegStretchWorker instance = LegStretchWorker._();

  Isolate? _isolate;
  SendPort? _sendPort;
  bool _started = false;

  /// 惰性启动常驻 isolate（仅首次调用真正创建）。
  Future<void> ensureStarted() async {
    if (_started) return;
    final mainPort = ReceivePort();
    final isolate =
        await Isolate.spawn(_legStretchWorkerEntry, mainPort.sendPort);
    _isolate = isolate;
    // 等 worker 回传它的 ReceivePort.sendPort，握手完成
    _sendPort = await mainPort.first as SendPort;
    _started = true;
  }

  /// 提交一次拉腿拉伸，等待结果返回。
  Future<LegStretchResult> stretch({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    required int legStretch,
  }) async {
    if (legStretch <= 0) {
      return LegStretchResult(
        ok: true,
        rgbaBytes: rgbaBytes,
        width: width,
        height: height,
      );
    }
    await ensureStarted();
    final replyPort = ReceivePort();
    _sendPort!.send({
      'reply': replyPort.sendPort,
      'rgbaBytes': rgbaBytes,
      'width': width,
      'height': height,
      'legStretch': legStretch,
    });
    try {
      final result = await replyPort.first as Map;
      return LegStretchResult(
        ok: result['ok'] as bool? ?? false,
        rgbaBytes: result['rgbaBytes'] as Uint8List?,
        width: result['width'] as int,
        height: result['height'] as int,
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

/// 拉腿 worker 入口（必须在顶层函数，Isolate.spawn 要求）。
void _legStretchWorkerEntry(SendPort mainPort) async {
  final port = ReceivePort();
  mainPort.send(port.sendPort);
  await for (final msg in port) {
    final reply = msg['reply'] as SendPort;
    try {
      final rgbaBytes = msg['rgbaBytes'] as Uint8List;
      final width = msg['width'] as int;
      final height = msg['height'] as int;
      final legStretch = msg['legStretch'] as int;

      // 字节级快速拉伸：直接操作 Uint8List + 整行拷贝，避免 img.Image
      // 逐像素 getPixel/setPixel 的对象开销，大幅缩短单次拉伸耗时，
      // 使抓帧在定时间隔内完成，不再叠加 GPU 读回导致拍摄页卡顿。
      final stretched = legStretchRgba(
        rgbaBytes,
        width: width,
        height: height,
        legStretch: legStretch,
      );

      reply.send({
        'ok': true,
        'rgbaBytes': stretched.bytes,
        'width': width,
        'height': stretched.height,
      });
    } catch (e, st) {
      stderr.writeln('[leg-stretch-worker] stretch failed: $e\n$st');
      // 失败回退：原样回传原始 rgba（等效不拉伸，保留实时画面）。
      reply.send({
        'ok': false,
        'rgbaBytes': msg['rgbaBytes'] as Uint8List?,
        'width': msg['width'] as int,
        'height': msg['height'] as int,
      });
    }
  }
}
