import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../data/rewards_models.dart';
import '../data/rewards_repository.dart';

class RewardsPage extends ConsumerWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的奖励')),
      body: rewardsAsync.when(
        data: (list) => _buildList(context, ref, list.rewards),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final isOffline = e is ApiException && e.isNetworkError;
          return Column(
            children: [
              if (isOffline) const ApiErrorBanner(),
              const Expanded(child: Center(child: Text('暂无奖励'))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<UnlockedReward> rewards) {
    if (rewards.isEmpty) {
      return const Center(child: Text('暂无奖励'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rewards.length,
      itemBuilder: (_, i) => _RewardCard(reward: rewards[i]),
    );
  }
}

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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tier ${r.tier} · ${r.source.toJson()}', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final item in r.rewardItems) Text('• ${item.label}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (r.status == UnlockStatus.unlocked)
                  ElevatedButton(
                    onPressed: _claiming ? null : _onClaim,
                    child: _claiming
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('领取'),
                  )
                else
                  Text(
                    '已领取',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
