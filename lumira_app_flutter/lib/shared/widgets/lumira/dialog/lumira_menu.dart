import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用统一弹出菜单
///
/// 替代 Material 的 `PopupMenuButton` + `showMenu`，颜色随 8 主题 × 4 风格变化。
///
/// 视觉规格来源：spec §3.2 Phase 2
/// - 菜单容器：`LumiraThemeResolver.containerVisual()`，圆角 = `appTheme.popupRadius / 2`，padding 4
/// - 菜单项高度 44，horizontal padding 16，圆角 = (`popupRadius / 2`) - 4
/// - 4 风格分支容器视觉
/// - 项状态：
///   - hover/按下：brandSubtle 背景
///   - 选中态（`isSelected == true`）：brand 背景 + textInverse 文字
///   - disabled：textTertiary 文字
///
/// 用法：
/// ```dart
/// // 1. 直接调用 showLumiraMenu
/// final result = await showLumiraMenu<String>(
///   context: context,
///   position: offset,
///   items: [
///     LumiraMenuItem(value: 'edit', label: '编辑', icon: Icons.edit),
///     LumiraMenuItem(value: 'delete', label: '删除', icon: Icons.delete),
///   ],
/// );
///
/// // 2. 使用 LumiraPopupMenuButton 包装触发器
/// LumiraPopupMenuButton<String>(
///   items: [...],
///   onSelected: (value) => print('selected: $value'),
///   child: Icon(Icons.more_vert),
/// )
/// ```

/// 菜单项数据
class LumiraMenuItem<T> {
  const LumiraMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.isSelected = false,
  });

  /// 选中后返回的值
  final T value;

  /// 显示文字
  final String label;

  /// 可选前缀图标
  final IconData? icon;

  /// 是否可点击
  final bool enabled;

  /// 是否为当前选中项（用于显示选中态高亮）
  final bool isSelected;
}

/// 展示 Lumira 弹出菜单
///
/// [position] 为菜单左上角的全屏坐标（`RenderBox.localToGlobal`）。
/// 为 null 时菜单居中显示。位置会自动 clamp 到屏幕安全区内。
Future<T?> showLumiraMenu<T>({
  required BuildContext context,
  required List<LumiraMenuItem<T>> items,
  Offset? position,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    useRootNavigator: false,
    builder: (dialogContext) {
      return _LumiraMenuOverlay<T>(
        items: items,
        position: position,
        onSelected: (value) => Navigator.of(dialogContext).pop(value),
        onDismiss: () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

/// 弹出菜单触发器
///
/// 包装 [child] 作为触发器，点击时计算 [child] 在屏幕中的位置，
/// 在其右下方调用 [showLumiraMenu]。
///
/// 必填 [items] / [onSelected] / [child]。
class LumiraPopupMenuButton<T> extends ConsumerStatefulWidget {
  const LumiraPopupMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    required this.child,
  });

  final List<LumiraMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget child;

  @override
  ConsumerState<LumiraPopupMenuButton<T>> createState() =>
      _LumiraPopupMenuButtonState<T>();
}

class _LumiraPopupMenuButtonState<T>
    extends ConsumerState<LumiraPopupMenuButton<T>> {
  final GlobalKey _key = GlobalKey();

  void _handleTap() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final origin = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    // 菜单左上角定位在触发器右下角，避免遮挡触发器本身
    final position = Offset(
      origin.dx + size.width,
      origin.dy + size.height,
    );
    showLumiraMenu<T>(
      context: context,
      items: widget.items,
      position: position,
    ).then((value) {
      if (value != null && mounted) widget.onSelected(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}

// ── 内部实现 ──

class _LumiraMenuOverlay<T> extends ConsumerWidget {
  const _LumiraMenuOverlay({
    required this.items,
    required this.position,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<LumiraMenuItem<T>> items;
  final Offset? position;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  static const double _menuMaxWidth = 240;
  static const double _screenMargin = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);

    return Stack(
      children: [
        // 全屏 barrier：点击空白处关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // 菜单面板
        if (position == null)
          Center(
            child: _LumiraMenuPanel<T>(
              items: items,
              onSelected: onSelected,
            ),
          )
        else
          Positioned(
            left: _clampHorizontal(
              position!.dx,
              mediaQuery.size.width,
            ),
            top: _clampVertical(
              position!.dy,
              mediaQuery.size.height,
              mediaQuery.padding,
            ),
            child: _LumiraMenuPanel<T>(
              items: items,
              onSelected: onSelected,
            ),
          ),
      ],
    );
  }

  /// 水平方向 clamp，保证菜单不超出屏幕右侧
  double _clampHorizontal(double left, double screenWidth) {
    final maxLeft = screenWidth - _menuMaxWidth - _screenMargin;
    if (left > maxLeft) return maxLeft < _screenMargin ? _screenMargin : maxLeft;
    if (left < _screenMargin) return _screenMargin;
    return left;
  }

  /// 垂直方向 clamp，保证菜单不超出屏幕底部
  double _clampVertical(
    double top,
    double screenHeight,
    EdgeInsets padding,
  ) {
    // 预估菜单高度：每项 44 + 容器 padding 8（上下各 4）
    final estimatedHeight = items.length * 44.0 + 8;
    final maxTop =
        screenHeight - estimatedHeight - padding.bottom - _screenMargin;
    if (top > maxTop) return maxTop < padding.top ? padding.top : maxTop;
    if (top < padding.top) return padding.top;
    return top;
  }
}

class _LumiraMenuPanel<T> extends ConsumerWidget {
  const _LumiraMenuPanel({
    required this.items,
    required this.onSelected,
  });

  final List<LumiraMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final radius = appTheme.popupRadius / 2;
    final visual = LumiraThemeResolver.containerVisual(
      tokens: tokens,
      style: style,
      radiusDp: radius,
    );

    return Container(
      constraints: const BoxConstraints(
        maxWidth: _LumiraMenuOverlay._menuMaxWidth,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: visual.background,
        gradient: visual.glassOverlay,
        border: visual.border,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: visual.shadows,
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              _LumiraMenuItemTile<T>(
                item: items[i],
                itemRadius: (radius - 4).clamp(0.0, radius),
                tokens: tokens,
                onTap: items[i].enabled
                    ? () => onSelected(items[i].value)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LumiraMenuItemTile<T> extends StatefulWidget {
  const _LumiraMenuItemTile({
    required this.item,
    required this.itemRadius,
    required this.tokens,
    required this.onTap,
  });

  final LumiraMenuItem<T> item;
  final double itemRadius;
  final ThemeTokens tokens;
  final VoidCallback? onTap;

  @override
  State<_LumiraMenuItemTile<T>> createState() => _LumiraMenuItemTileState<T>();
}

class _LumiraMenuItemTileState<T> extends State<_LumiraMenuItemTile<T>> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      setState(() => _pressed = false);
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final item = widget.item;
    final enabled = item.enabled;
    final isSelected = item.isSelected;

    Color backgroundColor;
    Color textColor;
    Color iconColor;

    if (!enabled) {
      backgroundColor = Colors.transparent;
      textColor = tokens.textTertiary;
      iconColor = tokens.textTertiary;
    } else if (isSelected) {
      backgroundColor = tokens.brand;
      textColor = tokens.textInverse;
      iconColor = tokens.textInverse;
    } else if (_pressed) {
      backgroundColor = tokens.brandSubtle;
      textColor = tokens.textPrimary;
      iconColor = tokens.brandText;
    } else {
      backgroundColor = Colors.transparent;
      textColor = tokens.textPrimary;
      iconColor = tokens.brandText;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(widget.itemRadius),
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 16, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}
