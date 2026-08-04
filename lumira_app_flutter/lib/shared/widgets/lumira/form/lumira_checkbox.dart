import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';

/// Lumira 全局复选框
///
/// 视觉规格来源：spec §3.3 LumiraCheckbox
/// - 选中：背景 `tokens.brand` + 白色对勾（Icons.check, size 16）
/// - 未选中：透明背景 + `tokens.divider` 边框（1.5px）
/// - 尺寸 20x20，圆角 4
/// - 点击动画 150ms
class LumiraCheckbox extends ConsumerStatefulWidget {
  const LumiraCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final bool enabled;

  @override
  ConsumerState<LumiraCheckbox> createState() => _LumiraCheckboxState();
}

class _LumiraCheckboxState extends ConsumerState<LumiraCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant LumiraCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

    final Color activeBg = widget.activeColor ?? tokens.brand;

    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: value ? _scaleAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? activeBg : Colors.transparent,
              border: value
                  ? null
                  : Border.all(
                      color: enabled ? tokens.divider : tokens.divider.withOpacity(0.5),
                      width: 1.5,
                    ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// LumiraCheckbox 的 ListTile 变体
///
/// 视觉规格来源：spec §3.3 LumiraCheckboxListTile
/// - 横向布局：LumiraCheckbox + 间距 12 + (title/subtitle Expanded) + trailing
/// - padding horizontal 16, vertical 12
/// - 点击整行触发 onChanged
class LumiraCheckboxListTile extends ConsumerWidget {
  const LumiraCheckboxListTile({
    super.key,
    required this.value,
    this.onChanged,
    required this.title,
    this.subtitle,
    this.trailing,
    this.activeColor,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Color? activeColor;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () => onChanged?.call(!value)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            LumiraCheckbox(
              value: value,
              onChanged: onChanged,
              activeColor: activeColor,
              enabled: enabled,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: enabled ? tokens.textPrimary : tokens.textTertiary,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 13,
                        color: enabled ? tokens.textSecondary : tokens.textTertiary,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
