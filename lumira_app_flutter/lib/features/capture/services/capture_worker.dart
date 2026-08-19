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

/// 场景一致性阈值（0-255 亮度域的帧间平均绝对差）。
/// 超过该值视为用户已移动画面（拍完立即换位置），拒绝该帧，
/// 保证成片始终是"按下快门那一刻"的内容。
const double kSceneChangeDistance = 15.0;

/// 仅当候选帧清晰度显著高于当前最佳（≥3%）时才替换，避免无意义的帧切换。
const double kScoreImprovementRatio = 1.03;

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

/// worker 连拍选帧（清晰度评分）结果。
class CaptureWorkerScoreResult {
  const CaptureWorkerScoreResult({
    required this.ok,
    this.bestPath,
    this.bestScore = 0,
    this.previewBytes,
    this.needsDeblur = false,
  });
  final bool ok;

  /// 评分最高（最清晰）的帧文件路径；全部失败时为 null
  final String? bestPath;
  final double bestScore;

  /// 最清晰帧的降采样预览 JPEG 字节（用于角标渐进显示，先出原图预览），可为 null
  final Uint8List? previewBytes;

  /// 最清晰帧清晰度低于阈值（画面可能仍模糊），后处理应应用额外锐化去模糊
  final bool needsDeblur;
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
      'task': 'process',
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

