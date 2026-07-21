import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 如画应用按钮变体
enum LumiraButtonVariant {
  /// 主按钮：textPrimary 背景 + canvas 文字
  primary,

  /// 品牌按钮：brand 背景 + inverse 文字 + brand 阴影
  brand,

  /// 描边按钮：透明背景 + divider 边框
  outline,

  /// 幽灵按钮：surfaceAlt 背景 + textSecondary 文字（小尺寸）
  ghost,
}

/// 如画应用统一按钮
///
/// 视觉规格来源：lumira-app/src/App.vue line 558-637
/// - primary: textPrimary bg + canvas text + 16rpx radius + 28rpx×48rpx padding
/// - brand: brand bg + inverse text + brand shadow + 16rpx radius + 28rpx×48rpx padding
/// - outline: transparent + textPrimary text + 3rpx divider border + 16rpx radius + 28rpx×48rpx padding
/// - ghost: surfaceAlt bg + textSecondary text + 16rpx radius + 20rpx×32rpx padding
///
/// 所有变体：
/// - width: 100%（除非 expand=false）
/// - max-width: 100% + box-sizing: border-box（防右溢出）
/// - :active scale(0.97)
class LumiraButton extends ConsumerWidget {
  const LumiraButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = LumiraButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final LumiraButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final spec = _ButtonSpec.from(variant, tokens, appTheme);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: spec.foregroundColor),
          const SizedBox(width: 8), // gap 16rpx → 8dp
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: spec.fontSize,
            fontWeight: FontWeight.w500,
            color: spec.foregroundColor,
            height: 1,
          ),
        ),
      ],
    );

    final decoration = BoxDecoration(
      color: spec.backgroundColor,
      borderRadius: BorderRadius.circular(spec.radius),
      border: spec.border,
      boxShadow: appTheme.style == UIStyle.female &&
              variant == LumiraButtonVariant.brand
          ? [
              // 女性美学：品牌按钮 0 8 24 rgba(brand, 0.25)
              BoxShadow(
                color: tokens.brand.withOpacity(0.25),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ]
          : (appTheme.style == UIStyle.neumorphic &&
                    variant == LumiraButtonVariant.brand
                ? tokens
                    .shadowConvex // 新拟态：使用中性色双向阴影，避免 brand 色阴影造成"发光"感
                : spec.boxShadow),
    );

    Widget button = _ScaleTap(
      scale: 0.97,
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: spec.padding,
        decoration: decoration,
        child: content,
      ),
    );

    if (!enabled) {
      button = Opacity(opacity: 0.5, child: button);
    }

    // expand: width 100% + max-width 100% + box-sizing border-box
    if (expand) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: SizedBox(width: double.infinity, child: button),
      );
    }

    return button;
  }
}

class _ButtonSpec {
  final Color backgroundColor;
  final Color foregroundColor;
  final double radius;
  final double fontSize;
  final EdgeInsets padding;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  _ButtonSpec({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.radius,
    required this.fontSize,
    required this.padding,
    this.border,
    this.boxShadow,
  });

  factory _ButtonSpec.from(
    LumiraButtonVariant variant,
    ThemeTokens tokens,
    AppThemeData appTheme,
  ) {
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;

    // 新拟态下：brand 按钮使用 shadowConvex（中性双向阴影），
    // primary 按钮也使用 shadowConvex（黑色按钮配中性阴影仍符合新拟态），
    // 不再使用 shadowConvexBrand（brand 色阴影会让按钮看起来发光）。
    final brandShadow = isNeumorphic
        ? tokens.shadowConvex
        : (appTheme.style == UIStyle.female
            ? tokens.shadowConvexBrand
            : null);
    final primaryShadow = isNeumorphic ? tokens.shadowConvex : null;
    final ghostShadow = isNeumorphic ? tokens.shadowConvexSubtle : null;

    switch (variant) {
      case LumiraButtonVariant.primary:
        return _ButtonSpec(
          backgroundColor: tokens.textPrimary,
          foregroundColor: tokens.canvas,
          radius: 8, // 16rpx → 8dp
          fontSize: 15, // 30rpx → 15dp
          padding: const EdgeInsets.symmetric(
            horizontal: 24, // 48rpx → 24dp
            vertical: 14, // 28rpx → 14dp
          ),
          boxShadow: primaryShadow,
        );

      case LumiraButtonVariant.brand:
        return _ButtonSpec(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.textInverse,
          radius: 8,
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          boxShadow: brandShadow,
        );

      case LumiraButtonVariant.outline:
        return _ButtonSpec(
          backgroundColor: Colors.transparent,
          foregroundColor: tokens.textPrimary,
          radius: 8,
          fontSize: 15,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          border: Border.all(color: tokens.divider, width: 1.5), // 3rpx → 1.5dp
        );

      case LumiraButtonVariant.ghost:
        return _ButtonSpec(
          backgroundColor: tokens.surfaceAlt,
          foregroundColor: tokens.textSecondary,
          radius: 8,
          fontSize: 13, // 26rpx → 13dp
          padding: const EdgeInsets.symmetric(
            horizontal: 16, // 32rpx → 16dp
            vertical: 10, // 20rpx → 10dp
          ),
          boxShadow: ghostShadow,
        );
    }
  }
}

// 复用 NeuCard 中的 _ScaleTap（为避免循环依赖，此处独立实现）
class _ScaleTap extends StatefulWidget {
  const _ScaleTap({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
