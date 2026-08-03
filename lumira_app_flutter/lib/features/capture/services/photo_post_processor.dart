// lib/features/capture/services/photo_post_processor.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'skin_smoother.dart';
import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';

/// 拍照后照片处理器（GPU 加速 + 单次 Canvas 合并版）
///
/// 第 5 次优化：修复 RAW 模式下跳过裁剪导致非 WYSIWYG 的问题。
///
/// 核心原则：
/// - **裁剪始终应用**（保证取景器所见即所得，与 rawMode 无关）
/// - **rawMode 仅跳过滤镜效果**（ColorMatrix / Vignette / Sharpen / Clarity / Grain）
/// - 之前的版本在 rawMode=true 时直接返回原图，导致 4:3 传感器照片未被裁剪，
///   用户在全屏取景器看到 9:16 但拍出 4:3 照片
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
    String? outputPath,
    bool rawMode = false,
    String aspectRatio = 'fullscreen',
    double screenRatio = 9.0 / 19.5,
    bool isPortrait = true,
    TransformParams? transform,
    FillLightState? fillLight,
    String facing = 'back',
  }) async {
    // 注意：rawMode 不再跳过裁剪。裁剪是 WYSIWYG 的保证（取景器所见即所得），
    // rawMode 仅跳过滤镜效果（ColorMatrix / Vignette / Sharpen / Clarity / Grain）。
    // 之前的 `if (rawMode) return inputPath;` 会导致全屏取景 9:16 但照片为 4:3。
    final sw = Stopwatch()..start();
    try {
      debugPrint(
          '[post-process] 开始: ratio=$aspectRatio, screenRatio=$screenRatio, isPortrait=$isPortrait, rawMode=$rawMode');

      // 1. 读取并解码 JPEG（硬件加速，~50ms）
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();
      debugPrint(
          '[post-process] 解码: ${srcImage.width}x${srcImage.height}, facing=$facing, isPortrait=$isPortrait, ${sw.elapsedMilliseconds}ms');

      // 1.5. 方向对齐：把 JPEG 旋转到与取景器显示方向一致（WYSIWYG）
      // camerawesome 预览自动旋转 sensor，但 JPEG 保存为 sensor 原生方向。
      // 必须先旋转 JPEG 到显示方向，裁剪区域才能与取景器一致。
      // 前置摄像头额外水平翻转（预览是镜像的，照片也要镜像保持一致）。
      var alignedImage = await _alignOrientation(srcImage, isPortrait, facing);
      if (alignedImage != srcImage) {
        srcImage.dispose();
        debugPrint('[post-process] 方向对齐: '
            '${alignedImage.width}x${alignedImage.height}, ${sw.elapsedMilliseconds}ms');
      }

      // 1.6. 应用用户变换（旋转/翻转/拉直）via Canvas（GPU）
      var workingImage = alignedImage;
      if (transform != null && !transform.isIdentity) {
        workingImage = await _applyTransform(alignedImage, transform);
        alignedImage.dispose();
        debugPrint('[post-process] 变换: rotation=${transform.rotation}, '
            'flipH=${transform.flipH}, flipV=${transform.flipV}, '
            'straighten=${transform.straighten}, '
            '${sw.elapsedMilliseconds}ms');
      }

      // 2. 计算裁剪区域（基于 aspectRatio 和 screenRatio）—— 始终应用
      final cropRect = computeCropRect(
        aspectRatio,
        workingImage.width,
        workingImage.height,
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

      // 4. 单次 Canvas 调用：降采样 + 裁剪 + (rawMode 时跳过 ColorMatrix/Vignette)
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
      var resultImage = await picture.toImage(outW, outH);
      picture.dispose();
      workingImage.dispose();
      debugPrint(
          '[post-process] GPU合并: ${resultImage.width}x${resultImage.height}, ${sw.elapsedMilliseconds}ms');

      // 4.5. 皮肤平滑（受 smoothStrength 控制）
      if (!rawMode && params.smoothStrength > 0) {
        try {
          final byteData =
              await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData != null) {
            final imgImage = img.Image.fromBytes(
              width: resultImage.width,
              height: resultImage.height,
              bytes: byteData.buffer.asUint8List().buffer,
              numChannels: 4,
              order: img.ChannelOrder.rgba,
            );
            final smoothed =
                SkinSmoother.smooth(imgImage, params.smoothStrength);
            // Convert back to ui.Image
            final completer = ui.PictureRecorder();
            final canvas = ui.Canvas(completer);
            final paint = ui.Paint();
            // Encode smoothed image to bytes and decode back
            final smoothedBytes = img.encodePng(smoothed);
            final codec = await ui.instantiateImageCodec(smoothedBytes);
            final frame = await codec.getNextFrame();
            canvas.drawImage(frame.image, ui.Offset.zero, paint);
            final picture = completer.endRecording();
            final newImage =
                await picture.toImage(smoothed.width, smoothed.height);
            resultImage.dispose();
            resultImage = newImage;
            frame.image.dispose();
            codec.dispose();
            picture.dispose();
            debugPrint(
                '[post-process] 皮肤平滑: smoothStrength=${params.smoothStrength}, ${sw.elapsedMilliseconds}ms');
          }
        } catch (e) {
          debugPrint('[post-process] 皮肤平滑失败（静默跳过）: $e');
        }
      }

      // 5. 逐像素效果（rawMode 跳过；仅在启用时用 img 包处理）
      if (!rawMode) {
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
      }

      // 5.5. 补光效果不应用到照片
      // 补光是屏幕发光照亮被摄物（物理光源），不应作为颜色滤镜叠加到照片上。

      // 6. 编码 JPEG 并保存
      final jpegBytes = await _encodeJpeg(resultImage);
      final finalPath = outputPath ?? inputPath;
      await File(finalPath).writeAsBytes(jpegBytes);
      resultImage.dispose();

      sw.stop();
      debugPrint('[post-process] 完成: ${sw.elapsedMilliseconds}ms');
      return finalPath;
    } catch (e, st) {
      sw.stop();
      // 裁剪/处理失败时返回原图（4:3 传感器比例），但明确警告 WYSIWYG 已破坏。
      // 之前的版本静默返回原图，用户无法察觉裁剪未应用，导致"取景器 9:16 但照片 4:3"。
      debugPrint(
          '[post-process] ⚠️ 失败 (${sw.elapsedMilliseconds}ms), WYSIWYG 已破坏: $e\n$st');
      return outputPath ?? inputPath;
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

  /// 把 JPEG 像素旋转到与取景器显示方向一致（WYSIWYG）。
  /// 与 DartPhotoPipeline._alignOrientationUi 逻辑一致。
  static Future<ui.Image> _alignOrientation(
      ui.Image src, bool isPortrait, String facing) async {
    final jpegIsLandscape = src.width > src.height;
    final deviceIsPortrait = isPortrait;
    final needRotate = (deviceIsPortrait && jpegIsLandscape) ||
        (!deviceIsPortrait && !jpegIsLandscape);
    final needMirror = facing == 'front';
    if (!needRotate && !needMirror) return src;

    final rotation = deviceIsPortrait ? 90 : 270;
    final outW = needRotate ? src.height : src.width;
    final outH = needRotate ? src.width : src.height;
    final radians = rotation * math.pi / 180.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(outW / 2.0, outH / 2.0);
    canvas.rotate(radians);
    canvas.scale(needMirror ? -1.0 : 1.0, 1.0);
    canvas.drawImage(
      src,
      ui.Offset(-src.width / 2.0, -src.height / 2.0),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final picture = recorder.endRecording();
    final result = await picture.toImage(outW, outH);
    picture.dispose();
    return result;
  }

  /// 应用变换（旋转/翻转/拉直）via GPU Canvas
  static Future<ui.Image> _applyTransform(
    ui.Image src,
    TransformParams transform,
  ) async {
    final radians = transform.rotation * math.pi / 180.0;
    final straightenRad = transform.straighten * math.pi / 180.0;
    final totalRotation = radians + straightenRad;

    // For 90/270 rotations, swap dimensions
    final swapDims = transform.rotation == 90 || transform.rotation == 270;
    final outW = swapDims ? src.height : src.width;
    final outH = swapDims ? src.width : src.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // For straighten, we need a larger canvas and crop later
    // For pure 90/180/270 + flip, use exact dimensions
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

  /// 计算裁剪区域 [x, y, width, height]
  ///
  /// 关键：使用与取景器 [CaptureState.computeTargetRatio] 完全一致的比例计算逻辑，
  /// 确保拍照裁剪区域与取景器显示区域一致（所见即所得）。
  ///
  /// 两种模式：
  /// - 'fullscreen'：单步 cover 裁剪到 screenRatio（与之前一致）
  /// - 其他比例：两步裁剪保证 WYSIWYG
  ///   1. 先按 screenRatio 模拟 cover 裁剪（匹配相机流 cover 行为，
  ///      因为相机流铺满全屏时传感器会被裁剪以匹配屏幕比例）
  ///   2. 再在可见区域内按 targetRatio 裁剪（匹配 _CropGuideOverlay 框线区域）
  static List<int> computeCropRect(
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

    final imgRatio = imgW / imgH;

    // fullscreen 模式：直接按 screenRatio cover 裁剪（与之前一致）
    if (ratio == 'fullscreen') {
      double cropW, cropH;
      if (imgRatio > screenRatio) {
        // 图片比屏幕更宽 → 裁剪左右
        cropH = imgH.toDouble();
        cropW = cropH * screenRatio;
      } else {
        // 图片比屏幕更高 → 裁剪上下
        cropW = imgW.toDouble();
        cropH = cropW / screenRatio;
      }
      cropW = cropW.clamp(1.0, imgW.toDouble());
      cropH = cropH.clamp(1.0, imgH.toDouble());
      final offsetX = ((imgW - cropW) / 2.0).round().clamp(0, imgW - 1);
      final offsetY = ((imgH - cropH) / 2.0).round().clamp(0, imgH - 1);
      final width = cropW.round().clamp(1, imgW - offsetX);
      final height = cropH.round().clamp(1, imgH - offsetY);
      debugPrint('[post-process] fullscreen 单步裁剪: imgRatio=$imgRatio, '
          'screenRatio=$screenRatio, 裁剪后比例=${width / height}');
      return [offsetX, offsetY, width, height];
    }

    // 非 fullscreen 模式：两步裁剪保证 WYSIWYG
    // 第 1 步：模拟相机流 cover 到屏幕比例（裁剪传感器以匹配屏幕）
    double visW, visH, visOffsetX, visOffsetY;
    if (imgRatio > screenRatio) {
      // 传感器比屏幕更宽 → 裁左右
      visH = imgH.toDouble();
      visW = visH * screenRatio;
      visOffsetX = (imgW - visW) / 2.0;
      visOffsetY = 0.0;
    } else {
      // 传感器比屏幕更窄 → 裁上下
      visW = imgW.toDouble();
      visH = visW / screenRatio;
      visOffsetX = 0.0;
      visOffsetY = (imgH - visH) / 2.0;
    }

    // 第 2 步：在可见区域内按 targetRatio 裁剪（对应辅助线框区域）
    final visRatio = visW / visH;
    double cropW, cropH;
    if (visRatio > targetRatio) {
      // 可见区域比目标更宽 → 裁左右
      cropH = visH;
      cropW = visH * targetRatio;
    } else {
      // 可见区域比目标更窄 → 裁上下
      cropW = visW;
      cropH = visW / targetRatio;
    }

    // 计算最终裁剪区域在原图中的位置
    // 水平方向居中，垂直方向顶部对齐（与取景器 _AnimatedCropOverlay 竖屏顶部对齐一致）
    final offsetX =
        (visOffsetX + (visW - cropW) / 2.0).round().clamp(0, imgW - 1);
    final offsetY = visOffsetY.round().clamp(0, imgH - 1);
    final width = cropW.round().clamp(1, imgW - offsetX);
    final height = cropH.round().clamp(1, imgH - offsetY);

    debugPrint(
        '[post-process] 两步裁剪: imgRatio=$imgRatio, screenRatio=$screenRatio, '
        'targetRatio=$targetRatio, 裁剪后比例=${width / height}');

    return [offsetX, offsetY, width, height];
  }
}
