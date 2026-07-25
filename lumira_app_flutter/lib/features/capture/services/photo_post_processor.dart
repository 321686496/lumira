// lib/features/capture/services/photo_post_processor.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';

/// 拍照后照片处理器（GPU 加速 + 单次 Canvas 合并版）
///
/// 第 4 次优化：解决速度慢、照片内容与取景器不一致、变形三个问题。
///
/// 核心优化：
/// 1. **合并所有 GPU 操作到一次 Canvas 调用**（降采样+ColorMatrix+裁剪+Vignette）
///    原方案 5 次 picture.toImage() → 新方案 1 次，节省 150-200ms
/// 2. **按屏幕比例裁剪 fullscreen 模式**：照片与取景器 cover 显示完全一致
/// 3. **降采样到 1536px**（从 2048px 降低，平衡质量和速度）
///
/// 性能预期：无逐像素效果 ~200ms，有逐像素效果 ~400ms
class PhotoPostProcessor {
  PhotoPostProcessor._();

  /// 处理拍照后的照片文件
  ///
  /// [screenRatio] 屏幕宽高比（width/height），用于 fullscreen 模式按取景器裁剪
  /// [isPortrait] 设备是否为竖屏，用于 '4:3' 等比例的方向自适应裁剪
  static Future<String> processFile({
    required String inputPath,
    required PostProcess params,
    bool rawMode = false,
    String aspectRatio = 'fullscreen',
    double screenRatio = 9.0 / 19.5,
    bool isPortrait = true,
  }) async {
    if (rawMode) {
      debugPrint('[post-process] rawMode=true, 跳过处理');
      return inputPath;
    }

    final sw = Stopwatch()..start();
    try {
      debugPrint('[post-process] 开始: ratio=$aspectRatio, screenRatio=$screenRatio, isPortrait=$isPortrait');

      // 1. 读取并解码 JPEG（硬件加速，~50ms）
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();
      debugPrint('[post-process] 解码: ${srcImage.width}x${srcImage.height}, ${sw.elapsedMilliseconds}ms');

      // 2. 计算裁剪区域（基于 aspectRatio 和 screenRatio）
      final cropRect = _computeCropRect(
        aspectRatio,
        srcImage.width,
        srcImage.height,
        screenRatio,
        isPortrait,
      );
      debugPrint('[post-process] 裁剪区域: $cropRect');

      // 3. 计算降采样后的输出尺寸（长边 ≤ 1536，严格保持裁剪区域比例）
      const maxDimension = 1536;
      var outW = cropRect[2];
      var outH = cropRect[3];
      if (outW > maxDimension || outH > maxDimension) {
        final scale = maxDimension / math.max(outW, outH);
        outW = (outW * scale).round();
        outH = (outH * scale).round();
      }
      // 严格保持目标比例（防止 round 引入的 ±1px 误差累积）
      final targetRatio = outW / outH;
      final intendedRatio = cropRect[2] / cropRect[3];
      if ((targetRatio - intendedRatio).abs() > 0.005) {
        // 重新计算 outH 让比例匹配
        outH = (outW / intendedRatio).round();
      }

      // 4. 单次 Canvas 调用：降采样 + ColorMatrix + 裁剪 + Vignette
      final matrix = composePostProcessMatrix(params);
      final hasMatrix = !_isIdentityMatrix(matrix);
      final hasVignette = params.vignette > 0;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 4a. 绘制照片（裁剪 + 降采样 + ColorMatrix 一步完成）
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
      if (hasMatrix) {
        paint.colorFilter = ui.ColorFilter.matrix(matrix);
      }
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(
          cropRect[0].toDouble(),
          cropRect[1].toDouble(),
          cropRect[2].toDouble(),
          cropRect[3].toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        paint,
      );

      // 4b. Vignette（在同一 Canvas 上叠加）
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
      var resultImage = await picture.toImage(outW, outH);
      picture.dispose();
      srcImage.dispose();
      debugPrint('[post-process] GPU合并: ${resultImage.width}x${resultImage.height}, ${sw.elapsedMilliseconds}ms');

      // 5. 逐像素效果（仅在启用时，用 img 包处理）
      final clarityVal = params.color.clarity;
      final needsPerPixel = params.sharpen > 0 ||
          (clarityVal != null && clarityVal != 0) ||
          params.grain > 0;
      if (needsPerPixel) {
        resultImage = await _applyPerPixelEffects(
          resultImage,
          sharpen: params.sharpen,
          clarity: clarityVal,
          grain: params.grain,
        );
        debugPrint('[post-process] 逐像素: ${sw.elapsedMilliseconds}ms');
      }

      // 6. 编码 JPEG 并保存
      final jpegBytes = await _encodeJpeg(resultImage);
      await file.writeAsBytes(jpegBytes);
      resultImage.dispose();

      sw.stop();
      debugPrint('[post-process] 完成: ${sw.elapsedMilliseconds}ms');
      return inputPath;
    } catch (e, st) {
      sw.stop();
      debugPrint('[post-process] 失败 (${sw.elapsedMilliseconds}ms): $e\n$st');
      return inputPath;
    }
  }

