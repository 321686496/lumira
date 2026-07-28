import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../../templates/widgets/template_import_sheet.dart';
import '../data/profile_mock_data.dart';

/// 个人中心主页
///
/// 视觉规格来源：lumira-app/src/pages/profile/index.vue（184 行）
/// 5 个 section：
/// 1. HeroCard（用户信息 + 经验进度）
/// 2. StatsCard（3 列 Bento：作品 / 模板 / 收藏）
/// 3. FragmentCard（4 项碎片收集）
/// 4. QuickActionsRow（3 个 ghost 按钮：成长中心 / 邀请有礼 / 摄影美学院）
/// 5. MenuCard（6 项菜单列表）
///
/// Forced fix: 之前注释说"Flutter 版 ProfilePage 不渲染 FloatingTabBar"是错的。
/// 与 HomePage / TemplatesPage / ChallengePage 一致，profile 作为 tab 页必须渲染 FloatingTabBar。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _goPage(BuildContext context, String path) {
    GoRouter.of(context).push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '我的',
        centerTitle: false,
        transparent: true,
        showBackButton: false,
        horizontalPadding: 24,
      ),
      body: Stack(
        children: [
          // Forced fix: glass 风格彩色斑点背景
          const Positioned.fill(child: GlassBackground(variant: GlassBackgroundVariant.profile)),
          // 主内容层
          Container(
            // 径向渐变背景装饰（glass 风格可见性）
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HeroCard
                    const FadeUp(child: _HeroCard(user: ProfileMockData.userProfile)),
                    const SizedBox(height: 20),
                    // 2. StatsCard
                    const FadeUp(
                      delay: Duration(milliseconds: 100),
                      child: _StatsCard(user: ProfileMockData.userProfile),
                    ),
                    const SizedBox(height: 20),
                    // 3. FragmentCard
                    const FadeUp(
                      delay: Duration(milliseconds: 200),
                      child: _FragmentCard(fragments: ProfileMockData.fragments),
                    ),
                    const SizedBox(height: 20),
                    // 4. QuickActionsRow
                    FadeUp(
                      delay: const Duration(milliseconds: 300),
                      child: _QuickActionsRow(onTap: (p) => _goPage(context, p)),
                    ),
                    const SizedBox(height: 20),
                    // 5. MenuCard
                    FadeUp(
                      delay: const Duration(milliseconds: 400),
                      child: _MenuCard(onTap: (p) => _goPage(context, p)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          // FloatingTabBar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(active: 'profile'),
          ),
        ],
      ),
    );
  }
}

