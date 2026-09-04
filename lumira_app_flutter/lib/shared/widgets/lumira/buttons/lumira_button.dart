import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../../effects/recessed_surface.dart';
import '../_internal/lumira_theme_resolver.dart';

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
    this.overlay = false,
    this.enableHoverScale = false,
    this.keepBrandOnPress = false,
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

  /// 是否为「悬浮/叠图」形态（按钮落在封面/照片/悬浮浮层等非纯色底上）。
  /// 新拟态双轨下，overlay 按钮走改良漂浮悬浮：半透明表面 + 细描边 + 仅暗色投影，
  /// 而非画布上的双向浮雕外阴影，避免在图片上形成光晕/脏边。
  final bool overlay;

  /// 是否启用悬停/按压缩放反馈，默认 false
  final bool enableHoverScale;

  /// 是否在按压时保持品牌色背景（品牌 CTA，默认 false）。
  ///
  /// 默认 false：新拟态下主/其他按钮按压时把外凸浮雕切换为凹陷表面（品牌色随之消失）。
  /// 为 true 时：新拟态主色按钮按压仅「加深品牌色 + 扁平化 + 缩小」，不切换凹陷表面，
  /// 满足「主色 CTA 保持主色」的诉求（如兑换码页「立即兑换」、场景管理「新建场景」）。
  final bool keepBrandOnPress;

  @override
  ConsumerState<LumiraButton> createState() => _LumiraButtonState();
}

class _LumiraButtonState extends ConsumerState<LumiraButton> {
  bool _pressed = false;

  // 呼吸按压动画（FemaleAestheticDesignSystem §4.4）：
  // 按下 140ms 快速内缩到 0.96（模拟物理按压）；
  // 松手 300ms 用 easeOutBack 弹性回弹，略超 1.0 再回落，形成有生命感的「呼吸」回弹。
  static const Duration _pressDuration = Duration(milliseconds: 140);
  static const Duration _releaseDuration = Duration(milliseconds: 300);

  bool get _disabled => widget.onPressed == null;

  void _handleTapDown(TapDownDetails _) {
    if (!_disabled) setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (_disabled) return;
    setState(() => _pressed = false);
    widget.onPressed!();
  }

  void _handleTapCancel() {
    if (!_disabled) setState(() => _pressed = false);
  }

