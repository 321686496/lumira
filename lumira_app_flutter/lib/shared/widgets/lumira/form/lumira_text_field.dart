import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 全局文本输入框
///
/// 替换项目中所有局部 `_TextField`，提供 4 风格 × 4 状态的统一视觉。
/// 内部包裹原生 `TextField`，自定义 `InputDecoration` 与容器装饰。
///
/// 视觉规格来源：spec §3.3 LumiraTextField
/// 4 风格：
/// - neumorphic：surface 凹陷阴影 `shadowConcaveSubtle` + 无边框
/// - flat：surfaceAlt 背景 + divider 边框
/// - glass：白透明 0.4 背景 + 白透明 0.6 边框
/// - female：brandSubtle 渐变背景 + hairline 边框
class LumiraTextField extends ConsumerStatefulWidget {
  const LumiraTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  @override
  ConsumerState<LumiraTextField> createState() => _LumiraTextFieldState();
}

class _LumiraTextFieldState extends ConsumerState<LumiraTextField> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  InputState _resolveState() {
    if (!widget.enabled) return InputState.disabled;
    if (widget.errorText != null && widget.errorText!.isNotEmpty) {
      return InputState.error;
    }
    if (_focused) return InputState.focused;
    return InputState.default_;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final state = _resolveState();
    final visual = appTheme.inputVisual(state);
    // rpx → dp：app_theme.inputRadius 存储的是 rpx 原值（12/8/12/24），/2 得 dp
    final radius = appTheme.inputRadius / 2;

    final BoxDecoration decoration = _buildDecoration(appTheme, tokens, visual, radius);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            style: TextStyle(
              fontSize: 14,
              color: visual.foreground,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 14,
                color: tokens.textTertiary,
              ),
              prefixIcon: widget.prefixIcon,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: widget.suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                fontSize: 12,
                color: tokens.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 按 4 风格分支构建容器装饰
  BoxDecoration _buildDecoration(
    AppThemeData appTheme,
    ThemeTokens tokens,
    InputVisual visual,
    double radius,
  ) {
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        // 嵌入态：surface 打底 + recessedGradient 表达凹陷，无阴影无边框
        return BoxDecoration(
          color: visual.gradient == null ? visual.background : null,
          gradient: visual.gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: visual.shadows,
        );
      case UIStyle.flat:
        // surfaceAlt + divider 边框 + 无阴影
        return BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
      case UIStyle.glass:
        // 白透明 0.4 + 白透明 0.6 边框（inputVisual 已返回）
        return BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
      case UIStyle.female:
        // brandSubtle 渐变背景 + hairline 边框（inputVisual 返回边框）
        // 用 LinearGradient 强化女性美学
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.55),
              tokens.brandLight.withOpacity(0.25),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
    }
  }
}
