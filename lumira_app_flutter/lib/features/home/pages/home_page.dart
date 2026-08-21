import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/notification/notification_providers.dart';
import '../../../shared/widgets/brand/home_brand_title.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../data/home_mock_data.dart';
import '../data/home_providers.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_banner.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recent_shot_card.dart';
import '../widgets/scene_reco_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/tip_card.dart';

/// 首页
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue
/// 8 个 section:
/// 1. LumiraNav（带位置 + 通知/二维码 actions）
/// 2. HeroCard（今日灵感）
/// 3. QuickActions（4 快捷入口）
/// 4. StreakCard（连续拍摄）
/// 5. TipCard（今日拍摄小贴士）
/// 6. SceneRecoCard 网格（场景推荐，2 列）
/// 7. RecentShotCard 网格（最近拍摄，2 列）
/// 8. StatsCard（统计）
///
/// 改进点（vs uni-app）：
/// - 用 ScrollController + listener 替代 window scroll 监听，更可靠
/// - 径向渐变背景装饰用 Container + BoxDecoration 实现（glass 风格可见性）
/// - Section 入场动画用 FadeUp（统一组件，可复用）
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  static const double _scrollThreshold = 12.0; // 滚动阈值统一 12dp

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
    final offset = _scrollController.offset;
    final newScrolled = offset > _scrollThreshold;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  void _goCapture() => GoRouter.of(context).push(RouteNames.capture);
  void _goTemplates() => context.go(RouteNames.templates);
  void _goChallenge() => context.go(RouteNames.challenge);
  void _goInspiration() => GoRouter.of(context).push(RouteNames.inspiration);
  void _goGallery() => GoRouter.of(context).push(RouteNames.gallery);
  void _goRetake(RecentShot recent) {
    // 复用来源：优先模板，其次场景；都没有则退回自由拍摄
    final params = <String, String>{};
    if (recent.templateId != null && recent.templateId!.isNotEmpty) {
      params[RouteNames.paramTemplateId] = recent.templateId!;
    } else if (recent.sceneId != null && recent.sceneId!.isNotEmpty) {
      params[RouteNames.paramSceneId] = recent.sceneId!;
    }
    GoRouter.of(context).push(RouteNames.build(RouteNames.capture, params));
  }
  void _goSceneGuide(String sceneId) {
    // 场景卡片深链直达场景详情（场景灵感页并入场景库后的统一落点）
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    // 未读通知数：provider 同步失败/未就绪时静默为 0，不阻断首页首帧。
    final unreadCount = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: tokens.canvas,
      // 透明 LumiraNav 作为 appBar（PreferredSizeWidget）
      // 首页使用可切换的艺术排版组件 HomeBrandTitle
      appBar: LumiraNav(
        centerTitle: false,
        transparent: true,
        scrolled: _scrolled,
        showBackButton: false,
        horizontalPadding: 24,
        leading: const HomeBrandTitle(),
        actions: [
          _NavAction(
            icon: Icons.notifications_outlined,
            tokens: tokens,
            badgeCount: unreadCount,
            onTap: () => GoRouter.of(context).push(RouteNames.profileNotifications),
          ),
          _NavAction(
            icon: Icons.card_giftcard_outlined,
            tokens: tokens,
            onTap: () => GoRouter.of(context).push(RouteNames.profileShareCode),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. 径向渐变背景装饰（glass 风格 backdrop-filter 可见性必需）
          _BackgroundDecoration(tokens: tokens),
          // Forced fix: glass 风格彩色斑点背景（让毛玻璃效果可见）
          const Positioned.fill(child: GlassBackground()),
          // 2. 主内容层（可滚动）
          // Forced fix: appBar 已处理顶部 inset，body 内 SafeArea 顶部对 ListView 无实际效果，
          // 仅保留 bottom（系统导航栏 inset）
          SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              controller: _scrollController,
              // 给 FloatingTabBar 留空间；顶部留 12 与标题栏做间距，避免内容顶在导航栏下
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
              children: [
                // Section 0: Banner 轮播
                // Forced fix: 改为 const HomeBanner()，由 widget 内部 watch
                // bannerRecommendationProvider 获取真实推荐数据
                const FadeUp(
                  child: HomeBanner(),
                ),
                const SizedBox(height: 20),
                // Section 1: Hero
                FadeUp(
                  child: HeroCard(onCapture: _goCapture),
                ),
                const SizedBox(height: 20), // section margin-bottom 40rpx → 20dp
                // Section 2: QuickActions
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: QuickActions(
                    onCapture: _goCapture,
                    onTemplates: _goTemplates,
                    onInspiration: _goInspiration,
                    onGallery: _goGallery,
                  ),
                ),
                const SizedBox(height: 20),
                // Section 3: Streak
                const FadeUp(
                  delay: Duration(milliseconds: 200),
                  child: StreakCard(),
                ),
                const SizedBox(height: 20),
                // Section 4: Tip
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: TipCard(onTry: _goCapture),
                ),
                const SizedBox(height: 20),
                // Section 5: Scene recommendations
                FadeUp(
                  delay: const Duration(milliseconds: 400),
                  child: _SectionTitle(
                    title: '场景推荐',
                    tagText: '为你而选',
                    tagColor: tokens.success,
                    tagBgColor: tokens.successSubtle,
                    tokens: tokens,
                    links: const ['查看全部', '收藏', '管理'],
                    onLinkTap: (label) {
                      switch (label) {
                        case '查看全部':
                          GoRouter.of(context).push(RouteNames.scenes);
                          break;
                        case '收藏':
                          GoRouter.of(context).push(RouteNames.build(
                            RouteNames.captureSceneManage,
                            {RouteNames.paramTab: 'fav'},
                          ));
                          break;
                        case '管理':
                          GoRouter.of(context).push(RouteNames.captureSceneManage);
                          break;
                      }
                    },
                  ),
                ),
                FadeUp(
                  delay: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SceneRecoGrid(onTap: _goSceneGuide),
                  ),
                ),
                const SizedBox(height: 20),
                // Section 6: Recent shots
                FadeUp(
                  child: _SectionTitle(
                    title: '最近拍摄',
                    tagText: '为你甄选',
                    tagColor: tokens.brand,
                    tagBgColor: tokens.brandSubtle,
                    tokens: tokens,
                    tagIcon: Icons.auto_awesome_outlined,
                    links: const ['全部'],
                    onLinkTap: (_) => _goGallery(),
                  ),
                ),
                FadeUp(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _RecentShotsGrid(
                      onTap: () => _goGallery(),
                      onCapture: _goCapture,
                      onRetake: _goRetake,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Section 7: Stats
                const FadeUp(
                  delay: Duration(milliseconds: 100),
                  child: StatsCard(),
                ),
              ],
            ),
          ),
          // 3. FloatingTabBar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(active: 'home'),
          ),
        ],
      ),
    );
  }
}

