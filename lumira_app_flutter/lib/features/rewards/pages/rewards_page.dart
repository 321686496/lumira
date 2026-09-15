import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show LumiraProgress;
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
                child: LumiraProgress.circular(),
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

    final invite = rewards
        .where((r) => r.source == RewardSource.invite)
        .toList();
    final redemption = rewards
        .where((r) => r.source == RewardSource.redemption)
        .toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        FadeUp(
          child: _OverviewCard(
            tokens: tokens,
            total: rewards.length,
            inviteCount: invite.length,
            redemptionCount: redemption.length,
          ),
        ),
        if (invite.isNotEmpty) ...[
          const SizedBox(height: 26),
          FadeUp(
            child: _SectionHeader(
              tokens: tokens,
              icon: Icons.people_alt_outlined,
              title: '邀请收获',
              subtitle: '你的邀请带来的美好回报',
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < invite.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            FadeUp(
              delay: Duration(milliseconds: (i + 1) * 80),
              child: _RewardCard(reward: invite[i]),
            ),
          ],
        ],
        if (redemption.isNotEmpty) ...[
          const SizedBox(height: 26),
          FadeUp(
            child: _SectionHeader(
              tokens: tokens,
              icon: Icons.redeem_outlined,
              title: '兑换所得',
              subtitle: '用积分兑换的专属奖励',
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < redemption.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            FadeUp(
              delay: Duration(milliseconds: (i + 1) * 80),
              child: _RewardCard(reward: redemption[i]),
            ),
          ],
        ],
      ],
    );
  }
}

/// 奖励分组小标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final ThemeTokens tokens;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: tokens.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
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
      child: SizedBox(
        // 账号占满卡片整宽，否则 Column 会收缩到最宽子元素宽度，导致内容整体左偏
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
      ),
    );
  }
}

/// 奖励总览卡：品牌渐变 hero + 累计解锁 + 按来源统计
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.tokens,
    required this.total,
    required this.inviteCount,
    required this.redemptionCount,
  });
  final ThemeTokens tokens;
  final int total;
  final int inviteCount;
  final int redemptionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.brandSubtle,
            tokens.brand.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  size: 24,
                  color: tokens.textInverse,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的奖励',
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '等你解锁的专属奖励，都为你守候在这里',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatItem(
                tokens: tokens,
                label: '累计解锁',
                value: '$total',
                accent: true,
              ),
              const SizedBox(width: 10),
              _StatItem(
                tokens: tokens,
                label: '邀请所得',
                value: '$inviteCount',
              ),
              const SizedBox(width: 10),
              _StatItem(
                tokens: tokens,
                label: '兑换所得',
                value: '$redemptionCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 总览卡内的单个统计块
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.tokens,
    required this.label,
    required this.value,
    this.accent = false,
  });
  final ThemeTokens tokens;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? tokens.brand : tokens.brandDeep;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent
                ? tokens.brand.withOpacity(0.30)
                : tokens.divider.withOpacity(0.7),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单张奖励卡：来源徽章 + 标题 + 奖励明细 + 「已解锁」状态（无领取按钮，
/// 解锁即视为已领取，避免无意义的确认操作）。
class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.reward});

  final UnlockedReward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reward;
    final tokens = ref.watch(themeTokensProvider);
    final title = (r.sourceDetail?.isNotEmpty ?? false)
        ? r.sourceDetail!
        : (r.source == RewardSource.invite ? '邀请奖励' : '兑换奖励');
    final subtitle = r.source == RewardSource.invite
        ? '邀请带来的美好回报'
        : '用积分兑换的专属奖励';

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 22,
                  color: tokens.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _UnlockedChip(tokens: tokens),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          for (var i = 0; i < r.rewardItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _rewardItemIcon(r.rewardItems[i]),
                    size: 14,
                    color: tokens.brand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.rewardItems[i].displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 「已解锁」状态标签（替代原「领取」按钮；解锁即视为已领取）
class _UnlockedChip extends StatelessWidget {
  const _UnlockedChip({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: tokens.brand),
          const SizedBox(width: 3),
          Text(
            '已解锁',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.brandText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 按奖励类型映射图标
IconData _rewardItemIcon(RewardItem item) {
  switch (item.type) {
    case RewardType.points:
      return Icons.stars_outlined;
    case RewardType.unlockCount:
      return Icons.lock_open_outlined;
    case RewardType.achievement:
      return Icons.emoji_events_outlined;
    case RewardType.template:
      return Icons.auto_awesome_outlined;
    case RewardType.templatePack:
      return Icons.collections_outlined;
  }
}
