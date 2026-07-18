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
