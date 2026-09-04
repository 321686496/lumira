import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../scenes/widgets/scene_category_overview.dart';
import '../data/remote_templates_providers.dart';
import '../data/templates_browse_mock_data.dart';
import '../data/templates_mock_data.dart';
import '../data/templates_providers.dart';
import '../services/template_mapper.dart';
import '../widgets/adaptive_cover_image.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/template_grid.dart';
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
    // 每次进入页面都 invalidate sync provider，强制重新拉取后端数据。
    // build() 中 ref.watch 这两个 provider，同步完成后自动 rebuild 刷新 UI。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(remoteCategoriesSyncProvider);
      ref.invalidate(remoteTemplatesSyncProvider);
      // 远程模板同步完成后刷新"今日为你推荐"候选池，
      // 让后台新增/下架的运营模板立即反映进推荐列表。
      ref.read(remoteTemplatesSyncProvider.future).then((_) {
        ref.invalidate(recommendedBuiltinTemplatesProvider);
      }).catchError((_) {
        ref.invalidate(recommendedBuiltinTemplatesProvider);
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 12;
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

  /// 下拉刷新：重新拉取远程模板/分类并同步到本地。
  Future<void> _onRefresh() async {
    ref.invalidate(remoteCategoriesSyncProvider);
    ref.invalidate(remoteTemplatesSyncProvider);
    await Future.wait([
      ref.read(remoteCategoriesSyncProvider.future).catchError((_) {}),
      ref.read(remoteTemplatesSyncProvider.future).catchError((_) {}),
    ]);
    // 远程模板同步完成，刷新"今日为你推荐"候选取，体现后台运营新增模板。
    ref.invalidate(recommendedBuiltinTemplatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    // watch sync providers：同步完成时自动 rebuild，刷新模板列表。
    ref.watch(remoteCategoriesSyncProvider);
    ref.watch(remoteTemplatesSyncProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      // 参考首页结构：不使用 extendBodyBehindAppBar，Scaffold 自动留出 appBar 高度，
      // body 从 appBar 下方开始，无需手动添加 viewPadding.top + 48 的 top padding。
      appBar: LumiraNav(
        leading: const NavPageTitle(title: '发现'),
        centerTitle: false,
        transparent: true,
        scrolled: _scrolled,
        showBackButton: false,
        horizontalPadding: 24,
        actions: [
          LumiraNavButton(
            icon: Icons.search,
            tooltip: '搜索',
            onPressed: () => GoRouter.of(context).push(
              RouteNames.withScope(RouteNames.search, SearchScope.all.name),
            ),
          ),
          LumiraNavButton(
            icon: Icons.apps_outlined,
            tooltip: '查看全部模板',
            onPressed: _goAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 背景层整体栅格化隔离：滚动/内容重绘时不牵引全屏背景（对齐首页结构）
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景装饰（glass 风格可见性）
                  _BackgroundDecoration(tokens: tokens),
                  // Forced fix: glass 风格彩色斑点背景
                  const GlassBackground(variant: GlassBackgroundVariant.templates),
                ],
              ),
            ),
          ),
          // 主内容（extendBodyBehindAppBar 让内容延伸到 nav 下方，需 top padding 占位避免被遮挡）
          RefreshIndicator(
            color: tokens.brand,
            backgroundColor: tokens.surface,
            onRefresh: _onRefresh,
            child: _BodyContent(
              scrollController: _scrollController,
              onTap: _goDetail,
            ),
          ),
        ],
      ),
    );
  }
}

/// 页面主体内容（ConsumerWidget，watch userPreferenceProvider 决定是否显示偏好 section）
class _BodyContent extends ConsumerWidget {
  const _BodyContent({required this.scrollController, required this.onTap});

