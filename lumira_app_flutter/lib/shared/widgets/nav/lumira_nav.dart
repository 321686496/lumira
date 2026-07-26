import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../brand/lumira_logo.dart';

/// 如画应用统一顶部导航栏
///
/// 视觉规格来源：lumira-app/src/App.vue line 373-490
/// - 透明背景（不阻挡页面背景色）
/// - 滚动后毛玻璃态（.scrolled 类）
/// - 标题居中（position absolute + left 50% + transform translate -50%）
/// - 可选左侧返回按钮（圆形 neumorphic 背景）
/// - 可选右侧操作按钮组
///
/// Logo 升级：新增 useWordmark 参数，启用后用品牌 SVG 文字标替换纯文本标题，
/// 适用于首页等需要展示品牌标识的 tab 页。
class LumiraNav extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const LumiraNav({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.scrolled = false,
    this.transparent = true,
    this.showBackButton = true,
    this.useWordmark = false,
    this.horizontalPadding = 24.0,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrolled;
  final bool transparent;

  /// 是否在 leading 为 null 且 canPop 时自动显示返回按钮。
  /// Tab 页（home/templates/challenge/profile）应传 false，
  /// 避免 go_router canPop 误判导致 tab 页显示返回按钮（点击退出应用）。
  final bool showBackButton;

  /// 是否用品牌 SVG 文字标（Lumira wordmark）替换纯文本标题。
  /// 启用时忽略 [title]，渲染 assets/logos/logo-lumira-wordmark.svg。
  /// 适用于首页等需要展示品牌标识的场景。
  final bool useWordmark;

  /// nav 左右内容与屏幕边缘的水平间距。
  /// Tab 页（home/templates/challenge/profile）传 24 与 body padding 对齐；
  /// 详情页保持默认或传 12。
  final double horizontalPadding;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  ConsumerState<LumiraNav> createState() => _LumiraNavState();
}

class _LumiraNavState extends ConsumerState<LumiraNav> {
  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isGlass = appTheme.style == UIStyle.glass;

    // Forced fix: glass 风格默认就启用半透明 + blur（不只 scrolled 时），
    // 让导航栏在 glass 风格下也有毛玻璃效果。
    final Color backgroundColor;
    if (isGlass) {
      // glass 风格：默认半透明白 0.55，scrolled 时加深至 0.72
      backgroundColor = Colors.white.withOpacity(widget.scrolled ? 0.72 : 0.55);
    } else if (widget.transparent && !widget.scrolled) {
      backgroundColor = Colors.transparent;
    } else if (widget.scrolled) {
      // .lumira-nav.scrolled: rgba(canvas, 0.72) + blur 28px saturate 1.8
      backgroundColor = tokens.canvas.withOpacity(0.72);
    } else {
      backgroundColor = tokens.canvas;
    }

    final border = widget.scrolled || isGlass
        ? Border(
            bottom: BorderSide(
              color: isGlass ? Colors.white.withOpacity(0.4) : tokens.divider,
              width: 0.5,
            ),
          )
        : null;

    final shadow = widget.scrolled
        ? const [
            BoxShadow(
              color: Color(0x08000000),
              offset: Offset(0, 0.5),
              blurRadius: 6,
            ),
          ]
        : null;

    // Forced fix: 计算 leading widget
    // - 如果显式传了 leading，用它
    // - 否则如果 showBackButton=true 且 canPop=true，显示返回按钮
    // - 否则占位 SizedBox（保持标题居中）
    // Tab 页传 showBackButton=false，避免 canPop 误判导致 tab 页显示返回按钮
    final Widget leadingWidget = widget.leading ??
        (widget.showBackButton && Navigator.of(context).canPop()
            ? _NavBackButton()
            : const SizedBox(width: 40));

    // Forced fix: glass 风格默认 blur 20，scrolled 时 blur 28
    final double blurSigma = isGlass
        ? (widget.scrolled ? 28.0 : 20.0)
        : (widget.scrolled ? 14.0 : 0.0);

    // Logo 升级：计算居中标题内容
    // - useWordmark=true → 品牌 SVG 文字标
    // - 否则若有 title → 纯文本标题
    final Widget? centerWidget = widget.useWordmark
        ? const LumiraLogo.wordmark(
            height: 22, // 略大于原 19dp 文本，承载 SVG 描边
            semanticsLabel: '如画文字标',
          )
        : (widget.title != null
            ? Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 19, // 38rpx → 19dp
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  letterSpacing: 0.04 * 19,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: border,
            boxShadow: shadow,
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48, // min-height 96rpx → 48dp
              child: widget.centerTitle
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // 左侧
                        Positioned(
                          left: widget.horizontalPadding,
                          child: leadingWidget,
                        ),
                        // 居中标题 / wordmark
                        if (centerWidget != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            child: Center(child: centerWidget),
                          ),
                        // 右侧
                        Positioned(
                          right: widget.horizontalPadding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions ?? [const SizedBox(width: 40)],
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                      child: Row(
                        children: [
                          leadingWidget,
                          if (centerWidget != null) ...[
                            const SizedBox(width: 4),
                            Flexible(child: centerWidget),
                          ],
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions ?? [const SizedBox(width: 40)],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 默认返回按钮（圆形 neumorphic 背景）
/// 来自 App.vue line 466-486: 64rpx 圆形 + surface 背景 + shadow-convex-subtle
class _NavBackButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 32, // 64rpx → 32dp
        height: 32,
        decoration: BoxDecoration(
          color: tokens.surface,
          shape: BoxShape.circle,
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Icon(
          Icons.chevron_left,
          size: 18, // 36rpx → 18dp
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

/// 导航栏按钮（用于 actions）
class LumiraNavButton extends ConsumerWidget {
  const LumiraNavButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    final content = Icon(
      icon,
      size: 20, // 40rpx → 20dp
      color: tokens.textSecondary,
    );

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6), // 12rpx → 6dp
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
        ),
        child: tooltip == null
            ? content
            : Tooltip(message: tooltip!, child: content),
      ),
    );
  }
}
