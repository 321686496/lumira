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
    this.actionsSpacing = 0,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrolled;
  final bool transparent;

  /// 右侧操作按钮组之间的水平间距（dp）。默认 0（兼容旧行为，按钮紧贴），
  /// 页面可通过传值调整，避免多个按钮挤在一起。
  final double actionsSpacing;

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

class _LumiraNavState extends ConsumerState<LumiraNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sigmaCurve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Forced fix: 初始 scrolled=true 时直接跳到终态，避免首帧 sigma=0 闪烁
    if (widget.scrolled) {
      _controller.value = 1.0;
    }
    _sigmaCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(LumiraNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Forced fix: sigma 与颜色动画同步——监听 scrolled 变化时 forward/reverse
    // 让 BackdropFilter 的 sigma 平滑过渡（不再瞬变），消除视觉撕裂
    if (widget.scrolled != oldWidget.scrolled) {
      if (widget.scrolled) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 计算右侧操作按钮列表：按 [actionsSpacing] 在按钮之间插入间距。
  /// 无操作按钮时返回一个宽度占位，维持标题居中不变形（与旧行为一致）。
  List<Widget> _actionsList() {
    final actions = widget.actions;
    if (actions == null || actions.isEmpty) return const [SizedBox(width: 40)];
    if (widget.actionsSpacing <= 0) return actions;
    final spaced = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) spaced.add(SizedBox(width: widget.actionsSpacing));
      spaced.add(actions[i]);
    }
    return spaced;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final UIStyle style = appTheme.style;
    final bool isGlass = style == UIStyle.glass;

    // Forced fix(风格自适): 半透明 + 毛玻璃(blur) 仅属于「玻璃拟态」。
    // 其余风格一律实心表面，避免出现不属于该风格的半透明/模糊观感。
    final double targetSigma;

    // Forced fix: 按「当前 UI 风格」解析滚动后的背景/描边/阴影
    final BoxDecoration decoration;
    if (isGlass) {
      // 玻璃拟态：始终半透明毛玻璃，滚动时加深，仅此风格保留 blur 动画；
      // 填充色跟随主题品牌（白底品牌微染）。
      targetSigma = 28.0;
      decoration = BoxDecoration(
        color: Color.lerp(Colors.white, tokens.brandLight, 0.12)!
            .withOpacity(widget.scrolled ? 0.68 : 0.50),
        border: Border(
          bottom: BorderSide(color: ThemeTokens.glassBorder(tokens), width: 0.5),
        ),
      );
    } else if (widget.scrolled) {
      // 非玻璃风格滚动后：实心表面，无 blur
      targetSigma = 0.0;
      decoration = _scrolledDecoration(style, tokens);
    } else {
      // 未滚动：透明。不能用 Colors.transparent（RGB 为黑），
      // 否则与 scrolled 的 canvas/表面之间的补间会经过"黑色半透明中间色"导致闪帧。
      // 用 canvas 自身 alpha=0 保持色相一致的透明。
      targetSigma = 0.0;
      decoration = BoxDecoration(
        color: widget.transparent ? tokens.canvas.withOpacity(0) : tokens.canvas,
      );
    }

    // Forced fix: 计算 leading widget
    // - 如果显式传了 leading，用它
    // - 否则如果 showBackButton=true 且 canPop=true，显示返回按钮
    // - 否则用 SizedBox.shrink()（不再占位 40dp，避免 tab 页左侧死区与右侧不对称）
    // Tab 页传 showBackButton=false，避免 canPop 误判导致 tab 页显示返回按钮
    final Widget leadingWidget = widget.leading ??
        (widget.showBackButton && Navigator.of(context).canPop()
            ? _NavBackButton()
            : const SizedBox.shrink());

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

    // Forced fix: 用 AnimatedBuilder 包裹 BackdropFilter，让 sigma 实时跟随动画值。
    // child（AnimatedContainer + 内部布局）是静态的，不随 sigma 重绘。
    return AnimatedBuilder(
      animation: _sigmaCurve,
      builder: (context, child) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: targetSigma * _sigmaCurve.value,
            sigmaY: targetSigma * _sigmaCurve.value,
          ),
          child: child,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: decoration,
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
                      // 用水平内边距预留两侧 leading/actions 的空间，
                      // 避免标题与较宽的右侧按钮（如编辑页的收藏+保存）重叠。
                      if (centerWidget != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.horizontalPadding + 72,
                              ),
                              child: centerWidget,
                            ),
                          ),
                        ),
                      // 右侧
                      Positioned(
                        right: widget.horizontalPadding,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _actionsList(),
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
                          children: _actionsList(),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 非玻璃风格「滚动后」的导航栏表面装饰。
  /// 各风格使用自身设计语言，不再借用玻璃风格的半透明/模糊观感：
  /// - neumorphic：实心 surface + 细描边（叠在内容之上的表面，不做外模糊/浮雕阴影）
  /// - flat：实心 surface + 实色细分隔线，无阴影
  /// - female：品牌渐变基底 + 品牌色细描边 + 柔和投影
  /// - glass：该分支由 build() 的 isGlass 提前接管，不会走到这里
  BoxDecoration _scrolledDecoration(UIStyle style, ThemeTokens tokens) {
    switch (style) {
      case UIStyle.neumorphic:
        return BoxDecoration(
          color: tokens.surface,
          border: Border(
            bottom: BorderSide(color: tokens.divider, width: 0.5),
          ),
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: tokens.surface,
          border: Border(
            bottom: BorderSide(color: tokens.divider, width: 1),
          ),
        );
      case UIStyle.female:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.75),
              tokens.surface.withOpacity(0.85),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: tokens.brand.withOpacity(0.25), width: 0.5),
          ),
          boxShadow: tokens.shadowFloat,
        );
      case UIStyle.glass:
        return const BoxDecoration(color: Colors.white);
    }
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

/// Tab 页顶部导航标题
///
/// 参考首页 [HomeBrandTitle] 的艺术排版，但不带 logo 符号标。
/// 使用 Noto Serif SC 衬线字体 + letter-spacing，与首页品牌标题的中文排版
/// （如画）保持视觉一致，用于挑战/发现/我的等 tab 页的 LumiraNav.leading。
class NavPageTitle extends ConsumerWidget {
  const NavPageTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Text(
      title,
      style: TextStyle(
        fontSize: 20, // 与 HomeBrandTitle 的 Lumira 英文同尺寸
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
        letterSpacing: 0.04 * 20, // 与 HomeBrandTitle 中文 letter-spacing 一致
        height: 1.2,
        fontFamily: 'Noto Serif SC',
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
