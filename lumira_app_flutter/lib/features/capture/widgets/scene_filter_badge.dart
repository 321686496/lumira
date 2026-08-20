import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/capture_scene_mock_data.dart';

/// 场景推荐滤镜徽章（对应 uni-app SceneFilterBadge.vue）
///
/// 视觉规格来源：lumira-app/src/components/SceneFilterBadge.vue
/// - 横向布局：左侧 film-strip 图标，右侧滤镜名 + 系统滤镜标签 + 滤镜理由
/// - 背景 rgba(0,0,0,0.04) + 20rpx 圆角 + 24rpx padding
class SceneFilterBadge extends ConsumerWidget {
  const SceneFilterBadge({super.key, required this.filter});

  final SceneFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final lutName = CaptureSceneMockData.getLutLabel(filter.lut);
    final systemFilterLabel =
        CaptureSceneMockData.getSystemFilterLabel(filter.systemFilter);

    return Container(
      padding: const EdgeInsets.all(12), // 24rpx → 12dp
      decoration: BoxDecoration(
        // 表面底色跟随主题（原先写死 rgba(0,0,0,0.04)）
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.movie_outlined, // ph-film-strip → Icons.movie_outlined
            size: 20, // 40rpx → 20dp
            // 硬编码颜色，与 uni-app 一致 (filter-icon 继承 — 用 brandDeep)
            color: tokens.brandDeep,
          ),
          const SizedBox(width: 8), // 16rpx → 8dp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        lutName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14, // 28rpx → 14dp
                          fontWeight: FontWeight.w600,
                          // 主文字色跟随主题（原先写死 #2A2520）
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (systemFilterLabel.isNotEmpty) ...[
                      const SizedBox(width: 6), // 12rpx → 6dp
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1), // 12rpx×2rpx → 6dp×1dp
                        decoration: BoxDecoration(
                          // 标签底色用品牌色低透明（原先写死 rgba(201,168,118,0.12)）
                          color: tokens.brand.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          systemFilterLabel,
                          style: TextStyle(
                            fontSize: 11, // 22rpx → 11dp
                            // 品牌色文字（原先写死 #C9A876）
                            color: tokens.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4), // 8rpx → 4dp
                Text(
                  filter.reason,
                  style: TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    height: 1.5,
                    // 次要文字色跟随主题（原先写死 #6B635A）
                    color: tokens.textSecondary,
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
