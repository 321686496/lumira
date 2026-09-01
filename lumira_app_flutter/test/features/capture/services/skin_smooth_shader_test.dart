import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/skin_smooth_shader.dart';

void main() {
  group('SkinSmoothConfig', () {
    test('strength 归一化 clamp 0..1', () {
      expect(
          skinStrength(const PostProcess(color: PostProcessColor(), smoothStrength: 50)),
          closeTo(0.5, 1e-9));
      expect(
          skinStrength(const PostProcess(color: PostProcessColor(), smoothStrength: 101)),
          1.0);
      expect(
          skinStrength(const PostProcess(color: PostProcessColor(), smoothStrength: -5)),
          0.0);
    });
    test('needsSkin 仅 smoothStrength>0', () {
      expect(
          needsSkin(const PostProcess(color: PostProcessColor(), smoothStrength: 30)),
          isTrue);
      expect(needsSkin(const PostProcess(color: PostProcessColor())), isFalse);
    });
    test('fromPostProcess 生成配置', () {
      final c = SkinSmoothConfig.fromPostProcess(
          const PostProcess(color: PostProcessColor(), smoothStrength: 60));
      expect(c.strength, closeTo(0.6, 1e-9));
    });
  });
}