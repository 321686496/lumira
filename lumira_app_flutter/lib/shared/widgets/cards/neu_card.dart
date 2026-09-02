import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../common/glass_surface.dart';
import '../lumira/_internal/lumira_theme_resolver.dart';

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
    this.overlayOnImage = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// 保留的兼容参数（历史上用于开关按压缩放）。
  /// 现衷：所有可点击卡片统一提供「呼吸」按压反馈，不再由该参数门控。
  final bool enableHoverScale;

  /// 新拟态阴影变体（仅 neumorphic 风格生效）
  final NeuShadowVariant shadowVariant;

  /// 自定义背景色（覆盖默认 surface；为 null 时使用 tokens.surface）
  final Color? backgroundColor;

  /// 本卡片是否叠在照片等非纯色底之上。
  /// 为 true 时，新拟态风格将放弃双向浮雕外阴影（照片无法承接同色阴影，
  /// 阴影会像光晕般发散），改用实心 surface + 细描边表达表面。
  /// 其余风格不受影响（它们本就不依赖双向浮雕）。
  final bool overlayOnImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    // rpx → dp：app_theme.cardRadius 存储的是 rpx 原值（28/20/28/48），/2 得 dp
    final radius = appTheme.cardRadius / 2;

    Widget card = _buildCard(appTheme, tokens, radius);

    // 卡片点击「呼吸」按压反馈（FemaleAestheticDesignSystem §4.4）：
    // 所有可点击卡片统一启用；女性美学取 0.96 更强的呼吸回弹，其余风格 0.98 轻微按压。
    // 该反馈存在时启用 _ScaleTap 的弹性补间（press 内缩 + release easeOutBack 回弹）。
    if (onTap != null) {
      card = _ScaleTap(
        scale: appTheme.style == UIStyle.female ? 0.96 : 0.98,
        onTap: onTap!,
        child: card,
      );
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
        // 叠在照片上（overlayOnImage）时放弃双向浮雕阴影（照片无法承接），
        // 改用实心 surface + 细描边表达表面，避免阴影在照片上"发光/发散"。
        if (overlayOnImage) {
          // 改良悬浮新拟态（Neumorphism 双轨「图片上」浮层）：
          // 叠在照片/封面等非纯色底上时，标准同色双向浮雕阴影无法被背景承接，
          // 会像光晕糊在图上显脏。改用「半透明 surface + 仅暗色投影 + 细描边」，
          // 禁用 inset，按压反馈由外层 _ScaleTap 用 scale 承担。
          final visual = LumiraThemeResolver.overlayOnImageVisual(
            tokens: tokens,
            radiusDp: radius,
          );
          final surfaceColor = backgroundColor ?? visual.background;
          return Container(
            padding: padding,
            decoration: BoxDecoration(
              color: surfaceColor.withOpacity(visual.background.opacity),
              borderRadius: BorderRadius.circular(radius),
              border: visual.border,
              boxShadow: visual.shadows,
            ),
            child: child,
          );
        }
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
          // Bug fix: 裁剪内容到圆角内部，避免卡片内的封面图/子组件溢出圆角
          clipBehavior: Clip.antiAlias,
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
          // Bug fix: 裁剪内容到圆角内部，避免封面图/子组件溢出圆角
          clipBehavior: Clip.antiAlias,
          child: child,
        );

      case UIStyle.glass:
        // Forced fix: 玻璃拟态改由共享 GlassSurface 渲染——半透明主题色磨砂填充 +
        // 顶部高光 + 内描边 + 柔和投影，让背后密集彩色背景透过半透明表面显现，
        // 形成明显的毛玻璃观感（BackdropFilter 无法跨 RepaintBoundary 采样页面背景，
        // 故不在此处依赖真模糊，改由透色达成）。
        // 颜色跟随当前主题品牌色，亮/暗主题各有一套。
        return GlassSurface(
          borderRadius: BorderRadius.circular(radius),
          padding: padding,
          shadows: appTheme.cardShadow,
          child: child,
        );

      case UIStyle.female:
        // Forced fix: 女性美学卡片重做，去「反光玻璃」观感。
        // 采用：不透明柔和扁平微渐变（纸面感）+ 极淡氛围光（非明亮光斑）+ 细腻暖色 hairline
        // 边框（替代刺眼白边）+ 单一柔和品牌色投影（去玻璃高光顶边）。
        // Bug fix: 用 Stack 结构让径向氛围光覆盖整个卡片（含 padding），
        // 再以 Padding 包裹内容，避免“边框带”效果。
        final mg = appTheme.multiGradient!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: mg.linear,
            border: mg.hairlineBorder,
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.16),
                offset: const Offset(0, 10),
                blurRadius: 28,
              ),
            ],
          ),
          // Bug fix: 裁剪内容到圆角内部，避免顶部封面图/子组件溢出圆角
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 层 1: 极淡暖色氛围光（覆盖整个卡片，包括 padding 区域）
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

  // 呼吸按压：按下 140ms 内缩；松手 300ms easeOutBack 弹性回弹略超 1.0（女性「呼吸感」）。
  static const Duration _pressDuration = Duration(milliseconds: 140);
  static const Duration _releaseDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? widget.scale : 1.0),
        duration: _pressed ? _pressDuration : _releaseDuration,
        // 按下 easeIn 平滑收缩；松手 easeOutBack 弹性回弹（略超 1.0 → 呼吸感）
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: widget.child,
      ),
    );
  }
}
