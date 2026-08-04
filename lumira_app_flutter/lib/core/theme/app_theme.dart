import 'package:flutter/material.dart';
import 'theme_tokens.dart';

class AppThemeData {
  final ThemeTokens tokens;
  final UIStyle style;

  const AppThemeData({
    required this.tokens,
    required this.style,
  });

  /// 卡片圆角（dp）。映射 App.vue --card-radius (rpx ÷ 2 ≈ dp)
  /// neumorphic: 28rpx → 14dp ... 注意: 此处按 brief 原值保留 28/20/28/48，rpx→dp 转换在 Widget 层处理
  double get cardRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 28;
      case UIStyle.flat:
        return 20;
      case UIStyle.glass:
        return 28;
      case UIStyle.female:
        return 48;
    }
  }

  /// 表面透明度（对应 App.vue --surface-alpha）
  double get surfaceAlpha {
    switch (style) {
      case UIStyle.neumorphic:
        return 1.0;
      case UIStyle.flat:
        return 1.0;
      case UIStyle.glass:
        return 0.55;
      case UIStyle.female:
        return 0.75;
    }
  }

  /// 卡片边框（对应 App.vue --card-border）
  Border? get cardBorder {
    switch (style) {
      case UIStyle.neumorphic:
        return null;
      case UIStyle.flat:
        return Border.all(color: tokens.divider, width: 1);
      case UIStyle.glass:
        return Border.all(color: const Color(0xFFFFFFFF).withOpacity(0.3), width: 1);
      case UIStyle.female:
        return null;
    }
  }

  /// 卡片阴影（对应 App.vue --shadow-convex）
  List<BoxShadow> get cardShadow {
    switch (style) {
      case UIStyle.neumorphic:
        return tokens.shadowConvex;
      case UIStyle.flat:
        return const [];
      case UIStyle.glass:
        return const [
          BoxShadow(color: Color(0x14000000), offset: Offset(0, 8), blurRadius: 32),
        ];
      case UIStyle.female:
        // App.vue --shadow-convex: 0 8px 32px rgba(brand-rgb, 0.15)
        return [
          BoxShadow(
            color: tokens.brand.withOpacity(0.15),
            offset: const Offset(0, 8),
            blurRadius: 32,
          ),
        ];
    }
  }

  // === 组件级尺寸 token（rpx 原值，widget 内部 /2 转 dp，与 cardRadius 保持一致） ===

  /// 按钮圆角（rpx）。neumorphic:28 / flat:20 / glass:28 / female:48
  double get buttonRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 28;
      case UIStyle.flat:
        return 20;
      case UIStyle.glass:
        return 28;
      case UIStyle.female:
        return 48;
    }
  }

  /// 输入框圆角（rpx）。neumorphic:12 / flat:8 / glass:12 / female:24
  double get inputRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 12;
      case UIStyle.flat:
        return 8;
      case UIStyle.glass:
        return 12;
      case UIStyle.female:
        return 24;
    }
  }

  /// 弹层（Dialog/BottomSheet/Menu）圆角（rpx）。neumorphic:20 / flat:16 / glass:20 / female:32
  double get popupRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 20;
      case UIStyle.flat:
        return 16;
      case UIStyle.glass:
        return 20;
      case UIStyle.female:
        return 32;
    }
  }

  /// 滑块轨道高度（dp，无 rpx 转换）。neumorphic:6 / flat:4 / glass:6 / female:8
  double get sliderTrackHeight {
    switch (style) {
      case UIStyle.neumorphic:
        return 6;
      case UIStyle.flat:
        return 4;
      case UIStyle.glass:
        return 6;
      case UIStyle.female:
        return 8;
    }
  }

  /// FAB 圆角（rpx）。neumorphic:24 / flat:20 / glass:24 / female:32
  double get fabRadius {
    switch (style) {
      case UIStyle.neumorphic:
        return 24;
      case UIStyle.flat:
        return 20;
      case UIStyle.glass:
        return 24;
      case UIStyle.female:
        return 32;
    }
  }

  /// 按钮视觉规格解析（4 variant × 4 风格）
  /// 调用方：LumiraButton / LumiraIconButton
  ButtonVisual buttonVisual(ButtonVariant variant) {
    switch (variant) {
      case ButtonVariant.primary:
        return ButtonVisual(
          background: tokens.brand,
          foreground: tokens.textInverse,
          border: null,
          shadows: style == UIStyle.neumorphic
              ? tokens.shadowConvexBrand
              : const [],
        );
      case ButtonVariant.secondary:
        switch (style) {
          case UIStyle.neumorphic:
            return ButtonVisual(
              background: tokens.surface,
              foreground: tokens.brandText,
              border: null,
              shadows: tokens.shadowConvexSubtle,
            );
          case UIStyle.flat:
            return ButtonVisual(
              background: tokens.surfaceAlt,
              foreground: tokens.brandText,
              border: Border.all(color: tokens.divider, width: 1),
              shadows: const [],
            );
          case UIStyle.glass:
            return ButtonVisual(
              background: Colors.white.withOpacity(0.55),
              foreground: tokens.brandText,
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              shadows: const [
                BoxShadow(color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 16),
              ],
            );
          case UIStyle.female:
            return ButtonVisual(
              background: tokens.brandSubtle,
              foreground: tokens.brandText,
              border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
              shadows: [
                BoxShadow(
                  color: tokens.brand.withOpacity(0.15),
                  offset: const Offset(0, 6),
                  blurRadius: 20,
                ),
              ],
            );
        }
      case ButtonVariant.ghost:
        return ButtonVisual(
          background: Colors.transparent,
          foreground: tokens.brandText,
          border: null,
          shadows: const [],
        );
      case ButtonVariant.danger:
        return ButtonVisual(
          background: tokens.danger,
          foreground: Colors.white,
          border: null,
          shadows: style == UIStyle.neumorphic
              ? [
                  BoxShadow(
                    color: tokens.danger.withOpacity(0.3),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                  ),
                ]
              : const [],
        );
    }
  }

  /// 输入框视觉规格解析（4 状态 × 4 风格）
  /// 调用方：LumiraTextField / LumiraDropdown
  InputVisual inputVisual(InputState state) {
    final isFocused = state == InputState.focused;
    final isError = state == InputState.error;
    final isDisabled = state == InputState.disabled;

    Color borderAccent = tokens.divider;
    if (isFocused) {
      borderAccent = tokens.brand;
    } else if (isError) {
      borderAccent = tokens.danger;
    }

    switch (style) {
      case UIStyle.neumorphic:
        return InputVisual(
          background: tokens.surface,
          border: null,
          shadows: isDisabled ? const [] : tokens.shadowConcaveSubtle,
          borderAccent: borderAccent,
          foreground: isDisabled ? tokens.textTertiary : tokens.textPrimary,
        );
      case UIStyle.flat:
        return InputVisual(
          background: tokens.surfaceAlt,
          border: Border.all(color: borderAccent, width: isFocused ? 1.5 : 1),
          shadows: const [],
          borderAccent: borderAccent,
          foreground: isDisabled ? tokens.textTertiary : tokens.textPrimary,
        );
      case UIStyle.glass:
        return InputVisual(
          background: Colors.white.withOpacity(0.4),
          border: Border.all(color: borderAccent.withOpacity(0.8), width: isFocused ? 1.5 : 1),
          shadows: const [],
          borderAccent: borderAccent,
          foreground: isDisabled ? tokens.textTertiary : tokens.textPrimary,
        );
      case UIStyle.female:
        return InputVisual(
          background: tokens.brandSubtle.withOpacity(0.5),
          border: Border.all(
            color: isFocused ? borderAccent : Colors.white.withOpacity(0.6),
            width: isFocused ? 1.2 : 0.8,
          ),
          shadows: const [],
          borderAccent: borderAccent,
          foreground: isDisabled ? tokens.textTertiary : tokens.textPrimary,
        );
    }
  }

  /// 女性美学专属：多渐变卡片背景（5 层视觉）
  /// 仅在 style == UIStyle.female 时由 Widget 调用
  /// 层 1: 线性渐变基底（brand→brandLight，135deg）
  /// 层 2: 径向高光（brandSubtle 中心 70%透明度）
  /// 层 3: 表面 75% 透明度（surfaceAlpha）
  /// 层 4: 白色 1px 边框（女性美学实际 cardBorder 为 null，但多渐变卡片本身需细边框强化层次）
  /// 层 5: 品牌色 0.15 阴影（cardShadow 已提供）
  MultiGradientSpec? get multiGradient {
    if (style != UIStyle.female) return null;
    return MultiGradientSpec(
      linear: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.brandSubtle.withOpacity(0.75),
          tokens.surface.withOpacity(0.75),
        ],
      ),
      radialHighlight: RadialGradient(
        center: Alignment.topLeft,
        radius: 0.85,
        colors: [
          tokens.brandLight.withOpacity(0.45),
          tokens.brandLight.withOpacity(0.0),
        ],
      ),
      hairlineBorder: Border.all(color: const Color(0xFFFFFFFF).withOpacity(0.6), width: 0.5),
    );
  }

  ThemeData toThemeData() {
    final isLight = tokens.canvas.computeLuminance() > 0.5;
    return ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      primaryColor: tokens.brand,
      scaffoldBackgroundColor: tokens.canvas,
      cardColor: tokens.surface,
      dividerColor: tokens.divider,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
          letterSpacing: 0.04,
        ),
        bodyLarge: TextStyle(fontSize: 30, color: tokens.textPrimary),
        bodyMedium: TextStyle(fontSize: 26, color: tokens.textSecondary),
        bodySmall: TextStyle(fontSize: 22, color: tokens.textTertiary),
      ),
    );
  }
}

