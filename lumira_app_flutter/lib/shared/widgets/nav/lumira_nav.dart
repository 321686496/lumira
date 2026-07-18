import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';

/// 如画应用统一顶部导航栏
///
/// 视觉规格来源：lumira-app/src/App.vue line 373-490
/// - 透明背景（不阻挡页面背景色）
/// - 滚动后毛玻璃态（.scrolled 类）
/// - 标题居中（position absolute + left 50% + transform translate -50%）
/// - 可选左侧返回按钮（圆形 neumorphic 背景）
/// - 可选右侧操作按钮组
class LumiraNav extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const LumiraNav({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.scrolled = false,
    this.transparent = true,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrolled;
  final bool transparent;

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

    final Color backgroundColor;
    if (widget.transparent && !widget.scrolled) {
      backgroundColor = Colors.transparent;
    } else if (widget.scrolled) {
      // .lumira-nav.scrolled: rgba(canvas, 0.72) + blur 28px saturate 1.8
      backgroundColor = tokens.canvas.withOpacity(0.72);
    } else {
      backgroundColor = tokens.canvas;
    }

    final border = widget.scrolled
        ? Border(
            bottom: BorderSide(color: tokens.divider, width: 0.5),
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

    return ClipRect(
      child: BackdropFilter(
        filter: widget.scrolled
            ? ImageFilter.blur(sigmaX: 14, sigmaY: 14)
            : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 左侧
                  Positioned(
                    left: 8,
                    child: widget.leading ??
                        (Navigator.of(context).canPop()
                            ? _NavBackButton()
                            : const SizedBox(width: 40)),
                  ),
                  // 居中标题
                  if (widget.title != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
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
                        ),
                      ),
                    ),
                  // 右侧
                  Positioned(
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions ?? [const SizedBox(width: 40)],
                    ),
                  ),
                ],
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
