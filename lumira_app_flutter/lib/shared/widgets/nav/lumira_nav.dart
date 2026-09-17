import 'dart:math' as math;
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
    this.forceTransparent = false,
    this.showBackButton = true,
    this.useWordmark = false,
    this.horizontalPadding = 24.0,
    this.actionsSpacing = 0,
    this.onBack,
    this.backFallback,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool scrolled;
  final bool transparent;

  /// 强制透明：即使当前 UI 风格是玻璃拟态（glass），也跳过毛玻璃表面与
  /// [BackdropFilter]，直接渲染透明导航。
  ///
  /// 用于照片预览等需要完全沉浸式、不允许任何半透明/模糊遮盖的场景——
  /// 玻璃风格默认的 50% 白 + blur 表面叠在深色照片上会显示为灰色矩形，
  /// 且 iOS 上 BackdropFilter 在大型变换图层的 backdrop 上可能产生右侧缺口伪影。
  final bool forceTransparent;

  /// 默认返回按钮点击时、执行 pop 之前调用的回调。
  /// 用于保留页面原有的副作用逻辑（如刷新上级列表、标记已读等）。
  final VoidCallback? onBack;

  /// 无上级路由可 pop（canPop 为 false）时默认返回按钮的回退动作。
  /// 不传则按钮仅在 canPop 时显示；传入后 deep-link/go 直接进入的页面
  /// 也能显示返回按钮并执行回退（如跳回「我的」）。
  final VoidCallback? backFallback;

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

/// 自适应顶栏布局 ID：leading / middle / trailing
const _kLayoutLeading = 'leading';
const _kLayoutMiddle = 'middle';
const _kLayoutTrailing = 'trailing';

/// 居中标题的真测量布局：
/// - 先测量 leading / trailing（actions），用 max(leading,trailing)+gap 对称预留
/// - 标题按可用宽度约束后仍居中
/// - 取代旧的固定 `horizontalPadding + 72` 方案，根除"标题与右侧按钮重叠"
/// - 标题可用空间过小时由 [_CrampedTitle] 用 LayoutBuilder 自判并淡出
class _CenterToolbarLayout extends MultiChildLayoutDelegate {
  _CenterToolbarLayout({
    required this.barHeight,
  });

  final double barHeight;

  /// leading 与 trailing 之间留出的最小水平间隙（dp）。
  /// 旧行为无间隙，视觉挤；这里固定 8dp 呼吸。
  static const double _sideGap = 8.0;

  @override
  void performLayout(Size size) {
    final hasLeading = hasChild(_kLayoutLeading);
    final hasTrailing = hasChild(_kLayoutTrailing);
    final hasMiddle = hasChild(_kLayoutMiddle);

    // 1) 测量 leading（宽松约束即可）
    final leadingSize = hasLeading
        ? layoutChild(
            _kLayoutLeading,
            BoxConstraints.loose(Size(size.width, barHeight)),
          )
        : Size.zero;

    // 2) 测量 trailing（宽松约束即可）
    final trailingSize = hasTrailing
        ? layoutChild(
            _kLayoutTrailing,
            BoxConstraints.loose(Size(size.width, barHeight)),
          )
        : Size.zero;

    // 3) 计算中间标题的可用宽度（对称预留，保留视觉居中）
    final sideSpace =
        math.max(leadingSize.width, trailingSize.width) + _sideGap;
    final maxMiddleWidth =
        math.max(0.0, size.width - 2 * sideSpace);

    // 4) 测量 middle：maxWidth=可用宽度；shrink-fit（高度由内容决定）
    final middleSize = hasMiddle
        ? layoutChild(
            _kLayoutMiddle,
            BoxConstraints(
              maxWidth: maxMiddleWidth,
              maxHeight: barHeight,
            ),
          )
        : Size.zero;

    // 5) 定位（垂直居中）
    if (hasLeading) {
      positionChild(
        _kLayoutLeading,
        Offset(0, (size.height - leadingSize.height) / 2),
      );
    }
    if (hasTrailing) {
      positionChild(
        _kLayoutTrailing,
        Offset(
          size.width - trailingSize.width,
          (size.height - trailingSize.height) / 2,
        ),
      );
    }
    if (hasMiddle) {
      final midX = (size.width - middleSize.width) / 2;
      positionChild(
        _kLayoutMiddle,
        Offset(midX, (size.height - middleSize.height) / 2),
      );
    }
  }

