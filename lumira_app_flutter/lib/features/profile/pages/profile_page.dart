import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../templates/widgets/template_import_sheet.dart';
import '../data/builtin_profiles.dart';
import '../data/profile_models.dart';
import '../data/profile_mock_data.dart';
import '../providers/fragments_providers.dart';
import '../providers/growth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/pref_selector.dart';

/// 个人中心主页
///
/// 视觉规格来源：lumira-app/src/pages/profile/index.vue（184 行）
/// 6 个 section：
/// 1. HeroCard（用户信息 + 经验进度）
/// 2. StatsCard（3 列 Bento：作品 / 模板 / 收藏）
/// 3. ContentCard（我的内容：相册 / 拍摄日记 / 探店足迹 / 精选集）
/// 4. FragmentCard（4 项碎片收集）
/// 5. QuickActionsRow（3 个 ghost 按钮：成长中心 / 邀请有礼 / 摄影美学院）
/// 6. MenuCard（8 项菜单列表）
///
/// Forced fix: 之前注释说"Flutter 版 ProfilePage 不渲染 FloatingTabBar"是错的。
/// 与 HomePage / TemplatesPage / ChallengePage 一致，profile 作为 tab 页必须渲染 FloatingTabBar。
///
/// Forced fix: 改为 ConsumerStatefulWidget，添加 ScrollController + _scrolled 状态，
/// 传 scrolled: _scrolled 给 LumiraNav（之前永远透明，未联动滚动）。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  static const double _scrollThreshold = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > _scrollThreshold;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  void _goPage(String path) {
    GoRouter.of(context).push(path);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        leading: const NavPageTitle(title: '我的'),
        centerTitle: false,
        transparent: true,
        scrolled: _scrolled,
        showBackButton: false,
        horizontalPadding: 24,
        actions: [
          LumiraNavButton(
            icon: Icons.settings_outlined,
            onPressed: () => _goPage(RouteNames.profileSettings),
          ),
        ],
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
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                controller: _scrollController,
                // Forced fix: extendBodyBehindAppBar=true 时 body 从 y=0 开始，
                // 用 viewPadding.top（不被 widget 消费）+ nav 内容高度 48dp 精确占位
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).viewPadding.top + 48 + 12,
                  24,
                  100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 头部信息条（头像+名字+等级/偏好签名+数据区）
                    FadeUp(
                      child: _ProfileHeader(onEdit: (p) => _goPage(p)),
                    ),
                    const SizedBox(height: 20),
                    // 2. ContentCard（我的内容宫格）
                    const FadeUp(
                      delay: Duration(milliseconds: 100),
                      child: _ContentCard(),
                    ),
                    const SizedBox(height: 20),
                    // 3. FragmentCard
                    const FadeUp(
                      delay: Duration(milliseconds: 200),
                      child: _FragmentCard(),
                    ),
                    const SizedBox(height: 20),
                    // 4. QuickActionsRow（2×2 工具宫格）
                    FadeUp(
                      delay: const Duration(milliseconds: 300),
                      child: _QuickActionsRow(onTap: (p) => _goPage(p)),
                    ),
                    const SizedBox(height: 20),
                    // 5. MenuCard（常用功能列表）
                    FadeUp(
                      delay: const Duration(milliseconds: 400),
                      child: _MenuCard(onTap: (p) => _goPage(p)),
                    ),
                    // 6. FeedbackEntryCard
                    const SizedBox(height: 20),
                    _FeedbackEntryCard(
                      onTap: () => _goPage(RouteNames.feedback),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 头部信息条：左对齐头像 + 名字 + 等级徽章 + 偏好签名 + 底部数据区
/// 替代原居中 HeroCard + 独立 StatsCard + 偏好卡；偏好未填时显示引导链接
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.onEdit});
  final void Function(String path) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    final user = ref.watch(userProfileProvider).valueOrNull ?? ProfileMockData.userProfile;
    // 名称/头像改用真实资料；profile 为 null（未分配本地资料）时回退 mock
    final profile = ref.watch(profileDataProvider).valueOrNull;
    final displayName = (profile != null && profile.username.isNotEmpty)
        ? profile.username
        : user.name;
    final avatarUrl = BuiltinProfiles.avatarUrl(
      profile?.avatarSeed ?? user.avatarSeed,
      customUrl: profile?.avatarUrl,
    );

    return NeuCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 头像（点击看大图）+ 编辑角标
                GestureDetector(
                  onTap: () => _showAvatarFullScreen(context, avatarUrl, tokens),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          url: avatarUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          backgroundColor: tokens.surfaceAlt,
                          // 头像未加载出来/加载失败时显示占位（人形剪影）
                          placeholder: _AvatarPlaceholder(size: 64, tokens: tokens),
                          errorWidget: _AvatarPlaceholder(size: 64, tokens: tokens),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => onEdit(RouteNames.profileEdit),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // 硬编码颜色：金色编辑角标
                              gradient: const LinearGradient(
                                colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                              ),
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.edit, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 名字 + 等级徽章 + 偏好签名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Noto Serif SC',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                // neumorphic 风格：tokens.textPrimary
                                color: isNeu ? tokens.textPrimary : const Color(0xFF3D2817),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 紧凑等级徽章
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isNeu ? tokens.brandSubtle : null,
                              gradient: isNeu
                                  ? null
                                  : const LinearGradient(
                                      colors: [Color(0xFFF5EDDB), Color(0xFFEDE0C8)],
                                    ),
                              borderRadius: BorderRadius.circular(1000),
                              border: isNeu
                                  ? null
                                  : Border.all(color: const Color(0xFF8C7340).withOpacity(0.15), width: 1),
                              boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.military_tech_outlined,
                                  size: 12,
                                  color: isNeu ? tokens.brandText : const Color(0xFF8C7340),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Lv.${user.level}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isNeu ? tokens.brandText : const Color(0xFF8C7340),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 偏好签名 / 未填引导
                      _PrefsSubline(
                        profile: profile,
                        onEdit: () => onEdit(RouteNames.profileEdit),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 数据区
          Divider(height: 1, thickness: 1, color: tokens.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: _HeaderStatCell(num: user.photosCount, label: '作品', divider: true, tokens: tokens)),
                Expanded(child: _HeaderStatCell(num: user.templatesCount, label: '模板', divider: true, tokens: tokens)),
                Expanded(child: _HeaderStatCell(num: user.collectionsCount, label: '收藏', divider: false, tokens: tokens)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 头像大图预览：全屏对话框 + 支持手势缩放平移
  void _showAvatarFullScreen(BuildContext context, String url, ThemeTokens tokens) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: PhotoView(
            imageProvider: NetworkImage(url),
            tightMode: true,
            minScale: PhotoViewComputedScale.contained,
            maxScale: 4.0,
            backgroundDecoration:
                const BoxDecoration(color: Colors.transparent),
            loadingBuilder: (_, __) =>
                _AvatarPlaceholder(size: 240, tokens: tokens),
            errorBuilder: (_, __, ___) =>
                _AvatarPlaceholder(size: 240, tokens: tokens),
          ),
        ),
      ),
    );
  }
}

