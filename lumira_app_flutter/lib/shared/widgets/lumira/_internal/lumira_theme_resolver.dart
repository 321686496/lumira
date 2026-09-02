import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 全局组件 4 风格解析工具
///
/// 提供给 subagent 创建组件时统一参考的辅助方法，避免每个组件重复实现
/// 4 风格背景/边框/阴影逻辑。所有方法均为纯函数，输入 tokens + style，输出
/// 视觉规格。
///
/// 设计原则：
/// - 不持有状态，不依赖 BuildContext（除 ref.read）
/// - 所有颜色从 tokens 取，零硬编码（glass/female 白透明叠加除外）
/// - 与 NeuCard 的 4 风格分支渲染保持视觉一致
class LumiraThemeResolver {
  LumiraThemeResolver._();

  /// 解析容器（Dialog/BottomSheet/Menu/弹层卡片）的视觉规格
  ///
  /// - [radiusDp]：已转换为 dp 的圆角值
  /// - [tokens]：当前主题 tokens
  /// - [style]：当前 UI 风格
  static ContainerVisual containerVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required double radiusDp,
  }) {
    switch (style) {
      case UIStyle.neumorphic:
        return ContainerVisual(
          background: tokens.surface,
          border: null,
          shadows: tokens.shadowFloat,
          backdropBlurSigma: 0,
          glassOverlay: null,
        );
      case UIStyle.flat:
        return ContainerVisual(
          background: tokens.surface,
          border: Border.all(color: tokens.divider, width: 1),
          shadows: const [],
          backdropBlurSigma: 0,
          glassOverlay: null,
        );
      case UIStyle.glass:
        return ContainerVisual(
          background: ThemeTokens.glassFill(tokens),
          border: Border.all(color: ThemeTokens.glassBorder(tokens), width: 1.2),
          shadows: const [
            BoxShadow(color: Color(0x1F000000), offset: Offset(0, 12), blurRadius: 36),
          ],
          backdropBlurSigma: 0,
          glassOverlay: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.35),
              Colors.white.withOpacity(0.0),
            ],
          ),
        );
      case UIStyle.female:
        return ContainerVisual(
          background: tokens.surface,
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
          shadows: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.18),
              offset: const Offset(0, 10),
              blurRadius: 32,
            ),
          ],
          backdropBlurSigma: 0,
          glassOverlay: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.6),
              tokens.surface.withOpacity(0.0),
            ],
          ),
        );
    }
  }

  /// 解析 ListTile 点击反馈色
  static Color listTileSplashColor(ThemeTokens tokens, UIStyle style) {
    switch (style) {
      case UIStyle.neumorphic:
      case UIStyle.flat:
        return tokens.brandSubtle;
      case UIStyle.glass:
        return Colors.white.withOpacity(0.2);
      case UIStyle.female:
        return tokens.brandSubtle.withOpacity(0.3);
    }
  }

  /// 解析选中态高亮色（菜单项、Tab 选中、BottomNav 选中）
  static Color selectedColor(ThemeTokens tokens) => tokens.brand;

  /// 解析选中态文字色
  static Color selectedTextColor(ThemeTokens tokens) => tokens.brandText;

  /// 解析未选中态文字色
  static Color unselectedTextColor(ThemeTokens tokens) => tokens.textTertiary;

  /// 解析通用「卡片/内容块」表面的视觉规格（空态卡、信息卡、分隔块等）。
  ///
  /// 与 [containerVisual]（Dialog 弹层）区别：卡片默认走 NeuCard 的浮雕观感
  /// （新拟态用双向外阴影 [shadowConvex]），而非弹层上浮投影。
  ///
  /// - [radiusDp]：已转换为 dp 的圆角值
  /// - [emphasize]：true 用强浮雕 [shadowConvex]，false 用轻量 [shadowConvexSubtle]
  static ContainerVisual cardVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required double radiusDp,
    bool emphasize = false,
  }) {
    final convex = emphasize ? tokens.shadowConvex : tokens.shadowConvexSubtle;
    switch (style) {
      case UIStyle.neumorphic:
        return ContainerVisual(
          background: tokens.surface,
          border: null,
          shadows: convex,
          backdropBlurSigma: 0,
          glassOverlay: null,
        );
      case UIStyle.flat:
        return ContainerVisual(
          background: tokens.surfaceAlt,
          border: Border.all(color: tokens.divider, width: 1),
          shadows: const [],
          backdropBlurSigma: 0,
          glassOverlay: null,
        );
      case UIStyle.glass:
        return ContainerVisual(
          background: ThemeTokens.glassFill(tokens),
          border: Border.all(color: ThemeTokens.glassBorder(tokens), width: 1),
          shadows: const [
            BoxShadow(color: Color(0x1F000000), offset: Offset(0, 6), blurRadius: 20),
          ],
          backdropBlurSigma: 0,
          glassOverlay: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.28),
              Colors.white.withOpacity(0.0),
            ],
          ),
        );
      case UIStyle.female:
        return ContainerVisual(
          background: tokens.surface,
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
          shadows: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.16),
              offset: const Offset(0, 10),
              blurRadius: 28,
            ),
          ],
          backdropBlurSigma: 0,
          glassOverlay: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.5),
              tokens.surface.withOpacity(0.0),
            ],
          ),
        );
    }
  }

  /// 解析「叠在图片/动态画面上」的浮层视觉规格（改良悬浮新拟态）。
  ///
  /// 依据 Neumorphism 双轨体系：组件落点是非纯色底（照片/封面/预览图）时，
  /// 标准同色双向浮雕阴影无法被背景承接，会像光晕一样糊在图上、显脏。
  /// 因此改用「半透明 surface 底色 + 仅暗色投影（不含纯白高光）+ 细描边」表达
  /// 表面；禁用 inset 内嵌阴影（动态画面光影易错乱），按压反馈交由外层用 scale。
  ///
  /// - [radiusDp]：已转换为 dp 的圆角值
  /// - [tokens]：当前主题 tokens
  /// - [overlayAlpha]：半透明底色透明度（默认 0.85，位于图片上足够通透又保可读）
  /// - [shadowOpacity]：暗色投影不透明度（默认 0.45，柔和不脏）
  static ContainerVisual overlayOnImageVisual({
    required ThemeTokens tokens,
    required double radiusDp,
    double overlayAlpha = 0.85,
    double shadowOpacity = 0.45,
  }) {
    // 暗色投影基色：亮色主题用灰色、暗色主题用更深灰，保证浮层与底层略有分离
    final shadowBase = tokens.canvas.computeLuminance() > 0.5
        ? const Color(0xFF4A4742)
        : const Color(0xFF000000);
    return ContainerVisual(
      background: tokens.surface.withOpacity(overlayAlpha),
      border: Border.all(
        color: Colors.white.withOpacity(
          tokens.canvas.computeLuminance() > 0.5 ? 0.35 : 0.14,
        ),
        width: 0.6,
      ),
      shadows: [
        BoxShadow(
          color: shadowBase.withOpacity(shadowOpacity),
          offset: const Offset(0, 6),
          blurRadius: 18,
        ),
      ],
      backdropBlurSigma: 0,
      glassOverlay: null,
    );
  }

  /// rpx → dp 工具：app_theme 的 radius 字段存储 rpx 原值，widget 内部 /2 转 dp
  static double rpxToDp(double rpx) => rpx / 2;
}

/// 容器视觉规格（Dialog/BottomSheet/Menu 共用）
class ContainerVisual {
  final Color background;
  final Border? border;
  final List<BoxShadow> shadows;

  /// glass 风格的 backdrop blur sigma（0 表示不应用 blur）
  final double backdropBlurSigma;

  /// glass/female 风格的渐变叠加层（null 表示不叠加）
  final Gradient? glassOverlay;

  const ContainerVisual({
    required this.background,
    required this.border,
    required this.shadows,
    required this.backdropBlurSigma,
    required this.glassOverlay,
  });
}

/// 从 WidgetRef 读取当前主题的便捷扩展
extension LumiraThemeRef on WidgetRef {
  AppThemeData get appTheme => watch(appThemeProvider);
  ThemeTokens get tokens => watch(appThemeProvider).tokens;
  UIStyle get uiStyle => watch(appThemeProvider).style;
}