  @override
  bool shouldRelayout(_CenterToolbarLayout oldDelegate) {
    return oldDelegate.barHeight != barHeight;
  }
}

/// 包装居中标题：用 LayoutBuilder 读取父级约束的 maxWidth，判定是否淡出。
///
/// 判定规则（[requiredWidth] 为标题的固有宽度，null 表示非文本无法测量）：
/// - available >= requiredWidth  → 完整显示
/// - available <  requiredWidth 但 >= [floor] → 省略号截断（仍有信息价值）
/// - available <  min(requiredWidth, floor)   → 淡出（太小，无意义）
///
/// 这样短标题（如"发现"）在窄空间里仍能显示，长标题优先截断而非整块消失，
/// 只有连"照片预览"这种 4 字短标题都塞不下时才让位给 leading/actions。
/// 在约束变化时（右侧动作栏出现/消失、旋转、字号改变）180ms 平滑过渡。
class _CrampedTitle extends StatelessWidget {
  const _CrampedTitle({required this.child, this.requiredWidth});

  final Widget child;

  /// 标题的固有宽度（dp）。null → 退化到 [_LumiraNavState._kMinTitleWidth]。
  final double? requiredWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const floor = _LumiraNavState._kMinTitleWidth;
        final need = requiredWidth == null
            ? floor
            : math.min(requiredWidth!, floor);
        final cramped = constraints.maxWidth < need;
        return IgnorePointer(
          ignoring: cramped,
          child: AnimatedOpacity(
            opacity: cramped ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: child,
          ),
        );
      },
    );
  }
}

class _LumiraNavState extends ConsumerState<LumiraNav> {
  /// 标题的"可读性下限"宽度（dp）。
  /// 可用宽度低于 min(标题固有宽度, 本值) 时才淡出——
  /// 保证至少能显示「照片预览」这类 4 字中文标题（19dp × 4 ≈ 80dp）。
  /// 高于该值一律显示（哪怕需要省略号截断），避免长标题整块消失。
  static const double _kMinTitleWidth = 80.0;

  /// 用 TextPainter 同步测量文本标题的固有宽度（dp）。
  /// 仅用于 [_CrampedTitle] 的淡出判定，不参与布局，开销可忽略。
  double _measureTitleWidth(String title, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
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

  /// 右侧 actions 行：单按钮直接返回，多个时用 Row 按间距排列。
  /// LayoutId(id: trailing) 由 [_buildCenterToolbar] 统一包裹，此处不可重复包裹——
  /// 嵌套在 Padding 内的 LayoutId 会触发 ParentData 冲突断言（debug 崩溃）。
  Widget _actionsRow() {
    final list = _actionsList();
    return list.length == 1
        ? list.first
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: list,
          );
  }

