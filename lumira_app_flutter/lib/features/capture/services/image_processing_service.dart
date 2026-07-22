// lib/features/capture/services/image_processing_service.dart
import 'dart:math' show sqrt, Random;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:image/image.dart' as img;

import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import 'lut_processor.dart';

/// 拍照后图像处理管线。
///
/// 按 CSS filter-string 顺序应用后期参数：brightness → contrast → saturation →
/// temperature → tint → highlights/shadows/blackPoint → clarity → vibrance →
/// brilliance → systemFilter → LUT → sharpen → grain → vignette。
///
/// 色彩调整通过单一 ColorMatrix 一次性应用（由 `fromPostProcess` 组合）。
/// Sharpen / Clarity / Grain 为逐像素操作，通过 `image` 包在 CPU 上完成。
///
/// LUT 处理策略（符合 Global Constraints "LUT：优先 gpu_image 3D LUT，运行时检测
/// 不可用时回退 ColorMatrix 近似"）：
/// 1. 若 `params.lut != 'none'`，先尝试 `LutProcessor.apply3DLut`（当前抛 UnimplementedError）。
/// 2. 若 gpu_image 成功：用其返回的图像作为 baseImage，并在 ColorMatrix 中排除 LUT
///    （避免双重应用）。
/// 3. 若 gpu_image 失败：用原始 input 作为 baseImage，ColorMatrix 包含 LUT 近似
///    （`fromPostProcess(params)` 已内含 `composeLutMatrix`）。
class ImageProcessingService {
  ImageProcessingService._();

  /// 处理图像：按管线顺序应用所有后期参数。
  ///
  /// 管线步骤：
  /// 1. （若 lut != 'none'）尝试 gpu_image 3D LUT，失败则回退 ColorMatrix 近似
  /// 2. 用组合 ColorMatrix 绘制 baseImage（包含 brightness/contrast/saturation/
  ///    temperature/tint/highlights/shadows/blackPoint/vibrance/brilliance/
  ///    systemFilter/LUT-colormatrix-fallback）
  /// 3. Sharpening — 3x3 Unsharp Mask 卷积（image 包 convolution）
  /// 4. Clarity — 高斯模糊 + Unsharp Mask，半径=3（image 包 gaussianBlur + 逐像素）
  /// 5. Grain — 加性噪声叠加，固定种子保证可复现（逐像素）
  /// 6. Vignette — 径向渐变覆盖层
  static Future<ui.Image> process({
    required ui.Image input,
    required PostProcess params,
  }) async {
    final width = input.width;
    final height = input.height;

    // Step 1: Attempt gpu_image 3D LUT first (currently throws UnimplementedError).
    // If it succeeds, exclude LUT from ColorMatrix to avoid double-application.
    ui.Image baseImage = input;
    bool gpuLutApplied = false;
    if (params.lut != 'none') {
      try {
        baseImage = await LutProcessor.apply3DLut(
          input: input,
          lutName: params.lut,
        );
        gpuLutApplied = true;
      } catch (_) {
        // gpu_image unavailable — fall back to ColorMatrix approximation below.
        // baseImage remains the original input; fromPostProcess(params) will
        // include the LUT as a ColorMatrix via composeLutMatrix.
      }
    }

    // Step 2: Compose color filter. Exclude LUT from matrix if gpu_image applied it.
    final effectiveParams = gpuLutApplied
        ? params.copyWith(lut: 'none')
        : params;
    final colorFilter = fromPostProcess(effectiveParams);

    final colorRecorder = ui.PictureRecorder();
    final colorCanvas = ui.Canvas(colorRecorder);
    colorCanvas.drawImage(
      baseImage,
      ui.Offset.zero,
      ui.Paint()..colorFilter = colorFilter,
    );
    final colorPicture = colorRecorder.endRecording();
    ui.Image intermediate = await colorPicture.toImage(width, height);
    colorPicture.dispose();

    // Steps 3–5: Sharpening / Clarity / Grain — per-pixel via `image` package.
    final clarityVal = params.color.clarity;
    final needsPerPixel =
        params.sharpen > 0 ||
        (clarityVal != null && clarityVal != 0) ||
        params.grain > 0;
    if (needsPerPixel) {
      final processed = await _applyPerPixelEffects(
        intermediate,
        sharpen: params.sharpen,
        clarity: clarityVal,
        grain: params.grain,
      );
      intermediate.dispose();
      intermediate = processed;
    }

    // Step 6: Vignette (radial gradient overlay).
    final finalRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(finalRecorder);
    canvas.drawImage(intermediate, ui.Offset.zero, ui.Paint());

    if (params.vignette > 0) {
      final centerX = width / 2.0;
      final centerY = height / 2.0;
      final radius = sqrt(centerX * centerX + centerY * centerY);
      final vignetteAlpha = params.vignette / 100.0 * 0.5;
      final vignettePaint = ui.Paint()
        ..shader = ui.Gradient.radial(
          ui.Offset(centerX, centerY),
          radius,
          [
            const ui.Color(0x00000000), // transparent center
            Colors.black.withOpacity(vignetteAlpha), // darkened edges
          ],
          [0.5, 1.0],
          ui.TileMode.clamp,
        );
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        vignettePaint,
      );
    }