  /// 逐像素效果：Sharpen + Clarity + Grain
  static Future<ui.Image> _applyPerPixelEffects(
    ui.Image input, {
    required int sharpen,
    required double? clarity,
    required int grain,
  }) async {
    final width = input.width;
    final height = input.height;

    final byteData = await input.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return input;

    final imgImage = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: byteData.buffer.asUint8List().buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    // Sharpen
    if (sharpen > 0) {
      final a = (sharpen / 100.0).clamp(0.0, 1.0);
      img.convolution(
        imgImage,
        filter: [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0],
        div: 1.0,
        amount: 1.0,
      );
    }

    // Clarity
    if (clarity != null && clarity != 0) {
      final amount = (clarity.abs() / 100.0).clamp(0.0, 1.0) * 0.6;
      final sign = clarity > 0 ? 1.0 : -1.0;
      final blurred = img.gaussianBlur(img.Image.from(imgImage), radius: 3);
      for (final p in imgImage) {
        final bp = blurred.getPixel(p.x, p.y);
        p
          ..r = (p.r + (p.r - bp.r) * sign * amount).clamp(0, 255)
          ..g = (p.g + (p.g - bp.g) * sign * amount).clamp(0, 255)
          ..b = (p.b + (p.b - bp.b) * sign * amount).clamp(0, 255);
      }
    }

    // Grain
    if (grain > 0) {
      final intensity = (grain / 100.0).clamp(0.0, 1.0) * 0.25;
      const maxOffset = 64.0;
      final random = math.Random(42);
      for (final p in imgImage) {
        final noise = (random.nextDouble() * 2 - 1) * intensity * maxOffset;
        p
          ..r = (p.r + noise).clamp(0, 255)
          ..g = (p.g + noise).clamp(0, 255)
          ..b = (p.b + noise).clamp(0, 255);
      }
    }

    // 转回 ui.Image
    final outBytes = imgImage.getBytes(order: img.ChannelOrder.rgba);
    final buffer = await ui.ImmutableBuffer.fromUint8List(outBytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    buffer.dispose();
    descriptor.dispose();
    codec.dispose();
    input.dispose();
    return frame.image;
  }

  /// 编码 JPEG
  static Future<Uint8List> _encodeJpeg(ui.Image image) async {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw StateError('toByteData(rawRgba) 返回 null');
    }
    final imgImage = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: rgba.buffer.asUint8List().buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(imgImage, quality: 88);
  }

  /// 判断是否为单位矩阵
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

  /// 计算裁剪区域 [x, y, width, height]
  ///
  /// 关键：使用与取景器 [CaptureState.computeTargetRatio] 完全一致的比例计算逻辑，
  /// 确保拍照裁剪区域与取景器显示区域一致（所见即所得）。
  /// 'fullscreen' 模式按 screenRatio 裁剪，其他模式按方向自适应的目标比例裁剪。
  static List<int> _computeCropRect(
    String ratio,
    int imgW,
    int imgH,
    double screenRatio,
    bool isPortrait,
  ) {
    // 不裁剪的情况
    if (ratio == 'free' || ratio == 'none') {
      return [0, 0, imgW, imgH];
    }

    // 计算目标比例（与取景器 _ViewfinderArea 使用同一逻辑）
    final targetRatio =
        CaptureState.computeTargetRatio(ratio, isPortrait) ?? screenRatio;

    // cover 裁剪算法：与 CameraPreviewFit.cover 完全一致
    final imgRatio = imgW / imgH;
    double cropW, cropH;
    if (imgRatio > targetRatio) {
      // 图片比目标更宽 → 裁剪左右
      cropH = imgH.toDouble();
      cropW = cropH * targetRatio;
    } else {
      // 图片比目标更高 → 裁剪上下
      cropW = imgW.toDouble();
      cropH = cropW / targetRatio;
    }

    // 严格 clamp 到图像边界内
    cropW = cropW.clamp(1.0, imgW.toDouble());
    cropH = cropH.clamp(1.0, imgH.toDouble());

    final offsetX = ((imgW - cropW) / 2.0).round().clamp(0, imgW - 1);
    final offsetY = ((imgH - cropH) / 2.0).round().clamp(0, imgH - 1);
    final width = cropW.round().clamp(1, imgW - offsetX);
    final height = cropH.round().clamp(1, imgH - offsetY);

    // 诊断日志：输出最终裁剪后的比例，便于与取景器对比
    debugPrint('[post-process] 目标比例=$targetRatio, 图像比例=$imgRatio, '
        '裁剪后比例=${width / height}');

    return [offsetX, offsetY, width, height];
  }
}
