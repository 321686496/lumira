import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../data/challenge_mock_data.dart';
import '../widgets/main_challenge_card.dart';
import '../widgets/sub_challenge_row.dart';
import '../widgets/tomorrow_preview_card.dart';
import '../widgets/streak_card.dart';

/// Challenge 列表页
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue
/// 5 个 section:
/// 1. LumiraNav（标题"每日挑战" + 右侧 clipboard-text 图标）
/// 2. MainChallengeCard（主挑战，已完成态）
/// 3. 附加挑战区块（区块标题 + 2 个 SubChallengeRow）
/// 4. 明日挑战预览（区块标题 + "全部" 链接 + TomorrowPreviewCard）
/// 5. 连续打卡（StreakCard）
class ChallengePage extends ConsumerStatefulWidget {
  const ChallengePage({super.key});

  @override
  ConsumerState<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends ConsumerState<ChallengePage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  static const double _scrollThreshold = 10.0;

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

  void _goAllTomorrow() {
    // mock 阶段无实际"全部"页，复用 detail 路由占位
    GoRouter.of(context).push(RouteNames.challengeDetail);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          // 径向渐变背景装饰（glass 风格可见性）
          Positioned.fill(
            child: DecoratedBox(
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
          ),
          // Forced fix: glass 风格彩色斑点背景
          const Positioned.fill(child: GlassBackground(variant: GlassBackgroundVariant.challenge)),
          // 主内容
          SafeArea(
            child: Column(
              children: [
                LumiraNav(
                  title: '每日挑战',
                  scrolled: _scrolled,
                  transparent: true,
                  showBackButton: false,
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.assignment_outlined,
                        size: 20,
                        color: tokens.textPrimary,
                      ),
                      onPressed: () {},
                      tooltip: '挑战记录',
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    children: [
                      // 1. 主挑战卡
                      const FadeUp(
                        child: MainChallengeCard(
                          challenge: ChallengeMockData.mainChallenge,
                        ),
                      ),
                      const SizedBox(height: 32), // margin-top 64rpx → 32dp
                      // 2. 附加挑战区块
                      const FadeUp(
                        delay: Duration(milliseconds: 80),
                        child: _SectionTitle(
                          title: '附加挑战',
                          subtitle: '1+2 弹性模式',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...ChallengeMockData.subChallenges.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeUp(
                                delay: Duration(
                                  milliseconds: 160 + entry.key * 80,
                                ),
                                child: SubChallengeRow(
                                  challenge: entry.value,
                                  onGoComplete: () =>
                                      _goDetail(entry.value.id),
                                ),
                              ),
                            ),
                          ),
                      const SizedBox(height: 32),
                      // 3. 明日挑战预览
                      FadeUp(
                        delay: const Duration(milliseconds: 320),
                        child: _SectionTitle(
                          title: '明日挑战预览',
                          trailing: _SectionLink(
                            text: '全部',
                            onTap: _goAllTomorrow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const FadeUp(
                        delay: Duration(milliseconds: 320),
                        child: TomorrowPreviewCard(
                          preview: ChallengeMockData.tomorrowPreview,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 4. 连续打卡
                      const FadeUp(
                        delay: Duration(milliseconds: 400),
                        child: StreakCard(streak: ChallengeMockData.streak),
                      ),
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
            child: FloatingTabBar(active: 'challenge'),
          ),
        ],
      ),
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
                    fontSize: 17, // 34rpx → 17dp
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
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
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

class _SectionLink extends StatelessWidget {
  const _SectionLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 10,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