  /// 悬浮/叠图形态的按钮视觉（仅在新拟态 overlay 场景使用）。
  ///
  /// 依据 Neumorphism 双轨体系：按钮落在图片/浮层等非纯色底上时，
  /// 标准同色双向浮雕阴影无法被背景承接，会像光晕一样糊在图上显脏。
  /// 因此改用「半透明表面 + 细描边 + 仅暗色投影」，去掉双向浮雕外阴影。
  ButtonVisual _overlayVisual(
    ThemeTokens tokens,
    double radius,
    ButtonVisual base,
  ) {
    final ov = LumiraThemeResolver.overlayOnImageVisual(
      tokens: tokens,
      radiusDp: radius,
      overlayAlpha: 0.9,
      shadowOpacity: 0.4,
    );
    if (widget.variant == ButtonVariant.primary) {
      // 主按钮叠图时保留品牌半透明表面，保证品牌识别度与可读性
      return ButtonVisual(
        background: tokens.brand.withOpacity(0.9),
        foreground: tokens.textInverse,
        border: ov.border,
        shadows: ov.shadows,
      );
    }
    return ButtonVisual(
      background: ov.background,
      foreground: base.foreground,
      border: ov.border,
      shadows: ov.shadows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    var visual = appTheme.buttonVisual(widget.variant);
    final isNeu = appTheme.style == UIStyle.neumorphic;

    final radius = (widget.radius ?? appTheme.buttonRadius / 2);

    // 品牌 CTA（keepBrandOnPress）新拟态：纯品牌色顶面 + 内斜边（亮上左/暗下右），
    // 按压时反转斜边（暗上左/亮下右），颜色不变、不加深。1.5px 实线不发散，
    // 替代外阴影避免异色按钮悬浮感。
    if (isNeu && widget.keepBrandOnPress) {
      visual = ButtonVisual(
        background: tokens.brand,
        foreground: tokens.textInverse,
        border: Border(
          top: BorderSide(color: ThemeTokens.brandBevelLight(tokens), width: 1.5),
          left: BorderSide(color: ThemeTokens.brandBevelLight(tokens), width: 1.5),
          bottom: BorderSide(color: ThemeTokens.brandBevelDark(tokens), width: 1.5),
          right: BorderSide(color: ThemeTokens.brandBevelDark(tokens), width: 1.5),
        ),
        shadows: const [],
      );
    }

    // 悬浮/叠图形态：新拟态下用改良漂浮浮层视觉（半透明表面 + 细边 + 仅暗投影），
    // 覆盖画布上的双向浮雕，避免在图片/浮层上形成光晕脏边。
    final effectiveVisual = (widget.overlay && isNeu)
        ? _overlayVisual(tokens, radius, visual)
        : visual;

    Color background = effectiveVisual.background;
    Color foreground = effectiveVisual.foreground;
    Border? border = effectiveVisual.border;
    List<BoxShadow> shadows = effectiveVisual.shadows;
    LinearGradient? gradient = effectiveVisual.gradient;
    bool useRecessedSurface = false;

    if (_disabled) {
      // disabled 态：背景降透明度 0.5，文字 textTertiary
      background = visual.background.withOpacity(0.5);
      foreground = tokens.textTertiary;
      shadows = const [];
      gradient = null;
    } else if (isNeu && _pressed && !widget.overlay) {
      // 新拟态按压态：将外凸浮雕切换为凹陷表面（上/左暗、下/右亮、中心平底），
      // 模拟手指按下去被压进画布的物理反馈。overlay（叠图）场景保持仅按压缩放，
      // 避免在图片上形成脏边（Neumorphism §4）。
      if (widget.keepBrandOnPress) {
        // 品牌 CTA 按压：反转内斜边（暗上左 / 亮下右），颜色不变、不加深。
        border = Border(
          top: BorderSide(color: ThemeTokens.brandBevelDark(tokens), width: 1.5),
          left: BorderSide(color: ThemeTokens.brandBevelDark(tokens), width: 1.5),
          bottom: BorderSide(color: ThemeTokens.brandBevelLight(tokens), width: 1.5),
          right: BorderSide(color: ThemeTokens.brandBevelLight(tokens), width: 1.5),
        );
      } else {
        useRecessedSurface = true;
      }
      gradient = null;
      shadows = const [];
    } else if (widget.variant == ButtonVariant.ghost && _pressed) {
      // ghost 按下时加 brandSubtle 背景
      background = tokens.brandSubtle;
      gradient = null;
    }

    // 内容（文字/图标）统一包一层，供凹陷表面承载。
    final Widget body = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      child: IconTheme(
        data: IconThemeData(color: foreground, size: 18),
        child: widget.child,
      ),
    );

    Widget content = useRecessedSurface
        ? RecessedSurface(
            tokens: tokens,
            borderRadius: radius,
            depth: 0.68,
            rimFraction: 0.3,
            child: Padding(padding: widget.padding, child: body),
          )
        : Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: gradient == null ? background : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(radius),
              border: border,
              boxShadow: shadows,
            ),
            child: body,
          );

    // 按压缩放反馈（disabled 不响应）。`enableHoverScale` 保留为 API 选项，
    // 移动端无 hover 概念，press 反馈始终启用。
    if (!_disabled) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: TweenAnimationBuilder<double>(
          // 每次 _pressed 变化触发往返补间（无需 Ticker 手动管理）
          tween: Tween(end: _pressed ? 0.96 : 1.0),
          duration: _pressed ? _pressDuration : _releaseDuration,
          // 按下 easeIn 平滑收缩；松手 easeOutBack 弹性回弹（略超 1.0 → 呼吸感）
          curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: content,
        ),
      );
    }

    return content;
  }
}
