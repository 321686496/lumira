// lib/features/capture/services/dart_photo_pipeline.dart
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import 'photo_pipeline.dart';
import 'photo_post_processor.dart';
import 'skin_smoother.dart';

/// 基于 Dart（dart:ui Canvas + image 包）的双管线 PhotoPipeline 实现。
///
/// - [quickProcess]：主 Isolate，用 dart:ui Canvas（GPU 加速）做解码+裁剪+
///   ColorMatrix+Vignette，返回 PNG 内存字节，目标 <100ms。
/// - [fullProcess]：通过 [compute] 把纯 image 包实现丢到 worker Isolate，
///   完成全部逐像素效果（皮肤平滑/Sharpen/Clarity/Grain/补光/JPEG 编码），
///   返回最终文件路径。失败时降级调用 [PhotoPostProcessor.processFile]。
class DartPhotoPipeline implements PhotoPipeline {
  DartPhotoPipeline();

  // ─────────────────────────────────────────────────────────────────────
  // quickProcess：主 Isolate，dart:ui Canvas
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 读取并解码 JPEG（dart:ui，主 Isolate 独占）
      final bytes = await io.File(inputPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();
      debugPrint(
          '[quickProcess] 解码: ${srcImage.width}x${srcImage.height}, ${sw.elapsedMilliseconds}ms');

      // 1.5 应用变换（旋转/翻转/拉直）via Canvas（GPU）
      var workingImage = srcImage;
      if (transform != null && !transform.isIdentity) {
        workingImage = await _applyTransformUi(srcImage, transform);
        srcImage.dispose();
      }

      // 2. 裁剪区域计算（复用 PhotoPostProcessor.computeCropRect）
      final cropRect = PhotoPostProcessor.computeCropRect(
        aspectRatio,
        workingImage.width,
        workingImage.height,
        screenRatio,
        isPortrait,
      );

      // 3. 降采样到长边 ≤ 1536（严格保持裁剪区域比例）
      const maxDimension = 1536;
      var outW = cropRect[2];
      var outH = cropRect[3];
      if (outW > maxDimension || outH > maxDimension) {
        final scale = maxDimension / math.max(outW, outH);
        outW = (outW * scale).round();
        outH = (outH * scale).round();
      }
      // 严格保持目标比例（防止 round 引入的 ±1px 误差）
      final intendedRatio = cropRect[2] / cropRect[3];
      if ((outW / outH - intendedRatio).abs() > 0.005) {
        outH = (outW / intendedRatio).round();
      }

      // 4. 单次 Canvas：裁剪+降采样 + ColorMatrix + Vignette
      final matrix = rawMode ? null : composePostProcessMatrix(params);
      final hasMatrix = matrix != null && !_isIdentityMatrix(matrix);
      final hasVignette = !rawMode && params.vignette > 0;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 4a. 绘制照片（裁剪 + 降采样 + ColorMatrix 一步完成）
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
      if (hasMatrix) {
        paint.colorFilter = ui.ColorFilter.matrix(matrix);
      }
      canvas.drawImageRect(
        workingImage,
        ui.Rect.fromLTWH(
          cropRect[0].toDouble(),
          cropRect[1].toDouble(),
          cropRect[2].toDouble(),
          cropRect[3].toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        paint,
      );

      // 4b. Vignette（在同一 Canvas 上叠加，rawMode 跳过）
      if (hasVignette) {
        final centerX = outW / 2.0;
        final centerY = outH / 2.0;
        final radius = math.sqrt(centerX * centerX + centerY * centerY);
        final vignetteAlpha = params.vignette / 100.0 * 0.5;
        final vignettePaint = ui.Paint()
          ..shader = ui.Gradient.radial(
            ui.Offset(centerX, centerY),
            radius,
            [
              const ui.Color(0x00000000),
              ui.Color.fromRGBO(0, 0, 0, vignetteAlpha),
            ],
            [0.5, 1.0],
            ui.TileMode.clamp,
          );
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
          vignettePaint,
        );
      }

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(outW, outH);
      picture.dispose();
      workingImage.dispose();
      debugPrint(
          '[quickProcess] GPU合并: ${outImage.width}x${outImage.height}, ${sw.elapsedMilliseconds}ms');

      // 5. 导出 PNG 字节（PNG 无损，角标预览用）
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      outImage.dispose();
      if (byteData == null) {
        debugPrint('[quickProcess] toByteData(png) 返回 null');
        return null;
      }

      final elapsed = sw.elapsedMilliseconds;
      debugPrint('[quickProcess] 完成: ${elapsed}ms');
      if (elapsed > 200) {
        debugPrint('[quickProcess] WARN: 超出 200ms 预算 (${elapsed}ms)');
      }
      return QuickResult(
        bytes: byteData.buffer.asUint8List(),
        width: outW,
        height: outH,
      );
    } catch (e, st) {
      debugPrint('[quickProcess] 失败: $e\n$st');
      return null;
    } finally {
      sw.stop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // fullProcess：worker Isolate（compute），image 包纯 Dart
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<FullResult> fullProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    FillLightState? fillLight,
    String? outputPath,
  }) async {
    final sw = Stopwatch()..start();
    final finalOutputPath = outputPath ?? inputPath.replaceAll('.jpg', '_final.jpg');

    try {
      // 1. 主 Isolate 读取原图字节
      final inputBytes = await io.File(inputPath).readAsBytes();

      // 2. 构造 Isolate 输入（全部可序列化的字段）
      final isolateInput = _IsolateInput(
        inputBytes: inputBytes,
        params: params,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
        rawMode: rawMode,
        transform: transform,
        fillLight: fillLight,
      );

      // 3. 在 worker Isolate 中执行完整处理
      //    用 compute() 而非 Isolate.run —— compute() 在所有 Flutter 平台
      //    （含 OHOS Flutter 3.7）上可用，API 更简单，内部封装 Isolate。
      final result = await compute(_processInIsolate, isolateInput);

      // 4. 主 Isolate 写文件
      await io.File(finalOutputPath).writeAsBytes(result.bytes);

      debugPrint('[fullProcess] 完成: ${sw.elapsedMilliseconds}ms');
      return FullResult(
        filePath: finalOutputPath,
        width: result.width,
        height: result.height,
      );
    } catch (e, st) {
      debugPrint('[fullProcess] Isolate 失败，降级到 PhotoPostProcessor: $e\n$st');
      // 5. 降级：用主 Isolate 的 PhotoPostProcessor.processFile
      try {
        final path = await PhotoPostProcessor.processFile(
          inputPath: inputPath,
          params: params,
          outputPath: finalOutputPath,
          rawMode: rawMode,
          aspectRatio: aspectRatio,
          screenRatio: screenRatio,
          isPortrait: isPortrait,
          transform: transform,
          fillLight: fillLight,
        );
        debugPrint('[fullProcess] 降级完成: ${sw.elapsedMilliseconds}ms');
        return FullResult(filePath: path, width: 0, height: 0);
      } catch (e2, st2) {
        debugPrint('[fullProcess] 降级也失败: $e2\n$st2');
        return FullResult(filePath: finalOutputPath, width: 0, height: 0);
      }
    } finally {
      sw.stop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 主 Isolate 辅助：dart:ui Canvas 变换
  // ─────────────────────────────────────────────────────────────────────

  /// 应用变换（旋转/翻转/拉直）via GPU Canvas。
  /// 从 PhotoPostProcessor._applyTransform 移植。
  Future<ui.Image> _applyTransformUi(ui.Image src, TransformParams transform) async {
    final radians = transform.rotation * math.pi / 180.0;
    final straightenRad = transform.straighten * math.pi / 180.0;
    final totalRotation = radians + straightenRad;

    // For 90/270 rotations, swap dimensions
    final swapDims = transform.rotation == 90 || transform.rotation == 270;
    final outW = swapDims ? src.height : src.width;
    final outH = swapDims ? src.width : src.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.translate(outW / 2, outH / 2);
    canvas.rotate(totalRotation);
    canvas.scale(
      transform.flipH ? -1.0 : 1.0,
      transform.flipV ? -1.0 : 1.0,
    );
    canvas.drawImage(
      src,
      ui.Offset(-src.width / 2, -src.height / 2),
      ui.Paint(),
    );

    final picture = recorder.endRecording();
    final result = await picture.toImage(outW, outH);
    picture.dispose();
    return result;
  }

  /// 判断 4×5 ColorMatrix 是否为单位矩阵。
  /// 从 PhotoPostProcessor._isIdentityMatrix 移植。
  static bool _isIdentityMatrix(List<double> m) {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        final idx = i * 5 + j;
        final expected = (i == j) ? 1.0 : 0.0;
        if ((m[idx] - expected).abs() > 0.001) return false;
      }
      if (m[i * 5 + 4].abs() > 0.001) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Isolate 通信类型（全部可序列化）
// ─────────────────────────────────────────────────────────────────────────

/// compute() 的输入参数。所有字段必须可跨 Isolate 传递。
class _IsolateInput {
  const _IsolateInput({
    required this.inputBytes,
    required this.params,
    required this.aspectRatio,
    required this.screenRatio,
    required this.isPortrait,
    required this.rawMode,
    required this.transform,
    required this.fillLight,
  });

  final Uint8List inputBytes;
  final PostProcess params;
  final String aspectRatio;
  final double screenRatio;
  final bool isPortrait;
  final bool rawMode;
  final TransformParams? transform;
  final FillLightState? fillLight;
}

/// compute() 的输出。所有字段必须可跨 Isolate 传递。
class _IsolateResult {
  const _IsolateResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

// ─────────────────────────────────────────────────────────────────────────
// 顶层函数：worker Isolate 入口（compute 要求顶层或静态）
// 纯 image 包实现，无 dart:ui 依赖
// ─────────────────────────────────────────────────────────────────────────

/// 在 worker Isolate 中执行完整照片后处理。
///
/// 从 [PhotoPostProcessor] 移植全部逻辑到 image 包 API：
/// - 解码 → 变换 → 裁剪 → 降采样 → ColorMatrix → 皮肤平滑 → Sharpen/Clarity/Grain → 补光 → JPEG 编码
Future<_IsolateResult> _processInIsolate(_IsolateInput input) async {
  // 1. 解码 JPEG（image 包）
  final decoded = img.decodeJpg(input.inputBytes);
  if (decoded == null) {
    throw StateError('img.decodeJpg 返回 null');
  }
  var image = decoded;

  // 2. 变换（旋转/翻转/拉直）—— 从 PhotoPostProcessor._applyTransform 移植到 image 包
  if (input.transform != null && !input.transform!.isIdentity) {
    image = _applyTransformImg(image, input.transform!);
  }

  // 3. 裁剪（复用 PhotoPostProcessor.computeCropRect 纯数学计算）
  final cropRect = PhotoPostProcessor.computeCropRect(
    input.aspectRatio,
    image.width,
    image.height,
    input.screenRatio,
    input.isPortrait,
  );
  image = img.copyCrop(
    image,
    x: cropRect[0],
    y: cropRect[1],
    width: cropRect[2],
    height: cropRect[3],
  );

  // 4. 降采样到长边 ≤ 1536
  const maxDimension = 1536;
  if (image.width > maxDimension || image.height > maxDimension) {
    final scale = maxDimension / math.max(image.width, image.height);
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  // 5. ColorMatrix 逐像素应用（rawMode 跳过）
  if (!input.rawMode) {
    final matrix = composePostProcessMatrix(input.params);
    if (!_isIdentityMatrixImg(matrix)) {
      image = _applyColorMatrixImg(image, matrix);
    }
  }

  // 6. 皮肤平滑（rawMode 跳过）—— 直接复用 SkinSmoother（已是纯 image 包实现）
  if (!input.rawMode && input.params.smoothStrength > 0) {
    try {
      image = SkinSmoother.smooth(image, input.params.smoothStrength);
    } catch (e) {
      // 皮肤平滑失败不阻塞，静默跳过
    }
  }

  // 7. Sharpen / Clarity / Grain（rawMode 跳过）
  //    从 PhotoPostProcessor._applyPerPixelEffects 移植到 image 包
  if (!input.rawMode) {
    final clarityVal = input.params.color.clarity;
    final needsPerPixel = input.params.sharpen > 0 ||
        (clarityVal != null && clarityVal != 0) ||
        input.params.grain > 0;
    if (needsPerPixel) {
      _applyPerPixelEffectsImg(
        image,
        sharpen: input.params.sharpen,
        clarity: clarityVal,
        grain: input.params.grain,
      );
    }
  }

  // 8. 补光（rawMode 跳过）—— 从 PhotoPostProcessor._applyFillLight 移植
  if (!input.rawMode && input.fillLight != null) {
    _applyFillLightImg(image, input.fillLight!);
  }

  // 9. JPEG 编码（quality: 88，与 PhotoPostProcessor._encodeJpg 一致）
  final outputBytes = img.encodeJpg(image, quality: 88);

  return _IsolateResult(
    bytes: Uint8List.fromList(outputBytes),
    width: image.width,
    height: image.height,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// image 包逐像素实现（从 PhotoPostProcessor 移植）
// ─────────────────────────────────────────────────────────────────────────

/// 应用变换（旋转/翻转/拉直）via image 包。
/// 从 PhotoPostProcessor._applyTransform 移植，把 dart:ui Canvas 调用改为 image 包 API。
img.Image _applyTransformImg(img.Image src, TransformParams t) {
  var result = src;

  // 1. 旋转（90/180/270 度精确旋转，image 包自动处理维度交换）
  if (t.rotation != 0) {
    result = img.copyRotate(result, angle: t.rotation.toDouble());
  }

  // 2. 拉直（小角度旋转，image 包会扩展画布以容纳旋转后的图像）
  if (t.straighten.abs() >= 0.01) {
    result = img.copyRotate(result, angle: t.straighten);
  }

  // 3. 翻转
  if (t.flipH) {
    result = img.flip(result, direction: img.FlipDirection.horizontal);
  }
  if (t.flipV) {
    result = img.flip(result, direction: img.FlipDirection.vertical);
  }

  return result;
}

/// 逐像素应用 4×5 ColorMatrix。
/// matrix 长度 20，按行优先存储：
///   R' = m[0]*R + m[1]*G + m[2]*B + m[3]*A + m[4]
///   G' = m[5]*R + m[6]*G + m[7]*B + m[8]*A + m[9]
///   B' = m[10]*R + m[11]*G + m[12]*B + m[13]*A + m[14]
///   A' = m[15]*R + m[16]*G + m[17]*B + m[18]*A + m[19]
///
/// 像素值范围 0-255（与 dart:ui ColorFilter.matrix 一致）。
img.Image _applyColorMatrixImg(img.Image image, List<double> m) {
  for (final p in image) {
    final r = p.r;
    final g = p.g;
    final b = p.b;
    final a = p.a;
    p
      ..r = (m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4]).clamp(0, 255)
      ..g = (m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9]).clamp(0, 255)
      ..b = (m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]).clamp(0, 255)
      ..a = (m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19]).clamp(0, 255);
  }
  return image;
}

/// Sharpen + Clarity + Grain 逐像素效果。
/// 从 PhotoPostProcessor._applyPerPixelEffects 移植，去掉 ui.Image ↔ img.Image 转换。
void _applyPerPixelEffectsImg(
  img.Image image, {
  required int sharpen,
  required double? clarity,
  required int grain,
}) {
  // Sharpen（卷积核）
  if (sharpen > 0) {
    final a = (sharpen / 100.0).clamp(0.0, 1.0);
    img.convolution(
      image,
      filter: [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0],
      div: 1.0,
      amount: 1.0,
    );
  }

  // Clarity（中频对比度：原图 - 高斯模糊，再按 amount 混合）
  if (clarity != null && clarity != 0) {
    final amount = (clarity.abs() / 100.0).clamp(0.0, 1.0) * 0.6;
    final sign = clarity > 0 ? 1.0 : -1.0;
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 3);
    for (final p in image) {
      final bp = blurred.getPixel(p.x, p.y);
      p
        ..r = (p.r + (p.r - bp.r) * sign * amount).clamp(0, 255)
        ..g = (p.g + (p.g - bp.g) * sign * amount).clamp(0, 255)
        ..b = (p.b + (p.b - bp.b) * sign * amount).clamp(0, 255);
    }
  }

  // Grain（胶片颗粒噪声）
  if (grain > 0) {
    final intensity = (grain / 100.0).clamp(0.0, 1.0) * 0.25;
    const maxOffset = 64.0;
    final random = math.Random(42);
    for (final p in image) {
      final noise = (random.nextDouble() * 2 - 1) * intensity * maxOffset;
      p
        ..r = (p.r + noise).clamp(0, 255)
        ..g = (p.g + noise).clamp(0, 255)
        ..b = (p.b + noise).clamp(0, 255);
    }
  }
}

/// 补光：BlendMode.multiply 等价实现。
/// 从 PhotoPostProcessor._applyFillLight 移植，把 Canvas 调用改为 image 包逐像素。
///
/// 算法（与 Canvas BlendMode.multiply + alpha 一致）：
///   final = dst * (1 - alpha) + (dst * light / 255) * alpha
/// 其中 alpha = intensity * 0.7，light = 补光颜色 RGB 分量。
void _applyFillLightImg(img.Image image, FillLightState state) {
  final alpha = (state.intensity * 0.7).clamp(0.0, 1.0);
  if (alpha <= 0) return;

  final lightR = state.color.red.toDouble();
  final lightG = state.color.green.toDouble();
  final lightB = state.color.blue.toDouble();
  final invAlpha = 1.0 - alpha;

  for (final p in image) {
    final r = p.r;
    final g = p.g;
    final b = p.b;
    p
      ..r = (r * invAlpha + r * lightR / 255.0 * alpha).clamp(0, 255)
      ..g = (g * invAlpha + g * lightG / 255.0 * alpha).clamp(0, 255)
      ..b = (b * invAlpha + b * lightB / 255.0 * alpha).clamp(0, 255);
  }
}

/// 判断 4×5 ColorMatrix 是否为单位矩阵（Isolate 内独立副本）。
bool _isIdentityMatrixImg(List<double> m) {
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      final idx = i * 5 + j;
      final expected = (i == j) ? 1.0 : 0.0;
      if ((m[idx] - expected).abs() > 0.001) return false;
    }
    if (m[i * 5 + 4].abs() > 0.001) return false;
  }
  return true;
}