/// HeroCard：用户头像 + 名字 + 等级徽章 + 经验进度
class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    // 硬编码颜色，与 uni-app 一致
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 24, 24), // 64rpx/48rpx/48rpx → 32/24/24dp
      decoration: BoxDecoration(
        // neumorphic 风格：移除渐变 / 边框，使用 tokens.surface + 双向凸起阴影
        color: isNeu ? tokens.surface : null,
        // 硬编码颜色：linear-gradient(145deg, #FFF8EE 0%, #F5EDDB 40%, #EDE3D0 100%)
        gradient: isNeu
            ? null
            : const LinearGradient(
                begin: Alignment(-0.4, -1),
                end: Alignment(0.4, 1),
                colors: [Color(0xFFFFF8EE), Color(0xFFF5EDDB), Color(0xFFEDE3D0)],
                stops: [0.0, 0.4, 1.0],
              ),
        border: isNeu ? null : Border.all(color: const Color(0xFFC9A96E).withOpacity(0.12), width: 1),
        borderRadius: BorderRadius.circular(isNeu ? 16 : 24), // 48rpx → 24dp；neumorphic 用 16
        boxShadow: isNeu
            ? tokens.shadowConvex
            : [
                BoxShadow(
                  color: const Color(0xFFC9A96E).withOpacity(0.08),
                  offset: const Offset(0, 4),
                  blurRadius: 24,
                ),
              ],
      ),
      child: Column(
        children: [
          // 头像 + 徽章
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88, // 176rpx → 88dp
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // neumorphic 风格：移除白边框，使用 tokens.shadowConvexSubtle
                  border: isNeu ? null : Border.all(color: Colors.white, width: 3),
                  boxShadow: isNeu
                      ? tokens.shadowConvexSubtle
                      : [
                          BoxShadow(
                            color: const Color(0xFFC9A96E).withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://picsum.photos/seed/${user.avatarSeed}/200/200',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22, // 44rpx → 22dp
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 硬编码颜色：linear-gradient(135deg, #C9A96E, #A88550)
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // 名字
          Text(
            user.name,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 24, // 48rpx → 24dp
              fontWeight: FontWeight.w600,
              // neumorphic 风格：tokens.textPrimary
              color: isNeu ? tokens.textPrimary : const Color(0xFF3D2817),
              letterSpacing: 0.02 * 24,
            ),
          ),
          const SizedBox(height: 10), // 20rpx → 10dp
          // 等级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), // 28rpx/10rpx → 14/5dp
            decoration: BoxDecoration(
              // neumorphic 风格：tokens.brandSubtle 纯色 + 凸起阴影
              color: isNeu ? tokens.brandSubtle : null,
              // 硬编码颜色：linear-gradient(135deg, #F5EDDB, #EDE0C8)
              gradient: isNeu
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFF5EDDB), Color(0xFFEDE0C8)],
                    ),
              borderRadius: BorderRadius.circular(1000),
              border: isNeu ? null : Border.all(color: const Color(0xFF8C7340).withOpacity(0.15), width: 1),
              boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  size: 13,
                  // neumorphic 风格：tokens.brandText
                  color: isNeu ? tokens.brandText : const Color(0xFF8C7340),
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv.${user.level} ${user.levelName}',
                  style: TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    fontWeight: FontWeight.w600,
                    // neumorphic 风格：tokens.brandText
                    color: isNeu ? tokens.brandText : const Color(0xFF8C7340),
                    letterSpacing: 0.04 * 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20), // 40rpx → 20dp
          // 经验进度
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260), // 520rpx → 260dp
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '经验',
                      style: TextStyle(
                        fontSize: 12, // 24rpx → 12dp
                        fontWeight: FontWeight.w500,
                        // neumorphic 风格：tokens.textSecondary
                        color: isNeu ? tokens.textSecondary : const Color(0xFF8C7340),
                      ),
                    ),
                    Text(
                      '${formatThousands(user.currentXp)} / ${formatThousands(user.maxXp)} XP',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier New',
                        fontWeight: FontWeight.w600,
                        // neumorphic 风格：tokens.textSecondary
                        color: isNeu ? tokens.textSecondary : const Color(0xFF8C7340),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // 16rpx → 8dp
                ClipRRect(
                  borderRadius: BorderRadius.circular(3), // 6rpx → 3dp
                  child: SizedBox(
                    height: 6, // 12rpx → 6dp
                    child: Stack(
                      children: [
                        Container(
                          color: const Color(0xFFC9A96E).withOpacity(0.18),
                        ),
                        FractionallySizedBox(
                          widthFactor: user.xpPercent / 100.0,
                          child: Container(
                            decoration: BoxDecoration(
                              // neumorphic 风格：tokens.brand 纯色填充
                              color: isNeu ? tokens.brand : null,
                              // 硬编码颜色：linear-gradient(90deg, #C9A96E, #D4B57A)
                              gradient: isNeu
                                  ? null
                                  : const LinearGradient(
                                      colors: [Color(0xFFC9A96E), Color(0xFFD4B57A)],
                                    ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '还差 ${formatThousands(user.xpRemaining)} XP 升级至${ProfileMockData.nextLevelName}',
                  style: TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    // neumorphic 风格：tokens.textSecondary
                    color: isNeu ? tokens.textSecondary : const Color(0xFFB89860),
                    letterSpacing: 0.02 * 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// StatsCard：3 列等宽 Bento（作品 / 模板 / 收藏）
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return NeuCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(child: _StatsCell(num: user.photosCount, label: '拍摄作品', tokens: tokens, divider: true)),
          Expanded(child: _StatsCell(num: user.templatesCount, label: '使用模板', tokens: tokens, divider: true)),
          Expanded(child: _StatsCell(num: user.collectionsCount, label: '收藏', tokens: tokens, divider: false)),
        ],
      ),
    );
  }
}

class _StatsCell extends StatelessWidget {
  const _StatsCell({
    required this.num,
    required this.label,
    required this.tokens,
    required this.divider,
  });
  final int num;
  final String label;
  final ThemeTokens tokens;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8), // 44rpx/16rpx → 22/8dp
      decoration: divider
          ? BoxDecoration(
              border: Border(
                right: BorderSide(color: tokens.divider, width: 1),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$num',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 26, // 52rpx → 26dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            label,
            style: TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: tokens.textTertiary,
              letterSpacing: 0.04 * 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// FragmentCard：4 项碎片收集
class _FragmentCard extends ConsumerWidget {
  const _FragmentCard({required this.fragments});
  final List<FragmentItem> fragments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    final collected = fragments.fold<int>(0, (s, f) => s + f.current);
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.extension, size: 18, color: tokens.brand),
              const SizedBox(width: 6), // 12rpx → 6dp
              Text(
                '碎片收集',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17, // 32rpx → 16dp，视觉接近用 17
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$collected/20 已集',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => GoRouter.of(context).push(RouteNames.profileFragmentDetail),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '查看全部 ›',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tokens.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // 4 项碎片
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: fragments.map((f) => _FragmentRow(item: f)).toList(),
          ),
        ],
      ),
    );
  }
}

class _FragmentRow extends ConsumerWidget {
  const _FragmentRow({required this.item});
  final FragmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16), // 32rpx gap → 16dp
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28, // 56rpx → 28dp
                height: 28,
                decoration: BoxDecoration(
                  color: tokens.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
                ),
                child: Icon(item.icon, size: 14, color: tokens.brand),
              ),
              const SizedBox(width: 8), // 16rpx → 8dp
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13, // 26rpx → 13dp
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              Text(
                '${item.current}/${item.max}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Courier New',
                fontWeight: FontWeight.w600,
                color: tokens.textTertiary,
              ),
              ),
            ],
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6, // 12rpx → 6dp
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: item.percent / 100.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// QuickActionsRow：3 个 ghost 按钮（成长中心 / 邀请有礼 / 摄影美学院）
///
/// Forced fix: 3 个 ghost LumiraButton 横向 Row 在窄屏（360dp）溢出。
/// ghost button padding horizontal:16 + icon 18 + gap 8 + 5 字文字 = ~107dp，
/// 3 个 + 2 个 8dp 间距 = 321dp+，但每列 Expanded 只有 ~98dp。
/// 改为自定义垂直 Column 布局（icon 上 + text 下），每按钮宽度 ~50dp 足够。
class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final items = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.emoji_events_outlined,
        label: '成长中心',
        onTap: () => onTap(RouteNames.profileGrowth),
      ),
      _QuickActionItem(
        icon: Icons.layers_outlined,
        label: '我的组合',
        onTap: () => onTap(RouteNames.profileCompositionKits),
      ),
      _QuickActionItem(
        icon: Icons.card_giftcard_outlined,
        label: '邀请有礼',
        onTap: () => onTap(RouteNames.profileInvite),
      ),
      _QuickActionItem(
        icon: Icons.menu_book_outlined,
        label: '摄影美学院',
        onTap: () => onTap(RouteNames.profileAcademy),
      ),
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final isLast = entry.key == items.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: _QuickActionCard(item: item, tokens: tokens, appTheme: appTheme),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.item,
    required this.tokens,
    required this.appTheme,
  });
  final _QuickActionItem item;
  final ThemeTokens tokens;
  final AppThemeData appTheme;

  @override
  Widget build(BuildContext context) {
    // Forced fix: 使用垂直布局避免横向溢出。
    // 同时按当前 UI 风格渲染，让风格切换效果可见。
    final isGlass = appTheme.style == UIStyle.glass;
    final isFemale = appTheme.style == UIStyle.female;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.brand.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 16, color: tokens.brand),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    if (isGlass) {
      return GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.70),
                    Colors.white.withOpacity(0.45),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 0.6,
                ),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    if (isFemale) {
      return GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.brandSubtle.withOpacity(0.80),
                tokens.surface.withOpacity(0.65),
                tokens.brandLight.withOpacity(0.50),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.15),
                offset: const Offset(0, 6),
                blurRadius: 20,
              ),
            ],
          ),
          child: content,
        ),
      );
    }

    // neumorphic / flat：用 NeuCard 风格
    final isNeu = appTheme.style == UIStyle.neumorphic;
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isNeu ? tokens.surface : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(isNeu ? 14 : 10),
          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
          border: isNeu ? null : Border.all(color: tokens.divider, width: 1),
        ),
        child: content,
      ),
    );
  }
}

