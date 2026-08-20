import 'package:flutter/material.dart';

/// 「呼吸」按压反馈容器（FemaleAestheticDesignSystem §4.4 情感化反馈）。
///
/// 为任意可点击卡片/元素提供轻量按压动画：
/// - 按下：140ms `easeIn` 平滑内缩到 [pressedScale]（模拟物理按压）
/// - 松手：300ms `easeOutBack` 弹性回弹，略超 1.0 再回落（「呼吸」回弹）
///
/// 用于此前仅用 `GestureDetector` 而无任何点击反馈的卡片（如模板网格卡片、
/// 分类卡片等），保证女性美学「克制但灵动」的统一点击体验。
class BreathingTap extends StatefulWidget {
  const BreathingTap({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.96,
  });

  final VoidCallback onTap;
  final Widget child;

  /// 按下时内缩到的缩放值；女性美学取 0.96，其余 0.98。
  final double pressedScale;

  @override
  State<BreathingTap> createState() => _BreathingTapState();
}

class _BreathingTapState extends State<BreathingTap> {
  bool _pressed = false;

  static const Duration _pressDuration = Duration(milliseconds: 140);
  static const Duration _releaseDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? widget.pressedScale : 1.0),
        duration: _pressed ? _pressDuration : _releaseDuration,
        // 按下 easeIn 平滑收缩；松手 easeOutBack 弹性回弹（略超 1.0 → 呼吸感）
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: widget.child,
      ),
    );
  }
}