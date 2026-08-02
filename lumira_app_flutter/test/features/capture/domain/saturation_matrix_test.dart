// test/features/capture/domain/saturation_matrix_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('Saturation matrix color cast fix', () {
    test('pure gray image keeps gray after saturation change (no color cast)', () {
      // 纯灰图 R=G=B=128，饱和度调整后应仍为灰（R=G=B），无色偏
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: 50),
      );
      final matrix = composePostProcessMatrix(postProcess);

      // 模拟纯灰像素 R=G=B=128, A=255
      final r = 128.0, g = 128.0, b = 128.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      // 灰色像素饱和度调整后应仍为灰色（R=G=B，允许浮点误差）
      expect((newR - newG).abs(), lessThan(0.5), reason: 'R and G should match for gray pixel');
      expect((newG - newB).abs(), lessThan(0.5), reason: 'G and B should match for gray pixel');
      expect((newR - newB).abs(), lessThan(0.5), reason: 'R and B should match for gray pixel');
    });

    test('saturation -100 produces grayscale (luminance only)', () {
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: -100),
      );
      final matrix = composePostProcessMatrix(postProcess);

      // 红色像素 (255,0,0) 饱和度-100 后应变为亮度值
      final r = 255.0, g = 0.0, b = 0.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      // 红色像素变灰后 R=G=B
      expect((newR - newG).abs(), lessThan(1.0));
      expect((newG - newB).abs(), lessThan(1.0));
    });

    test('saturation 0 is identity for color channels', () {
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: 0),
      );
      final matrix = composePostProcessMatrix(postProcess);

      final r = 100.0, g = 150.0, b = 200.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      expect(newR, closeTo(100, 0.5));
      expect(newG, closeTo(150, 0.5));
      expect(newB, closeTo(200, 0.5));
    });
  });
}
