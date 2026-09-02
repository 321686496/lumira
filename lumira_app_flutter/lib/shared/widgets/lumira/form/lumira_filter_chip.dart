import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 筛选 chip（多选 pill）
///
/// 用于搜索/筛选弹层中的单选项标签。颜色与形态随 8 主题 × 4 风格变化，
/// 读取 [AppThemeData]（tokens + style）渲染：
/// - neumorphic：未选中 `surface` + 双向浮雕凸起阴影，选中 `brand` + 品牌浮雕阴影
/// - flat      ：未选中 `surfaceAlt` + divider 细边，选中 `brand`，无阴影
/// - glass     ：未选中 半透明玻璃磨砂 + 白细边，选中 `brand` + 柔和投影
/// - female    ：未选中 `brandSubtle` + 白 hairline + 品牌柔和阴影，选中 品牌扁平微渐变
///
/// 选中态统一品牌色 + 反白文字，未选中 `textSecondary`；圆角随 `appTheme.buttonRadius`。
/// 带按下呼吸反馈（按压缩放 0.96，模拟物理按压）。
class LumiraFilterChip extends ConsumerStatefulWidget {
  const LumiraFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.leading,
  });

  /// 显示文案
  final String label;

  /// 是否选中
  final bool active;

  /// 点击回调
  final VoidCallback onTap;

  /// 可选前置图标（如复选框、单选指示）
  final Widget? leading;

  @override
  ConsumerState<LumiraFilterChip> createState() => _LumiraFilterChipState();
}

class _LumiraFilterChipState extends ConsumerState<LumiraFilterChip> {
  bool _pressed = false;

  static const Duration _pressDuration = Duration(milliseconds: 140);
  static const Duration _releaseDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final visual = _resolveVisual(appTheme, tokens, _pressed);

    final radius = appTheme.buttonRadius / 2;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: visual.background,
        gradient: visual.gradient,
        borderRadius: BorderRadius.circular(radius),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null) ...[
            DefaultTextStyle.merge(
              style: TextStyle(
                color: visual.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: visual.foreground,
                  size: 14,
                ),
                child: widget.leading!,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              color: visual.foreground,
              fontSize: 12,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 0.94 : 1.0),
        duration: _pressed ? _pressDuration : _releaseDuration,
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: chip,
      ),
    );
  }

  /// 解析 4 风格 × 选中/未选中 的视觉。逻辑与 `AppThemeData.buttonVisual` 对齐，
  /// 但针对「标签 chip」小尺寸形态调整（阴影更轻、圆角更小）。
  /// [pressed]：是否处于手指按压态。新拟态下，选中态与按压态均呈现「凹陷」内阴影，
  /// 符合「凸起=常态、凹陷=激活/按压」的语义（Neumorphism §1.3）。
  _ChipVisual _resolveVisual(
      AppThemeData appTheme, ThemeTokens tokens, bool pressed) {
    final style = appTheme.style;
    final active = widget.active;

    if (active) {
      // 选中态：统一品牌色。
      switch (style) {
        case UIStyle.female:
          return _ChipVisual(
            background: tokens.brand,
            foreground: tokens.textInverse,
            border: null,
            shadows: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.25),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
            // 女性美学扁平微渐变（与 buttonVisual.primary 一致取向）
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(tokens.brandLight, Colors.white, 0.3)!,
                tokens.brandLight,
                tokens.brand,
              ],
              stops: const [0.0, 0.32, 1.0],
            ),
          );
        case UIStyle.neumorphic:
          return _ChipVisual(
            background: tokens.brand,
            foreground: tokens.textInverse,
            border: null,
            // 选中=激活=凹陷内阴影（原为 shadowConvexBrand 凸起，改为向内按压）
            shadows: tokens.shadowPressed,
          );
        case UIStyle.glass:
          return _ChipVisual(
            background: tokens.brand,
            foreground: tokens.textInverse,
            border: null,
            shadows: const [
              BoxShadow(
                color: Color(0x22000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          );
        case UIStyle.flat:
          return _ChipVisual(
            background: tokens.brand,
            foreground: tokens.textInverse,
            border: null,
            shadows: const [],
          );
      }
    }

    // 未选中态：各风格专属表面。
    switch (style) {
      case UIStyle.neumorphic:
        return _ChipVisual(
          background: tokens.surface,
          foreground: tokens.textSecondary,
          border: null,
          // 未选中常态凸起；按压时切换为凹陷内阴影，模拟按下去的物理反馈
          shadows: pressed ? tokens.shadowPressed : tokens.shadowConvexSubtle,
        );
      case UIStyle.flat:
        return _ChipVisual(
          background: tokens.surfaceAlt,
          foreground: tokens.textSecondary,
          border: Border.all(color: tokens.divider, width: 1),
          shadows: const [],
        );
      case UIStyle.glass:
        return _ChipVisual(
          background: ThemeTokens.glassFill(tokens),
          foreground: tokens.textSecondary,
          border: Border.all(
            color: ThemeTokens.glassBorder(tokens),
            width: 1,
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        );
      case UIStyle.female:
        return _ChipVisual(
          background: tokens.brandSubtle,
          foreground: tokens.brandText,
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 0.8),
          shadows: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.12),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        );
    }
  }
}

/// chip 视觉规格（背景/前景/边框/阴影/可选渐变）
class _ChipVisual {
  final Color background;
  final Color foreground;
  final Border? border;
  final List<BoxShadow> shadows;
  final LinearGradient? gradient;

  const _ChipVisual({
    required this.background,
    required this.foreground,
    required this.border,
    required this.shadows,
    this.gradient,
  });
}