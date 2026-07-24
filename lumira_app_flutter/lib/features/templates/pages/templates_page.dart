import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../../scenes/widgets/scene_category_overview.dart';
import '../data/templates_mock_data.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/template_grid_card.dart';
import '../widgets/user_preference_card.dart';

/// 模板页（Tab 页，FloatingTabBar active="templates"）
///
/// 视觉规格来源：lumira-app/src/pages/templates/index.vue
/// 页面结构：
/// 1. LumiraNav（无返回，右侧"查看全部"按钮跳 /templates/all）
/// 2. Hero 推荐区（横向滚动卡片列表）
/// 3. 拍摄偏好（仅 totalPhotos > 0 显示）
/// 4. 更多模板（2 列网格）
/// 5. FloatingTabBar
class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  late ScrollController _scrollController;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 8;
    if (scrolled != _scrolled) {
      setState(() => _scrolled = scrolled);
    }
  }

  void _goAll() {
    GoRouter.of(context).push(RouteNames.templatesAll);
  }

  void _goDetail(String templateId) {
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesDetail, templateId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          // 背景装饰（glass 风格可见性）
          _BackgroundDecoration(tokens: tokens),
          // Forced fix: glass 风格彩色斑点背景
          const Positioned.fill(child: GlassBackground(variant: GlassBackgroundVariant.templates)),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                LumiraNav(
                  title: '发现',
                  centerTitle: false,
                  transparent: true,
                  scrolled: _scrolled,
                  showBackButton: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.apps_outlined, size: 20),
                      onPressed: _goAll,
                      tooltip: '查看全部',
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      // === 模板库 section（上）===
                      FadeUp(
                        child: _TemplateSectionHeader(),
                      ),
                      _HeroSection(
                        onTap: _goDetail,
                      ),
                      if (TemplatesMockData.userPreference.totalPhotos > 0)
                        FadeUp(
                          delay: const Duration(milliseconds: 80),
                          child: _PreferenceSection(),
                        ),
                      FadeUp(
                        delay: const Duration(milliseconds: 120),
                        child: _OtherSection(onTap: _goDetail),
                      ),
                      const SizedBox(height: 28),
                      // === 场景 section（下）===
                      FadeUp(
                        delay: const Duration(milliseconds: 160),
                        child: _SceneSectionHeader(),
                      ),
                      const FadeUp(
                        delay: Duration(milliseconds: 200),
                        child: SceneCategoryOverview(compact: true),
                      ),
                      const SizedBox(height: 28),
                      // === 摄影美学院 section ===
                      FadeUp(delay: const Duration(milliseconds: 240), child: _AcademyEntrySection()),
                      const SizedBox(height: 140), // bottom spacer 避开 FloatingTabBar
                    ],
                  ),
                ),
              ],
            ),
          ),
          // FloatingTabBar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(active: 'templates'),
          ),
        ],
      ),
    );
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「场景」分区标题
class _SceneSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final tokens = ref.watch(appThemeProvider).tokens;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              Icon(Icons.filter_drama_outlined, size: 20, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                '场景',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 「模板库」分区标题
class _TemplateSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final tokens = ref.watch(appThemeProvider).tokens;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Icon(Icons.layers_outlined, size: 20, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                '模板库',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hero 推荐区
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onTap});

  final void Function(String templateId) onTap;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 28), // 24rpx 0 32rpx → 12 0 28（增大底部留白避免阴影被下个 section 遮挡）
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10), // 40rpx 0 40rpx 20rpx → 20 0 20 10
              child: Text(
                '今日为你推荐',
                style: TextStyle(
                  fontSize: 20, // 40rpx → 20dp
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.01 * 20,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: 244, // Forced fix: 220 不够容纳 130*4/3=173.33 图片 + 名字 + 2 行 reason (~241.73dp)；改为 244
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20), // 40rpx → 20dp
                itemCount: TemplatesMockData.recommendations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10), // gap 20rpx → 10dp
                itemBuilder: (_, index) {
                  final rec = TemplatesMockData.recommendations[index];
                  return RecommendationCard(
                    recommendation: rec,
                    onTap: () => onTap(rec.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 拍摄偏好 section
class _PreferenceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final tokens = ref.watch(appThemeProvider).tokens;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), // 40rpx 16rpx 40rpx 24rpx → 20 8 20 12
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8), // margin-bottom: 16rpx → 8dp
                child: Text(
                  '你的拍摄偏好',
                  style: TextStyle(
                    fontSize: 16, // 32rpx → 16dp
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.01 * 16,
                    height: 1.2,
                  ),
                ),
              ),
              const UserPreferenceCard(
                preference: TemplatesMockData.userPreference,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 更多模板 section
class _OtherSection extends StatelessWidget {
  const _OtherSection({required this.onTap});

  final void Function(String templateId) onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final tokens = ref.watch(appThemeProvider).tokens;
        const others = TemplatesMockData.otherTemplates;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), // 40rpx 16rpx 40rpx 0 → 20 8 20 0
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8), // margin-bottom: 16rpx → 8dp
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '更多模板',
                      style: TextStyle(
                        fontSize: 16, // 32rpx → 16dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.01 * 16,
                        height: 1.2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          GoRouter.of(context).push(RouteNames.templatesAll),
                      child: Text(
                        '查看全部 ›',
                        style: TextStyle(
                          fontSize: 12, // 24rpx → 12dp
                          fontWeight: FontWeight.w500,
                          color: tokens.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (others.isEmpty)
                _EmptyState(tokens: tokens)
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12, // 24rpx → 12dp
                    crossAxisSpacing: 12,
                    // Forced fix: 原 0.78 导致 33px 溢出。
                    // 文字区 = 8+13*1.2+3+11+10 = 47.6dp，图 1:1 = w
                    // 设 w=154: 0.70 → h=220dp，图 154 + 文字 47.6 = 201.6 ✓
                    childAspectRatio: 0.70,
                  ),
                  itemCount: others.length > 6 ? 6 : others.length,
                  itemBuilder: (_, index) {
                    final tpl = others[index];
                    return TemplateGridCard(
                      template: tpl,
                      onTap: () => onTap(tpl.id),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20), // 64rpx 40rpx → 32 20
      child: Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 40, // 80rpx → 40dp
            color: tokens.textTertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 8), // gap 16rpx → 8dp
          Text(
            '暂无更多模板',
            style: TextStyle(
              fontSize: 13, // 26rpx → 13dp
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 摄影美学院入口卡片
class _AcademyEntrySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 20, color: tokens.brand),
                const SizedBox(width: 6),
                Text(
                  '摄影美学院',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // 入口卡片（与模板网格卡片视觉一致）
          NeuCard(
            padding: EdgeInsets.zero,
            shadowVariant: NeuShadowVariant.convex,
            onTap: () => GoRouter.of(context).push(RouteNames.profileAcademy),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // 封面图
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      'https://picsum.photos/seed/academy_entry/640/360',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(Icons.school_outlined, size: 40, color: tokens.textTertiary),
                      ),
                    ),
                  ),
                  // 渐变遮罩 + 文字
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // 标题 + 副标题
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '系统学习摄影美学',
                          style: TextStyle(
                            fontFamily: 'Noto Serif SC',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '16 节课程 · 8 张知识卡片 · 实战作业',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右上角箭头
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: tokens.textPrimary,
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
