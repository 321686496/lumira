// lib/features/capture/services/ohos_native_processor.dart
//
// OHOS 原生全尺寸后处理封装。
//
// 通过独立 BasicMessageChannel `lumira/fullsize_processor` 调用原生
// FullSizeImageProcessor（image 硬件解码 + 连续内存逐像素 + ImagePacker 硬件
// JPEG 编码），在**全尺寸 4000px** 下一次性应用全部六种效果：
//   色彩矩阵 / 锐化 / 清晰度 / 颗粒 / 磨皮 / 暗角
// 外加方向对齐 / 中心裁剪 / 前置镜像 —— 与原 CPU 链路语义一致。
//
// 目标：≤800ms、全尺寸输出、不砍任何功能。
//
// 能力判定：仅当变换为恒等（rotation/flip/straighten 全默认）且无自定义裁剪框
// 时才走原生路径；否则回退到现有 CPU 链路（保证变换/自定义裁剪功能不受影响）。
import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';

import '../data/capture_state.dart';
import '../domain/filter_recipe.dart' show composePostProcessMatrix;
import '../domain/photo_template.dart';

/// 原生全尺寸处理结果。
class OhosNativeProcessResult {
  const OhosNativeProcessResult({
    required this.ok,
    required this.outputPath,
    required this.width,
    required this.height,
    required this.elapsedMs,
    required this.error,
  });

  final bool ok;
  final String outputPath;
  final int width;
  final int height;
  final int elapsedMs;
  final String error;
}

/// OHOS 原生全尺寸后处理器。
class OhosNativeProcessor {
  static const BasicMessageChannel<Object?> _channel =
      BasicMessageChannel<Object?>('lumira/fullsize_processor', StandardMessageCodec());

  /// 是否可用：OHOS 平台才注册了原生 channel。
  static bool get isSupported => Platform.operatingSystem == 'ohos';

  /// 能力判定：仅当变换恒等且无自定义裁剪框时原生链路可完整覆盖。
  static bool capabilityCovers(
    PostProcess params, {
    TransformParams? transform,
  }) {
    final isIdentityTransform = transform == null || transform.isIdentity;
    // 无自定义裁剪框，或裁剪框为默认整幅（x/y≈0 且 w/h≈1）。
    final custom = params.customCropRect;
    final noCustomCrop = custom == null ||
        (custom.x.abs() < 0.001 &&
            custom.y.abs() < 0.001 &&
            (custom.w - 1.0).abs() < 0.001 &&
            (custom.h - 1.0).abs() < 0.001);
    return isIdentityTransform && noCustomCrop;
  }

  /// 计算传给原生的目标宽高比（宽/高）。
  static double computeTargetRatio(String aspectRatio, bool isPortrait) {
    return CaptureState.computeTargetRatio(aspectRatio, isPortrait) ?? 1.0;
  }

  /// 调用原生全尺寸处理。输出写入 [outputPath]。
  ///
  /// [targetRatio] 直接传入已计算好的目标宽高比（宽/高），避免反推 aspectRatio 字符串。
  static Future<OhosNativeProcessResult> process({
    required String inputPath,
    required String outputPath,
    required PostProcess params,
    required double targetRatio,
    required bool isPortrait,
    required String facing,
    int quality = 95,
  }) async {
    final matrix = composePostProcessMatrix(params);
    final clarityVal = params.color.clarity ?? 0;
    final isFront = facing == 'front';

    // 入参顺序与原生 handler 保持一致：
    // [inputPath, outputPath, targetRatio, isPortrait, isFront,
    //  colorMatrix(20), sharpen, clarity, grain, smoothStrength, vignette, quality]
    final List<Object?> args = <Object?>[
      inputPath,
      outputPath,
      targetRatio,
      isPortrait,
      isFront,
      matrix,
      params.sharpen,
      clarityVal,
      params.grain,
      params.smoothStrength,
      params.vignette,
      quality,
    ];

    List<Object?>? reply;
    try {
      reply = await _channel.send(args) as List<Object?>?;
    } catch (e) {
      return OhosNativeProcessResult(
        ok: false,
        outputPath: outputPath,
        width: 0,
        height: 0,
        elapsedMs: 0,
        error: 'channel-error: $e',
      );
    }
    if (reply == null || reply.isEmpty) {
      return OhosNativeProcessResult(
        ok: false,
        outputPath: outputPath,
        width: 0,
        height: 0,
        elapsedMs: 0,
        error: 'channel-empty-reply',
      );
    }
    return OhosNativeProcessResult(
      ok: (reply[0] as bool?) ?? false,
      outputPath: (reply[1] as String?) ?? outputPath,
      width: (reply[2] as int?) ?? 0,
      height: (reply[3] as int?) ?? 0,
      elapsedMs: (reply[4] as int?) ?? 0,
      error: (reply[5] as String?) ?? '',
    );
  }

  /// 便捷方法：把原生字节校验输入存在。若输入不存在直接返回失败，避免原生侧 openSync 抛错。
  static Future<bool> inputExists(String inputPath) async {
    try {
      final file = File(inputPath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }
}