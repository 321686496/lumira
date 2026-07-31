// test/features/capture/services/photo_pipeline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

void main() {
  group('computeCropRect', () {
    // 传感器 4032x3024 (4:3)，竖屏屏幕 9:19.5
    const imgW = 4032;
    const imgH = 3024;
    const screenRatio = 9.0 / 19.5;
    const isPortrait = true;

    test('fullscreen 模式按 screenRatio cover 裁剪', () {
      final rect = PhotoPostProcessor.computeCropRect(
        'fullscreen', imgW, imgH, screenRatio, isPortrait,
      );
      // cover: 短边对齐，裁掉长边多余部分；裁剪后比例应近似 screenRatio
      expect(rect[2] / rect[3], closeTo(screenRatio, 0.01));
    });

    test('1:1 模式输出正方形', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '1:1', imgW, imgH, screenRatio, isPortrait,
      );
      expect(rect[2].toDouble(), closeTo(rect[3].toDouble(), 1.0));
    });

    test('4:3 竖屏输出 3:4', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '4:3', imgW, imgH, screenRatio, isPortrait,
      );
      expect(rect[2] / rect[3], closeTo(3.0 / 4.0, 0.01));
    });

    test('3:4 模式输出 3:4', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '3:4', imgW, imgH, screenRatio, isPortrait,
      );
      expect(rect[2] / rect[3], closeTo(3.0 / 4.0, 0.01));
    });

    test('任意 W:H 格式（如 16:9）按字面比例输出', () {
      final rect = PhotoPostProcessor.computeCropRect(
        '16:9', imgW, imgH, screenRatio, isPortrait,
      );
      expect(rect[2] / rect[3], closeTo(16.0 / 9.0, 0.01));
    });
  });
}
