// lib/features/capture/services/photo_post_processor.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'skin_smoother.dart';
import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';

// ─────────────────────────────────────────────────────────────────────────
// iOS 宽色域（Display P3）JPEG 的色域校正
// ─────────────────────────────────────────────────────────────────────────
//
// iPhone 宽色域相机的 AVCapturePhoto JPEG（CameraPictureController.m 直接落盘原始
// 传感器字节）内嵌 Display P3 的 ICC 配置。取景器（AVCaptureVideoPreviewLayer）在
// 设备 P3 显示色域下原生渲染，故肤色自然；但成图侧 `ui.instantiateImageCodec` 解码
// 后，`ImageByteFormat.rawRgba` 返回的仍是 P3 数值（dart:ui 不做 ICC 换算），再按
// sRGB 编码保存就导致肤色/暖色偏黄（P3 与 sRGB 共享 D65 白点→中性色不受影响，
// 唯暖色/肤色这些接近色域边缘的色调明显偏移，与症状完全吻合）。
//
// 修复：解码出合成后的像素里检测到 P3 标签时，做 P3→sRGB 线性基色矩阵换算，
// 让保存成图与取景器保持一致。
bool _isDisplayP3Jpeg(Uint8List bytes) {
  for (final marker in const ['Display P3', 'DCI-P3', 'P3D65', 'DISPLAY P3', 'Apple P3']) {
    if (_bytesContainsAscii(bytes, marker)) return true;
  }
  return false;
}

bool _bytesContainsAscii(Uint8List hay, String needle) {
  final pat = needle.codeUnits;
  final n = hay.length - pat.length;
  if (n < 0) return false;
  outer:
  for (int i = 0; i <= n; i++) {
    for (int j = 0; j < pat.length; j++) {
      if (hay[i + j] != pat[j]) continue outer;
    }
    return true;
  }
  return false;
}

// sRGB 传递函数的线性化与编码用查表（避免逐像素 pow 拖累 800ms 预算）。
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