/// MenuCard：6 项菜单列表
class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    const items = <_MenuItem>[
      _MenuItem(icon: Icons.image_outlined, title: '我的相册'),
      _MenuItem(icon: Icons.layers_outlined, title: '我的模板'),
      _MenuItem(icon: Icons.map_outlined, title: '场景管理'),
      _MenuItem(icon: Icons.download_outlined, title: '导入模板'),
      _MenuItem(icon: Icons.card_giftcard_outlined, title: '我的奖励'),
      _MenuItem(icon: Icons.redeem_outlined, title: '兑换码'),
      _MenuItem(icon: Icons.settings_outlined, title: '设置'),
      _MenuItem(icon: Icons.info_outline, title: '关于如画'),
    ];

    // 路由跳转在 _MenuItemRow.onTap 中根据 title 触发，避免 lambda 无法 const 化
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 32rpx/16rpx → 16/8dp
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _MenuItemRow(
              item: items[i],
              isLast: i == items.length - 1,
              tokens: tokens,
              onTap: () => _handleMenuTap(context, items[i].title, onTap),
            ),
        ],
      ),
    );
  }

  void _handleMenuTap(
    BuildContext context,
    String title,
    void Function(String path) onNav,
  ) {
    // Forced fix: 之前只处理 3 项菜单（我的相册/我的模板/设置），其余 3 项无响应。
    // 补齐：场景管理/导入模板/关于如画跳对应页。
    if (title == '我的相册') {
      onNav(RouteNames.gallery);
    } else if (title == '我的模板') {
      onNav(RouteNames.profileMyTemplates);
    } else if (title == '场景管理') {
      onNav(RouteNames.captureSceneManage);
    } else if (title == '导入模板') {
      TemplateImportSheet.show(
        context,
        onImported: (_) => onNav(RouteNames.profileMyTemplates),
      );
    } else if (title == '我的奖励') {
      onNav(RouteNames.profileRewards);
    } else if (title == '兑换码') {
      onNav(RouteNames.profileRedeem);
    } else if (title == '设置') {
      onNav(RouteNames.profileSettings);
    } else if (title == '关于如画') {
      onNav(RouteNames.profileAbout);
    }
  }
}

class _MenuItem {
  const _MenuItem({required this.icon, required this.title});
  final IconData icon;
  final String title;
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.isLast,
    required this.tokens,
    required this.onTap,
  });
  final _MenuItem item;
  final bool isLast;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16), // 32rpx → 16dp
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.divider, width: 1),
                ),
              ),
        child: Row(
          children: [
            Container(
              width: 40, // 80rpx → 40dp
              height: 40,
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
              ),
              child: Icon(item.icon, size: 20, color: tokens.brand),
            ),
            const SizedBox(width: 12), // 24rpx → 12dp
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15, // 30rpx → 15dp
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}
