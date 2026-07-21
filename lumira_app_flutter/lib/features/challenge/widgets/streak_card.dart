import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/challenge_models.dart';

/// 连续打卡卡
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue line 91-110
/// - 火焰图标（72rpx，brand 色）
/// - 标题"连续打卡 N 天"
/// - 副标题鼓励文案
/// - 7 个完成 dot + 1 个 next dot
/// - tip 文案
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key, required this.streak});

  final StreakInfo streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    // Forced fix: neumorphic 风格下使用 tokens.shadowConvexSubtle（主题派生色），canvas→surface
    final isNeumorphic = style == UIStyle.neumorphic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24), // 48rpx → 24dp
      decoration: BoxDecoration(
        color: isNeumorphic ? tokens.surface : tokens.canvas,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isNeumorphic
            ? tokens.shadowConvexSubtle
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: const Offset(3, 3),
                  blurRadius: 7,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  offset: const Offset(-3, -3),
                  blurRadius: 7,
                ),
              ],
      ),
      child: Column(
        children: [
          // 火焰图标
          Icon(
            Icons.local_fire_department,
            size: 36, // 72rpx → 36dp
            color: tokens.brand,
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            '连续打卡 ${streak.currentStreak} 天',
            style: TextStyle(
              fontSize: 20, // 40rpx → 20dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // 副标题
          Text(
            '继续保持，解锁连续打卡奖励！',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          // 7 个 dot + 1 个 next
          Wrap(
            spacing: 6, // 12rpx → 6dp
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < streak.totalDays; i++)
                _StreakDot(
                  done: true,
                  dayNumber: i + 1,
                  tokens: tokens,
                ),
              _StreakDot(
                done: false,
                dayNumber: streak.currentStreak + 1,
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // tip
          Text(
            streak.tipMessage,
            style: TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: tokens.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  const _StreakDot({
    required this.done,
    required this.dayNumber,
    required this.tokens,
  });

  final bool done;
  final int dayNumber;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, // 56rpx → 28dp
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? tokens.brand : tokens.divider,
      ),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check, size: 14, color: tokens.textInverse)
          : Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
