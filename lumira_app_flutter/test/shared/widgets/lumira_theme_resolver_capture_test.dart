import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/capture_appearance.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/_internal/lumira_theme_resolver.dart';

void main() {
  final light = ThemeTokens.of(ThemeKey.warmWhite);
  final dark = ThemeTokens.of(ThemeKey.ink);

  CaptureOverlayVisual resolve(ThemeTokens tokens, UIStyle style,
          CaptureAppearance appearance, CaptureOverlayRole role) =>
      LumiraThemeResolver.captureOverlayVisual(
        tokens: tokens,
        style: style,
        appearance: appearance,
        role: role,
        radiusDp: 20,
      );

  group('immersive：跨风格统一暗色浮层', () {
    for (final style in UIStyle.values) {
      test('pill/$style 暗色胶囊 + 白前景 + 金 accent', () {
        final v = resolve(
            light, style, CaptureAppearance.immersive, CaptureOverlayRole.pill);
        expect(v.background, const Color(0xFF141416).withOpacity(0.72));
        expect(v.foreground, Colors.white);
        expect(v.foregroundSecondary, Colors.white70);
        expect(v.foregroundMuted, Colors.white38);
        expect(v.accent, const Color(0xFFC9A96E));
        expect(v.onAccent, Colors.black);
        expect(v.fillSubtle, Colors.white12);
      });

      test('panel/$style 近黑面板', () {
        final v = resolve(
            light, style, CaptureAppearance.immersive, CaptureOverlayRole.panel);
        expect(v.background, const Color(0xFF141416).withOpacity(0.80));
        expect(v.foreground, Colors.white);
      });

      test('blur/$style 新拟态不毛玻璃，其余 20', () {
        final v = resolve(
            light, style, CaptureAppearance.immersive, CaptureOverlayRole.pill);
        expect(v.backdropBlurSigma, style == UIStyle.neumorphic ? 0 : 20);
      });
    }
  });

  group('theme：按风格「叠照片浮层」取向', () {
    test('neumorphic pill：实心 surface + divider 细边 + 无阴影无模糊', () {
      final v = resolve(
          light, UIStyle.neumorphic, CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(v.background, light.surface.withOpacity(0.92));
      expect(v.border, Border.all(color: light.divider, width: 0.8));
      expect(v.shadows, isEmpty);
      expect(v.backdropBlurSigma, 0);
    });

    test('flat pill：半透明 surfaceAlt + divider 边 + 无阴影', () {
      final v = resolve(
          light, UIStyle.flat, CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(v.background, light.surfaceAlt.withOpacity(0.88));
      expect(v.shadows, isEmpty);
      expect(v.backdropBlurSigma, 0);
    });

    test('glass pill：glassFill + glassBorder + blur 20', () {
      final v = resolve(
          light, UIStyle.glass, CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(v.background, ThemeTokens.glassFill(light));
      expect(v.border, Border.all(color: ThemeTokens.glassBorder(light), width: 1));
      expect(v.backdropBlurSigma, 20);
      expect(v.shadows, isNotEmpty);
    });

    test('female pill：surface + 白细边 + 品牌柔和阴影', () {
      final v = resolve(
          light, UIStyle.female, CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(v.background, light.surface.withOpacity(0.92));
      expect(v.border,
          Border.all(color: Colors.white.withOpacity(0.7), width: 0.8));
      expect(v.shadows, isNotEmpty);
      expect(v.shadows.first.color, light.brand.withOpacity(0.15));
    });

    test('前景取 tokens：浅色主题深字、暗色主题浅字', () {
      final vLight = resolve(light, UIStyle.neumorphic,
          CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(vLight.foreground, light.textPrimary);
      expect(vLight.accent, light.brand);
      final vDark = resolve(dark, UIStyle.neumorphic,
          CaptureAppearance.theme, CaptureOverlayRole.pill);
      expect(vDark.foreground, dark.textPrimary);
    });

    test('panel：neumorphic 实心 surface（不透明）', () {
      final v = resolve(
          light, UIStyle.neumorphic, CaptureAppearance.theme, CaptureOverlayRole.panel);
      expect(v.background, light.surface);
      expect(v.shadows, isEmpty);
    });
  });
}
