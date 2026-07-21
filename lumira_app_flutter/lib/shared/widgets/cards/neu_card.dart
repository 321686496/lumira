import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 阴影变体选择
enum NeuShadowVariant {
  /// 标准凸起阴影（默认）：shadowConvex (6,6)/(-6,-6) blur 14
  convex,

  /// 轻量凸起阴影：shadowConvexSubtle (3,3)/(-3,-3) blur 6
  convexSubtle,

  /// 品牌色凸起阴影：shadowConvexBrand (4,4)/(-4,-4) blur 10
  convexBrand,
}

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
    this.shadowVariant = NeuShadowVariant.convex,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableHoverScale;

  /// 新拟态阴影变体（仅 neumorphic 风格生效）
  final NeuShadowVariant shadowVariant;

  /// 自定义背景色（覆盖默认 surface；为 null 时使用 tokens.surface）
  final Color? backgroundColor;

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
        // Forced fix: 新拟态需卡片与背景同色 + 双向阴影才有效果。
        // 使用 surface（接近 canvas 但稍亮）增强阴影对比，避免与背景完全融合看不见。
        List<BoxShadow> shadows;
        switch (shadowVariant) {
          case NeuShadowVariant.convex:
            shadows = tokens.shadowConvex;
            break;
          case NeuShadowVariant.convexSubtle:
            shadows = tokens.shadowConvexSubtle;
            break;
          case NeuShadowVariant.convexBrand:
            shadows = tokens.shadowConvexBrand;
            break;
        }
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? tokens.surface, // surface 比 canvas 稍亮，增强阴影对比
            borderRadius: BorderRadius.circular(radius),
            boxShadow: shadows,
          ),
          child: child,
        );

      case UIStyle.flat:
        // Forced fix: 扁平化使用 surfaceAlt 区分卡片与背景，无阴影、细边框。
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.surfaceAlt, // 区分于 canvas 背景
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.divider, width: 1),
          ),
          child: child,
        );

      case UIStyle.glass:
        // Forced fix: 玻璃拟态彻底重做，加强 5 个视觉特征让 glass 效果明显：
        // 1. blur 25（强模糊）
        // 2. 3 段渐变：顶部高光白 0.85 → 中部白 0.50 → 底部白 0.30（玻璃边缘反射）
        // 3. 双层边框：外白 0.6 + 内白 0.15（玻璃厚度感）
        // 4. 顶部高光反射：Stack 顶层放一个 LinearGradient（白 0.45 → 透明）只覆盖顶部 1/3
        // 5. 深阴影：brand 色微染 + 黑色阴影双层
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              // 层 1: BackdropFilter blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      // 3 段渐变模拟玻璃边缘反射
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.85),
                          Colors.white.withOpacity(0.50),
                          Colors.white.withOpacity(0.30),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              // 层 2: 顶部高光反射（玻璃边缘高光）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radius),
                      topRight: Radius.circular(radius),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.45),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 层 3: 内边框（玻璃厚度感）
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius - 1.5),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              // 层 4: 内容
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        );

      case UIStyle.female:
        // Forced fix: 女性美学加强渐变对比与高光，增加品牌色饱和度。
        // 多渐变卡片：5 层视觉
        //
        // Bug fix: 之前 CustomPaint 放在 padding 内部，导致径向高光只绘制在
        // 内容区域，padding 区域只有底层 LinearGradient，两层渐变不一致，
        // 视觉上出现"边框带"效果。改为用 Stack 结构，让径向高光覆盖整个卡片
        // （包括 padding 区域），再用 Padding 包裹 child。
        final mg = appTheme.multiGradient!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSubtle.withOpacity(0.85),
                tokens.surface.withOpacity(0.65),
                tokens.brandLight.withOpacity(0.45),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.20),
                offset: const Offset(0, 10),
                blurRadius: 32,
              ),
              BoxShadow(
                color: tokens.brandLight.withOpacity(0.15),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 层 1: 径向高光（覆盖整个卡片，包括 padding 区域）
              // Bug fix: 传入 radius 让 painter 用 drawRRect 绘制圆角矩形，
              // 避免覆盖 Container 的 borderRadius 导致圆角视觉消失。
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RadialHighlightPainter(
                      mg.radialHighlight,
                      radius,
                    ),
                  ),
                ),
              ),
              // 层 2: 内容（被 padding 包裹）
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        );
    }
  }
}

/// 径向高光绘制器（用于 female 风格第 2 层）
/// Bug fix: 添加 borderRadius 参数，用 drawRRect 绘制圆角矩形，
/// 避免覆盖 Container 的 borderRadius 导致圆角视觉消失。
class _RadialHighlightPainter extends CustomPainter {
  _RadialHighlightPainter(this.gradient, this.borderRadius);

  final RadialGradient gradient;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RadialHighlightPainter oldDelegate) =>
      gradient != oldDelegate.gradient ||
      borderRadius != oldDelegate.borderRadius;
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
