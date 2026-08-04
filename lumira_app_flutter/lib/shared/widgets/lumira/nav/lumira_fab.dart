import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用统一 FloatingActionButton
///
/// 视觉规格来源：spec §3.5 LumiraFloatingActionButton
///
/// - 尺寸：normal 56x56，mini 40x40
/// - 圆角 = appTheme.fabRadius / 2
/// - 4 风格：
///   - neumorphic：surface + shadowConvex
///   - flat：brand 背景 + 白色 child（假设 child 是图标）
///   - glass：白透明 0.7 + backdrop blur 15 + brand 边框
///   - female：brandLight→brand 渐变 + hairline 白边 + brand 阴影
/// - 按压缩放 0.95
/// - tooltip 不为 null 时用 Tooltip 包裹
class LumiraFloatingActionButton extends ConsumerWidget {
  const LumiraFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.mini = false,
  });

  final VoidCallback onPressed;
  final Widget child;
  final String? tooltip;
  final bool mini;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final size = mini ? 40.0 : 56.0;
    final radius = LumiraThemeResolver.rpxToDp(appTheme.fabRadius);

    Widget fab = _ScaleTap(
      scale: 0.95,
      onTap: onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: _buildDecoratedChild(tokens, style, radius),
      ),
    );

    if (tooltip != null) {
      fab = Tooltip(message: tooltip!, child: fab);
    }

    return fab;
  }

  Widget _buildDecoratedChild(ThemeTokens tokens, UIStyle style, double radius) {
    switch (style) {
      case UIStyle.neumorphic:
        // surface + shadowConvex
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: tokens.shadowConvex,
          ),
          child: Center(child: child),
        );

      case UIStyle.flat:
        // brand 背景 + 白色 child（假设 child 是图标）
        return Container(
          decoration: BoxDecoration(
            color: tokens.brand,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
        );

      case UIStyle.glass:
        // 白透明 0.7 + backdrop blur 15 + brand 边框
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: tokens.brand, width: 1.2),
              ),
              child: Center(child: child),
            ),
          ),
        );

      case UIStyle.female:
        // brandLight→brand 渐变 + hairline 白边 + brand 阴影
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tokens.brandLight, tokens.brand],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.20),
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: Center(child: child),
        );
    }
  }
}

/// 按压缩放容器（用于 FAB 的 :active 反馈）
class _ScaleTap extends StatefulWidget {
  const _ScaleTap({
    required this.child,
    required this.onTap,
    this.scale = 0.95,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