/// 将 image 包像素就地做 P3(D65)→sRGB(D65) 线性基色换算。
///
/// P3 与 sRGB 同为 D65 白点、同为 sRGB 传递函数，仅基色不同，故线性化后乘
/// 「sRGB→P3 正向矩阵的逆」再按 sRGB 传递函数编码即可。必须用带负系数的逆矩阵
/// （正向矩阵会把 P3 的红色压低、G/B 抬高，对肤色引入残余黄色）。
void _applyP3ToSrgb(img.Image image) {
  const steps = 4096;
  for (final p in image) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final lr = _srgbToLinearLut[r];
    final lg = _srgbToLinearLut[g];
    final lb = _srgbToLinearLut[b];
    // P3(D65) → sRGB(D65) 线性基色转换矩阵（sRGB→P3 正向矩阵的逆）。
    final sr = (1.2249 * lr - 0.2247 * lg).clamp(0.0, 1.0);
    final sg = (-0.0420 * lr + 1.0419 * lg).clamp(0.0, 1.0);
    final sb = (-0.0197 * lr - 0.0786 * lg + 1.0983 * lb).clamp(0.0, 1.0);
    p
      ..r = (_srgbEncodeLut[(sr * (steps - 1)).round()] * 255).round()
      ..g = (_srgbEncodeLut[(sg * (steps - 1)).round()] * 255).round()
      ..b = (_srgbEncodeLut[(sb * (steps - 1)).round()] * 255).round();
  }
}

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
  /// [customCropRect] 自定义裁剪框（相对坐标 0.0-1.0，相对比例裁剪后的可见区域）。
  ///   为 null 时使用默认居中按比例裁剪（向后兼容）；
  ///   不为 null 时在比例裁剪的基础上进一步裁剪（两步裁剪保证 WYSIWYG）。
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
    CropRect? customCropRect,
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
      var cropRect = computeCropRect(
        aspectRatio,
        workingImage.width,
        workingImage.height,
        screenRatio,
        isPortrait,
      );
      debugPrint('[post-process] 裁剪区域（比例）: $cropRect');

      // 2.5. 如果有自定义裁剪框，在比例裁剪的基础上进一步裁剪（两步裁剪）
      // 自定义裁剪框的相对坐标是相对于"比例裁剪后的可见区域"（即用户在编辑页看到的图片）
      // 因此先按比例裁剪得到可见区域，再在可见区域内按自定义 Rect 裁剪
      if (customCropRect != null) {
        final innerCrop = computeCustomCropRect(
          customCropRect,
          cropRect[2], // 比例裁剪后的宽度
          cropRect[3], // 比例裁剪后的高度
        );
        // 合并：在原图中的绝对位置 = 比例裁剪偏移 + 自定义裁剪偏移
        cropRect = [
          cropRect[0] + innerCrop[0],
          cropRect[1] + innerCrop[1],
          innerCrop[2],
          innerCrop[3],
        ];
        debugPrint('[post-process] 裁剪区域（自定义）: $cropRect');
      }

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

      // 5.6. 色域校正：iOS 宽色域照片的 P3→sRGB 转换
      // 输入 JPEG 带 Display P3 ICC，dart:ui 解码后 rawRgba 返回 P3 数值，
      // 但 image 包的 JPEG 编码器按 sRGB 编码且不嵌入 ICC，导致查看器把 P3 数值当 sRGB 解释，
      // 肤色/暖色偏黄。必须在编码前做 P3→sRGB 线性基色矩阵换算。
      final p3Tag = _isDisplayP3Jpeg(bytes);
      if (p3Tag) {
        final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final imgImage = img.Image.fromBytes(
            width: resultImage.width,
            height: resultImage.height,
            bytes: byteData.buffer.asUint8List().buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          _applyP3ToSrgb(imgImage);
          // 转回 ui.Image
          final outBytes = imgImage.getBytes(order: img.ChannelOrder.rgba);
          final buffer = await ui.ImmutableBuffer.fromUint8List(outBytes);
          final descriptor = ui.ImageDescriptor.raw(
            buffer,
            width: resultImage.width,
            height: resultImage.height,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          final codec = await descriptor.instantiateCodec();
          final frame = await codec.getNextFrame();
          resultImage.dispose();
          resultImage = frame.image;
          buffer.dispose();
          descriptor.dispose();
          codec.dispose();
          debugPrint('[p3dbg] P3→sRGB applied');
        }
      }

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

    // 仅当需要旋转时才旋转并交换宽高；仅镜像时保持原尺寸与 0°，
    // 避免"竖屏 JPEG + 前置镜像"时把图片旋转 90° 填入未交换的竖屏画布导致横向拉伸变形。
    final int rotation;
    final int outW;
    final int outH;
    if (needRotate) {
      rotation = deviceIsPortrait ? 90 : 270;
      outW = src.height;
      outH = src.width;
    } else {
      rotation = 0;
      outW = src.width;
      outH = src.height;
    }
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
  /// 统一裁剪模式（同时适用于 fullscreen / 4:3 / 1:1 / 模板 W:H 等比例）：
  /// 取景器 [_ViewfinderArea] 把相机预览约束到目标比例的矩形框内并以
  /// [CameraPreviewFit.cover] 填充，因此可见区域 = 传感器图像按目标比例的
  /// **居中裁剪**：
  /// - 图像比目标更宽（targetRatio 小）→ 左右裁剪，保留全高
  /// - 图像比目标更窄（targetRatio 大）→ 上下裁剪，保留全宽
  /// - 比例相等 → 不裁剪（4:3 传感器在 4:3 框中显示全部内容）
  ///
  /// 修复说明（原为两步裁剪）：
  /// 旧版先把传感器图像 cover 到屏幕比例，再按 targetRatio 裁剪，
  /// 这与"比例框直接约束传感器图像"的现实布局不符，
  /// 导致非 fullscreen 比例下成片比取景器更大（左右、上下都被再裁一次）。
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

    double cropW, cropH;
    if (imgRatio > targetRatio) {
      // 图片比目标比例更宽 → 裁剪左右，保留全高
      cropH = imgH.toDouble();
      cropW = cropH * targetRatio;
    } else if (imgRatio < targetRatio) {
      // 图片比目标比例更窄 → 裁剪上下，保留全宽
      cropW = imgW.toDouble();
      cropH = cropW / targetRatio;
    } else {
      // 比例相等，无需裁剪
      cropW = imgW.toDouble();
      cropH = imgH.toDouble();
    }
    cropW = cropW.clamp(1.0, imgW.toDouble());
    cropH = cropH.clamp(1.0, imgH.toDouble());

    // 居中对齐（与取景器 cover 的居中裁剪行为一致）
    final offsetX = ((imgW - cropW) / 2.0).round().clamp(0, imgW - 1);
    final offsetY = ((imgH - cropH) / 2.0).round().clamp(0, imgH - 1);
    final width = cropW.round().clamp(1, imgW - offsetX);
    final height = cropH.round().clamp(1, imgH - offsetY);

    debugPrint(
        '[post-process] 单步裁剪: imgRatio=$imgRatio, targetRatio=$targetRatio, '
        '裁剪后比例=${width / height}');

    return [offsetX, offsetY, width, height];
  }

  /// 计算自定义裁剪区域 [x, y, width, height]（像素坐标）
  ///
  /// 将相对坐标（0.0-1.0）的自定义裁剪框转换为像素坐标。
  /// 用于可拖拽裁剪框方案：用户在编辑页拖拽调整裁剪框后，导出时转为像素裁剪区域。
  ///
  /// 参数：
  /// - [relativeRect] 自定义裁剪框（相对坐标 0.0-1.0）
  /// - [imgW] 图片宽度（像素）
  /// - [imgH] 图片高度（像素）
  ///
  /// 返回：[x, y, width, height] 像素坐标，已 clamp 到合法范围
  static List<int> computeCustomCropRect(
    CropRect relativeRect,
    int imgW,
    int imgH,
  ) {
    final x = (relativeRect.x * imgW).round().clamp(0, imgW - 1);
    final y = (relativeRect.y * imgH).round().clamp(0, imgH - 1);
    final w = (relativeRect.w * imgW).round().clamp(1, imgW - x);
    final h = (relativeRect.h * imgH).round().clamp(1, imgH - y);
    return [x, y, w, h];
  }
}
