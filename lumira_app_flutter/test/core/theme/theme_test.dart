import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/core/theme/app_theme.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';

void main() {
  group('ThemeTokens', () {
    test('should return non-null tokens for each of 8 themes', () {
      for (final theme in ThemeKey.values) {
        final tokens = ThemeTokens.of(theme);
        expect(tokens, isNotNull,
            reason: 'theme $theme returned null tokens');
        expect(tokens.canvas, isNotNull);
        expect(tokens.brand, isNotNull);
        expect(tokens.brandDeep, isNotNull);
        expect(tokens.brandLight, isNotNull,
            reason: 'theme $theme missing brandLight');
        expect(tokens.shadowConvex.length, greaterThan(0));
        expect(tokens.shadowFloat.length, greaterThan(0));
      }
    });

    test('warmWhite canvas should be #FAF7F2', () {
      expect(ThemeTokens.of(ThemeKey.warmWhite).canvas.value, 0xFFFAF7F2);
    });

    test('ink canvas should be #1C1A17', () {
      expect(ThemeTokens.of(ThemeKey.ink).canvas.value, 0xFF1C1A17);
    });

    test('retro brand should be #B8855A', () {
      // Neumorphic fix: 调深以提升胶片复古质感
      expect(ThemeTokens.of(ThemeKey.retro).brand.value, 0xFFB8855A);
    });

    test('fresh brand should be #7BA068', () {
      // Neumorphic fix: 调深以让绿色更有活力
      expect(ThemeTokens.of(ThemeKey.fresh).brand.value, 0xFF7BA068);
    });

    test('cozy brand should be #D89090', () {
      // Neumorphic fix: 调深以提升温馨粉质感
      expect(ThemeTokens.of(ThemeKey.cozy).brand.value, 0xFFD89090);
    });

    test('macaron brand should be #7BC4AB', () {
      // Neumorphic fix: 提升饱和度让薄荷绿更鲜活
      expect(ThemeTokens.of(ThemeKey.macaron).brand.value, 0xFF7BC4AB);
    });

    test('morandi brand should be #8B9DAF', () {
      expect(ThemeTokens.of(ThemeKey.morandi).brand.value, 0xFF8B9DAF);
    });

    test('rosegold brand should be #BC8888', () {
      // Neumorphic fix: 调深以让玫瑰金特色更明显
      expect(ThemeTokens.of(ThemeKey.rosegold).brand.value, 0xFFBC8888);
    });
  });

  group('AppThemeData', () {
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);

    test('neumorphic style: cardRadius=28, surfaceAlpha=1.0, border=null', () {
      final t = AppThemeData(tokens: tokens, style: UIStyle.neumorphic);
      expect(t.cardRadius, 28);
      expect(t.surfaceAlpha, 1.0);
      expect(t.cardBorder, isNull);
      expect(t.multiGradient, isNull);
    });

    test('flat style: cardRadius=20, surfaceAlpha=1.0, border=divider', () {
      final t = AppThemeData(tokens: tokens, style: UIStyle.flat);
      expect(t.cardRadius, 20);
      expect(t.surfaceAlpha, 1.0);
      expect(t.cardBorder, isNotNull);
      expect(t.multiGradient, isNull);
    });

    test('glass style: cardRadius=28, surfaceAlpha=0.55, border=white', () {
      final t = AppThemeData(tokens: tokens, style: UIStyle.glass);
      expect(t.cardRadius, 28);
      expect(t.surfaceAlpha, 0.55);
      expect(t.cardBorder, isNotNull);
      expect(t.multiGradient, isNull);
    });

    test('female style: cardRadius=48, surfaceAlpha=0.75, border=null, multiGradient!=null', () {
      final t = AppThemeData(tokens: tokens, style: UIStyle.female);
      expect(t.cardRadius, 48);
      expect(t.surfaceAlpha, 0.75);
      expect(t.cardBorder, isNull);
      expect(t.multiGradient, isNotNull,
          reason: '女性美学风格必须提供多渐变规格');
      // 线性渐变 3 色（高光→表面→暖调），径向氛围光 2 色
      expect(t.multiGradient!.linear.colors.length, 3);
      expect(t.multiGradient!.radialHighlight.colors.length, 2);
    });
  });

  group('Providers', () {
    test('themeKeyProvider defaults to warmWhite', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeKeyProvider), ThemeKey.warmWhite);
    });

    test('uiStyleProvider defaults to neumorphic', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(uiStyleProvider), UIStyle.neumorphic);
    });

    test('appThemeProvider composes tokens + style', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final theme = container.read(appThemeProvider);
      expect(theme.tokens.canvas.value, 0xFFFAF7F2);
      expect(theme.style, UIStyle.neumorphic);
    });

    test('changing themeKeyProvider propagates to appThemeProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeKeyProvider.notifier).state = ThemeKey.ink;
      final theme = container.read(appThemeProvider);
      expect(theme.tokens.canvas.value, 0xFF1C1A17);
    });

    test('changing uiStyleProvider propagates to appThemeProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(uiStyleProvider.notifier).state = UIStyle.female;
      final theme = container.read(appThemeProvider);
      expect(theme.style, UIStyle.female);
      expect(theme.multiGradient, isNotNull);
    });
  });
}
