import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/widgets/skin_smooth_preview.dart';

void main() {
  test('shouldRender: strength=0 返回 false（快速路径）', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: true, strength: 0.0);
    expect(r, isFalse);
  });
  test('shouldRender: enabled=false 返回 false', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: false, strength: 0.5);
    expect(r, isFalse);
  });
  test('shouldRender: 启用且 strength>0 返回 true', () {
    final r = SkinSmoothPreview.staticShouldRender(enabled: true, strength: 0.5);
    expect(r, isTrue);
  });
}