import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/home_mock_data.dart';
import '../data/home_providers.dart';

/// 连续拍摄卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 68-90 + style line 484-569
/// - streak-head: title (icon+text) + num (大数字+单位)
/// - streak-week: 7 个圆点（done 实心+对号；today 虚线圆+日期数字）
///
/// 数据来源：homeStreakProvider（基于 shootingCheckinProvider 统一拍摄打卡数据）
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final asyncStreak = ref.watch(homeStreakProvider);

    // 真实数据：loading/error 时用 empty 兜底（避免空白）
    final streak = asyncStreak.valueOrNull ?? HomeStreakStatus.empty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), // 40rpx → 20dp
      child: GestureDetector(
        onTap: () {
          GoRouter.of(context).push(RouteNames.galleryDiary);
        },
        behavior: HitTestBehavior.opaque,
        child: NeuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // streak-head
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 标题
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 20, // 40rpx → 20dp
                      color: tokens.brand,
                    ),
                    const SizedBox(width: 8), // 16rpx → 8dp
                    Text(
                      '连续拍摄',
                      style: TextStyle(
                        fontSize: 15, // 30rpx → 15dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                // 天数
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${streak.streakDays}',
                      style: TextStyle(
                        fontSize: 22, // 44rpx → 22dp
                        fontWeight: FontWeight.w700,
                        color: tokens.brand,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 2), // 4rpx → 2dp
                    Text(
                      '天',
                      style: TextStyle(
                        fontSize: 12, // 24rpx → 12dp
                        color: tokens.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18), // 36rpx → 18dp
            // streak-week
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: streak.weekDays
                  .map((day) => _StreakDay(day: day, tokens: tokens))
                  .toList(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StreakDay extends StatelessWidget {
  const _StreakDay({required this.day, required this.tokens});

  final WeekDay day;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, // 56rpx → 28dp
          height: 28,
          decoration: BoxDecoration(
            color: day.today
                ? tokens.brand.withOpacity(0.15)
                : tokens.brand,
            shape: BoxShape.circle,
            border: day.today
                ? Border.all(
                    color: tokens.brand,
                    width: 2, // 4rpx → 2dp
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : null,
          ),
          child: day.done
              ? const Icon(
                  Icons.check,
                  size: 12, // 24rpx → 12dp
                  color: Colors.white,
                )
              : Center(
                  child: Text(
                    day.label,
                    style: TextStyle(
                      fontSize: 10, // 20rpx → 10dp
                      fontWeight: FontWeight.w600,
                      color: tokens.brand,
                      height: 1,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4), // 8rpx → 4dp
        Text(
          day.label,
          style: TextStyle(
            fontSize: 10, // 20rpx → 10dp
            color: tokens.textTertiary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
