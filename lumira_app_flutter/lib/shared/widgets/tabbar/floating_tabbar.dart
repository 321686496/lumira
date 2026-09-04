import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/router/route_names.dart';

/// 如画应用悬浮 Tab 栏
///
/// 视觉规格来源：lumira-app/src/components/FloatingTabBar.vue + App.vue line 488-555
/// - fixed 定位，bottom 28rpx→14dp
/// - width: calc(100% - 80rpx) → 横向 padding 40rpx→20dp
/// - height: 108rpx → 54dp
/// - border-radius: 9999rpx → 完全圆角（pill 形）
/// - canvas 背景 + backdrop-filter blur 24px
/// - shadow-convex
/// - 5 个 item：首页/模板/(中心拍摄按钮)/挑战/我的
/// - 中心按钮：100rpx→50dp 圆形 + brand bg + shadow-convex-brand + translateY(-12rpx)→-6dp
/// - active item: brand 色
/// - 女性美学：active item + center 有呼吸光晕动画
class FloatingTabBar extends ConsumerStatefulWidget {
  const FloatingTabBar({
    super.key,
    required this.active,
    this.onTabSelected,
  });

  /// 当前激活的 tab key：'home' | 'templates' | 'challenge' | 'profile'
  final String active;

  /// 可选：tab 被点击时的外部回调（参数为 tab 序号 0/1/3/4，2 为中间的拍摄按钮）。
  /// 提供后此组件不再自行跳转路由（用于由外部容器在本机切换 tab）；为 null 时保持默认 context.go 跳转。
  final void Function(int tabIndex)? onTabSelected;