  /// 居中标题的自适应顶栏：真测量 leading / actions 宽度后对称预留，
  /// 避免重叠；当可用宽度小于 [_kMinTitleWidth] 时淡出标题，让位给 actions。
  Widget _buildCenterToolbar({
    required Widget leadingWidget,
    required Widget? centerWidget,
    required Widget actionsRow,
    double? titleRequiredWidth,
  }) {
    final delegate = _CenterToolbarLayout(barHeight: 48);

    return CustomMultiChildLayout(
      delegate: delegate,
      children: [
        // 用 Padding 把 horizontalPadding 应用到 leading 与 trailing，
        // 保持与旧实现一致的左右内边距（详情页 12dp、tab 页 24dp）
        LayoutId(
          id: _kLayoutLeading,
          child: Padding(
            padding: EdgeInsets.only(left: widget.horizontalPadding),
            child: leadingWidget,
          ),
        ),
        if (centerWidget != null)
          LayoutId(
            id: _kLayoutMiddle,
            child: _CrampedTitle(
              requiredWidth: titleRequiredWidth,
              child: centerWidget,
            ),
          ),
        LayoutId(
          id: _kLayoutTrailing,
          child: Padding(
            padding: EdgeInsets.only(right: widget.horizontalPadding),
            child: actionsRow,
          ),
        ),
      ],
    );
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
    if (widget.forceTransparent) {
      // 强制透明（照片预览等沉浸式场景）：跳过玻璃毛玻璃表面，
      // 与未滚动 transparent 分支一致，用 canvas 自身 alpha=0 保持色相一致的透明。
      targetSigma = 0.0;
      decoration = BoxDecoration(
        color: tokens.canvas.withOpacity(0),
      );
    } else if (isGlass) {
      // 玻璃拟态：始终半透明毛玻璃（blur 恒定，不随 scrolled 动画），滚动时加深填充；
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
    // - 否则如果 showBackButton=true 且（canPop=true 或提供了 backFallback），
    //   显示默认圆形返回按钮（onBack 在 pop 前执行，backFallback 兜底无上级路由场景）
    // - 否则用 SizedBox.shrink()（不再占位 40dp，避免 tab 页左侧死区与右侧不对称）
    // Tab 页传 showBackButton=false，避免 canPop 误判导致 tab 页显示返回按钮
    final bool canPop = Navigator.of(context).canPop();
    final Widget leadingWidget = widget.leading ??
        (widget.showBackButton && (canPop || widget.backFallback != null)
            ? _NavBackButton(
                onBack: widget.onBack,
                backFallback: widget.backFallback,
              )
            : const SizedBox.shrink());

    // Logo 升级：计算居中标题内容
    // - useWordmark=true → 品牌 SVG 文字标
    // - 否则若有 title → 纯文本标题
    final titleStyle = TextStyle(
      fontSize: 19, // 38rpx → 19dp
      fontWeight: FontWeight.w600,
      color: tokens.textPrimary,
      letterSpacing: 0.04 * 19,
      height: 1.3,
    );
    final Widget? centerWidget = widget.useWordmark
        ? const LumiraLogo.wordmark(
            height: 22, // 略大于原 19dp 文本，承载 SVG 描边
            semanticsLabel: '如画文字标',
          )
        : (widget.title != null
            ? Text(
                widget.title!,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    // 文本标题的固有宽度（用于淡出判定；SVG 文字标无法同步测量 → null）
    final double? titleRequiredWidth =
        (!widget.useWordmark && widget.title != null)
            ? _measureTitleWidth(widget.title!, titleStyle)
            : null;

    // 性能(Forced fix): BackdropFilter 会令引擎把其背后的滚动内容单独成层，
    // 并在滚动时每帧重新捕获/合成该条区域——这是四个 Tab 页在 OHOS 上滚动掉帧的
    // 共性成本之一（sigma=0 无可见模糊，却依然承担 backdrop 分层开销）。
    // 因此仅在玻璃风格（sigma 恒为 28，真正需要模糊）时包裹 BackdropFilter；
    // 其余风格 sigma 恒为 0，直接渲染静态表面，视觉与原实现完全一致。
    final Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48, // min-height 96rpx → 48dp
          child: widget.centerTitle
              ? _buildCenterToolbar(
                  centerWidget: centerWidget,
                  leadingWidget: leadingWidget,
                  actionsRow: _actionsRow(),
                  titleRequiredWidth: titleRequiredWidth,
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
    );

    // 玻璃风格：恒定毛玻璃（sigma=28），其余风格跳过。
    // Forced fix: 之前的实现把 blur 的 sigma 绑定在 _sigmaCurve（随 scrolled 滚动动画
    // 从 0→28）上——摄影美学院这类「透明 + 不传 scrolled」的页面 sigma 恒为 0，
    // 玻璃没有模糊，内容滑到导航栏下被一层 50% 白糊住、透不过来。
    // 现在 blur 与 scrolled 彻底解耦：任何时候内容滑动到导航栏下方都实时透出模糊，
    // scrolled 只负责加深填充不透明度（0.50→0.68，由 AnimatedContainer 平滑过渡）。
    // 玻璃风格：恒定毛玻璃（sigma=28），其余风格跳过。
    // forceTransparent 时即使 glass 也跳过 BackdropFilter（沉浸式透明）。
    if (!isGlass || widget.forceTransparent) return surface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: targetSigma, sigmaY: targetSigma),
        child: surface,
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
  const _NavBackButton({this.onBack, this.backFallback});

  /// pop 前执行的回调（保留页面副作用逻辑）。
  final VoidCallback? onBack;

  /// 无上级路由可 pop 时的回退动作。
  final VoidCallback? backFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return GestureDetector(
      onTap: () {
        onBack?.call();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        } else {
          backFallback?.call();
        }
      },
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