    final picture = finalRecorder.endRecording();
    final result = await picture.toImage(width, height);
    picture.dispose();
    intermediate.dispose();
    return result;
  }

  /// 在 [input] 上应用 Sharpening / Clarity / Grain 三种逐像素效果。
  ///
  /// 流程：ui.Image → image.Image → 应用三种效果 → image.Image → ui.Image。
  /// 仅当至少一项效果启用时调用（由调用方判断）。
  static Future<ui.Image> _applyPerPixelEffects(
    ui.Image input, {
    required int sharpen,
    required double? clarity,
    required int grain,
  }) async {
    final width = input.width;
    final height = input.height;

    // Convert ui.Image → image.Image (RGBA, 4 channels).
    final byteData = await input.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return input; // cannot convert — return as-is
    }
    final rgbaBytes = byteData.buffer.asUint8List();

    final imgImage = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(rgbaBytes).buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    // Step 3: Sharpening — 3x3 convolution Unsharp Mask.
    // Kernel (sum = 1.0):
    //   [ 0,      -a, 0      ]
    //   [ -a, 1+4a,  -a      ]
    //   [ 0,      -a, 0      ]
    // a = sharpen / 100.0 ∈ [0, 1]
    if (sharpen > 0) {
      final a = (sharpen / 100.0).clamp(0.0, 1.0);
      img.convolution(
        imgImage,
        filter: [
          0, -a, 0,
          -a, 1 + 4 * a, -a,
          0, -a, 0,
        ],
        div: 1.0,
        amount: 1.0,
      );
    }

    // Step 4: Clarity — Unsharp Mask with larger radius (gaussian blur).
    // output = original + amount * (original - blurred)
    //        = original * (1 + amount) - blurred * amount
    // Positive clarity enhances local contrast; negative reduces it.
    if (clarity != null && clarity != 0) {
      final amount = (clarity.abs() / 100.0).clamp(0.0, 1.0) * 0.6;
      final sign = clarity > 0 ? 1.0 : -1.0;
      // Work on a blurred copy so we can compute (original - blurred).
      final blurred = img.gaussianBlur(img.Image.from(imgImage), radius: 3);
      for (final p in imgImage) {
        final bp = blurred.getPixel(p.x, p.y);
        // delta = original - blurred (with sign for direction)
        final dR = (p.r - bp.r) * sign * amount;
        final dG = (p.g - bp.g) * sign * amount;
        final dB = (p.b - bp.b) * sign * amount;
        p
          ..r = (p.r + dR).clamp(0, 255)
          ..g = (p.g + dG).clamp(0, 255)
          ..b = (p.b + dB).clamp(0, 255);
      }
    }

    // Step 5: Grain — additive luminance noise.
    // Each pixel gets a uniform random offset in [-intensity*maxOffset, +intensity*maxOffset]
    // applied equally to R/G/B for neutral (non-chromatic) grain.
    // Fixed seed (42) ensures tests are reproducible.
    if (grain > 0) {
      final intensity = (grain / 100.0).clamp(0.0, 1.0) * 0.25;
      const maxOffset = 64.0; // ±64 max at full intensity
      final random = Random(42);
      for (final p in imgImage) {
        final noise = (random.nextDouble() * 2 - 1) * intensity * maxOffset;
        p
          ..r = (p.r + noise).clamp(0, 255)
          ..g = (p.g + noise).clamp(0, 255)
          ..b = (p.b + noise).clamp(0, 255);
      }
    }

    // Convert image.Image → ui.Image.
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
    return frame.image;
  }
}
