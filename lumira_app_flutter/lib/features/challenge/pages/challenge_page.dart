import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/challenge_models.dart';
import '../data/challenge_providers.dart';
import '../widgets/achievement_wall_card.dart';
import '../widgets/challenge_rules_card.dart';
import '../widgets/challenge_tip_card.dart';
import '../widgets/daily_flip_card.dart';
import '../widgets/flip_summary_widgets.dart';
import '../widgets/main_challenge_card.dart';
import '../widgets/sub_challenge_row.dart';
import '../widgets/weekly_calendar_card.dart';

/// Challenge 列表页
///
/// 5 个 section:
/// 1. LumiraNav（标题"每日挑战" + 右侧 clipboard-text 图标）
/// 2. 翻牌流程（每天首次进入触发，3 张卡牌选 1）
/// 3. 主挑战卡 + 附加挑战
/// 4. 本周日历 / 挑战成就 / 拍摄技巧
/// 5. 连续拍摄
class ChallengePage extends ConsumerStatefulWidget {
  const ChallengePage({super.key});

  @override
  ConsumerState<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends ConsumerState<ChallengePage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  bool _selecting = false;

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

  void _goDetail(String subChallengeId) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.challengeDetail,
        {RouteNames.paramChallengeId: subChallengeId},
      ),
    );
  }

  void _goDetailForDate(String challengeId, String date) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.challengeDetail,
        {
          RouteNames.paramChallengeId: challengeId,
          RouteNames.paramDate: date,
        },
      ),
    );
  }

  Future<void> _onFlipSelected(ChallengePoolItem selected) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      final repo = await ref.read(challengeRepositoryProvider.future);
      await repo.recordDailySelection(selected);
      // 刷新相关 providers
      ref.invalidate(dailyChallengeStateProvider);
      ref.invalidate(challengeTipProvider);
      ref.invalidate(subChallengesProvider);
      ref.invalidate(weeklyHistoryProvider);
      ref.invalidate(challengeAchievementsProvider);
    } finally {
      if (mounted) {
        setState(() => _selecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncState = ref.watch(dailyChallengeStateProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      // 参考首页结构：不使用 extendBodyBehindAppBar，Scaffold 自动留出 appBar 高度，
      // body 从 appBar 下方开始，无需手动添加 viewPadding.top + 48 的 top padding。
      appBar: LumiraNav(
        leading: const NavPageTitle(title: '每日挑战'),
        centerTitle: false,
        scrolled: _scrolled,
        transparent: true,
        showBackButton: false,
        horizontalPadding: 24,
        actions: [
          GestureDetector(
            onTap: () => GoRouter.of(context).push(RouteNames.challengeHistory),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Icon(
                Icons.assignment_outlined,
                size: 20,
                color: tokens.textPrimary,
              ),
            ),
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
                  // 径向渐变背景装饰（glass 风格可见性）
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.7, -0.5),
                        radius: 1.2,
                        colors: [
                          tokens.brand.withOpacity(0.06),
                          tokens.canvas,
                        ],
                        stops: const [0.0, 0.6],
                      ),
                    ),
                  ),
                  // glass 风格彩色斑点背景
                  const GlassBackground(variant: GlassBackgroundVariant.challenge),
                ],
              ),
            ),
          ),
          // 主内容（extendBodyBehindAppBar 让内容延伸到 nav 下方）
          asyncState.when(
            loading: () => Center(
              child: LumiraProgress.circular(),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败: $e',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (state) {
              if (state.needsFlip && state.candidates != null) {
                return _FlipView(
                  candidates: state.candidates!,
                  onSelected: _onFlipSelected,
                  scrollController: _scrollController,
                );
              }
              final selected = state.selected;
              if (selected == null) {
                return Center(
                  child: Text(
                    '暂无挑战',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                );
              }
              return _RevealedView(
                selected: selected,
                scrollController: _scrollController,
                goDetail: _goDetail,
                goDetailForDate: _goDetailForDate,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 翻牌视图：3 张卡牌翻面选 1 + 下方挑战摘要
class _FlipView extends StatelessWidget {
  const _FlipView({
    required this.candidates,
    required this.onSelected,
    required this.scrollController,
  });

  final List<ChallengePoolItem> candidates;
  final void Function(ChallengePoolItem selected) onSelected;
  final ScrollController scrollController;

  void _goHistory(BuildContext context) {
    GoRouter.of(context).push(RouteNames.challengeHistory);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 性能(Forced fix): ListView(children:) 会一次性 build 全部小节；
    // 换 CustomScrollView + SliverList 保持结构与视觉不变，仅由 sliver 按需布局。
    return CustomScrollView(
      controller: scrollController,
      cacheExtent: 480, // 提前约一屏预构建，让卡片更早触发图片下载/解码
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                FadeUp(
                  child: Column(
                    children: [
                      Icon(
                        Icons.casino_outlined,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '今日挑战翻牌',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '从 3 张卡牌中选 1 张作为你的今日挑战',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FadeUp(
                  delay: const Duration(milliseconds: 80),
                  child: DailyFlipCard(
                    candidates: candidates,
                    onSelected: onSelected,
                  ),
                ),
                const SizedBox(height: 24),
                // 打卡进度条
                FadeUp(
                  delay: const Duration(milliseconds: 160),
                  child: const FlipStreakBar(),
                ),
                const SizedBox(height: 16),
                // 用户成就摘要
                FadeUp(
                  delay: const Duration(milliseconds: 240),
                  child: const FlipUserSummary(),
                ),
                const SizedBox(height: 24),
                // 最近完成记录
                FadeUp(
                  delay: const Duration(milliseconds: 320),
                  child: FlipRecentRecords(
                    onViewAll: () => _goHistory(context),
                  ),
                ),
                const SizedBox(height: 24),
                FadeUp(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    '提示：挑战基于你的拍摄偏好智能推荐，每天首次进入触发翻牌',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)), // bottom spacer 避开 FloatingTabBar
      ],
    );
  }
}

/// 翻牌完成后的正常视图
class _RevealedView extends ConsumerWidget {
  const _RevealedView({
    required this.selected,
    required this.scrollController,
    required this.goDetail,
    required this.goDetailForDate,
  });

  final ChallengePoolItem selected;
  final ScrollController scrollController;
  final void Function(String id) goDetail;
  final void Function(String challengeId, String date) goDetailForDate;

  void _goCapture(BuildContext context, String challengeId) {
    GoRouter.of(context).push(
      '${RouteNames.capture}?${RouteNames.paramChallengeId}=${Uri.encodeComponent(challengeId)}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncSubs = ref.watch(subChallengesProvider);
    // 查询今日主挑战是否已完成，并取出关联的作品照片 ID
    // 注意：必须限定 r.date == 今天，否则会匹配到之前日期完成的同 id 挑战
    // （题库每天随机选题，不同日期可能选中同一挑战，导致误判为已完成）
    final historyAsync = ref.watch(weeklyHistoryProvider);
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    ChallengeStatus mainStatus = ChallengeStatus.pending;
    String? mainPhotoId;
    historyAsync.whenData((history) {
      final match = history.where((r) =>
          r.date == todayStr &&
          r.challengeId == selected.id &&
          r.status == ChallengeStatus.done);
      if (match.isNotEmpty) {
        mainStatus = ChallengeStatus.done;
        // photoIds 为追加存储（attachPhoto 不去重），取最后一个即最近一次提交的作品
        final record = match.first;
        if (record.photoIds.isNotEmpty) {
          mainPhotoId = record.photoIds.last;
        }
      }
    });

    final mainChallenge = MainChallenge(
      title: selected.title,
      description: selected.description,
      rewardXP: selected.rewardXP,
      status: mainStatus,
      coverImage: 'https://picsum.photos/seed/${selected.id}/400/600',
      photoId: mainPhotoId,
      tags: [
        ChallengeTag(
          label: '+${selected.rewardXP} XP',
          color: ChallengeTagColor.gold,
        ),
        ChallengeTag(
          label: ChallengeCategory.label(selected.category),
          color: ChallengeTagColor.green,
        ),
      ],
    );

    return CustomScrollView(
      controller: scrollController,
      cacheExtent: 480, // 提前约一屏预构建，让卡片更早触发图片下载/解码
      slivers: [
        // 顶部留 12 与标题栏做间距，避免内容顶在导航栏下；底部 100 避开 FloatingTabBar。
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // 1. 主挑战卡（pending 态带"去拍照"按钮，直接跳拍摄页）
                FadeUp(
                  child: MainChallengeCard(
                    challenge: mainChallenge,
                    onGoCapture: () => _goCapture(context, selected.id),
                    onTap: () => goDetail(selected.id),
                  ),
                ),
                const SizedBox(height: 32),
                // 2. 附加挑战
                const FadeUp(
                  delay: Duration(milliseconds: 80),
                  child: _SectionTitle(
                    title: '附加挑战',
                    subtitle: '1+2 弹性模式',
                  ),
                ),
                const SizedBox(height: 16),
                asyncSubs.when(
                  loading: () => SizedBox(
                    height: 100,
                    child: Center(child: LumiraProgress.circular()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        '加载失败',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                  ),
                  data: (subs) {
                    return Column(
                      children: subs.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeUp(
                            delay: Duration(milliseconds: 160 + entry.key * 80),
                            child: SubChallengeRow(
                              challenge: entry.value,
                              onGoComplete: () => _goCapture(context, entry.value.id),
                              onTap: () => goDetail(entry.value.id),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // 3. 本周日历
                const FadeUp(
                  delay: Duration(milliseconds: 240),
                  child: _SectionTitle(
                    title: '本周日历',
                    subtitle: '查看本周挑战进度',
                  ),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  delay: const Duration(milliseconds: 240),
                  child: WeeklyCalendarCard(
                    onDateTap: goDetailForDate,
                  ),
                ),
                const SizedBox(height: 32),
                // 4. 挑战成就墙
                const FadeUp(
                  delay: Duration(milliseconds: 320),
                  child: _SectionTitle(
                    title: '荣誉墙',
                    subtitle: '解锁更多荣誉',
                  ),
                ),
                const SizedBox(height: 16),
                const FadeUp(
                  delay: Duration(milliseconds: 320),
                  child: AchievementWallCard(),
                ),
                const SizedBox(height: 32),
                // 5. 拍摄技巧
                const FadeUp(
                  delay: Duration(milliseconds: 400),
                  child: _SectionTitle(
                    title: '拍摄技巧',
                    subtitle: '提升你的拍摄水平',
                  ),
                ),
                const SizedBox(height: 16),
                const FadeUp(
                  delay: Duration(milliseconds: 400),
                  child: ChallengeTipCard(),
                ),
                const SizedBox(height: 32),
                // 6. 挑战规则说明
                const FadeUp(
                  delay: Duration(milliseconds: 480),
                  child: ChallengeRulesCard(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.5),
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}