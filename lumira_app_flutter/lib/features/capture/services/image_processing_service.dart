// lib/features/capture/services/image_processing_service.dart
import 'dart:math' show sqrt;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;

import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import 'lut_processor.dart';

/// 拍照后图像处理管线。
///
/// 按 CSS filter-string 顺序应用后期参数：brightness → contrast → saturation →
/// temperature → tint → highlights/shadows/blackPoint → clarity → vibrance →
/// brilliance → systemFilter → LUT。所有色彩调整通过单一 ColorMatrix 一次性应用
/// （由 `fromPostProcess` 组合），随后叠加暗角等覆盖层。
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
  ///    temperature/tint/highlights/shadows/blackPoint/clarity/vibrance/brilliance/
  ///    systemFilter/LUT-colormatrix-fallback）
  /// 3. （TODO）Sharpening — Unsharp Mask，需 ImageFilter.blur 合成，暂未实现
  /// 4. （TODO）Clarity — 高反差保留，需 compute shader，暂未实现
  /// 5. （TODO）Grain — Perlin 噪声，需逐像素操作，暂未实现
  /// 6. Vignette — 径向渐变覆盖层（已实现）
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

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw the (possibly LUT-processed) image with the combined color filter.
    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint()..colorFilter = colorFilter);

    // Step 3–5: Sharpening / Clarity / Grain — pending implementation (see class doc).
    // These require ImageFilter composition or compute shaders and are intentionally
    // not implemented in this task. The params.sharpen / params.color.clarity /
    // params.grain values are read by the UI but have no effect on output yet.

    // Step 6: Vignette (radial gradient overlay).
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

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }
}
