import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../data/home_mock_data.dart';
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
/// 4. StreakCard（连续打卡）
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

  static const double _scrollThreshold = 10.0; // uni-app 用 20px → 10dp

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
  void _goSceneGuide(String sceneId) {
    // 项目记忆规则：场景推荐卡片跳转 scene-guide?scene=xxx（不是 scene-detail）
    // Forced fix: 改为 push 而非 context.go，避免返回时跳到其他页面或退出应用
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.captureSceneGuide,
        {RouteNames.paramScene: sceneId},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      // 透明 LumiraNav 作为 appBar（PreferredSizeWidget）
      appBar: LumiraNav(
        title: '如画',
        transparent: true,
        scrolled: _scrolled,
        leading: _NavLocation(tokens: tokens),
        actions: [
          _NavAction(
            icon: Icons.notifications_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：通知中心
          ),
          _NavAction(
            icon: Icons.qr_code_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：扫一扫
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
          SafeArea(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 100), // 给 FloatingTabBar 留空间
              children: [
                // Section 0: Banner 轮播
                FadeUp(
                  child: HomeBanner(banners: HomeMockData.banners),
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
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12, // 24rpx → 12dp
                      crossAxisSpacing: 12,
                      // Forced fix: SceneRecoCard 文字区需要 ~101dp（12+14+4+33+6+14+14）
                      // + 图片 3:4 占 0.75w。设 w=152.7dp：
                      //   0.50 → h=305.4dp，图 203.6 + 文字 101 = 304.6dp ✓
                      //   0.60 → h=254.5dp，图 203.6 + 文字 101 = 304.6dp ✗ 溢出 50dp（原报错 49px）
                      childAspectRatio: 0.50,
                      children: HomeMockData.scenes
                          .map((scene) => SceneRecoCard(
                                scene: scene,
                                onTap: () => _goSceneGuide(scene.id),
                              ))
                          .toList(),
                    ),
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
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.56,
                      children: HomeMockData.recents
                          .map((recent) => RecentShotCard(
                                recent: recent,
                                onTap: () => GoRouter.of(context)
                                    .push(RouteNames.gallery),
                              ))
                          .toList(),
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

/// 顶部导航左侧位置显示
class _NavLocation extends StatelessWidget {
  const _NavLocation({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.place_outlined,
          size: 16, // 32rpx → 16dp
          color: tokens.textSecondary,
        ),
        const SizedBox(width: 4), // 8rpx → 4dp
        Text(
          HomeMockData.location,
          style: TextStyle(
            fontSize: 14, // 28rpx → 14dp
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// 顶部导航右侧 action 按钮
class _NavAction extends StatelessWidget {
  const _NavAction({
    required this.icon,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 20, // 40rpx → 20dp
          color: tokens.textSecondary,
        ),
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
