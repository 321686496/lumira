import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/home_providers.dart';

/// 轻量成长条：首页不再使用大号打卡/统计卡，压缩成一条可扫读的信息。
class GrowthStrip extends ConsumerWidget {
  const GrowthStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final streak =
        ref.watch(homeStreakProvider).valueOrNull ?? HomeStreakStatus.empty;
    final stats = ref.watch(homeStatsProvider).valueOrNull ?? HomeStats.empty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _GrowthItem(
              icon: Icons.local_fire_department_outlined,
              value: '${streak.streakDays}',
              label: '连续天',
              color: tokens.danger,
              tokens: tokens,
            ),
            _GrowthDivider(tokens: tokens),
            _GrowthItem(
              icon: Icons.photo_library_outlined,
              value: '${stats.totalPhotos}',
              label: '作品',
              color: tokens.brand,
              tokens: tokens,
            ),
            _GrowthDivider(tokens: tokens),
            _GrowthItem(
              icon: Icons.favorite_border,
              value: '${stats.favorites}',
              label: '收藏',
              color: tokens.danger,
              tokens: tokens,
            ),
            _GrowthDivider(tokens: tokens),
            _GrowthItem(
              icon: Icons.show_chart,
              value: '${stats.totalXp}',
              label: '经验',
              color: tokens.success,
              tokens: tokens,
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthDivider extends StatelessWidget {
  const _GrowthDivider({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: tokens.divider,
    );
  }
}

class _GrowthItem extends StatelessWidget {
  const _GrowthItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.tokens,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.textTertiary,
                    height: 1.2,
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
