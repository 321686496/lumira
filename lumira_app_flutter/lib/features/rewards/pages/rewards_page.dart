import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/rewards_models.dart';
import '../data/rewards_repository.dart';

/// 我的奖励页
///
/// UI 重写：接入 ThemeTokens + LumiraNav + GlassBackground + NeuCard + LumiraButton + FadeUp。
/// 数据层（rewardsListProvider / rewardsRepositoryProvider）保持不变。
class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
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

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final rewardsAsync = ref.watch(rewardsListProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的奖励',
        transparent: true,
        scrolled: _scrolled,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.standard),
          ),
          SafeArea(
            child: rewardsAsync.when(
              data: (list) => _buildList(tokens, list.rewards),
              loading: () => Center(
                child: CircularProgressIndicator(color: tokens.brand),
              ),
              error: (e, _) {
                final isOffline = e is ApiException && e.isNetworkError;
                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    if (isOffline)
                      ApiErrorBanner(
                        onRetry: () => ref.invalidate(rewardsListProvider),
                      ),
                    if (isOffline) const SizedBox(height: 16),
                    _EmptyState(tokens: tokens),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeTokens tokens, List<UnlockedReward> rewards) {
    if (rewards.isEmpty) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [_EmptyState(tokens: tokens)],
      );
    }

    final claimedCount =
        rewards.where((r) => r.status == UnlockStatus.claimed).length;
    final pendingCount =
        rewards.where((r) => r.status == UnlockStatus.unlocked).length;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        FadeUp(
          child: _OverviewCard(
            tokens: tokens,
            claimedCount: claimedCount,
            pendingCount: pendingCount,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < rewards.length; i++) ...[
          FadeUp(
            delay: Duration(milliseconds: (i + 1) * 80),
            child: _RewardCard(reward: rewards[i]),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 空状态卡：NeuCard + 插图 + 文案
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_outlined,
              size: 36,
              color: tokens.brand,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无奖励',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '邀请好友或输入兑换码即可解锁专属奖励',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 奖励总览卡：累计已领 X 项 / 待领取 Y 项
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.tokens,
    required this.claimedCount,
    required this.pendingCount,
  });
  final ThemeTokens tokens;
  final int claimedCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 28,
              color: tokens.brand,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '奖励总览',
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '累计已领 $claimedCount 项 · 待领取 $pendingCount 项',
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
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

/// 单张奖励卡：左侧 tier 徽章 + 右侧标题/items/状态
class _RewardCard extends ConsumerStatefulWidget {
  final UnlockedReward reward;
  const _RewardCard({required this.reward});

  @override
  ConsumerState<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends ConsumerState<_RewardCard> {
  bool _claiming = false;

  Future<void> _onClaim() async {
    setState(() => _claiming = true);
    try {
      final repo = await ref.read(rewardsRepositoryProvider.future);
      await repo.claim(widget.reward.id);
      ref.invalidate(rewardsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('奖励已领取')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('领取失败：${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final tokens = ref.watch(themeTokensProvider);
    final sourceLabel =
        r.source == RewardSource.invite ? '邀请奖励' : '兑换奖励';
    final title = r.sourceDetail ?? sourceLabel;
    final canClaim = r.status == UnlockStatus.unlocked;

    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.brand,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'T${r.tier}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < r.rewardItems.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: tokens.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.rewardItems[i].label,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canClaim)
                      LumiraButton(
                        label: _claiming ? '领取中...' : '领取',
                        variant: LumiraButtonVariant.brand,
                        expand: false,
                        enabled: !_claiming,
                        onPressed: _onClaim,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.brandSubtle,
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        child: Text(
                          '已领取',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.brandText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
