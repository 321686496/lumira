import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/preferences/home_wordmark_style.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/brand/home_brand_title.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/home_nav_action.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 首页标题样式选择页
///
/// 视觉规格来源：lumira-app/src/pages/profile/settings.vue（首页标题样式的独立成页）
///
/// ## 预览如何保证「与首页一致」
///
/// 这一版不再手绘一个假的导航栏，而是**直接复用首页的真实组件**：
/// - `LumiraNav`（与首页同一个组件、同样的 `horizontalPadding: 24`）
/// - `HomeNavAction`（与首页同一个按钮组件，三个入口：扫码 / 通知 / 奖励）
/// - 导航栏下方接首页 body 的第一个 section（搜索胶囊）
///
/// 这样首页改了导航栏，预览自动跟着改，不会再出现「预览里少一个图标 /
/// 颜色对不上」这类漂移。首页的 `_NavAction` 正是为此提取成了公共组件
/// `shared/widgets/nav/home_nav_action.dart`。
///
/// 唯一需要处理的坑：`LumiraNav` 内部自带 `SafeArea(bottom: false)`，
/// 放在页面 body（已在 SafeArea 内）会再叠一层状态栏高度。用
/// `MediaQuery.removePadding(removeTop: true)` 把顶部 padding 归零即可。
class ProfileSettingsWordmarkPage extends ConsumerStatefulWidget {
  const ProfileSettingsWordmarkPage({super.key});

  @override
  ConsumerState<ProfileSettingsWordmarkPage> createState() =>
      _ProfileSettingsWordmarkPageState();
}

class _ProfileSettingsWordmarkPageState
    extends ConsumerState<ProfileSettingsWordmarkPage> {
  void _select(HomeWordmarkStyle style) {
    if (ref.read(homeWordmarkStyleProvider) == style) return;
    ref.read(homeWordmarkStyleProvider.notifier).state = style;
    LumiraToast.show(
      context,
      '已切换至${HomeWordmarkLabels.labelOf(style)}',
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final current = ref.watch(homeWordmarkStyleProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '首页标题样式',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // —— 1. 大预览舞台：真实导航栏 + 搜索胶囊
                _StagePreview(style: current, tokens: tokens),
                const SizedBox(height: 20),
                // —— 2. 候选样式卡片（预览在上、信息在下，便于纵向对比）
                _SectionTitle(text: '选择样式', tokens: tokens),
                const SizedBox(height: 8),
                for (final style in HomeWordmarkLabels.order)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WordmarkCard(
                      style: style,
                      selected: style == current,
                      tokens: tokens,
                      onTap: () => _select(style),
                    ),
                  ),
                const SizedBox(height: 4),
                _BottomNote(tokens: tokens),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileSettings);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textTertiary,
          letterSpacing: 0.04 * 13,
        ),
      ),
    );
  }
}

/// 大预览舞台：还原首页顶部（导航栏 + 搜索胶囊）
class _StagePreview extends StatelessWidget {
  const _StagePreview({required this.style, required this.tokens});