/// 头像占位组件：头像 URL 为空 / 加载中 / 加载失败时显示的人形剪影。
/// 底色取当前主题 surfaceAlt，图标为主品牌色，随设置里的 UI 风格 & 主题联动。
class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size, required this.tokens});

  final double size;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: tokens.surfaceAlt,
        child: Center(
          child: Icon(
            Icons.person_outline,
            size: size * 0.5,
            color: tokens.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 头部偏好签名行：已填显示中文摘要，未填显示「完善摄影偏好 ›」引导链接
class _PrefsSubline extends ConsumerWidget {
  const _PrefsSubline({required this.profile, required this.onEdit});
  final ProfileData? profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final p = profile;
    final parts = <String>[];
    if (p != null) {
      final gender = p.gender;
      if (gender != null) {
        parts.add(PrefOptions.gender[gender] ?? gender);
      }
      final skillLevel = p.skillLevel;
      if (skillLevel != null) {
        parts.add(PrefOptions.skillLevel[skillLevel] ?? skillLevel);
      }
      final shootFrequency = p.shootFrequency;
      if (shootFrequency != null) {
        parts.add(PrefOptions.shootFrequency[shootFrequency] ?? shootFrequency);
      }
      if (p.commonScenes.isNotEmpty) {
        parts.add(p.commonScenes.take(2).map((k) => PrefOptions.commonScenes[k] ?? k).join('/'));
      }
    }
    if (parts.isEmpty) {
      return GestureDetector(
        onTap: onEdit,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 13, color: tokens.brand),
            const SizedBox(width: 4),
            Text(
              '完善摄影偏好 ›',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.brand,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
    );
  }
}

/// 头部数据区单格（作品 / 模板 / 收藏）
class _HeaderStatCell extends StatelessWidget {
  const _HeaderStatCell({
    required this.num,
    required this.label,
    required this.divider,
    required this.tokens,
  });
  final int num;
  final String label;
  final bool divider;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              letterSpacing: 0.04 * 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// ContentCard：我的内容（记录功能统一入口）
class _ContentCard extends ConsumerWidget {
  const _ContentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    const entries = <_ContentEntry>[
      _ContentEntry(
        icon: Icons.photo_library_outlined,
        label: '我的相册',
        route: RouteNames.gallery,
      ),
      _ContentEntry(
        icon: Icons.menu_book_outlined,
        label: '拍摄日记',
        route: RouteNames.galleryDiary,
      ),
      _ContentEntry(
        icon: Icons.place_outlined,
        label: '探店足迹',
        route: RouteNames.checkinList,
      ),
      _ContentEntry(
        icon: Icons.collections_bookmark_outlined,
        label: '我的精选集',
        route: RouteNames.profileCollections,
      ),
    ];

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.auto_awesome_mosaic_outlined, size: 18, color: tokens.brand),
              const SizedBox(width: 6), // 12rpx → 6dp
              Text(
                '我的内容',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17, // 32rpx → 16dp，视觉接近用 17
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // 4 项内容入口
          Row(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                Expanded(child: _ContentEntryItem(entry: entries[i], tokens: tokens)),
                if (i != entries.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentEntry {
  const _ContentEntry({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _ContentEntryItem extends StatelessWidget {
  const _ContentEntryItem({required this.entry, required this.tokens});

  final _ContentEntry entry;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(entry.route),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, size: 18, color: tokens.brand),
          ),
          const SizedBox(height: 6),
          Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  }
}

/// FragmentCard：4 项碎片收集
class _FragmentCard extends ConsumerWidget {
  const _FragmentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final fragments = ref.watch(fragmentsProvider).valueOrNull ??
        const <FragmentItem>[];

    final collected = fragments.fold<int>(0, (s, f) => s + f.current);
    final total = fragments.fold<int>(0, (s, f) => s + f.max);
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
                '$collected/$total 已集',
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

/// MenuCard：8 项菜单列表
class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    const items = <_MenuItem>[
      _MenuItem(icon: Icons.layers_outlined, title: '我的模板'),
      _MenuItem(icon: Icons.map_outlined, title: '场景管理'),
      _MenuItem(icon: Icons.download_outlined, title: '导入模板'),
      _MenuItem(icon: Icons.card_giftcard_outlined, title: '我的奖励'),
      _MenuItem(icon: Icons.account_balance_wallet_outlined, title: '我的积分'),
      _MenuItem(icon: Icons.redeem_outlined, title: '兑换码'),
      _MenuItem(icon: Icons.info_outline, title: '关于如画'),
      _MenuItem(icon: Icons.headset_mic_outlined, title: '联系我们'),
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
    if (title == '我的模板') {
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
    } else if (title == '我的积分') {
      onNav(RouteNames.pointsWallet);
    } else if (title == '兑换码') {
      onNav(RouteNames.profileRedeem);
    } else if (title == '关于如画') {
      onNav(RouteNames.profileAbout);
    } else if (title == '联系我们') {
      onNav(RouteNames.profileContact);
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

/// FeedbackEntryCard：个人中心醒目「意见反馈」入口（brand 渐变底 + 反馈 icon + 副文案 + 右箭头）
class _FeedbackEntryCard extends StatelessWidget {
  const _FeedbackEntryCard({required this.onTap, required this.tokens});
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.6),
              tokens.brandLight.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.brand.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.feedback_outlined, size: 22, color: tokens.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '意见反馈',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '有 Bug / 想法 / 想要的模板？告诉我们',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}