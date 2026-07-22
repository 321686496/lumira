// lib/features/capture/services/lut_processor.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, Colors;
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';

/// LUT 处理器
///
/// **回退策略说明**（符合 Global Constraints "LUT：优先 gpu_image 3D LUT，运行时检测
/// 不可用时回退 ColorMatrix 近似"）：
///
/// `gpu_image 1.0.0` 仅提供 Platform View UI 组件，不支持 3D LUT 文件加载，且不支持
/// HarmonyOS。因此 `apply3DLut` **不抛异常**，而是直接使用 `composeLutMatrix` 生成的
/// 4x5 ColorMatrix 对输入图像进行一次 ColorFilter 绘制，返回处理后的 [ui.Image]。
///
/// 这使得 [ImageProcessingService.process] 中的 Step 1（LUT 处理）能够正常完成，
/// 后续 Step 2 的组合 ColorMatrix 中会排除 LUT 分量（`params.copyWith(lut: 'none')`），
/// 避免 LUT 被双重应用。
class LutProcessor {
  LutProcessor._();

  /// 对 [input] 应用名为 [lutName] 的 LUT 效果。
  ///
  /// 实现方式：使用 [composeLutMatrix] 将 LUT 转换为 4x5 色彩矩阵，
  /// 然后通过 `ColorFilter.matrix` + `Canvas.drawImage` 绘制到新图像。
  ///
  /// 返回值：处理后的新 [ui.Image]（与 [input] 同尺寸）。
  /// 如果 [lutName] 为 `'none'` 或不在已知列表中，返回 [input] 原图（不复制）。
  static Future<ui.Image> apply3DLut({
    required ui.Image input,
    required String lutName,
  }) async {
    if (lutName == 'none') return input;

    final matrix = composeLutMatrix(lutName);
    if (matrix == null) return input;

    final width = input.width;
    final height = input.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(
      input,
      ui.Offset.zero,
      ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix),
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(width, height);
    picture.dispose();
    return result;
  }
}
