import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/capture_scene_mock_data.dart';

/// 场景成就卡片（对应 uni-app SceneAchievementCard.vue）
///
/// 视觉规格来源：lumira-app/src/components/SceneAchievementCard.vue
/// - 三段式：照片统计 / 进度条（level < 5 时显示） / 排行榜
/// - 背景跟随主题 surfaceAlt + 20rpx 圆角 + 24rpx padding
class SceneAchievementCard extends ConsumerWidget {
  const SceneAchievementCard({
    super.key,
    required this.achievement,
    required this.sceneName,
    this.rank,
    this.rankLabel = '本周',
  });

  final SceneAchievement achievement;
  final String sceneName;
  final int? rank;
  final String rankLabel;

  double get _progressPercent {
    if (achievement.nextLevelCount <= 0) return 100;
    final p = (achievement.photoCount / achievement.nextLevelCount) * 100;
    if (p > 100) return 100;
    if (p < 0) return 0;
    return p;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：颜色随设置里的 UI 风格 / 主题色切换
    final appTheme = ref.watch(appThemeProvider);
    final ThemeTokens tokens = appTheme.tokens;
    return Container(
      padding: const EdgeInsets.all(12), // 24rpx → 12dp
      decoration: appTheme.style == UIStyle.glass
          ? BoxDecoration(
              // 玻璃风格：半透明底色 + 细白描边 + 柔和投影
              color: ThemeTokens.glassFill(tokens),
              borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
              border: Border.all(
                color: ThemeTokens.glassBorder(tokens),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 6),
                  blurRadius: 20,
                ),
              ],
            )
          : BoxDecoration(
              // 卡片底色跟随主题 surfaceAlt
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：照片统计 + 等级
          Wrap(
            spacing: 16, // 32rpx → 16dp
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined, // ph-images-square → Icons.photo_library_outlined
                    size: 16, // 32rpx → 16dp
                    // 图标色跟随主题 textPrimary
                    color: tokens.textPrimary,
                  ),
                  const SizedBox(width: 4), // 8rpx → 4dp
                  Text(
                    '${achievement.photoCount} 张',
                    style: TextStyle(
                      fontSize: 13, // 26rpx → 13dp
                      fontWeight: FontWeight.w500,
                      // 文字色跟随主题 textPrimary
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              if (achievement.level > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined, // ph-trophy → Icons.emoji_events_outlined
                      size: 16,
                      // 奖杯图标色跟随主题 brand
                      color: tokens.brand,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sceneName ${achievement.levelName} Lv.${achievement.level}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        // 文字色跟随主题 textPrimary
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8), // 16rpx → 8dp
          // 进度条
          if (achievement.level < 5) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3), // 6rpx → 3dp
                    child: LinearProgressIndicator(
                      value: _progressPercent / 100,
                      minHeight: 6, // 12rpx → 6dp
                      // 进度条底色跟随主题 surfaceAlt
                      backgroundColor: tokens.surfaceAlt,
                      // 进度条填充色跟随主题 brand
                      valueColor:
                          AlwaysStoppedAnimation<Color>(tokens.brand),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // 16rpx → 8dp
                Text(
                  '${achievement.photoCount}/${achievement.nextLevelCount}',
                  style: TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    // 文字色跟随主题 textSecondary
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // 排行榜
          if (rank != null)
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined, // ph-fire → Icons.local_fire_department_outlined
                  size: 14, // 28rpx → 14dp
                  // 图标色跟随主题 brand
                  color: tokens.brand,
                ),
                const SizedBox(width: 4), // 8rpx → 4dp
                Text(
                  '$rankLabel热门 #$rank',
                  style: TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    fontWeight: FontWeight.w600,
                    // 文字色跟随主题 brand
                    color: tokens.brand,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}