// test/features/capture/services/leg_stretch_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/dart_photo_pipeline.dart';

void main() {
  group('legStretchRgba（字节级快速实现）', () {
    // 构造一张已知内容的测试图（竖屏 20x30，RGBA）。
    img.Image buildTestImage(int w, int h) {
      final image = img.Image(width: w, height: h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          // 用坐标生成确定性颜色，便于对比。
          image.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 255);
        }
      }
      return image;
    }

    void expectMatchesReference({
      required img.Image src,
      required int legStretch,
    }) {
      // 参考实现：img.Image 逐像素版（applyLegStretchImg 只读 src，不改写）。
      final ref = applyLegStretchImg(src, legStretch: legStretch);
      final refBytes = ref.getBytes(order: img.ChannelOrder.rgba);

      // 快速实现：字节级。
      final srcBytes = src.getBytes(order: img.ChannelOrder.rgba);
      final fast = legStretchRgba(
        Uint8List.fromList(srcBytes),
        width: src.width,
        height: src.height,
        legStretch: legStretch,
      );

      expect(fast.height, ref.height, reason: '输出高度应一致');
      expect(
        fast.bytes,
        refBytes,
        reason: '输出 RGBA 字节应逐字节一致（legStretch=$legStretch）',
      );
    }

    test('legStretch=0 时不拉伸', () {
      final src = buildTestImage(20, 30);
      final srcBytes = src.getBytes(order: img.ChannelOrder.rgba);
      final fast = legStretchRgba(
        Uint8List.fromList(srcBytes),
        width: 20,
        height: 30,
        legStretch: 0,
      );
      expect(fast.height, 30);
      expect(fast.bytes, srcBytes);
    });

    test('半档 legStretch=50 与参考实现逐字节一致', () {
      expectMatchesReference(src: buildTestImage(20, 30), legStretch: 50);
    });

    test('满档 legStretch=100 与参考实现逐字节一致', () {
      expectMatchesReference(src: buildTestImage(20, 30), legStretch: 100);
    });

    test('小档位 legStretch=10 与参考实现逐字节一致', () {
      expectMatchesReference(src: buildTestImage(20, 30), legStretch: 10);
    });

    test('非整数比例宽高（21x47）满档与参考实现逐字节一致', () {
      expectMatchesReference(src: buildTestImage(21, 47), legStretch: 100);
    });
  });
}