  final HomeWordmarkStyle style;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                '预期效果',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                  letterSpacing: 0.04 * 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 首页顶部：导航栏 + 搜索胶囊（首页 body 的第一个 section）
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: tokens.canvas,
              child: Column(
                children: [
                  _NavPreview(
                    style: style,
                    tokens: tokens,
                    horizontalPadding: 24,
                    iconSize: 20,
                  ),
                  _SearchCapsulePreview(tokens: tokens),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '以上为首页顶部的实际比例，右侧依次为扫码、通知与奖励入口。',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页导航栏预览（真实 LumiraNav + HomeNavAction）
///
/// [horizontalPadding] / [iconSize] 在大舞台传首页原值（24 / 20）；
/// 卡片内略收（20 / 16）以适配窄屏，但排布方式（左标题、右三个入口）
/// 与首页完全相同，所以「是不是首页那个样子」这件事是同源保证的。
class _NavPreview extends StatelessWidget {
  const _NavPreview({
    required this.style,
    required this.tokens,
    required this.horizontalPadding,
    required this.iconSize,
  });

  final HomeWordmarkStyle style;
  final ThemeTokens tokens;
  final double horizontalPadding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      // LumiraNav 内部有 SafeArea(bottom: false)，这里已在外层 SafeArea 内，
      // 不清零顶部 padding 会多出一条状态栏高度的空白。
      context: context,
      removeTop: true,
      child: LumiraNav(
        centerTitle: false,
        transparent: true,
        showBackButton: false,
        horizontalPadding: horizontalPadding,
        leading: HomeBrandTitle(styleOverride: style),
        actions: [
          HomeNavAction(
            icon: Icons.qr_code_scanner,
            tokens: tokens,
            iconSize: iconSize,
          ),
          HomeNavAction(
            icon: Icons.notifications_outlined,
            tokens: tokens,
            iconSize: iconSize,
          ),
          HomeNavAction(
            icon: Icons.card_giftcard_outlined,
            tokens: tokens,
            iconSize: iconSize,
          ),
        ],
      ),
    );
  }
}

/// 搜索胶囊预览（首页 body 的第一个 section）
///
/// 按 `home/widgets/search_capsule.dart` 的规格静态复刻：40dp 高、20 圆角、
/// surface 底 + divider 描边、18dp 搜索图标 + 13sp 占位文案。
/// 不直接引用真实 SearchCapsule，是因为它耦合了 `context.push` 跳转，
/// 在预览里点击会误跳到搜索页。
class _SearchCapsulePreview extends StatelessWidget {
  const _SearchCapsulePreview({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索模板 / 场景 / 拍摄教程',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个候选项卡片
///
/// 排版顺序：**预览在上、信息在下**。
/// 这样三张卡片的预览条左端对齐、高度一致，用户上下扫一眼就能比较出
/// 「有没有符号标」「中英文层次」的差异，而不会被文字信息打断。
class _WordmarkCard extends StatelessWidget {
  const _WordmarkCard({
    required this.style,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final HomeWordmarkStyle style;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _StyleAwareSelectableCard(
        selected: selected,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // —— 预览条：与首页同源的导航栏（缩小 padding 与图标以适配卡片）
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: tokens.canvas,
                child: _NavPreview(
                  style: style,
                  tokens: tokens,
                  // 卡片内比首页的 24 略收（20），图标 16dp：
                  // 320dp 窄屏上 24+20dp 图标会顶到边缘，收一点留安全余量。
                  horizontalPadding: 20,
                  iconSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // —— 信息区：单选圈 + 名称（+ 当前标记）+ 说明
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? tokens.brand : tokens.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              HomeWordmarkLabels.labelOf(style),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? tokens.brand
                                    : tokens.textPrimary,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            _CurrentTag(tokens: tokens),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        HomeWordmarkLabels.descriptionOf(style),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 随 UI 风格变化的「可选中」卡片表面
///
/// 之前卡片是自己写死的 `Container(color: tokens.surface)` + divider 描边，
/// **只在新拟态下是对的**，切到 flat / glass / female 会变成一张不属于该风格的白卡片。
///
/// 这里改用项目统一的风格解析入口 `LumiraThemeResolver.cardVisual`
/// （`LumiraSurface` 内部也是用它）拿到背景 / 描边 / 阴影 / 玻璃渐变叠加，
/// 在此基础上叠加选中态：
/// - 通用：品牌色 1.5dp 描边 + brandSubtle 淡染
/// - 新拟态额外：选中转内凹阴影 `shadowConcaveSubtle`（与主题页 _StyleCard
///   用 RecessedSurface 表达「按下去了」是同一个语义）
///
/// 注意选中底色是作为 **Stack 的底层** 叠在内容下面，不能盖在内容上。
class _StyleAwareSelectableCard extends ConsumerWidget {
  const _StyleAwareSelectableCard({
    required this.selected,
    required this.padding,
    required this.child,
  });

  final bool selected;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    // 圆角也跟随风格（与 NeuCard 一致：app_theme.cardRadius 存 rpx 原值，/2 得 dp）：
    // neumorphic 14 / flat 10 / glass 14 / female 24
    final double radius = appTheme.cardRadius / 2;

    final visual = LumiraThemeResolver.cardVisual(
      tokens: tokens,
      style: style,
      radiusDp: radius,
      emphasize: selected,
    );

    // 新拟态：未选中凸起、选中内凹（按压语义）
    final List<BoxShadow> shadows =
        (style == UIStyle.neumorphic && selected)
            ? tokens.shadowConcaveSubtle
            : visual.shadows;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(radius),
        border: selected
            ? Border.all(color: tokens.brand, width: 1.5)
            : visual.border,
        boxShadow: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 风格自带的渐变叠加层（glass / female）
          if (visual.glassOverlay != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: visual.glassOverlay!),
                ),
              ),
            ),
          // 选中淡染（必须在内容之下）
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.brandSubtle.withOpacity(0.22),
                  ),
                ),
              ),
            ),
          // 内容
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// 「当前」小标签
class _CurrentTag extends StatelessWidget {
  const _CurrentTag({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brand.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '当前',
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: tokens.brand,
        ),
      ),
    );
  }
}

class _BottomNote extends StatelessWidget {
  const _BottomNote({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '标题样式切换后首页立即生效',
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
