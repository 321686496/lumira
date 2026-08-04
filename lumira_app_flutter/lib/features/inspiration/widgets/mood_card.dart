import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/inspiration_mock_data.dart';

/// 今日心情卡片
///
/// 视觉规格来源：lumira-app/src/pages/inspiration/index.vue line 12-24
/// - 135° 渐变背景 #FDF6EC → #F8EDD8（硬编码，与 uni-app 一致）
/// - 7 个 mood pill，flex wrap，gap 16rpx→8dp
/// - 每个 pill：icon + label + count，圆角 9999rpx，2rpx border
class MoodCard extends ConsumerWidget {
  const MoodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    return Container(
      decoration: BoxDecoration(
        color: isNeu ? tokens.surface : null,
        gradient: isNeu
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight, // 135deg
                colors: [Color(0xFFFDF6EC), Color(0xFFF8EDD8)],
              ),
        borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
        boxShadow: isNeu ? tokens.shadowConvex : null,
      ),
      padding: const EdgeInsets.all(20), // 40rpx → 20dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                Icons.wb_twilight_outlined, // ph-sun-horizon 替代
                size: 20, // 40rpx → 20dp
                color: tokens.brand,
              ),
              const SizedBox(width: 8), // 16rpx → 8dp
              Text(
                '今日心情',
                style: TextStyle(
                  fontSize: 16, // 32rpx → 16dp
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // mood pills
          Wrap(
            spacing: 8, // 16rpx → 8dp
            runSpacing: 8,
            children: InspirationMockData.moods.map((mood) => _MoodPill(mood: mood)).toList(),
          ),
        ],
      ),
    );
  }
}

class _MoodPill extends StatelessWidget {
  const _MoodPill({required this.mood});
  final MoodEntry mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 24rpx/12rpx → 12dp/6dp
      decoration: BoxDecoration(
        color: mood.colorScheme.background,
        borderRadius: BorderRadius.circular(1000),
        border: Border.all(color: mood.colorScheme.border, width: 1), // 2rpx → 1dp
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mood.icon, size: 13, color: mood.colorScheme.foreground), // 26rpx → 13dp
          const SizedBox(width: 4), // 8rpx → 4dp
          Text(
            mood.label,
            style: TextStyle(
              fontSize: 13, // 26rpx → 13dp
              color: mood.colorScheme.foreground,
            ),
          ),
          const SizedBox(width: 2), // 4rpx → 2dp
          Text(
            '${mood.count}',
            style: TextStyle(
              fontSize: 11, // 22rpx → 11dp
              color: mood.colorScheme.foreground.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
