import 'dart:ui';

/// Computes the render size for a `cover` (aspect-fill) camera preview.
///
/// This mirrors the algorithm used by [AwesomeCameraPreview] so the viewfinder
/// can be tested from the app test suite. See `awesome_camera_preview.dart`.
///
/// 修复说明（移植自 camerawesome_ohos 1.0.2）：
/// 原版 1.4.0 始终以取景框高度为基准缩放纹理（竖屏宽 = 高 × ratio），
/// 当取景框比纹理更宽（如 4:3 / 1:1 框 vs 竖屏 16:9 预览流）时不会裁切而是
/// 留黑边，取景器显示比例与成片不一致。正确 cover 应取“按宽铺满”与“按高铺满”
/// 中能完整覆盖取景框的那一个，再对超出部分居中裁切。
Size computeCoverPreviewSize({
  required Size textureSize,
  required Size boxSize,
}) {
  final previewRatio = textureSize.width / textureSize.height;
  // 按宽度铺满时的目标尺寸
  final targetWidthByWidth = boxSize.width;
  final targetHeightByWidth = boxSize.width / previewRatio;
  // 按高度铺满时的目标尺寸
  final targetWidthByHeight = boxSize.height * previewRatio;
  final targetHeightByHeight = boxSize.height;
  // 选择能完整覆盖取景框的那一个，超出部分由 ClipRect 居中裁切
  final bool useWidth = targetHeightByWidth >= boxSize.height;
  return useWidth
      ? Size(targetWidthByWidth, targetHeightByWidth)
      : Size(targetWidthByHeight, targetHeightByHeight);
}