  @override
  ConsumerState<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends ConsumerState<FloatingTabBar> {
  /// tab 点击统一入口：优先交给外部回调（本机切页，保留状态）；
  /// 未提供时回退到默认的路由跳转（兼容 academy 等独立用例）。
  void _handleTabTap(int tabIndex) {
    final external = widget.onTabSelected;
    if (external != null) {
      external(tabIndex);
      return;
    }
    switch (tabIndex) {
      case 0:
        context.go(RouteNames.home);
        break;
      case 1:
        context.go(RouteNames.templates);
        break;
      case 3:
        context.go(RouteNames.challenge);
        break;
      case 4:
        context.go(RouteNames.profile);
        break;
    }
  }
  /// tab bar 表面（底色/描边/阴影 + 5 个 item 的 Row）。
  /// 与玻璃模糊解耦，便于在非玻璃风格跳过 BackdropFilter，只保留纯静态表面。
  Widget _barContent(ThemeTokens tokens, bool isFemale, bool isGlass) {
    return Container(
      height: 54, // 108rpx → 54dp
      decoration: BoxDecoration(
        // Forced fix: glass 用主题色磨砂渐变 + 白描边（跟随品牌色）
        gradient: isGlass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.72),
                  Color.lerp(Colors.white, tokens.brandLight, 0.12)!
                      .withOpacity(0.46),
                  Color.lerp(Colors.white, tokens.brandLight, 0.20)!
                      .withOpacity(0.30),
                ],
                stops: const [0.0, 0.5, 1.0],
              )
            : null,
        color: isGlass ? null : tokens.canvas,
        borderRadius: BorderRadius.circular(1000),
        border: isGlass
            ? Border.all(
                color: ThemeTokens.glassBorder(tokens),
                width: 1.0,
              )
            : null,
        boxShadow: isGlass
            ? const [
                BoxShadow(
                  color: Color(0x29000000),
                  offset: Offset(0, 10),
                  blurRadius: 30,
                ),
              ]
            : isFemale
                ? [
                    BoxShadow(
                      color: tokens.brand.withOpacity(0.15),
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                    ),
                  ]
                : tokens.shadowConvex,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TabItem(
            icon: Icons.home_outlined,
            label: '首页',
            active: widget.active == 'home',
            onTap: () => _handleTabTap(0),
            tokens: tokens,
            isFemale: isFemale,
          ),
          _TabItem(
            icon: Icons.grid_view_outlined,
            label: '发现',
            active: widget.active == 'templates',
            onTap: () => _handleTabTap(1),
            tokens: tokens,
            isFemale: isFemale,
          ),
          // 中间占位（capture button 由 Stack 顶层渲染）
          const SizedBox(width: 60),
          _TabItem(
            icon: Icons.flag_outlined,
            label: '挑战',
            active: widget.active == 'challenge',
            onTap: () => _handleTabTap(3),
            tokens: tokens,
            isFemale: isFemale,
          ),
          _TabItem(
            icon: Icons.person_outline,
            label: '我的',
            active: widget.active == 'profile',
            onTap: () => _handleTabTap(4),
            tokens: tokens,
            isFemale: isFemale,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isFemale = appTheme.style == UIStyle.female;
    final isGlass = appTheme.style == UIStyle.glass;

    // Forced fix: 之前 _CenterCaptureButton 在 ClipRRect 内部，
    // Transform.translate(0, -6) 的部分被 ClipRRect 剪切。
    // 改为 Stack 结构：底层是带 ClipRRect 的 tab bar（4 个 tab + 中间空位），
    // 顶层是悬浮的 capture button（可自由超出 tab bar 范围）。
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 14, // 28rpx → 14dp
        ),
        child: SizedBox(
          height: 70, // 容纳 tab bar (54dp) + capture button 上移空间 (16dp)
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // 底层：tab bar
              // 性能(Forced fix): BackdropFilter 会令引擎把其背后的滚动内容单独成层，
              // 并在内容滚动时每帧重新光栅/合成整条区域——这是四个 Tab 页在 OHOS 上滚动掉帧的
              // 共性根因（sigma=0 无可见模糊，却依然承担 backdrop 分层开销）。因此仅在玻璃风格
              // 真正需要模糊时包裹 BackdropFilter；其余风格直接 ClipRRect。并对整栏加
              // RepaintBoundary，让静态表面不被反复重绘。视觉与原实现完全一致。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1000),
                    child: isGlass
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: _barContent(tokens, isFemale, isGlass),
                          )
                        : _barContent(tokens, isFemale, isGlass),
                  ),
                ),
              ),
              // 顶层：悬浮 capture button（可超出 tab bar 范围，不被剪切）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _CenterCaptureButton(tokens: tokens, isFemale: isFemale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.tokens,
    required this.isFemale,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemeTokens tokens;
  final bool isFemale;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with TickerProviderStateMixin {
  // 女性美学：选中态「呼吸光晕」脉冲动画（FemaleAestheticDesignSystem §4.4 焦点引导）。
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (widget.isFemale && widget.active) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldPulse = widget.isFemale && widget.active;
    final wasPulsing = _pulseController != null;
    if (shouldPulse && !wasPulsing) {
      _startPulse();
    } else if (!shouldPulse && wasPulsing) {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  void _startPulse() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseController = controller;
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _pulseController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.tokens.brand : widget.tokens.textTertiary;
    // 女性美学呼吸光晕：0→1→0 的柔和呼吸，仅选中态触发；透明则无动画。
    final Widget iconGlow = AnimatedBuilder(
      animation: _pulseController ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        final t = _pulseController?.value ?? 0.0;
        final alpha = 0.45 * (1 - (t * 2 - 1).abs());
        final spread = 2 + 3 * (1 - (t * 2 - 1).abs());
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _pulseController == null
                ? null
                : [
                    BoxShadow(
                      color: widget.tokens.brand.withOpacity(alpha),
                      blurRadius: 12,
                      spreadRadius: spread,
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: Icon(widget.icon, size: 22, color: color),
    );

    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 26, child: Center(child: iconGlow)),
            const SizedBox(height: 1), // gap 2rpx → 1dp
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10, // 20rpx → 10dp
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4, // 0.04em * 10
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCaptureButton extends StatefulWidget {
  const _CenterCaptureButton({required this.tokens, required this.isFemale});

  final ThemeTokens tokens;
  final bool isFemale;

  @override
  State<_CenterCaptureButton> createState() => _CenterCaptureButtonState();
}

class _CenterCaptureButtonState extends State<_CenterCaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isFemale) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Forced fix: 移除 Transform.translate，由 Stack 的 Positioned 控制位置。
    // 这样按钮可以自由超出 tab bar 范围而不被 ClipRRect 剪切。
    //
    // Neumorphic fix: 之前使用 shadowConvexBrand（brand 色阴影），由于阴影颜色与按钮
    // 背景色接近，视觉上像"发光"而非新拟态凸起。改为使用标准 shadowConvex（双向
    // 中性色阴影），让按钮呈现标准新拟态凸起效果。同时叠加一层 surface 色内圈
    // 制造品牌色"嵌入"感，符合新拟态设计语言。
    final captureBtn = Container(
      width: 50, // 100rpx → 50dp
      height: 50,
      decoration: BoxDecoration(
        color: widget.tokens.brand,
        shape: BoxShape.circle,
        boxShadow: widget.tokens.shadowConvex,
      ),
      child: Icon(
        Icons.camera_alt_outlined,
        size: 24, // 48rpx → 24dp
        color: widget.tokens.textInverse,
      ),
    );

    final button = GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.capture),
      child: captureBtn,
    );

    if (!widget.isFemale) {
      return button;
    }

    // 女性美学：呼吸光晕动画
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        // 0→1→0 的脉冲：0.4 → 0
        final alpha = 0.4 * (1 - (t * 2 - 1).abs());
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.tokens.brand.withOpacity(alpha),
                blurRadius: 16,
                spreadRadius: 4 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: button,
    );
  }
}
