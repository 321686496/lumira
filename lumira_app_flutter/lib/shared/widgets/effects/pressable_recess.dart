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
  final List<BoxShadow>? raisedShadow;

  /// 按压凹陷表面时覆盖内影色调（默认用 `shadowConcave`；品牌 CTA 传品牌色）。
  final Color? recessDark;
  final Color? recessLight;

  /// 内斜边亮色（用于品牌按钮常态上/左边）。与 [bevelDark] 同时设置时，
  /// 常态用「亮上左 + 暗下右」内斜边，按压用「暗上左 + 亮下右」反转内斜边，
  /// 替代外阴影浮雕，避免异色按钮悬浮感。
  final Color? bevelLight;

  /// 内斜边暗色（用于品牌按钮常态下/右边）。
  final Color? bevelDark;

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

    final hasBevel = widget.bevelLight != null && widget.bevelDark != null;

    Widget content;
    if (isNeu && fill != null && hasBevel) {
      // 内斜边模式：常态「亮上左 + 暗下右」、按压「暗上左 + 亮下右」反转，
      // 1.5px 实线不发散，替代外阴影避免异色按钮悬浮感。
      content = Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border(
            top: BorderSide(
              color: _pressed ? widget.bevelDark! : widget.bevelLight!,
              width: 1.5,
            ),
            left: BorderSide(
              color: _pressed ? widget.bevelDark! : widget.bevelLight!,
              width: 1.5,
            ),
            bottom: BorderSide(
              color: _pressed ? widget.bevelLight! : widget.bevelDark!,
              width: 1.5,
            ),
            right: BorderSide(
              color: _pressed ? widget.bevelLight! : widget.bevelDark!,
              width: 1.5,
            ),
          ),
        ),
        child: widget.child,
      );
    } else if (isNeu && fill != null && _pressed) {
      // 按压态：填充色凹陷表面（上/左暗、下/右亮、中心平底）
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
      // 常态：填充色凸起胶囊（浮雕外阴影），按下时再切换为凹陷
      content = Container(
        decoration: BoxDecoration(
          color: fill,
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