import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/challenge_mock_data.dart';
import '../data/challenge_models.dart';

/// 翻牌页下方：连续打卡进度条
class FlipStreakBar extends ConsumerWidget {
  const FlipStreakBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final streak = ChallengeMockData.flipStreak;
    final weeklyDone = ChallengeMockData.weeklyCompletedCount;
    final weeklyTotal = ChallengeMockData.weeklyTotalCount;
    final progress = (weeklyDone / weeklyTotal).clamp(0.0, 1.0);

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_outlined,
                  size: 18, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                '连续打卡 ${streak.currentStreak} 天',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '本周 $weeklyDone/$weeklyTotal',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: tokens.brandSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            streak.tipMessage,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 翻牌页下方：用户成就摘要（3 列 Bento）
class FlipUserSummary extends ConsumerWidget {
  const FlipUserSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final summary = ChallengeMockData.userSummary;

    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          _StatCell(
            tokens: tokens,
            icon: Icons.stars_outlined,
            value: '${summary.totalXP}',
            label: '总 XP',
          ),
          _Divider(tokens: tokens),
          _StatCell(
            tokens: tokens,
            icon: Icons.check_circle_outline,
            value: '${summary.completedCount}',
            label: '已完成',
          ),
          _Divider(tokens: tokens),
          _StatCell(
            tokens: tokens,
            icon: Icons.shield_outlined,
            value: 'Lv.${summary.level}',
            label: summary.levelName,
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.tokens,
    required this.icon,
    required this.value,
    required this.label,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: tokens.brand),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: tokens.surfaceAlt,
    );
  }
}

/// 翻牌页下方：最近完成记录
class FlipRecentRecords extends ConsumerWidget {
  const FlipRecentRecords({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final records = ChallengeMockData.recentRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                '最近完成',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.brand,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: tokens.brand),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final r in records) ...[
          _RecentRecordCard(record: r),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RecentRecordCard extends ConsumerWidget {
  const _RecentRecordCard({required this.record});
  final ChallengeHistoryRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final thumbnail = record.photoIds.isNotEmpty
        ? ChallengeMockData.photoUrl(record.photoIds.first)
        : null;
    final isDone = record.status == ChallengeStatus.done;

    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 缩略图
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: thumbnail != null
                  ? Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ThumbPlaceholder(
                          tokens: tokens, icon: Icons.image_outlined),
                    )
                  : _ThumbPlaceholder(
                      tokens: tokens, icon: Icons.visibility_off_outlined),
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      record.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDone
                            ? tokens.successSubtle
                            : tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        isDone ? '已完成' : '已跳过',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDone ? tokens.success : tokens.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // XP
          if (isDone) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_outlined, size: 14, color: tokens.brand),
                const SizedBox(width: 2),
                Text(
                  '+${record.rewardXP}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.brand,
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

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.tokens, required this.icon});
  final ThemeTokens tokens;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.brandSubtle,
      child: Center(
        child: Icon(icon, size: 20, color: tokens.brand),
      ),
    );
  }
}