  final ScrollController scrollController;
  final void Function(String templateId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 真实数据：用户拍摄偏好（totalPhotos > 0 且 topCategory 非空时显示）
    final asyncPref = ref.watch(userPreferenceProvider);
    final showPreference = asyncPref.maybeWhen(
      data: (p) => p.totalPhotos > 0,
      orElse: () => false,
    );

    // 性能(Forced fix): 原 ListView(children:) + shrinkWrap 瀑布流会把「更多模板」的全部
    // 卡片一次性 build/layout、封面一次性解码，在 OHOS 上滚动到网格区时产生连续解码突刺
    // → 掉帧。改为 CustomScrollView：固定小节用 SliverList，瀑布流网格用
    // SliverMasonryGrid 懒加载，按滚动位置只 build/解码视口内的卡片。
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(), // 支持下拉刷新
      cacheExtent: 480, // 提前约一屏预构建，让网格卡片更早触发图片下载/解码
      slivers: [
        // === 模板库 section（上）===
        // 固定小节（体积小，一次性构建即可）
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                FadeUp(child: _TemplateSectionHeader()),
                _HeroSection(onTap: onTap),
                if (showPreference)
                  FadeUp(
                    delay: const Duration(milliseconds: 80),
                    child: _PreferenceSection(),
                  ),
                // 「更多模板」标题行（网格本身是懒加载 sliver，紧跟其后）
                const _MoreTemplatesHeader(),
              ],
            ),
          ),
        ),
        // 「更多模板」瀑布流网格（懒加载 SliverMasonryGrid）
        const _MoreTemplatesGridSliver(),
        // === 场景 section（下）===
        SliverPadding(
          padding: const EdgeInsets.only(top: 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                FadeUp(
                  delay: const Duration(milliseconds: 160),
                  child: _SceneSectionHeader(),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: FadeUp(
            delay: Duration(milliseconds: 200),
            child: SceneCategoryOverview(compact: true),
          ),
        ),
        // === 摄影美学院 section ===
        SliverPadding(
          padding: const EdgeInsets.only(top: 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                FadeUp(
                  delay: const Duration(milliseconds: 240),
                  child: _AcademyEntrySection(),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)), // bottom spacer 避开 FloatingTabBar
      ],
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
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
class _HeroSection extends ConsumerWidget {
  const _HeroSection({required this.onTap});

  final void Function(String templateId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Forced fix: 用 recommendedBuiltinTemplatesProvider 替代 templatesDaoProvider + FutureBuilder，
    // 缓存查询结果避免每次 build 反复进入 loading 状态导致 SizedBox(244) 持续显示 loading 圈。
    // loading/error/空数据时不渲染 SizedBox(244)，避免标题下方出现大空白。
    final asyncList = ref.watch(recommendedBuiltinTemplatesProvider);
    // 已拍照片数（Hero 卡右下角角标，与模板库卡片一致）
    final usageCounts = ref.watch(templateUsageCountsProvider).valueOrNull ?? const <String, int>{};
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 12), // 减小底部留白避免与"更多模板"间距过大
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
            asyncList.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  // 卡片 = 固定封面 172 + 信息区约 76 ≈ 248，高度贴合并预留阴影空间。
                  height: 256,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none, // 允许阴影溢出裁剪边界
                    padding: const EdgeInsets.symmetric(horizontal: 20), // 40rpx → 20dp
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10), // gap 20rpx → 10dp
                    itemBuilder: (_, index) {
                      final rec = _recordToRecommendation(list[index]);
                      return RecommendationCard(
                        recommendation: rec,
                        usageCount: usageCounts[rec.id] ?? 0,
                        onTap: () => onTap(rec.id),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 拍摄偏好 section（真实数据：来自 userPreferenceProvider）
class _PreferenceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final preference = ref.watch(userPreferenceProvider).valueOrNull ??
        const UserPreference(
          totalPhotos: 0,
          topCategory: '',
          topCategoryPercentage: 0,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '你的拍摄偏好',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: -0.01 * 16,
                height: 1.2,
              ),
            ),
          ),
          UserPreferenceCard(preference: preference),
        ],
      ),
    );
  }
}

/// 「更多模板」标题行（网格由懒加载 sliver 紧跟其后）
class _MoreTemplatesHeader extends ConsumerWidget {
  const _MoreTemplatesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '更多模板',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              letterSpacing: -0.01 * 16,
              height: 1.2,
            ),
          ),
          GestureDetector(
            onTap: () => GoRouter.of(context).push(RouteNames.templatesAll),
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
    );
  }
}

/// 「更多模板」瀑布流网格（懒加载 SliverMasonryGrid）
///
/// 性能(Forced fix): 原 shrinkWrap Row/Column 双列配平会把全部卡片一次性 build/layout、
/// 封面一次性解码；改为 SliverMasonryGrid 后按滚动位置只 build/解码视口内的卡片。
/// 卡片高度由内容（AdaptiveCoverImage 自适应封面 + 文字）固有决定，无需手工估算。
class _MoreTemplatesGridSliver extends ConsumerWidget {
  const _MoreTemplatesGridSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final asyncOthers = ref.watch(hotAndNewTemplatesProvider);
    // 已拍照片数（「更多模板」卡右下角角标，与模板库卡片一致）
    final usageCounts =
        ref.watch(templateUsageCountsProvider).valueOrNull ?? const <String, int>{};

    return asyncOthers.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (e, _) => SliverToBoxAdapter(child: _EmptyState(tokens: tokens)),
      data: (others) {
        if (others.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyState(tokens: tokens));
        }
        final visible = others.length > 6 ? others.sublist(0, 6) : others;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childCount: visible.length,
            itemBuilder: (_, i) {
              final r = visible[i];
              // 与「全部模板页」卡片同构：TemplateCard + 共享徽标（免费/积分/已拍）
              final item = templateGridItemFromRecord(r, isCustom: false);
              // 整卡隔离成独立图层，滚动时合成器直接搬移缓存层，避免每帧重绘阴影
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TemplateCard(
                    tokens: tokens,
                    template: item,
                    usageCount: usageCounts[item.id] ?? 0,
                  ),
                ),
              );
            },
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
                  // 封面图（本地资源，避免网络占位图加载慢/失败）
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: LumiraImage(
                      'assets/images/academy/course_01_cover.jpg',
                      fit: BoxFit.cover,
                      errorWidget: Container(
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

/// TemplateRecord → TemplateRecommendation 适配
/// DAO 推荐模板数据 → RecommendationCard 所需类型
TemplateRecommendation _recordToRecommendation(TemplateRecord r) {
  // 来源 badge 文案由 TemplateSource.systemPick → '为你推荐'（见 sourceLabel）。
  // 副行展示模板短描述，更有内容感、不再固定一句话。
  final desc = r.shortDesc.isNotEmpty
      ? r.shortDesc
      : (r.description.isNotEmpty ? r.description : '为你推荐');
  return TemplateRecommendation(
    id: r.id,
    name: r.name,
    reason: desc,
    source: TemplateSource.systemPick,
    imageSeed: r.id,
    category: r.category,
    cover: r.cover.isEmpty ? null : TemplateMapper.normalizeAssetUrl(r.cover),
    coverData: r.coverData,
    // 与「全部模板页」卡片对齐的徽标数据：价格/自定义/氛围
    price: r.price,
    isCustom: r.source == 'custom',
    ambience: TemplateMapper.ambienceFromJson(r.ambienceJson),
  );
}