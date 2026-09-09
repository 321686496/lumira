import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/preview_beauty_shader.dart';
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

  // ── shader asset key 回归测试（2026-09-09 修复）──
  // pubspec.yaml shaders 段声明的路径（assets/shaders/x.frag）原样成为编译
  // 产物的 asset key（AssetManifest 实证）。若候选列表缺失带前缀路径，
  // iOS/Android 上加载必然失败 → DetailEffectsLayer 静默回退原图 →
  // 细节栏调整锐化/磨皮/暗角/颗粒无实时变化。
  test('skin_smooth.frag 可从带 assets/ 前缀的 asset key 加载', () async {
    final program = await loadFragmentProgramFromCandidates(
      const ['assets/shaders/skin_smooth.frag', 'shaders/skin_smooth.frag'],
    );
    expect(program, isNotNull,
        reason: 'shader 编译产物 asset key 应为 assets/shaders/skin_smooth.frag');
  });

  test('edit_detail_effects.frag 可从带 assets/ 前缀的 asset key 加载', () async {
    final program = await loadFragmentProgramFromCandidates(
      const [
        'assets/shaders/edit_detail_effects.frag',
        'shaders/edit_detail_effects.frag',
      ],
    );
    expect(
      program,
      isNotNull,
      reason:
          'shader 编译产物 asset key 应为 assets/shaders/edit_detail_effects.frag（缺失会导致编辑页细节参数无实时预览）',
    );
  });
}