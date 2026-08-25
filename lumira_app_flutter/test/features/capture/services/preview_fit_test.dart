import 'dart:ui' show Offset, Size;

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

  group('computePreviewTapOffset', () {
    // 修复背景：全屏取景框（390×844）+ 4:3 竖屏传感器（3024×4032）时，
    // cover 模式纹理被放大到 633×844 并左右居中裁切。手势层覆盖整张纹理，
    // 其 localPosition 相对纹理左上角（在取景框左侧 -121.5 处），导致对焦框
    // 相对手指触点向右偏移 121.5。该函数把纹理坐标换算回取景框坐标。
    test('cover 全屏 + 4:3 纹理：水平向左平移，垂直无偏移', () {
      final offset = computePreviewTapOffset(
        textureSize: const Size(633, 844),
        boxSize: const Size(390, 844),
      );
      expect(offset.dx, closeTo(-121.5, 0.01));
      expect(offset.dy, closeTo(0, 0.01));

      // 手指点屏幕中央 (195, 422) → 手势层 localPosition (316.5, 422)
      // → 换算回取景框坐标后应回到 (195, 422)
      final tap = const Offset(316.5, 422) + offset;
      expect(tap.dx, closeTo(195, 0.01));
      expect(tap.dy, closeTo(422, 0.01));
    });

    test('contain 竖屏 + 16:9 纹理：垂直向下平移，水平无偏移', () {
      // 16:9 纹理 390×219.4 居中放入 390×844 取景框
      final offset = computePreviewTapOffset(
        textureSize: const Size(390, 219.4),
        boxSize: const Size(390, 844),
      );
      expect(offset.dx, closeTo(0, 0.01));
      expect(offset.dy, closeTo((844 - 219.4) / 2, 0.01));
    });

    test('等比铺满（4:3 框 + 4:3 纹理）：无偏移', () {
      final offset = computePreviewTapOffset(
        textureSize: const Size(633, 844),
        boxSize: const Size(633, 844),
      );
      expect(offset.dx, closeTo(0, 0.01));
      expect(offset.dy, closeTo(0, 0.01));
    });
  });
}
