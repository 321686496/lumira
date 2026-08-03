// lib/features/capture/services/photo_pipeline.dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'dart_photo_pipeline.dart';

/// 照片后处理管线接口。
///
/// 双管线设计：
/// - [quickProcess]：主 Isolate，dart:ui Canvas GPU，<100ms，返回内存字节用于角标即时预览。
/// - [fullProcess]：worker Isolate，image 包纯 Dart CPU，400-800ms，返回最终文件路径。
///
/// 关键约束：
/// - `dart:ui`（Canvas/PictureRecorder/instantiateImageCodec）只能在主 Isolate 使用。
/// - `image` 包是纯 Dart，可在 worker Isolate 中使用。
abstract class PhotoPipeline {
  /// 同步快速处理（主 Isolate）。
  ///
  /// 输入：原始 JPEG 文件路径 + 后处理参数快照。
  /// 输出：近似最终图的内存字节（已调色 + 裁剪 + 降采样，无皮肤平滑/Sharpen/Grain）。
  /// 目标 < 100ms。失败时返回 null，调用方降级为等待 [fullProcess]。
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    String facing = 'back',
  });

  /// 异步完整处理（worker Isolate）。
  ///
  /// 输入同 [quickProcess]，额外支持 [fillLight] 补光与 [outputPath] 自定义输出路径。
  /// 输出：最终图文件路径 + 宽高元数据。
  /// 失败时内部降级为 `PhotoPostProcessor.processFile`（主 Isolate 实现）。
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
    String facing = 'back',
  });
}

/// quickProcess 的返回值：内存字节 + 宽高。
class QuickResult {
  const QuickResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// PNG 编码的字节流（可直接喂给 `Image.memory`）。
  final Uint8List bytes;
  final int width;
  final int height;
}

/// fullProcess 的返回值：文件路径 + 宽高。
class FullResult {
  const FullResult({
    required this.filePath,
    required this.width,
    required this.height,
  });

  final String filePath;
  final int width;
  final int height;
}

/// 默认 PhotoPipeline Provider，返回 [DartPhotoPipeline] 实现。
final photoPipelineProvider = Provider<PhotoPipeline>((ref) {
  return DartPhotoPipeline();
});
