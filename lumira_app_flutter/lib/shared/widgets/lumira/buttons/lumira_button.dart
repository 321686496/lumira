import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 通用按钮组件
///
/// 替代 Material 的 `TextButton` / `ElevatedButton`，颜色随 8 主题 × 4 风格变化。
///
/// 4 种 variant（spec §3.1）：
/// - [ButtonVariant.primary]：brand 背景 + textInverse 文字
/// - [ButtonVariant.secondary]：surface 背景 + brandText 文字（4 风格分支见 buttonVisual）
/// - [ButtonVariant.ghost]：透明背景 + brandText 文字，按下时 brandSubtle 背景
/// - [ButtonVariant.danger]：danger 背景 + 白色文字
///
/// 视觉规格通过 `appTheme.buttonVisual(variant)` 统一解析，4 风格分支：
/// - neumorphic：surface + shadowConvexSubtle / brand + shadowConvexBrand
/// - flat：surfaceAlt + divider 边框
/// - glass：白透明 0.55 + 白透明边框 + 阴影
/// - female：brandSubtle + 白透明 hairline + brand 阴影
///
/// 按压缩放 0.97（neumorphic/flat/glass）/ 0.96（female），沿用 NeuCard._ScaleTap 模式。
/// `onPressed` 为 null 时进入 disabled 态：背景透明度 0.5，文字 textTertiary。
class LumiraButton extends ConsumerStatefulWidget {
  const LumiraButton({
    super.key,
    required this.variant,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.radius,
    this.enableHoverScale = false,
  });

  /// 按钮 variant，决定背景/前景/边框/阴影
  final ButtonVariant variant;

  /// 点击回调，为 null 时进入 disabled 态
  final VoidCallback? onPressed;

  /// 子内容（通常为文字，也可能包含图标）
  final Widget child;

  /// 内边距，默认 horizontal:24 vertical:12
  final EdgeInsetsGeometry padding;

  /// 圆角（dp），为 null 时使用 `appTheme.buttonRadius / 2`
  final double? radius;

  /// 是否启用悬停/按压缩放反馈，默认 false
  final bool enableHoverScale;

  @override
  ConsumerState<LumiraButton> createState() => _LumiraButtonState();
}

class _LumiraButtonState extends ConsumerState<LumiraButton> {
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
    final style = appTheme.style;
    final visual = appTheme.buttonVisual(widget.variant);

    final radius = (widget.radius ?? appTheme.buttonRadius / 2);
    final pressedScale = style == UIStyle.female ? 0.96 : 0.97;

    Color background = visual.background;
    Color foreground = visual.foreground;
    Border? border = visual.border;
    List<BoxShadow> shadows = visual.shadows;

    if (_disabled) {
      // disabled 态：背景降透明度 0.5，文字 textTertiary
      background = visual.background.withOpacity(0.5);
      foreground = tokens.textTertiary;
      shadows = const [];
    } else if (widget.variant == ButtonVariant.ghost && _pressed) {
      // ghost 按下时加 brandSubtle 背景
      background = tokens.brandSubtle;
    }

    Widget content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadows,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        child: IconTheme(
          data: IconThemeData(color: foreground, size: 18),
          child: widget.child,
        ),
      ),
    );

    // 按压缩放反馈（disabled 不响应）。`enableHoverScale` 保留为 API 选项，
    // 移动端无 hover 概念，press 反馈始终启用。
    if (!_disabled) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedScale(
          scale: _pressed ? pressedScale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: content,
        ),
      );
    }

    return content;
  }
}
