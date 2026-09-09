import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/capture_appearance.dart';
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
  /// - [darkContext]：true = 渲染在黑画布上（如预览页沉浸式看图）。
  ///   仅对 neumorphic 生效：卡面近黑带主题色调 + 深暗影 + 微亮高光
  ///   （见 [darkNeuPalette]）；其余风格不受影响。
  static ContainerVisual cardVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required double radiusDp,
    bool emphasize = false,
    bool darkContext = false,
  }) {
    final convex = emphasize ? tokens.shadowConvex : tokens.shadowConvexSubtle;
    switch (style) {
      case UIStyle.neumorphic:
        if (darkContext) {
          // 黑画布浮雕：近黑卡面 + 更深暗影 + 微亮高光（明暗梯度见 darkNeuPalette）
          final p = darkNeuPalette(tokens);
          final offset = emphasize ? const Offset(6, 6) : const Offset(4, 4);
          final blur = emphasize ? 14.0 : 8.0;
          return ContainerVisual(
            background: p.surface,
            border: null,
            shadows: [
              BoxShadow(color: p.shadow, offset: offset, blurRadius: blur),
              BoxShadow(color: p.highlight, offset: -offset, blurRadius: blur),
            ],
            backdropBlurSigma: 0,
            glassOverlay: null,
          );
        }
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

  /// 暗色语境（黑画布，如拍摄预览页沉浸式看图）新拟态配色。
  ///
  /// 「组件与背景同色」铁律在黑画布上的推论：卡面近黑带主题色调
  /// （canvas 10%），右下暗影更深（3%）、左上高光比卡面微亮（22%），
  /// 形成黑底上的真浮雕明暗梯度。亮/暗主题均适用：全部从当前主题
  /// canvas lerp 派生，不复制 ink 色值。
  static DarkNeuPalette darkNeuPalette(ThemeTokens tokens) => DarkNeuPalette(
        surface: Color.lerp(Colors.black, tokens.canvas, 0.10)!,
        shadow: Color.lerp(Colors.black, tokens.canvas, 0.03)!,
        highlight: Color.lerp(Colors.black, tokens.canvas, 0.22)!,
      );

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

  /// 解析拍摄页/预览页浮层视觉规格（沉浸式 vs 跟随主题）。
  ///
  /// - immersive：跨风格统一的暗色浮层（「黑白半透明遮罩」合法例外），
  ///   与历史写死视觉一致（胶囊 0xFF141416@0.72 / 面板 @0.80 / 白细边 /
  ///   金色 0xFFC9A96E 激活态）；neumorphic 不毛玻璃，其余风格 blur 20。
  /// - theme：按当前风格的「叠照片浮层」取向（UI 规范 §4）：
  ///   浮层都落在取景器/照片之上，neumorphic 不得使用双向浮雕外阴影
  ///   （规范 §3），改实心/半透明 surface + 细边表达表面。
  ///
  /// [role]：pill=叠取景器胶囊/浮条；panel=底部承载内容的面板/抽屉。
  static CaptureOverlayVisual captureOverlayVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required CaptureAppearance appearance,
    required CaptureOverlayRole role,
    required double radiusDp,
  }) {
    // ── 沉浸式：跨风格统一暗色 ──
    if (appearance == CaptureAppearance.immersive) {
      final isPill = role == CaptureOverlayRole.pill;
      return CaptureOverlayVisual(
        background:
            const Color(0xFF141416).withOpacity(isPill ? 0.72 : 0.80),
        border: Border.all(
          color: Colors.white.withOpacity(isPill ? 0.10 : 0.08),
          width: 0.5,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withOpacity(isPill ? 0.15 : 0.2),
            blurRadius: isPill ? 12 : 24,
            offset: Offset(0, isPill ? 2 : 4),
          ),
        ],
        backdropBlurSigma: style == UIStyle.neumorphic ? 0 : 20,
        foreground: Colors.white,
        foregroundSecondary: Colors.white70,
        foregroundMuted: Colors.white38,
        fillSubtle: Colors.white12,
        accent: const Color(0xFFC9A96E),
        onAccent: Colors.black,
      );
    }

    // ── 跟随主题：按风格「叠照片浮层」取向 ──
    switch (style) {
      case UIStyle.neumorphic:
        return CaptureOverlayVisual(
          background: role == CaptureOverlayRole.pill
              ? tokens.surface.withOpacity(0.92)
              : tokens.surface,
          border: Border.all(color: tokens.divider, width: 0.8),
          shadows: const [],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.flat:
        return CaptureOverlayVisual(
          background: role == CaptureOverlayRole.pill
              ? tokens.surfaceAlt.withOpacity(0.88)
              : tokens.surface,
          border: Border.all(color: tokens.divider, width: 1),
          shadows: const [],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.glass:
        return CaptureOverlayVisual(
          background: ThemeTokens.glassFill(tokens),
          border: Border.all(color: ThemeTokens.glassBorder(tokens), width: 1),
          shadows: const [
            BoxShadow(
                color: Color(0x14000000),
                offset: Offset(0, 6),
                blurRadius: 20),
          ],
          backdropBlurSigma: 20,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
      case UIStyle.female:
        return CaptureOverlayVisual(
          background: tokens.surface.withOpacity(0.92),
          border:
              Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
          shadows: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.15),
              offset: const Offset(0, 6),
              blurRadius: 20,
            ),
          ],
          backdropBlurSigma: 0,
          foreground: tokens.textPrimary,
          foregroundSecondary: tokens.textSecondary,
          foregroundMuted: tokens.textTertiary,
          fillSubtle: tokens.divider,
          accent: tokens.brand,
          onAccent: tokens.textInverse,
        );
    }
  }
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

/// 暗色语境新拟态三色配色（卡面/暗影/高光），
/// 由 [LumiraThemeResolver.darkNeuPalette] 派生。
class DarkNeuPalette {
  final Color surface;
  final Color shadow;
  final Color highlight;
  const DarkNeuPalette({
    required this.surface,
    required this.shadow,
    required this.highlight,
  });
}

/// 拍摄浮层视觉规格（容器 + 前景），由
/// [LumiraThemeResolver.captureOverlayVisual] 解析。
class CaptureOverlayVisual {
  /// 容器底色
  final Color background;

  /// 容器边框（null 无边框）
  final Border? border;

  /// 容器阴影
  final List<BoxShadow> shadows;

  /// >0 时组件需包裹 BackdropFilter 毛玻璃（新拟态恒 0）
  final double backdropBlurSigma;

  /// 主文字/图标色
  final Color foreground;

  /// 次级文字/未激活图标（对应历史 white70）
  final Color foregroundSecondary;

  /// 三级弱文字（对应历史 white38/white54/white24）
  final Color foregroundMuted;

  /// 弱底色（对应历史 white12/white10 占位底）
  final Color fillSubtle;

  /// 激活态强调色（immersive=金 0xFFC9A96E；theme=brand）
  final Color accent;

  /// 激活态底色上的前景（immersive=黑；theme=textInverse）
  final Color onAccent;

  const CaptureOverlayVisual({
    required this.background,
    required this.border,
    required this.shadows,
    required this.backdropBlurSigma,
    required this.foreground,
    required this.foregroundSecondary,
    required this.foregroundMuted,
    required this.fillSubtle,
    required this.accent,
    required this.onAccent,
  });
}

/// 从 WidgetRef 读取当前主题的便捷扩展
extension LumiraThemeRef on WidgetRef {
  AppThemeData get appTheme => watch(appThemeProvider);
  ThemeTokens get tokens => watch(appThemeProvider).tokens;
  UIStyle get uiStyle => watch(appThemeProvider).style;
}
