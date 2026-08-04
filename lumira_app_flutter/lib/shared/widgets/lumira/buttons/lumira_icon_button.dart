import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';

/// Lumira 图标按钮 variant
enum LumiraIconButtonVariant {
  /// 透明背景
  standard,

  /// surface 背景 + shadowConvexSubtle 阴影
  filled,

  /// divider 边框
  outlined,
}

/// Lumira 图标按钮组件
///
/// 替代 Material 的 `IconButton`，颜色随 8 主题 × 4 风格变化。
///
/// 3 种 variant（spec §3.1）：
/// - [LumiraIconButtonVariant.standard]：透明背景
/// - [LumiraIconButtonVariant.filled]：surface 背景 + shadowConvexSubtle 阴影
/// - [LumiraIconButtonVariant.outlined]：divider 边框
///
/// 必填 [icon]（IconData）+ [onPressed]，可选 [color]（默认 brandText）/ [size]（默认 22）。
/// 按压缩放 0.95。
///
/// 注：spec 提到 PhosphorIcons，但项目 pubspec 未引入 `phosphor_flutter` 包，
/// 因此 [icon] 参数类型为 [IconData]，兼容 Material Icons 及未来扩展的图标库。
class LumiraIconButton extends ConsumerStatefulWidget {
  const LumiraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.variant = LumiraIconButtonVariant.standard,
    this.color,
    this.size = 22,
    this.padding = const EdgeInsets.all(8),
    this.radius,
  });

  /// 图标数据（接受 Material Icons 或任意 IconData 源）
  final IconData icon;

  /// 点击回调，为 null 时进入 disabled 态
  final VoidCallback? onPressed;

  /// 按钮 variant，默认 standard
  final LumiraIconButtonVariant variant;

  /// 图标颜色，默认 tokens.brandText
  final Color? color;

  /// 图标尺寸，默认 22
  final double size;

  /// 内边距，默认 EdgeInsets.all(8)
  final EdgeInsetsGeometry padding;

  /// 圆角（dp），为 null 时使用 `appTheme.buttonRadius / 2`
  final double? radius;

  @override
  ConsumerState<LumiraIconButton> createState() => _LumiraIconButtonState();
}

class _LumiraIconButtonState extends ConsumerState<LumiraIconButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null;

  void _handleTapDown(TapDownDetails _) {
    if (!_disabled) setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_disabled) {
      setState(() => _pressed = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    if (!_disabled) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final radius = (widget.radius ?? appTheme.buttonRadius / 2);

    final Color iconColor = _disabled
        ? tokens.textTertiary
        : (widget.color ?? tokens.brandText);

    Color? background;
    Border? border;
    List<BoxShadow> shadows = const [];

    switch (widget.variant) {
      case LumiraIconButtonVariant.standard:
        // 透明背景
        background = Colors.transparent;
        break;
      case LumiraIconButtonVariant.filled:
        // surface 背景 + shadowConvexSubtle 阴影
        background = _disabled ? tokens.surfaceAlt : tokens.surface;
        shadows = _disabled ? const [] : tokens.shadowConvexSubtle;
        break;
      case LumiraIconButtonVariant.outlined:
        // divider 边框
        background = Colors.transparent;
        border = Border.all(color: tokens.divider, width: 1);
        break;
    }

    Widget content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadows,
      ),
      child: Icon(
        widget.icon,
        size: widget.size,
        color: iconColor,
      ),
    );

    // 按压缩放 0.95（disabled 不响应）
    if (!_disabled) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: content,
        ),
      );
    }

    return content;
  }
}
