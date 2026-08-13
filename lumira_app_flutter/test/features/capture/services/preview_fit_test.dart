import 'dart:ui' show Size;

import 'package:camerawesome/preview_fit.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取景器 cover 缩放算法回归测试。
///
/// 背景：原版 camerawesome 1.4.0 的 cover 算法始终以取景框高度为基准缩放
/// 竖屏纹理（宽 = 高 × ratio），当取景框比纹理更宽（如 4:3 / 1:1 框 vs
/// 竖屏 16:9 预览流）时不会裁切而是留黑边，导致取景器显示比例与成片不一致
/// （iOS 非所见即所得）。OHOS fork 已修复，此处移植其算法并固定测试。
void main() {
  group('computeCoverPreviewSize', () {
    // 修复后 iOS 预览流 = 4:3 全传感器（竖屏），与成片一致
    const sensorTexture = Size(3024, 4032);
    // 修复前 iOS 预览流 = 16:9 视频（竖屏）
    const videoTexture = Size(2160, 3840);

    test('4:3 取景框 + 4:3 预览流：等比铺满，无裁剪', () {
      final size = computeCoverPreviewSize(
        textureSize: sensorTexture,
        boxSize: const Size(633, 844),
      );
      expect(size.width, closeTo(633, 0.01));
      expect(size.height, closeTo(844, 0.01));
    });

    test('全屏取景框 + 4:3 预览流：按高度铺满，左右居中裁剪', () {
      final size = computeCoverPreviewSize(
        textureSize: sensorTexture,
        boxSize: const Size(390, 844),
      );
      expect(size.width, closeTo(633, 0.01));
      expect(size.height, closeTo(844, 0.01));
    });

    test('1:1 取景框 + 4:3 预览流：按宽度铺满，上下居中裁剪', () {
      final size = computeCoverPreviewSize(
        textureSize: sensorTexture,
        boxSize: const Size(844, 844),
      );
      expect(size.width, closeTo(844, 0.01));
      expect(size.height, closeTo(844 / (3 / 4), 0.01));
    });

    test('4:3 取景框 + 16:9 预览流：按宽度铺满，上下居中裁剪（修复前留黑边）', () {
      final size = computeCoverPreviewSize(
        textureSize: videoTexture,
        boxSize: const Size(633, 844),
      );
      expect(size.width, closeTo(633, 0.01));
      expect(size.height, closeTo(633 / (9 / 16), 0.01));
    });

    test('全屏取景框 + 16:9 预览流：按高度铺满，左右居中裁剪', () {
      final size = computeCoverPreviewSize(
        textureSize: videoTexture,
        boxSize: const Size(390, 844),
      );
      expect(size.width, closeTo(844 * (9 / 16), 0.01));
      expect(size.height, closeTo(844, 0.01));
    });
  });
}