/// 顶部导航右侧 action 按钮
class _NavAction extends StatelessWidget {
  const _NavAction({
    required this.icon,
    required this.tokens,
    this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final ThemeTokens tokens;

  /// 未读通知角标数量；<=0 或 null 时不显示角标。
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(
      icon,
      size: 20, // 40rpx → 20dp
      color: tokens.textSecondary,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: (badgeCount != null && badgeCount! > 0)
            ? Badge(
                label: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    fontSize: 9,
                    color: tokens.textInverse,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: tokens.brand,
                smallSize: 8,
                child: iconWidget,
              )
            : iconWidget,
      ),
    );
  }
}

/// Section 标题行：标题 + tag + 右侧链接组
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.tagText,
    required this.tagColor,
    required this.tagBgColor,
    required this.tokens,
    this.tagIcon,
    required this.links,
    required this.onLinkTap,
  });

  final String title;
  final String tagText;
  final Color tagColor;
  final Color tagBgColor;
  final ThemeTokens tokens;
  final IconData? tagIcon;
  final List<String> links;
  final void Function(String label) onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tagIcon != null) ...[
                      Icon(tagIcon, size: 10, color: tagColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      tagText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tagColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: links
                .map((link) => Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: GestureDetector(
                        onTap: () => onLinkTap(link),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          link,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textTertiary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 径向渐变背景装饰
///
/// 视觉规格来源：lumira-app/src/App.vue .lumira-container background-image radial-gradient
/// glass 风格 backdrop-filter 可见性必需（项目记忆规则）
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: tokens.canvas,
            // 两个径向渐变（左上 + 右下）作为背景装饰
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.8),
              radius: 1.2,
              colors: [
                tokens.brand.withOpacity(0.06),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 场景推荐网格（真实数据）
///
/// 数据来源：homeSceneRecosProvider（按用户拍摄数排序的场景列表）
/// loading 时显示占位骨架，无数据时显示内置预设兜底
class _SceneRecoGrid extends ConsumerWidget {
  const _SceneRecoGrid({required this.onTap});

  final void Function(String sceneId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScenes = ref.watch(homeSceneRecosProvider);

    return asyncScenes.when(
      loading: () => _buildSkeleton(),
      error: (_, __) => _buildSkeleton(),
      data: (scenes) {
        if (scenes.isEmpty) return _buildSkeleton();
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.50,
          children: scenes
              .map((scene) => SceneRecoCard(
                    scene: scene,
                    onTap: () => onTap(scene.id),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.50,
      children: HomeMockData.scenes
          .map((scene) => SceneRecoCard(
                scene: scene,
                onTap: () => onTap(scene.id),
              ))
          .toList(),
    );
  }
}

/// 最近拍摄网格（真实数据）
///
/// 数据来源：homeRecentShotsProvider（来自 GalleryDao.getRecent）
/// 无照片时显示空状态引导拍摄
class _RecentShotsGrid extends ConsumerWidget {
  const _RecentShotsGrid({
    required this.onTap,
    required this.onCapture,
    required this.onRetake,
  });

  final VoidCallback onTap;
  final VoidCallback onCapture;
  final void Function(RecentShot recent) onRetake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final asyncRecents = ref.watch(homeRecentShotsProvider);

    return asyncRecents.when(
      loading: () => _buildSkeleton(),
      error: (_, __) => _buildSkeleton(),
      data: (recents) {
        if (recents.isEmpty) {
          return _buildEmpty(tokens);
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.56,
          children: recents
              .map((recent) => RecentShotCard(
                    recent: recent,
                    onTap: onTap,
                    onRetake: () => onRetake(recent),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.56,
      children: HomeMockData.recents
          .map((recent) => RecentShotCard(
                recent: recent,
                onTap: onTap,
                onRetake: () => onRetake(recent),
              ))
          .toList(),
    );
  }

  Widget _buildEmpty(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: tokens.shadowConvex,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 48,
            color: tokens.textTertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有作品',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              fontFamily: 'Noto Serif SC',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击下方拍摄按钮，记录你的第一张作品',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onCapture,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(8),
                boxShadow: tokens.shadowConvexBrand,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 16, color: tokens.textInverse),
                  const SizedBox(width: 6),
                  Text(
                    '开始拍摄',
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textInverse,
                      fontWeight: FontWeight.w600,
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