  /// 对多张连拍帧做清晰度评分（拉普拉斯方差），返回最清晰帧路径 + 小图预览。
  ///
  /// 全部在 worker isolate 中执行，不阻塞 UI 线程；用于抗手抖连拍选帧。
  /// [smallRgba] / [smallW] / [smallH]：主 isolate 已用 dart:ui（OS 加速解码）把
  /// 每帧降采样到 240px 的 rawRgba 字节与宽高（并行列表，与 [paths] 一一对应）。
  /// 提供后 worker 直接包装成 img.Image 评分，跳过"读文件 + 纯 Dart 全量解码"
  /// （OHOS 上纯 Dart 解码 4000px JPEG 每帧 0.3-0.8s，是本方案最大耗时瓶颈）。
  /// 不提供（或长度不匹配）时回退到 worker 内自行读文件解码，行为不变。
  Future<CaptureWorkerScoreResult> scoreFrames(
    List<String> paths, {
    List<Uint8List>? smallRgba,
    List<int>? smallW,
    List<int>? smallH,
  }) async {
    await ensureStarted();
    final replyPort = ReceivePort();
    final msg = <String, dynamic>{
      'reply': replyPort.sendPort,
      'task': 'score',
      'paths': paths,
    };
    if (smallRgba != null && smallRgba.length == paths.length &&
        smallW != null && smallW.length == paths.length &&
        smallH != null && smallH.length == paths.length) {
      msg['smallRgba'] = smallRgba;
      msg['smallW'] = smallW;
      msg['smallH'] = smallH;
    }
    _sendPort!.send(msg);
    try {
      final result = await replyPort.first as Map;
      return CaptureWorkerScoreResult(
        ok: result['ok'] as bool? ?? false,
        bestPath: result['bestPath'] as String?,
        bestScore: (result['bestScore'] as num? ?? 0).toDouble(),
        previewBytes: result['previewBytes'] as Uint8List?,
        needsDeblur: result['needsDeblur'] as bool? ?? false,
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
    final task = msg['task'] as String? ?? 'process';

    // 连拍选帧评分：与后处理解耦，单独分支处理
    if (task == 'score') {
      try {
        await _handleScore(reply, msg);
      } catch (e, st) {
        stderr.writeln('[capture-worker] score failed: $e\n$st');
        reply.send({
          'ok': false,
          'bestPath': null,
          'bestScore': 0.0,
          'previewBytes': null,
          'needsDeblur': false,
        });
      }
      continue;
    }

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

/// 连拍选帧：对每帧解码并降到小图，用拉普拉斯方差评清晰度，返回最清晰帧 + 小图预览。
///
/// 关键规则：
/// 1. **中位帧作为场景一致性基准**，而非首帧：
///    - 某些平台（如 OHOS）camerawesome 的 takePhoto() 首帧可能是按下快门前的
///      预览缓冲区（stale buffer），用首帧做参考会导致真正的快门帧被拒绝。
///    - 中位帧（`paths.length ~/ 2`）在统计上最接近"按下快门瞬间"的内容。
/// 2. **场景一致性检测**：所有候选帧必须与基准帧亮度距离 ≤ kSceneChangeDistance，
///    超出阈值视为用户已经移动画面，直接拒绝，保证不选到快门后的新场景。
/// 3. **清晰度提升阈值**：仅当候选帧清晰度 ≥ 当前最佳 × kScoreImprovementRatio 时才替换，
///    避免无意义的小幅波动切换，保证只选到真正更清晰的帧。
/// 4. 当最终最佳帧清晰度低于 kBlurScoreThreshold 时，标记 needsDeblur=true，
///    后续后处理管线会应用更强的默认锐化来补偿运动模糊。
Future<void> _handleScore(SendPort reply, Map<dynamic, dynamic> msg) async {
  final paths = (msg['paths'] as List).cast<String>();
  if (paths.isEmpty) {
    reply.send({'ok': false, 'bestPath': null, 'bestScore': 0.0, 'previewBytes': null, 'needsDeblur': false});
    return;
  }

  // 主 isolate 已用 dart:ui（OS 加速）降采样好的 240px rawRgba（可选）。
  // 提供时直接包装评分，跳过"读文件 + 纯 Dart 全量解码"（OHOS 性能关键）。
  final smallRgba = (msg['smallRgba'] as List?)?.cast<Uint8List>();
  final smallW = (msg['smallW'] as List?)?.cast<int>();
  final smallH = (msg['smallH'] as List?)?.cast<int>();
  final useProvided = smallRgba != null &&
      smallRgba.length == paths.length &&
      smallW != null && smallW.length == paths.length &&
      smallH != null && smallH.length == paths.length;

  // 1. 准备所有帧的 240px 小图（评分和场景一致性检测用）
  final n = paths.length;
  final smallImages = <img.Image>[];
  final scores = <double>[];
  for (var i = 0; i < n; i++) {
    img.Image? small;
    try {
      if (useProvided) {
        final rgba = smallRgba[i];
        final w = smallW[i], h = smallH[i];
        if (rgba.isEmpty || w <= 0 || h <= 0) throw StateError('empty');
        small = img.Image.fromBytes(
          width: w,
          height: h,
          bytes: rgba.buffer,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
      } else {
        // 回退路径：worker 内读文件 + 纯 Dart 解码（无主 isolate 预解码时）
        final bytes = await File(paths[i]).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) throw StateError('decode null');
        small = img.copyResize(decoded, width: 240, interpolation: img.Interpolation.average);
      }
    } catch (e) {
      stderr.writeln('[capture-worker] score frame ${paths[i]} failed: $e');
      smallImages.add(img.Image(width: 240, height: 240)); // 占位空图，评分 0
      scores.add(0);
      continue;
    }
    smallImages.add(small);
    scores.add(_laplacianVariance(small));
  }

  // 2. 用中位帧作为场景一致性基准（而非首帧）
  //    中位帧在统计上最不容易是"过时缓冲区"或"移动后画面"：
  //    - OHOS 上 takePhoto() 首帧可能是按下快门前的预览缓冲区（stale buffer），
  //      若用首帧做参考会把真正的快门帧误判为"画面已变"而全部拒绝；
  //    - 末尾帧在用户拍完立即移动相机时可能是移动后的新画面。
  final refIdx = (n ~/ 2).clamp(0, n - 1);
  final refImage = smallImages[refIdx];

  // 3. 一致性过滤 + 评分选帧。
  //    - 先选出【最靠前】且与基准帧一致的帧作为初始最佳帧：连拍首帧最接近
  //      "按下快门瞬间"，后续帧可能已因用户移动而偏离快门内容；在清晰度相近
  //      时优先保留更靠前的帧，避免成片变成"拍完后移动过去的内容"。
  //    - 再向后扫描，仅当某帧与基准一致且清晰度显著提升（≥kScoreImprovementRatio）
  //      时才替换，兼顾抗手抖（选到真正更清晰的稳定瞬间）。
  final consistent = <bool>[];
  for (var i = 0; i < n; i++) {
    consistent.add(scores[i] > 0 &&
        _frameDistance(smallImages[i], refImage) <= kSceneChangeDistance);
  }

  double bestScore = 0;
  String? bestPath;
  img.Image? bestSmall;
  for (var i = 0; i < n; i++) {
    if (!consistent[i]) {
      if (i != refIdx) {
        stderr.writeln('[capture-worker] frame $i (${paths[i]}) scene changed, skipped');
      }
      continue;
    }
    final small = smallImages[i];
    final score = scores[i];
    if (bestPath == null || score > bestScore * kScoreImprovementRatio) {
      bestScore = score;
      bestPath = paths[i];
      bestSmall = small;
    }
  }
  // 理论上一定至少选中基准帧；防御性兜底
  bestPath ??= paths[refIdx];
  bestScore = bestScore < 0 ? 0.0 : bestScore;
  bestSmall ??= refImage;

  // 4. 判断是否需要额外去模糊：最佳帧清晰度低于阈值
  //    阈值 20 是经验值：240px 拉普拉斯方差 < 20 表示画面严重模糊
  const double kBlurScoreThreshold = 20.0;
  final needsDeblur = bestScore < kBlurScoreThreshold;

  // bestSmall 已由上方兜底保证非空
  final previewBytes = img.encodeJpg(bestSmall, quality: 85);
  reply.send({
    'ok': true,
    'bestPath': bestPath,
    'bestScore': bestScore < 0 ? 0.0 : bestScore,
    'previewBytes': previewBytes,
    'needsDeblur': needsDeblur,
  });
}

/// 拉普拉斯方差：衡量图像高频能量，值越大表示越清晰（运动模糊会抹平高频细节）。
double _laplacianVariance(img.Image image) {
  final w = image.width, h = image.height;
  if (w < 3 || h < 3) return 0;
  double sum = 0, sumSq = 0;
  int count = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final c = _lum(image.getPixel(x, y));
      final up = _lum(image.getPixel(x, y - 1));
      final down = _lum(image.getPixel(x, y + 1));
      final left = _lum(image.getPixel(x - 1, y));
      final right = _lum(image.getPixel(x + 1, y));
      final lap = (up + down + left + right) - 4 * c;
      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }
  if (count == 0) return 0;
  final mean = sum / count;
  return (sumSq / count) - mean * mean;
}

/// 帧间场景一致性检测：计算两图亮度通道的平均绝对差（越小越相似）。
/// 两图应为相同尺寸（调用方已 resize 到 240px），用于判断连拍帧是否
/// 仍属于"按下快门那一刻"的场景，防止拍完立即移动画面导致错帧。
double _frameDistance(img.Image a, img.Image b) {
  // 确保尺寸一致（copyResize 到 240x240 正方形中心裁切可能变形，
  // 这里用等比缩放到相同尺寸，保证逐像素对齐比较有效）
  final w = a.width < b.width ? a.width : b.width;
  final h = a.height < b.height ? a.height : b.height;
  final aResized = img.copyResize(a, width: w, height: h);
  final bResized = img.copyResize(b, width: w, height: h);

  double sum = 0;
  int count = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final lumA = _lum(aResized.getPixel(x, y));
      final lumB = _lum(bResized.getPixel(x, y));
      sum += (lumA - lumB).abs();
      count++;
    }
  }
  return count == 0 ? 0 : sum / count;
}

/// 近似亮度（Rec.601 系数），避免依赖 image 包版本间 grayscale API 差异。
double _lum(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
