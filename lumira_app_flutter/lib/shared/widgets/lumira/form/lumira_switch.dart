import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 全局开关
///
/// 视觉规格来源：spec §3.3 LumiraSwitch
/// 自定义实现（不用原生 Switch，便于 4 风格化）
/// - 关闭态：track 背景 `tokens.surfaceAlt` + `tokens.divider` 边框，thumb 在左侧
/// - 开启态：track 背景 `tokens.brand`，thumb 在右侧，thumb 白色 + `shadowConvexSubtle`
/// - track 尺寸：宽 44，高 24，圆角 12
/// - thumb 直径 20，切换动画 200ms `Curves.easeOut`
class LumiraSwitch extends ConsumerStatefulWidget {
  const LumiraSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  ConsumerState<LumiraSwitch> createState() => _LumiraSwitchState();
}

class _LumiraSwitchState extends ConsumerState<LumiraSwitch> {
  static const double _trackWidth = 44;
  static const double _trackHeight = 24;
  static const double _thumbSize = 20;
  static const Duration _duration = Duration(milliseconds: 200);

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final value = widget.value;
    final enabled = widget.enabled;

    // 关闭态 track 颜色/阴影
    final Color trackColorOff = enabled ? tokens.surface : tokens.surface.withOpacity(0.5);
    List<BoxShadow> trackShadowsOff = [];
    Border? borderOff;
    if (style == UIStyle.neumorphic) {
      // 新拟态：关闭态 track 是「凹陷凹槽」，用 recessedGradient，无边框
      trackShadowsOff = const <BoxShadow>[];
      borderOff = null;
    } else {
      trackShadowsOff = [];
      borderOff = Border.all(color: tokens.divider, width: 1);
    }

    // 开启态 track 颜色
    final Color trackColorOn = enabled ? tokens.brand : tokens.brand.withOpacity(0.5);

    // thumb 颜色与阴影：关闭态也略微凸起（在凹槽中），开启态白色凸起
    final Color thumbColorOff = enabled ? tokens.surface : tokens.surface.withOpacity(0.7);
    const Color thumbColorOn = Colors.white;
    final List<BoxShadow> thumbShadowsOff = (style == UIStyle.neumorphic && enabled)
        ? tokens.shadowConvexSubtle
        : [];
    final List<BoxShadow> thumbShadowsOn = enabled ? tokens.shadowConvexSubtle : const [];

    // 新拟态关闭态：track 以 recessedGradient 表达「凹陷凹槽」
    final Gradient? trackGradientOff = (style == UIStyle.neumorphic && !value)
        ? ThemeTokens.recessedGradient(tokens, depth: 0.18)
        : null;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: value
                ? trackColorOn
                : (trackGradientOff != null ? null : trackColorOff),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: value ? null : borderOff,
            gradient: value ? null : trackGradientOff,
            boxShadow: value ? null : trackShadowsOff,
          ),
          child: AnimatedAlign(
            duration: _duration,
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                color: value ? thumbColorOn : thumbColorOff,
                shape: BoxShape.circle,
                boxShadow: value ? thumbShadowsOn : thumbShadowsOff,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
