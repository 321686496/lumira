import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../effects/recessed_surface.dart';

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
    this.focusNode,
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

  /// 外部传入的焦点节点（用于自动聚焦）。缺省时内部自建并自管理。
  final FocusNode? focusNode;

  @override
  ConsumerState<LumiraTextField> createState() => _LumiraTextFieldState();
}

class _LumiraTextFieldState extends ConsumerState<LumiraTextField> {
  bool _focused = false;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    // 仅释放内部自建的节点；外部传入的节点由调用方生命周期管理。
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
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
        _buildSurface(appTheme, tokens, visual, state, radius),
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

  /// 输入表面容器：新拟态走「凹陷表面」（[RecessedSurface]），其余风格走 [BoxDecoration]。
  ///
  /// 新拟态用 `recessedGradient(depth:0.18)` 时凹陷过于微弱、几乎不可见；改用
  /// [RecessedSurface] 手绘「左上暗 / 右下亮」方向性内沿，才读得出明确的凹陷感/浮雕感。
  /// 聚焦态加深凹陷，作为嵌入输入的视觉反馈；禁用态保持平底。
  Widget _buildSurface(
    AppThemeData appTheme,
    ThemeTokens tokens,
    InputVisual visual,
    InputState state,
    double radius,
  ) {
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: _buildTextField(visual.foreground, tokens),
    );

    if (appTheme.style == UIStyle.neumorphic) {
      // 禁用态：平底无凹陷（与 inputVisual 的 gradient==null 语义一致）。
      if (state == InputState.disabled) {
        return Container(
          decoration: BoxDecoration(
            color: visual.background,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: inner,
        );
      }
      // 常态凹陷，聚焦时加深 → 明确的「嵌入感 / 凹陷感」。
      // 刻意压低 depth + 收窄 rim + 暖化明暗（拉向表面色而不是硬中性灰），
      // 让凹陷浅淡、柔和、带治愈感，避免生硬或显脏。
      final depth = _focused ? 0.38 : 0.20;
      return RecessedSurface(
        tokens: tokens,
        borderRadius: radius,
        depth: depth,
        rimFraction: 0.24,
        recessDark: Color.lerp(tokens.surface, tokens.shadowConcave.first.color, 0.5)!,
        recessLight:
            Color.lerp(tokens.surface, tokens.shadowConcave[1].color, 0.55)!,
        color: visual.background,
        child: inner,
      );
    }

    final decoration = _buildDecoration(appTheme, tokens, visual, radius);
    return Container(
      decoration: decoration,
      child: inner,
    );
  }

  /// 原生 [TextField] 主体，样式统一、跨风格复用。
  Widget _buildTextField(Color foreground, ThemeTokens tokens) {
    return TextField(
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
        color: foreground,
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
    );
  }

  /// 按 4 风格分支构建容器装饰（新拟态已在 [build]/[_buildSurface] 用 [RecessedSurface]
  /// 处理，本方法仅服务于 flat / glass / female）。
  BoxDecoration _buildDecoration(
    AppThemeData appTheme,
    ThemeTokens tokens,
    InputVisual visual,
    double radius,
  ) {
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        // 不应到达（新拟态走 RecessedSurface）；兜底为平底 surface。
        return BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(radius),
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
