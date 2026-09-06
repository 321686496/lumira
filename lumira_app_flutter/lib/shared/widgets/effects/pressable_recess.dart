import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import 'recessed_surface.dart';

/// 包一层「按压时凹陷」的反馈外壳。
///
/// 仅在新拟态（[UIStyle.neumorphic]）下生效：手指按下时把 [child] 包进
/// [RecessedSurface]（上/左暗、下/右亮、中心平底的内凹表面），模拟把胶囊按进
/// 画布的物理反馈，松手恢复原样。[child] 自身的 padding/尺寸不变，因此按下/松手
/// 不会引起布局跳动。非新拟态风格下退化为普通按压缩放反馈。
class PressableRecess extends ConsumerStatefulWidget {
  const PressableRecess({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = 999,
    this.depth = 0.68,
    this.rimFraction = 0.3,
    this.behavior = HitTestBehavior.opaque,
    this.raisedFill,
    this.raisedShadow,
    this.raisedGradient,
    this.recessDark,
    this.recessLight,
  });

  /// 点击回调
  final VoidCallback onTap;

  /// 承载内容（保持自身 padding/尺寸）
  final Widget child;

  final double borderRadius;

  /// 凹陷明暗强度 0~1
  final double depth;

  /// 内阴影沿短边的内伸量比例
  final double rimFraction;

  final HitTestBehavior behavior;

  /// 常态「凸起浮雕」表面填充色；仅在**新拟态**且非空时生效。
  ///
  /// 为 null 时保持默认行为：常态直接展示 [child]（含其自身背景/阴影），
  /// 仅按压时切为凹陷表面。为颜色值时（如表面色 `tokens.surface` 做普通
  /// 胶囊、`tokens.brand` 做品牌 CTA）：新拟态下未按压用「填充色+浮雕外阴影」
  /// 的凸起胶囊，按压时切换为同底色的凹陷表面，实现「常态浮雕/按下凹陷」。
  final Color? raisedFill;

  /// 常态凸起胶囊使用的外浮雕阴影，默认 [ThemeTokens.shadowConvexSubtle]。
  /// 品牌 CTA 传 [ThemeTokens.brandEmbossShadows]。
  final List<BoxShadow>? raisedShadow;

  /// 常态凸起胶囊的顶面渐变（可选）。品牌 CTA 传
  /// [ThemeTokens.brandEmbossGradient]：均匀色块 + 投影会读作「悬浮实体」，
  /// 145° 受光曲面微渐变（左上受光 → 右下背光）才读得出「从画布鼓起」的浮雕。
  final LinearGradient? raisedGradient;

  /// 按压凹陷表面时覆盖内影色调（默认用 `shadowConcave` 中性影）。
  /// 品牌 CTA 必须传品牌色系（[ThemeTokens.brandRecessDark] /
  /// [ThemeTokens.brandRecessLight]），避免中性灰在金色表面糊出脏边。
  final Color? recessDark;
  final Color? recessLight;

  @override
  ConsumerState<PressableRecess> createState() => _PressableRecessState();
}

class _PressableRecessState extends ConsumerState<PressableRecess> {
  bool _pressed = false;

  void _down(TapDownDetails _) => setState(() => _pressed = true);

  void _up(TapUpDetails _) {
    setState(() => _pressed = false);
    widget.onTap();
  }

  void _cancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    final fill = widget.raisedFill;

    Widget content;
    if (isNeu && fill != null && _pressed) {
      // 按压态：填充色凹陷表面（上/左暗、下/右亮、中心平底）。
      // 品牌 CTA 由调用方传 recessDark/recessLight 品牌色系内影，按压保持主色。
      content = RecessedSurface(
        tokens: tokens,
        borderRadius: widget.borderRadius,
        depth: widget.depth,
        rimFraction: widget.rimFraction,
        color: fill,
        recessDark: widget.recessDark,
        recessLight: widget.recessLight,
        child: widget.child,
      );
    } else if (isNeu && fill != null) {
      // 常态：填充色凸起胶囊（浮雕外阴影 + 可选受光曲面渐变），按下时切换为凹陷
      content = Container(
        decoration: BoxDecoration(
          color: widget.raisedGradient == null ? fill : null,
          gradient: widget.raisedGradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: widget.raisedShadow ?? tokens.shadowConvexSubtle,
        ),
        child: widget.child,
      );
    } else {
      // 默认路径（兼容旧用法）：常态直接展示 child；新拟态按压包进凹陷表面
      content = (isNeu && _pressed)
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: widget.borderRadius,
              depth: widget.depth,
              rimFraction: widget.rimFraction,
              child: widget.child,
            )
          : widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 0.95 : 1.0),
        duration: Duration(milliseconds: _pressed ? 140 : 260),
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: content,
      ),
    );
  }
}