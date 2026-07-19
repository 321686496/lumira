import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
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
/// 注：与 uni-app 不同，Flutter 版 ProfilePage **不渲染 FloatingTabBar**。
/// uni-app 中 profile 是 tab 页，但 Flutter 现有架构中 profile 是普通 GoRoute，
/// TabBar 由父级 Shell Route 渲染（Task 2.1 已实现）。本页未在 Shell Route 内，
/// 因此渲染时没有底部 TabBar — 与 HomePage / TemplatesPage / ChallengePage /
/// GalleryPage / InspirationPage 保持一致。
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
      appBar: const LumiraNav(title: '我的', transparent: true),
      body: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
    );
  }
}

/// HeroCard：用户头像 + 名字 + 等级徽章 + 经验进度
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    // 硬编码颜色，与 uni-app 一致
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 32, 24, 24), // 64rpx/48rpx/48rpx → 32/24/24dp
      decoration: BoxDecoration(
        // 硬编码颜色：linear-gradient(145deg, #FFF8EE 0%, #F5EDDB 40%, #EDE3D0 100%)
        gradient: const LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.4, 1),
          colors: [Color(0xFFFFF8EE), Color(0xFFF5EDDB), Color(0xFFEDE3D0)],
          stops: [0.0, 0.4, 1.0],
        ),
        border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.12), width: 1),
        borderRadius: BorderRadius.circular(24), // 48rpx → 24dp
        boxShadow: [
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
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
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
            style: const TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 24, // 48rpx → 24dp
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D2817), // 硬编码颜色，与 uni-app 一致
              letterSpacing: 0.02 * 24,
            ),
          ),
          const SizedBox(height: 10), // 20rpx → 10dp
          // 等级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), // 28rpx/10rpx → 14/5dp
            decoration: BoxDecoration(
              // 硬编码颜色：linear-gradient(135deg, #F5EDDB, #EDE0C8)
              gradient: const LinearGradient(
                colors: [Color(0xFFF5EDDB), Color(0xFFEDE0C8)],
              ),
              borderRadius: BorderRadius.circular(1000),
              border: Border.all(color: const Color(0xFF8C7340).withOpacity(0.15), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.military_tech_outlined, size: 13, color: Color(0xFF8C7340)),
                const SizedBox(width: 4),
                Text(
                  'Lv.${user.level} ${user.levelName}',
                  style: const TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C7340),
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
                    const Text(
                      '经验',
                      style: TextStyle(
                        fontSize: 12, // 24rpx → 12dp
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8C7340),
                      ),
                    ),
                    Text(
                      '${_formatNum(user.currentXp)} / ${_formatNum(user.maxXp)} XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Courier New',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8C7340),
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
                              // 硬编码颜色：linear-gradient(90deg, #C9A96E, #D4B57A)
                              gradient: const LinearGradient(
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
                  '还差 ${_formatNum(user.xpRemaining)} XP 升级至${ProfileMockData.nextLevelName}',
                  style: const TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    color: Color(0xFFB89860),
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

  String _formatNum(int n) {
    // 1,280 / 2,000 格式
    final s = n.toString();
    final buf = <String>[];
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.add(',');
      buf.add(s[s.length - i - 1]);
    }
    return buf.reversed.join();
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
class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: LumiraButton(
            label: '成长中心',
            variant: LumiraButtonVariant.ghost,
            icon: Icons.emoji_events_outlined,
            expand: true,
            onPressed: () => onTap(RouteNames.profileGrowth),
          ),
        ),
        const SizedBox(width: 8), // 16rpx gap → 8dp
        Expanded(
          child: LumiraButton(
            label: '邀请有礼',
            variant: LumiraButtonVariant.ghost,
            icon: Icons.card_giftcard_outlined,
            expand: true,
            onPressed: () => onTap(RouteNames.profileInvite),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LumiraButton(
            label: '摄影美学院',
            variant: LumiraButtonVariant.ghost,
            icon: Icons.menu_book_outlined,
            expand: true,
            onPressed: () => onTap(RouteNames.profileAcademy),
          ),
        ),
      ],
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
              onTap: () => _handleMenuTap(items[i].title, onTap),
            ),
        ],
      ),
    );
  }

  void _handleMenuTap(String title, void Function(String path) onNav) {
    if (title == '我的相册') {
      onNav(RouteNames.gallery);
    } else if (title == '我的模板') {
      onNav(RouteNames.profileMyTemplates);
    } else if (title == '设置') {
      onNav(RouteNames.profileSettings);
    }
    // 场景管理 / 导入模板 / 关于如画 在 uni-app 中无 @click 绑定，仅展示不跳转
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