/// 女性美学多渐变卡片规格
class MultiGradientSpec {
  final LinearGradient linear;
  final RadialGradient radialHighlight;
  final Border hairlineBorder;

  const MultiGradientSpec({
    required this.linear,
    required this.radialHighlight,
    required this.hairlineBorder,
  });
}

// === 组件视觉规格数据类（供 Lumira 全局组件使用） ===

/// LumiraButton variant
enum ButtonVariant { primary, secondary, ghost, danger }

/// LumiraButton 视觉解析结果
class ButtonVisual {
  final Color background;
  final Color foreground;
  final Border? border;
  final List<BoxShadow> shadows;

  const ButtonVisual({
    required this.background,
    required this.foreground,
    required this.border,
    required this.shadows,
  });
}

/// LumiraTextField 状态
enum InputState { default_, focused, error, disabled }

/// LumiraTextField 视觉解析结果
class InputVisual {
  final Color background;
  final Border? border;
  final List<BoxShadow> shadows;

  /// 边框强调色（focused=brand, error=danger, default=divider）
  /// 用于 flat/glass/female 风格的边框颜色，neumorphic 风格可忽略
  final Color borderAccent;

  /// 文字颜色（disabled 时为 textTertiary）
  final Color foreground;

  const InputVisual({
    required this.background,
    required this.border,
    required this.shadows,
    required this.borderAccent,
    required this.foreground,
  });
}
