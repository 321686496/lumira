import 'package:flutter/material.dart';

import '../data/capture_scene_mock_data.dart';

/// 场景成就卡片（对应 uni-app SceneAchievementCard.vue）
///
/// 视觉规格来源：lumira-app/src/components/SceneAchievementCard.vue
/// - 三段式：照片统计 / 进度条（level < 5 时显示） / 排行榜
/// - 背景 rgba(0,0,0,0.04) + 20rpx 圆角 + 24rpx padding
class SceneAchievementCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // 24rpx → 12dp
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (achievement-card bg rgba(0,0,0,0.04))
        color: const Color.fromRGBO(0, 0, 0, 0.04),
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
                  const Icon(
                    Icons.photo_library_outlined, // ph-images-square → Icons.photo_library_outlined
                    size: 16, // 32rpx → 16dp
                    // 硬编码颜色，与 uni-app 一致 (ach-icon #2A2520 继承)
                    color: Color(0xFF2A2520),
                  ),
                  const SizedBox(width: 4), // 8rpx → 4dp
                  Text(
                    '${achievement.photoCount} 张',
                    style: const TextStyle(
                      fontSize: 13, // 26rpx → 13dp
                      fontWeight: FontWeight.w500,
                      // 硬编码颜色，与 uni-app 一致 (ach-value #2A2520)
                      color: Color(0xFF2A2520),
                    ),
                  ),
                ],
              ),
              if (achievement.level > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined, // ph-trophy → Icons.emoji_events_outlined
                      size: 16,
                      color: Color(0xFFC9A876),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$sceneName ${achievement.levelName} Lv.${achievement.level}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2A2520),
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
                      // 硬编码颜色，与 uni-app 一致 (ach-progress-bar bg rgba(0,0,0,0.08))
                      backgroundColor: const Color.fromRGBO(0, 0, 0, 0.08),
                      // 硬编码颜色，与 uni-app 一致 (ach-progress-fill #C9A876)
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFFC9A876)),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // 16rpx → 8dp
                Text(
                  '${achievement.photoCount}/${achievement.nextLevelCount}',
                  style: const TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    // 硬编码颜色，与 uni-app 一致 (ach-progress-text #6B635A)
                    color: Color(0xFF6B635A),
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
                const Icon(
                  Icons.local_fire_department_outlined, // ph-fire → Icons.local_fire_department_outlined
                  size: 14, // 28rpx → 14dp
                  // 硬编码颜色，与 uni-app 一致 (ach-rank-icon 继承)
                  color: Color(0xFFC9A876),
                ),
                const SizedBox(width: 4), // 8rpx → 4dp
                Text(
                  '$rankLabel热门 #$rank',
                  style: const TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    fontWeight: FontWeight.w600,
                    // 硬编码颜色，与 uni-app 一致 (ach-rank-text #C9A876)
                    color: Color(0xFFC9A876),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
