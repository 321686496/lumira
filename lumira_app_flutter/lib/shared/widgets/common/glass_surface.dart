import 'dart:math' show min;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 玻璃拟态统一表面组件
///
/// 视觉规格来源：iOS Control Center / Apple Vision Pro 玻璃质感。
/// 解决 BackdropFilter 无法跨 RepaintBoundary 采样页面背景的问题：
/// 玻璃观感主要通过「半透明主题色磨砂填充 + 顶部高光 + 内外描边 + 柔和投影」
/// 组合达成，让背后的彩色背景透过半透明表面显现；仅当 [blurSigma] > 0 且
/// 表面与背景处于同一重绘作用域时（如 FAB 与背景同 Stack），才额外叠加真模糊。
///
/// 玻璃颜色跟随当前主题品牌色（[ThemeTokens.brandLight]/[ThemeTokens.brand]），
/// 亮色主题为白色调品牌微染，暗色主题（ink）为暗色调品牌微染。
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.blurSigma = 0,
    this.shadows = const [],
    this.showTopHighlight = true,
    this.showInnerBorder = true,
    this.borderWidth = 1,
  });

  /// 内容
  final Widget child;

  /// 整体圆角（支持仅有顶部圆角的 BottomSheet）
  final BorderRadius borderRadius;

  /// 内容区内边距
  final EdgeInsetsGeometry? padding;

  /// backdrop blur sigma。仅当表面与背景处于同一重绘作用域时有实际效果，
  /// 否则模糊不到背景，保持 0 以节省性能。
  final double blurSigma;

  /// 玻璃表面外阴影
  final List<BoxShadow> shadows;

  /// 是否绘制顶部高光反射（玻璃边缘光）
  final bool showTopHighlight;

  /// 是否绘制内描边（玻璃厚度感）
  final bool showInnerBorder;

  /// 外描边宽度
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final isDark = tokens.canvas.computeLuminance() < 0.5;

    // —— 玻璃配色（跟随主题，亮/暗两套）——
    // 半透明磨砂填充：让背后彩色背景透出，形成「毛玻璃后有色块」的视觉。
    final tintColors = _tintColors(tokens, isDark);
    final fillGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tintColors.top,
        tintColors.mid,
        tintColors.bottom,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    // 外描边：灯下白色细边（亮）/ 白色微光（暗）
    final outerBorder = Border.all(
      color: Colors.white.withOpacity(isDark ? 0.20 : 0.55),
      width: borderWidth,
    );

    // 顶部高光（玻璃边缘反射）
    final highlight = showTopHighlight
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(isDark ? 0.16 : 0.42),
              Colors.white.withOpacity(0.0),
            ],
            stops: const [0.0, 1.0],
          )
        : null;

    final fillDecoration = BoxDecoration(
      gradient: fillGradient,
      borderRadius: borderRadius,
      border: outerBorder,
    );

    final Widget fill;
    if (blurSigma > 0) {
      fill = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(decoration: fillDecoration),
      );
    } else {
      fill = DecoratedBox(decoration: fillDecoration);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 层 1: 磨砂填充底（可选真模糊）
          Positioned.fill(child: fill),
          // 层 2: 顶部高光反射
          if (highlight != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 44,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: highlight,
                    borderRadius: BorderRadius.only(
                      topLeft: borderRadius.topLeft,
                      topRight: borderRadius.topRight,
                    ),
                  ),
                ),
              ),
            ),
          // 层 3: 内描边（玻璃厚度感）
          if (showInnerBorder)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.all(1.2),
                  decoration: BoxDecoration(
                    borderRadius: _shrinkBorderRadius(borderRadius, 1.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(isDark ? 0.10 : 0.20),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          // 层 4: 内容
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }

  /// 推攻由主题品牌色推导的玻璃磨砂三层色（跟随用户所选 8 主题）。
  ///
  /// Forced fix: 之前返回的色不透明，半透明白填充把背后彩色斑点完全盖住，
  /// 致使看不出玻璃/透明效果。现全部 `withOpacity` 保留透明度，
  /// 让 GlassBackground 的彩色斑点透过半透明表面显现，形成毛玻璃观感。
  static _GlassTint _tintColors(ThemeTokens tokens, bool isDark) {
    if (isDark) {
      // 暗色主题：以近背景的暗色为底，品牌色微染出冷亮边缘
      final tint = Color.lerp(tokens.surface, tokens.brand, 0.10)!;
      return _GlassTint(
        Color.lerp(tint, Colors.white, 0.06)!.withOpacity(0.35),
        tint.withOpacity(0.40),
        Color.lerp(tint, tokens.brandDeep, 0.05)!.withOpacity(0.38),
      );
    }
    // 亮色主题：白底品牌微染，半透明让背景透出
    final tint = Color.lerp(Colors.white, tokens.brandLight, 0.10)!;
    return _GlassTint(
      Color.lerp(tint, Colors.white, 0.16)!.withOpacity(0.55),
      tint.withOpacity(0.42),
      Color.lerp(tint, tokens.brandLight, 0.14)!.withOpacity(0.35),
    );
  }
}

/// 向内收缩 BorderRadius（用于内描边圆角）
/// 私有 helper，供 GlassSurface 内部使用
BorderRadius _shrinkBorderRadius(BorderRadius radius, double inset) {
  Radius shrink(Radius r) =>
      Radius.circular((min(r.x, r.y) - inset).clamp(0.0, double.infinity));
  return BorderRadius.only(
    topLeft: shrink(radius.topLeft),
    topRight: shrink(radius.topRight),
    bottomLeft: shrink(radius.bottomLeft),
    bottomRight: shrink(radius.bottomRight),
  );
}

/// 玻璃磨砂三层色
class _GlassTint {
  const _GlassTint(this.top, this.mid, this.bottom);
  final Color top;
  final Color mid;
  final Color bottom;
}