import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 如画应用统一卡片组件
///
/// 视觉规格来源：lumira-app/src/App.vue line 640-660 + 900-1200
/// 4 种 UI 风格分支渲染：
/// - neumorphic: canvas 背景 + shadowConvex 双向外阴影 + 14dp 圆角
/// - flat: canvas 背景 + divider 0.5dp 边框 + 10dp 圆角 + 无阴影
/// - glass: rgba(255,255,255,0.55) 背景 + white 30% 0.5dp 边框 + 14dp 圆角 + backdrop blur 20px
/// - female: multiGradient 5 层（linear + radial + hairline + brand shadow）+ 24dp 圆角
class NeuCard extends ConsumerWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20), // 40rpx → 20dp
    this.margin,
    this.onTap,
    this.enableHoverScale = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableHoverScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    // rpx → dp：app_theme.cardRadius 存储的是 rpx 原值（28/20/28/48），/2 得 dp
    final radius = appTheme.cardRadius / 2;

    Widget card = _buildCard(appTheme, tokens, radius);

    if (enableHoverScale && onTap != null) {
      card = _ScaleTap(
        scale: appTheme.style == UIStyle.female ? 0.96 : 0.98,
        onTap: onTap!,
        child: card,
      );
    } else if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }

  Widget _buildCard(AppThemeData appTheme, ThemeTokens tokens, double radius) {
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.canvas, // 与背景同色形成 3D 效果
            borderRadius: BorderRadius.circular(radius),
            boxShadow: tokens.shadowConvex,
          ),
          child: child,
        );

      case UIStyle.flat:
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.canvas,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.divider, width: 0.5),
          ),
          child: child,
        );

      case UIStyle.glass:
        // 半透明 + backdrop-filter + 1rpx white 30% border
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(appTheme.surfaceAlpha),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 0.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );

      case UIStyle.female:
        // 多渐变卡片：5 层视觉
        // 层 1: linear gradient 基底
        // 层 2: radial highlight
        // 层 3: surface 75% alpha（由 linear gradient 提供）
        // 层 4: hairline border
        // 层 5: brand shadow（cardShadow）
        final mg = appTheme.multiGradient!;
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: mg.linear,
            border: mg.hairlineBorder,
            boxShadow: appTheme.cardShadow,
          ),
          child: CustomPaint(
            painter: _RadialHighlightPainter(mg.radialHighlight),
            child: child,
          ),
        );
    }
  }
}

/// 径向高光绘制器（用于 female 风格第 2 层）
class _RadialHighlightPainter extends CustomPainter {
  _RadialHighlightPainter(this.gradient);

  final RadialGradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 按压缩放容器（用于卡片和按钮的 :active 反馈）
class _ScaleTap extends StatefulWidget {
  const _ScaleTap({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
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
