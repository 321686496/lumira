import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../profile/providers/growth_providers.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/challenge_models.dart';
import '../data/challenge_providers.dart';
import '../../gallery/providers/gallery_diary_providers.dart';

/// 翻牌页下方：连续拍摄进度条
///
/// 数据源：shootingCheckinProvider（统一拍摄打卡状态）
class FlipStreakBar extends ConsumerWidget {
  const FlipStreakBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final checkinAsync = ref.watch(shootingCheckinProvider);

    return checkinAsync.when(
      loading: () => _SkeletonBar(tokens: tokens),
      error: (_, __) => _SkeletonBar(tokens: tokens),
      data: (checkin) {
        // 本周完成数 = 本周已拍天数
        final weeklyDone = checkin.weekDays.where((d) => d.done).length;
        const weeklyTotal = 7;
        final progress = (weeklyDone / weeklyTotal).clamp(0.0, 1.0);

        final tipMessage = _buildTipMessage(checkin.streakDays, weeklyDone);

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
                    '连续拍摄 ${checkin.streakDays} 天',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '本周拍摄 $weeklyDone/$weeklyTotal',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LumiraProgress.linear(
                value: progress,
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Text(
                tipMessage,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildTipMessage(int streak, int weeklyDone) {
    if (streak == 0) return '今天拍摄一张照片开启打卡';
    if (streak >= 7) return '已坚持一周，再接再厉！';
    final remain = 7 - streak;
    return '再坚持 $remain 天获得额外 50 XP';
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连续拍摄 - 天',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          LumiraProgress.linear(value: 0, minHeight: 6),
        ],
      ),
    );
  }
}

/// 翻牌页下方：用户成就摘要（3 列 Bento）
///
/// 数据源：growthLevelProvider（XP/等级）+ challengeDaoProvider（完成数）
class FlipUserSummary extends ConsumerWidget {
  const FlipUserSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final growthAsync = ref.watch(growthLevelProvider);

    return growthAsync.when(
      loading: () => _SkeletonSummary(tokens: tokens),
      error: (_, __) => _SkeletonSummary(tokens: tokens),
      data: (growth) {
        return NeuCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              _StatCell(
                tokens: tokens,
                icon: Icons.stars_outlined,
                value: '${growth.currentXp}',
                label: '总 XP',
              ),
              _Divider(tokens: tokens),
              _StatCell(
                tokens: tokens,
                icon: Icons.check_circle_outline,
                value: '${growth.level}',
                label: '等级',
              ),
              _Divider(tokens: tokens),
              _StatCell(
                tokens: tokens,
                icon: Icons.shield_outlined,
                value: growth.levelName,
                label: '头衔',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonSummary extends StatelessWidget {
  const _SkeletonSummary({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        children: [
          _StatCell(
            tokens: tokens,
            icon: Icons.stars_outlined,
            value: '-',
            label: '加载中',
          ),
          _Divider(tokens: tokens),
          _StatCell(
            tokens: tokens,
            icon: Icons.check_circle_outline,
            value: '-',
            label: '加载中',
          ),
          _Divider(tokens: tokens),
          _StatCell(
            tokens: tokens,
            icon: Icons.shield_outlined,
            value: '-',
            label: '加载中',
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
///
/// 数据源：weeklyHistoryProvider（取已完成、按完成时间倒序、前 2 条）
class FlipRecentRecords extends ConsumerWidget {
  const FlipRecentRecords({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final historyAsync = ref.watch(weeklyHistoryProvider);

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        // 过滤已完成、按完成时间倒序、取前 2 条
        final records = history
            .where((r) =>
                r.status == ChallengeStatus.done && r.completedAt != null)
            .toList()
          ..sort((a, b) => (b.completedAt ?? 0).compareTo(a.completedAt ?? 0));
        final top2 = records.take(2).toList();

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
            if (top2.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '本周还没有完成挑战',
                    style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                  ),
                ),
              )
            else
              for (final r in top2) ...[
                _RecentRecordCard(record: r),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _RecentRecordCard extends ConsumerWidget {
  const _RecentRecordCard({required this.record});
  final ChallengeHistoryRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final isDone = record.status == ChallengeStatus.done;

    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 缩略图占位（无图片源时显示分类图标）
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _ThumbPlaceholder(
                  tokens: tokens, icon: Icons.check_circle_outline),
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
