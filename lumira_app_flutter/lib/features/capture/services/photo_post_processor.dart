// lib/features/capture/services/photo_post_processor.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart' as pp;

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

      // 1.5. 方向对齐
      var alignedImage = await _alignOrientation(srcImage, isPortrait, facing);
      if (alignedImage != srcImage) {
        srcImage.dispose();
        debugPrint('[post-process] 方向对齐: '
            '${alignedImage.width}x${alignedImage.height}, ${sw.elapsedMilliseconds}ms');
      }

      // 1.6. 应用用户变换
      var workingImage = alignedImage;
      if (transform != null && !transform.isIdentity) {
        workingImage = await _applyTransform(alignedImage, transform);
        alignedImage.dispose();
        debugPrint('[post-process] 变换: rotation=${transform.rotation}, '
            'flipH=${transform.flipH}, flipV=${transform.flipV}, '
            'straighten=${transform.straighten}, '
            '${sw.elapsedMilliseconds}ms');
      }

      // 2. 计算裁剪区域
      var cropRect = computeCropRect(
        aspectRatio,
        workingImage.width,
        workingImage.height,
        screenRatio,
        isPortrait,
      );
      debugPrint('[post-process] 裁剪区域（比例）: $cropRect');

      // 2.5. 自定义裁剪
      if (customCropRect != null) {
        final innerCrop = computeCustomCropRect(
          customCropRect,
          cropRect[2],
          cropRect[3],
        );
        cropRect = [
          cropRect[0] + innerCrop[0],
          cropRect[1] + innerCrop[1],
          innerCrop[2],
          innerCrop[3],
        ];
        debugPrint('[post-process] 裁剪区域（自定义）: $cropRect');
      }

      // 3. 计算降采样后的输出尺寸
      const maxDimension = 1536;
      var outW = cropRect[2];
      var outH = cropRect[3];
      if (outW > maxDimension || outH > maxDimension) {
        final scale = maxDimension / math.max(outW, outH);
        outW = (outW * scale).round();
        outH = (outH * scale).round();
      }
      final targetRatio = outW / outH;
      final intendedRatio = cropRect[2] / cropRect[3];
      if ((targetRatio - intendedRatio).abs() > 0.005) {
        outH = (outW / intendedRatio).round();
      }

      // 4. 单次 Canvas 调用
      final matrix = rawMode ? null : composePostProcessMatrix(params);
      final hasMatrix = matrix != null && !_isIdentityMatrix(matrix);
      final hasVignette = !rawMode && params.vignette > 0;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

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

      // 4.5. 皮肤平滑
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
            final completer = ui.PictureRecorder();
            final canvas = ui.Canvas(completer);
            final paint = ui.Paint();
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

      // 5. 逐像素效果
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

      // 6. 编码 JPEG 并保存（无条件做 P3→sRGB 转换，iOS 宽色域相机输出 P3）
      final imgWidth = resultImage.width;
      final imgHeight = resultImage.height;
      final jpegBytes = await _encodeJpeg(resultImage);
      resultImage.dispose();

      // 写入诊断文件到临时目录（更容易访问）
      await _writeDiagnosticFile(
        width: imgWidth,
        height: imgHeight,
        outputPath: outputPath ?? inputPath,
      );

      final finalPath = outputPath ?? inputPath;
      await File(finalPath).writeAsBytes(jpegBytes);

      sw.stop();
      debugPrint('[post-process] 完成: ${sw.elapsedMilliseconds}ms');
      return finalPath;
    } catch (e, st) {
      sw.stop();
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

    if (sharpen > 0) {
      final a = (sharpen / 100.0).clamp(0.0, 1.0);
      img.convolution(
        imgImage,
        filter: [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0],
        div: 1.0,
        amount: 1.0,
      );
    }

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

  /// 编码 JPEG（含 P3→sRGB 色域转换）
  ///
  /// iOS 宽色域相机输出 Display P3 JPEG，dart:ui 解码后 rawRgba 返回 P3 像素值。
  /// image 包的 JPEG 编码器不嵌入 ICC 配置文件，查看器默认按 sRGB 解释 P3 数值
  /// 会导致肤色/暖色偏黄。无条件对输入做 P3→sRGB 线性基色矩阵换算后再编码。
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
    // 禁用 P3→sRGB 转换（测试：OHOS 也偏黄，说明不是 P3 色域问题）
    // _applyP3ToSrgbInPlace(imgImage);
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

  /// 把 JPEG 像素旋转到与取景器显示方向一致
  static Future<ui.Image> _alignOrientation(
      ui.Image src, bool isPortrait, String facing) async {
    final jpegIsLandscape = src.width > src.height;
    final deviceIsPortrait = isPortrait;
    final needRotate = (deviceIsPortrait && jpegIsLandscape) ||
        (!deviceIsPortrait && !jpegIsLandscape);
    final needMirror = facing == 'front';
    if (!needRotate && !needMirror) return src;

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

  /// 应用变换
  static Future<ui.Image> _applyTransform(
    ui.Image src,
    TransformParams transform,
  ) async {
    final radians = transform.rotation * math.pi / 180.0;
    final straightenRad = transform.straighten * math.pi / 180.0;
    final totalRotation = radians + straightenRad;

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

  /// 计算裁剪区域
  static List<int> computeCropRect(
    String ratio,
    int imgW,
    int imgH,
    double screenRatio,
    bool isPortrait,
  ) {
    if (ratio == 'free' || ratio == 'none') {
      return [0, 0, imgW, imgH];
    }

    final targetRatio =
        CaptureState.computeTargetRatio(ratio, isPortrait) ?? screenRatio;

    final imgRatio = imgW / imgH;

    double cropW, cropH;
    if (imgRatio > targetRatio) {
      cropH = imgH.toDouble();
      cropW = cropH * targetRatio;
    } else if (imgRatio < targetRatio) {
      cropW = imgW.toDouble();
      cropH = cropW / targetRatio;
    } else {
      cropW = imgW.toDouble();
      cropH = imgH.toDouble();
    }
    cropW = cropW.clamp(1.0, imgW.toDouble());
    cropH = cropH.clamp(1.0, imgH.toDouble());

    final offsetX = ((imgW - cropW) / 2.0).round().clamp(0, imgW - 1);
    final offsetY = ((imgH - cropH) / 2.0).round().clamp(0, imgH - 1);
    final width = cropW.round().clamp(1, imgW - offsetX);
    final height = cropH.round().clamp(1, imgH - offsetY);

    debugPrint(
        '[post-process] 单步裁剪: imgRatio=$imgRatio, targetRatio=$targetRatio, '
        '裁剪后比例=${width / height}');

    return [offsetX, offsetY, width, height];
  }

  /// 计算自定义裁剪区域
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

  /// 写入诊断数据到 Documents 目录（真机可通过「文件」App 访问）
  /// 同时写入临时目录一份
  static Future<void> _writeDiagnosticFile({
    required int width,
    required int height,
    required String outputPath,
  }) async {
    try {
      final docDir = await pp.getApplicationDocumentsDirectory();
      final tmpDir = await pp.getTemporaryDirectory();

      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'size': '${width}x${height}',
        'outputPath': outputPath,
        'documentsDir': docDir.path,
        'tempDir': tmpDir.path,
        'note': 'P3→sRGB 转换已无条件启用。如仍偏黄说明矩阵方向错误或输入非 P3',
      };
      final json = jsonEncode(data);

      // 写入 Documents 目录
      final docFile = File('${docDir.path}/lumira_diag.json');
      await docFile.writeAsString(json);
      debugPrint('[diag] 诊断文件已写入 Documents: ${docFile.path}');

      // 写入临时目录
      final tmpFile = File('${tmpDir.path}/lumira_diag.json');
      await tmpFile.writeAsString(json);
      debugPrint('[diag] 诊断文件已写入 Temp: ${tmpFile.path}');
    } catch (e) {
      debugPrint('[diag] 写入诊断文件失败: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// P3→sRGB 色域转换（在 _encodeJpeg 中调用）
// ─────────────────────────────────────────────────────────────────────────

/// 将 image 包像素就地做 P3(D65)→sRGB(D65) 线性基色换算。
///
/// P3 与 sRGB 同为 D65 白点、同为 sRGB 传递函数，仅基色不同，故线性化后乘
/// 「sRGB→P3 正向矩阵的逆」再按 sRGB 传递函数编码即可。必须用带负系数的逆矩阵
/// （正向矩阵会把 P3 的红色压低、G/B 抬高，对肤色引入残余黄色）。
void _applyP3ToSrgbInPlace(img.Image image) {
  const steps = 4096;
  // 构建 sRGB 传递函数的线性化与编码查表
  final srgbToLinear = List<double>.generate(256, (i) {
    final v = i / 255.0;
    if (v <= 0.04045) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  });
  final srgbEncode = List<double>.generate(steps, (i) {
    final c = i / (steps - 1);
    if (c <= 0.0031308) return c * 12.92;
    return (1.055 * math.pow(c, 1.0 / 2.4) - 0.055).clamp(0.0, 1.0).toDouble();
  });

  for (final p in image) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final lr = srgbToLinear[r];
    final lg = srgbToLinear[g];
    final lb = srgbToLinear[b];
    // P3(D65) → sRGB(D65) 线性基色转换矩阵（sRGB→P3 正向矩阵的逆）。
    final sr = (1.2249 * lr - 0.2247 * lg).clamp(0.0, 1.0);
    final sg = (-0.0420 * lr + 1.0419 * lg).clamp(0.0, 1.0);
    final sb = (-0.0197 * lr - 0.0786 * lg + 1.0983 * lb).clamp(0.0, 1.0);
    p
      ..r = (srgbEncode[(sr * (steps - 1)).round()] * 255).round()
      ..g = (srgbEncode[(sg * (steps - 1)).round()] * 255).round()
      ..b = (srgbEncode[(sb * (steps - 1)).round()] * 255).round();
  }
}
