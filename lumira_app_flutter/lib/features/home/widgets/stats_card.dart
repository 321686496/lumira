import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/home_mock_data.dart';

/// 统计卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 192-213 + style line 806-846
/// - 标题行：图标 + "保持记录，养成习惯"
/// - 3 列等宽统计：收藏/获赞/作品，中间列有左右 divider
/// - 数字 56rpx→28dp，标签 lumira-stat-label
class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart, // ph-chart-line
                  size: 16, // 32rpx → 16dp
                  color: tokens.brand,
                ),
                const SizedBox(width: 6), // 12rpx → 6dp
                Text(
                  '保持记录，养成习惯',
                  style: TextStyle(
                    fontSize: 13, // 26rpx → 15dp（原 26rpx→13dp，但 stat-head-title 26rpx）
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // 32rpx → 16dp
            // 统计网格
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    value: '${HomeMockData.statsFavorites}',
                    label: '收藏',
                    tokens: tokens,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    value: HomeMockData.statsLikes,
                    label: '获赞',
                    tokens: tokens,
                    showBorders: true,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    value: '${HomeMockData.statsWorks}',
                    label: '作品',
                    tokens: tokens,
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.tokens,
    this.showBorders = false,
  });

  final String value;
  final String label;
  final ThemeTokens tokens;
  final bool showBorders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: showBorders
          ? BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: tokens.divider, width: 0.5),
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox 防止 8.5k 这种字符串在小屏溢出
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 28, // 56rpx → 28dp
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, // lumira-stat-label
              color: tokens.textTertiary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
