// lib/features/capture/services/photo_post_processor.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart' as pp;

import 'dart_photo_pipeline.dart' show applyLegStretchImg, applyPerPixelEffectsImg;
import 'skin_smooth_shader.dart';
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
  /// [customCropRect] 自定义裁剪框（相对坐标 0.0-1.0，相对【当前展示的烘焙照片】）。
  ///   为 null 时表示本次未框选（保持 [baseCropRect] 区域不变）；
  ///   不为 null 时表示用户本次在展示照片上的新框选，与 [baseCropRect]
  ///   嵌套组合后应用到比例基准区域（保证多轮编辑 WYSIWYG）。
  /// [baseCropRect] 烘焙照片已有的自定义裁剪（相对坐标 0.0-1.0，相对【比例基准区域】），
  ///   即 DB 记录 postProcess.customCropRect。多轮编辑时用于还原当前展示照片
  ///   在原图中的真实来源区域；为 null 时基准 = 比例裁剪区域（首轮编辑）。
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
    CropRect? baseCropRect,
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

      // 2. 计算裁剪区域（比例裁剪 = 裁剪 UI 显示的烘焙图对应的参考区域）。
      //    裁剪发生在旋转/翻转【之前】：customCropRect 相对「未变换的对齐图」
      //    解释，先裁剪出所框区域，再应用用户变换（旋转/翻转/拉直），与裁剪面板
      //    所见即所得一致（见 specs/2026-08-24-preview-edit-crop-exif-save-design.md）。
      //    旧实现先变换后裁剪，把相对对齐图的选区错套到旋转后的工作图上，
      //    导致框选区域与最终成片不一致。
      final ratioCropRect = computeCropRect(
        aspectRatio,
        alignedImage.width,
        alignedImage.height,
        screenRatio,
        isPortrait,
      );
      debugPrint('[post-process] 裁剪区域（比例）: $ratioCropRect');

      // 2.5 组合裁剪（嵌套两步，保证多轮编辑 WYSIWYG）：
      // - 烘焙基区域 = 比例基准区域 ⊕ baseCropRect（还原当前展示照片的来源区域）
      //   裁剪 UI（PhotoCropLayer/CropOverlay）叠加在「已烘焙的照片」上，而该照片
      //   是原图经方向校正/变换后按比例裁剪、再应用上一轮 customCropRect 的结果。
      //   因此本轮框选必须先与上一轮裁剪嵌套组合，再映射到比例基准区域内；
      //   若直接相对比例区域解释，会丢失上一轮裁剪基准，选区与导出不一致。
      // - 最终区域 = 烘焙基区域 ⊕ customCropRect（本次新框选，相对展示照片）
      // 相对坐标嵌套组合满足结合律：基准 ⊕ (a ⊕ b) == (基准 ⊕ a) ⊕ b。
      // customCropRect == null 时保持烘焙基区域不变（本次未框选）。
      var bakedBase = ratioCropRect;
      if (baseCropRect != null) {
        bakedBase = computeCustomCropRect(
          baseCropRect,
          ratioCropRect[0],
          ratioCropRect[1],
          ratioCropRect[2],
          ratioCropRect[3],
        );
        debugPrint('[post-process] 烘焙基区域（比例区域 ⊕ 已有裁剪）: $bakedBase');
      }
      var cropRect = bakedBase;
      if (customCropRect != null) {
        cropRect = computeCustomCropRect(
          customCropRect,
          bakedBase[0],
          bakedBase[1],
          bakedBase[2],
          bakedBase[3],
        );
        debugPrint('[post-process] 裁剪区域（烘焙基区域 ⊕ 本次框选）: $cropRect');
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
        alignedImage,
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
        // 统一解析暗角 A.3（与 OHOS C++ / iOS 预览同一公式）：
        //   dn = 径向归一距离（中心 0、对角 ~1）；factor = 1 − s·smoothstep(0.45,1.0,dn)，s=vignette/100。
        // 用半透明黑 source-over 等效乘法（黑色 src → out = dst·(1−alpha)），alpha = s·smoothstep(0.45,1.0,dn)，
        // 在 [0.45,1.0] 上分段线性采样 smoothstep 逼近解析曲线 → 预览与成片暗角逐像素一致、中心不变边缘渐变。
        final double s = params.vignette / 100.0;
        const int kSeg = 9;
        final stops = List<double>.filled(kSeg, 0);
        final colors = List<ui.Color>.filled(kSeg, const ui.Color(0x00000000));
        for (var i = 0; i < kSeg; i++) {
          final t = 0.45 + (1.0 - 0.45) * i / (kSeg - 1);
          stops[i] = t;
          var u = (t - 0.45) / (1.0 - 0.45);
          final e = u * u * (3.0 - 2.0 * u); // smoothstep
          final alpha = (s * e).clamp(0.0, 1.0).toDouble();
          colors[i] = ui.Color.fromRGBO(0, 0, 0, alpha);
        }
        final centerX = outW / 2.0;
        final centerY = outH / 2.0;
        final radius = math.sqrt(centerX * centerX + centerY * centerY);
        final vignettePaint = ui.Paint()
          ..shader = ui.Gradient.radial(
            ui.Offset(centerX, centerY),
            radius,
            colors,
            stops,
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
      alignedImage.dispose();
      debugPrint(
          '[post-process] GPU裁剪: ${resultImage.width}x${resultImage.height}, ${sw.elapsedMilliseconds}ms');

      // 1.6. 应用用户变换（旋转/翻转/拉直）——裁剪【之后】应用，
      // 保证 customCropRect 相对未变换的对齐图解释，框选与成片一致。
      if (transform != null && !transform.isIdentity) {
        final transformed = await _applyTransform(resultImage, transform);
        resultImage.dispose();
        resultImage = transformed;
        debugPrint('[post-process] 变换: rotation=${transform.rotation}, '
            'flipH=${transform.flipH}, flipV=${transform.flipV}, '
            'straighten=${transform.straighten}, '
            '${sw.elapsedMilliseconds}ms');
      }

      // 1.7. 拉腿：对图像下半部做平滑纵向拉伸（仅改变高度）。
      //      在裁剪/变换【之后】作为最终几何调整应用，随后再叠加逐像素效果。
      if (params.legStretch > 0) {
        resultImage = await _applyLegStretch(resultImage, params.legStretch);
        debugPrint('[post-process] 拉腿: legStretch=${params.legStretch}, '
            '${resultImage.width}x${resultImage.height}, ${sw.elapsedMilliseconds}ms');
      }

      debugPrint(
          '[post-process] GPU合并: ${resultImage.width}x${resultImage.height}, ${sw.elapsedMilliseconds}ms');

      // 4.5. 皮肤平滑（GPU shader 优先，与预览同一 shader，保证 WYSIWYG）
      if (!rawMode && params.smoothStrength > 0) {
        final int smoothW = resultImage.width;
        final int smoothH = resultImage.height;
        ui.FragmentProgram? program;
        try {
          // 载荷失败/渲染异常一律回退 CPU 路径，不抛出、不阻塞成片。
          program = await ui.FragmentProgram.fromAsset(
              'shaders/skin_smooth.frag');
        } catch (_) {
          program = null;
        }
        if (program != null) {
          try {
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            // 与 SkinSmoothPainter 相同的 uniform 索引约定：
            // - float 域：uSize(vec2)→0,1；uStrength→2。
            // - sampler 域：uTexture→0（sampler 独立索引空间）。
            final shader = program.fragmentShader()
              ..setFloat(0, smoothW.toDouble())
              ..setFloat(1, smoothH.toDouble())
              ..setFloat(2, skinStrength(params))
              ..setImageSampler(0, resultImage);
            canvas.drawRect(
              ui.Rect.fromLTWH(
                  0, 0, smoothW.toDouble(), smoothH.toDouble()),
              ui.Paint()..shader = shader,
            );
            final picture = recorder.endRecording();
            final newImage = await picture.toImage(smoothW, smoothH);
            resultImage.dispose();
            resultImage = newImage;
            picture.dispose();
            debugPrint(
                '[post-process] 皮肤平滑 (GPU): smoothStrength=${params.smoothStrength}, ${sw.elapsedMilliseconds}ms');
          } catch (e) {
            debugPrint(
                '[post-process] 皮肤平滑 (GPU) 渲染异常，回退 CPU: $e');
            resultImage =
                await _applyCpuSkinSmoothing(resultImage, params, sw);
          }
        } else {
          debugPrint('[post-process] 磨皮 shader 加载失败，回退 CPU');
          resultImage =
              await _applyCpuSkinSmoothing(resultImage, params, sw);
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

  /// 拉腿：把 ui.Image 转为 image 包像素做纵向拉伸，再转回 ui.Image。
  static Future<ui.Image> _applyLegStretch(ui.Image input, int legStretch) async {
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

    final stretched = applyLegStretchImg(imgImage, legStretch: legStretch);

    final outBytes = stretched.getBytes(order: img.ChannelOrder.rgba);
    final buffer = await ui.ImmutableBuffer.fromUint8List(outBytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: stretched.width,
      height: stretched.height,
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

  /// 皮肤平滑 CPU 回退路径（GPU shader 加载/渲染失败时使用）。
  /// 消费并回收 [input]，返回磨皮后的新图。
  static Future<ui.Image> _applyCpuSkinSmoothing(
    ui.Image input,
    PostProcess params,
    Stopwatch sw,
  ) async {
    try {
      final byteData =
          await input.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return input;
      final imgImage = img.Image.fromBytes(
        width: input.width,
        height: input.height,
        bytes: byteData.buffer.asUint8List().buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final smoothed = SkinSmoother.smooth(imgImage, params.smoothStrength);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint();
      final smoothedBytes = img.encodePng(smoothed);
      final codec = await ui.instantiateImageCodec(smoothedBytes);
      final frame = await codec.getNextFrame();
      canvas.drawImage(frame.image, ui.Offset.zero, paint);
      final picture = recorder.endRecording();
      final newImage = await picture.toImage(smoothed.width, smoothed.height);
      input.dispose();
      frame.image.dispose();
      codec.dispose();
      picture.dispose();
      debugPrint(
          '[post-process] 皮肤平滑 (CPU): smoothStrength=${params.smoothStrength}, ${sw.elapsedMilliseconds}ms');
      return newImage;
    } catch (e) {
      debugPrint('[post-process] 皮肤平滑 (CPU) 失败（静默跳过）: $e');
      return input;
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

    // 复用统一逐像素管线（锐化亮度死区 + clarity + 颗粒 tile），与 isolate 慢管线同源。
    applyPerPixelEffectsImg(
      imgImage,
      sharpen: sharpen,
      clarity: clarity,
      grain: grain,
    );

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

  /// 计算自定义裁剪区域（相对坐标 0.0-1.0，相对【比例裁剪区域】）
  ///
  /// 裁剪 UI（PhotoCropLayer/CropOverlay）叠加在已烘焙照片上，该照片对应原图
  /// 按比例裁剪的可见区域 [refX,refY,refW,refH]（[computeCropRect] 的结果）。
  /// 因此裁剪框的相对坐标必须映射到该参考区域内，才能保证选区与导出一致。
  ///
  /// [relativeRect] 裁剪框相对坐标（0.0-1.0）。
  /// [refX]/[refY]/[refW]/[refH] 参考区域（工作图上的像素坐标）。
  ///   自由比例（'free'/'none'）时参考区域即整图，行为与旧版（相对整图）一致。
  static List<int> computeCustomCropRect(
    CropRect relativeRect,
    int refX,
    int refY,
    int refW,
    int refH,
  ) {
    final x = (refX + relativeRect.x * refW).round().clamp(refX, refX + refW - 1);
    final y = (refY + relativeRect.y * refH).round().clamp(refY, refY + refH - 1);
    final w = (relativeRect.w * refW).round().clamp(1, refX + refW - x);
    final h = (relativeRect.h * refH).round().clamp(1, refY + refH - y);
    return [x, y, w, h];
  }

  /// 将裁剪框从「叠了变换预览的展示坐标」反算回「未变换照片坐标」（相对 0-1）。
  ///
  /// 裁剪叠加层会把照片包一层变换预览（Rot(rotation)∘Flip∘Rot(straighten)，见
  /// CropOverlay._applyTransform），用户看到的框选区域是变换后的展示。而
  /// processFile 采用「先按原图裁剪、后应用变换」的语义，即 customCropRect 相对
  /// 【未变换】的照片解释。因此裁剪框需先逆变换回来（撤销 rotation→flip→straighten），
  /// 才能保证「框选内容 == 导出内容」（WYSIWYG）。恒等变换时原样返回。
  ///
  /// [frame] 裁剪框相对坐标（0-1，展示空间，已反算缩放/平移）。
  /// 取逆变换后四角的包围盒，作为未变换照片空间里应保留的轴对齐区域。
  static ui.Rect invertCropTransform(ui.Rect frame, TransformParams? t) {
    if (t == null || t.isIdentity) return frame;

    ui.Offset rotateOffset(ui.Offset v, double deg) {
      final rad = deg * math.pi / 180.0;
      final co = math.cos(rad);
      final si = math.sin(rad);
      return ui.Offset(v.dx * co - v.dy * si, v.dx * si + v.dy * co);
    }

    ui.Offset undo(ui.Offset p) {
      const c = ui.Offset(0.5, 0.5);
      // 正变换 = R(rotation)∘Flip∘R(straighten)，逆序撤销。
      final d1 = rotateOffset(p - c, -t.rotation.toDouble());
      final d2 = ui.Offset(t.flipH ? -d1.dx : d1.dx, t.flipV ? -d1.dy : d1.dy);
      final d3 = rotateOffset(d2, -t.straighten);
      return d3 + c;
    }

    final a = undo(frame.topLeft);
    final b = undo(frame.bottomRight);
    final left = math.min(a.dx, b.dx).clamp(0.0, 1.0).toDouble();
    final top = math.min(a.dy, b.dy).clamp(0.0, 1.0).toDouble();
    final right = math.max(a.dx, b.dx).clamp(0.0, 1.0).toDouble();
    final bottom = math.max(a.dy, b.dy).clamp(0.0, 1.0).toDouble();
    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  /// 组合两个相对坐标裁剪框：[inner]（相对 [base] 区域）→ 结果相对 base 的基准区域。
  ///
  /// 多轮编辑时，DB 记录里的 customCropRect（相对比例基准区域）是上一轮的框选；
  /// 本轮 UI 框选相对「上一轮裁剪后的展示照片」。两者按相对坐标嵌套组合
  /// （x' = base.x + inner.x * base.w，w' = inner.w * base.w，y/h 同理），
  /// 结果仍是相对比例基准区域的相对框，可直接作为新一轮的记录值。
  ///
  /// - base 为 null 时视为整图 [0,0,1,1]，结果 = inner；
  /// - inner 为 null 时表示本次未框选，结果 = base（保持原裁剪不变）；
  /// - 两者均为 null 时返回 null（无自定义裁剪）。
  static CropRect? composeCropRects(CropRect? base, CropRect? inner) {
    if (inner == null) return base;
    if (base == null) return inner;
    return CropRect(
      x: (base.x + inner.x * base.w).clamp(0.0, 1.0),
      y: (base.y + inner.y * base.h).clamp(0.0, 1.0),
      w: (inner.w * base.w).clamp(0.0, 1.0),
      h: (inner.h * base.h).clamp(0.0, 1.0),
    );
  }

  /// 仅读取图片头部元数据获取尺寸（不解码像素，开销极小）。
  /// 失败时返回 null（调用方需自行回退）。
  static Future<ui.Size?> resolveImageSize(String path) async {
    try {
      final data = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(data);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = ui.Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      buffer.dispose();
      descriptor.dispose();
      return size;
    } catch (e) {
      debugPrint('[post-process] resolveImageSize 失败（$path）: $e');
      return null;
    }
  }

  /// 推断烘焙照片的基准裁剪比例（ratioId）。
  ///
  /// 背景：拍摄落库时 postProcess.cropRatio 曾未持久化实际使用的比例
  /// （自由模式存的是默认 '3:4'，实际却按 'fullscreen' 等比例裁剪），导致
  /// 编辑保存时 computeCropRect 用错误比例重算基准区域 → 框选与导出错位。
  ///
  /// 方法：无历史自定义裁剪时，展示照片的实际宽高比 == 比例基准区域宽高比，
  /// 据此在候选比例中挑选与展示照片宽高比最匹配的一项；存储值本身能对上时
  /// 优先使用存储值。推断结果应随保存写回 DB 记录（自愈旧数据）。
  ///
  /// [bakedSize] 当前展示（烘焙）照片的尺寸；[originalSize] 原图尺寸；
  /// [storedRatio] DB 记录里的 cropRatio；[screenRatio] 当前屏幕宽高比
  /// （fullscreen 基准与拍摄设备一致，App 锁竖屏时同一设备不变）。
  static String resolveBaseRatio({
    required ui.Size bakedSize,
    required ui.Size originalSize,
    required String storedRatio,
    required double screenRatio,
  }) {
    if (bakedSize.width <= 0 || bakedSize.height <= 0) return storedRatio;
    final bakedAspect = bakedSize.width / bakedSize.height;
    // 竖横方向从烘焙照片推断（拍摄时可能横屏持机，比当前屏幕方向可靠）
    final isPortrait = bakedSize.height >= bakedSize.width;
    // 方向对齐后的原图尺寸（与 _alignOrientation 相同的判定）
    final origLandscape = originalSize.width > originalSize.height;
    final needRotate = (isPortrait && origLandscape) ||
        (!isPortrait && !origLandscape);
    final alignedW =
        (needRotate ? originalSize.height : originalSize.width).round();
    final alignedH =
        (needRotate ? originalSize.width : originalSize.height).round();
    if (alignedW <= 0 || alignedH <= 0) return storedRatio;

    double aspectOf(String ratioId) {
      final r = computeCropRect(
        ratioId,
        alignedW,
        alignedH,
        screenRatio,
        isPortrait,
      );
      return r[2] / r[3];
    }

    const tol = 0.03;
    if ((aspectOf(storedRatio) - bakedAspect).abs() <= tol) {
      return storedRatio;
    }

    const candidates = <String>{
      'fullscreen', 'free', '1:1', '4:3', '3:4',
      '16:9', '9:16', '2:3', '3:2', '4:5', '5:4',
    };
    String best = storedRatio;
    double bestDiff = double.infinity;
    for (final c in {...candidates, storedRatio}) {
      final diff = (aspectOf(c) - bakedAspect).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = c;
      }
    }
    return bestDiff <= tol ? best : storedRatio;
  }

  /// 由照片实际宽高比推断裁剪 UI 应选中/锁定的比例（ratioId）。
  ///
  /// 用于编辑会话初始化裁剪 Tab：让选中的比例与展示照片的实际比例一致，
  /// 进入裁剪模式时的默认选框即满幅（无操作 = 无裁剪）。
  /// 无匹配（任意裁剪过的怪比例）时返回 'free'。
  static String uiRatioIdForAspect(double? aspect, double screenRatio) {
    if (aspect == null || !aspect.isFinite || aspect <= 0) return 'free';
    final isPortrait = aspect <= 1.0;
    double aspectOf(String ratioId) =>
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
    const candidates = <String>[
      '1:1', '3:4', '16:9', '9:16', '4:5', '3:2', '2:3', '5:4', '4:3',
    ];
    for (final c in candidates) {
      if ((aspectOf(c) - aspect).abs() <= 0.03) return c;
    }
    if ((screenRatio - aspect).abs() <= 0.03) return 'fullscreen';
    return 'free';
  }

  /// 解析编辑保存所需的裁剪上下文（多轮编辑 WYSIWYG 的统一入口）。
  ///
  /// 编辑页的裁剪 UI 叠加在「已烘焙照片」上，本轮框选（local.customCropRect）
  /// 相对该照片；而照片 = 原图 → 比例基准区域 ⊕ 上一轮裁剪（baked.customCropRect，
  /// 相对比例基准区域）。保存时需三者齐备才能从原图还原出与选框一致的输出：
  ///
  /// - 基准比例 [CropSavePlan.baseRatio]：
  ///   - 无历史裁剪时用 [resolveBaseRatio] 按烘焙照片实际比例自愈存储值
  ///     （旧数据拍摄落库时 cropRatio 可能存的是默认 '3:4'，实际按 'fullscreen' 裁剪）；
  ///   - 有历史裁剪时裁剪框相对「存储比例」的基准区域，直接信任存储值。
  /// - 方向 [CropSavePlan.isPortrait] 按烘焙照片推断（横屏拍摄的照片不会因
  ///   当前屏幕竖屏而被误旋）。
  /// - 记录值 [CropSavePlan.composedCropRect] = base ⊕ inner（相对比例基准区域），
  ///   保存后写回 DB，供下一轮嵌套。
  ///
  /// [displayedPhotoPath] 当前展示（烘焙）照片路径；[originalPath] 原图路径；
  /// [baked] DB 记录的烘焙参数；[local] 本轮编辑增量（框选在 local.customCropRect）；
  /// [screenRatio] 屏幕宽高比；[fallbackIsPortrait] 尺寸解析失败时的方向回退；
  /// [fallbackRatio] baked.cropRatio 为空时的比例回退（如拍摄会话传入的实际比例）。
  static Future<CropSavePlan> resolveCropSavePlan({
    required PostProcess baked,
    required PostProcess local,
    required String displayedPhotoPath,
    required String originalPath,
    required double screenRatio,
    required bool fallbackIsPortrait,
    String? fallbackRatio,
  }) async {
    final bakedCrop = baked.customCropRect;
    final localCrop = local.customCropRect;

    final bakedSize = await resolveImageSize(displayedPhotoPath);
    final origSize = await resolveImageSize(originalPath);

    final isPortrait = bakedSize != null
        ? bakedSize.height >= bakedSize.width
        : fallbackIsPortrait;

    var storedRatio = baked.cropRatio;
    if (storedRatio.isEmpty) {
      storedRatio =
          (fallbackRatio != null && fallbackRatio.isNotEmpty) ? fallbackRatio : 'fullscreen';
    }

    String baseRatio;
    if (bakedCrop != null) {
      // 有历史自定义裁剪：裁剪框相对存储比例的基准区域，信任存储值。
      baseRatio = storedRatio;
    } else if (bakedSize != null && origSize != null) {
      baseRatio = resolveBaseRatio(
        bakedSize: bakedSize,
        originalSize: origSize,
        storedRatio: storedRatio,
        screenRatio: screenRatio,
      );
    } else {
      baseRatio = storedRatio;
    }

    return CropSavePlan(
      baseRatio: baseRatio,
      isPortrait: isPortrait,
      baseCropRect: bakedCrop,
      innerCropRect: localCrop,
      composedCropRect: composeCropRects(bakedCrop, localCrop),
    );
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

/// 编辑保存时的裁剪上下文（[PhotoPostProcessor.resolveCropSavePlan] 的产物）。
///
/// 统一解决多轮编辑的坐标基准问题：
/// - [baseRatio] / [isPortrait]：重建「比例基准区域」所需的参数
///   （processFile 的 aspectRatio / isPortrait 入参）；
/// - [baseCropRect]：DB 记录的上一轮裁剪（相对比例基准区域）；
/// - [innerCropRect]：本轮 UI 框选（相对当前展示照片）；
/// - [composedCropRect]：两者嵌套组合后应写回 DB 的 customCropRect。
class CropSavePlan {
  const CropSavePlan({
    required this.baseRatio,
    required this.isPortrait,
    required this.baseCropRect,
    required this.innerCropRect,
    required this.composedCropRect,
  });

  /// processFile 的 aspectRatio 入参（重建展示照片来源区域的比例基准）。
  final String baseRatio;

  /// processFile 的 isPortrait 入参（按烘焙照片实际方向推断，横屏拍摄不误判）。
  final bool isPortrait;

  /// DB 记录的上一轮自定义裁剪（相对比例基准区域）。
  final CropRect? baseCropRect;

  /// 本轮 UI 框选（相对当前展示照片）。
  final CropRect? innerCropRect;

  /// base ⊕ inner 组合结果（相对比例基准区域），保存后写回 DB。
  final CropRect? composedCropRect;
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
