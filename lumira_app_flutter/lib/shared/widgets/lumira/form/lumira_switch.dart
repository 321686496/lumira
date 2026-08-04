import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';

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
    final value = widget.value;
    final enabled = widget.enabled;

    // 关闭态 track 颜色
    final Color trackColorOff = enabled
        ? tokens.surfaceAlt
        : tokens.surfaceAlt.withOpacity(0.5);
    // 开启态 track 颜色
    final Color trackColorOn = enabled
        ? tokens.brand
        : tokens.brand.withOpacity(0.5);

    // thumb 颜色
    final Color thumbColorOff = enabled ? tokens.surface : tokens.surface.withOpacity(0.7);
    const Color thumbColorOn = Colors.white;

    // thumb 阴影：开启态使用 shadowConvexSubtle，关闭态无阴影
    const List<BoxShadow> thumbShadowsOff = [];
    final List<BoxShadow> thumbShadowsOn = enabled ? tokens.shadowConvexSubtle : const [];

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
            color: value ? trackColorOn : trackColorOff,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: value ? null : Border.all(color: tokens.divider, width: 1),
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
