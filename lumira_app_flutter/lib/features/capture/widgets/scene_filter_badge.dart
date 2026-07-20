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
        // 硬编码颜色，与 uni-app 一致 (filter-badge bg rgba(0,0,0,0.04))
        color: const Color.fromRGBO(0, 0, 0, 0.04),
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
                        style: const TextStyle(
                          fontSize: 14, // 28rpx → 14dp
                          fontWeight: FontWeight.w600,
                          // 硬编码颜色，与 uni-app 一致 (filter-name #2A2520)
                          color: Color(0xFF2A2520),
                        ),
                      ),
                    ),
                    if (systemFilterLabel.isNotEmpty) ...[
                      const SizedBox(width: 6), // 12rpx → 6dp
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1), // 12rpx×2rpx → 6dp×1dp
                        decoration: BoxDecoration(
                          // 硬编码颜色，与 uni-app 一致 (filter-systemFilter bg rgba(201,168,118,0.12))
                          color: const Color.fromRGBO(201, 168, 118, 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          systemFilterLabel,
                          style: const TextStyle(
                            fontSize: 11, // 22rpx → 11dp
                            // 硬编码颜色，与 uni-app 一致 (filter-systemFilter #C9A876)
                            color: Color(0xFFC9A876),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4), // 8rpx → 4dp
                Text(
                  filter.reason,
                  style: const TextStyle(
                    fontSize: 12, // 24rpx → 12dp
                    height: 1.5,
                    // 硬编码颜色，与 uni-app 一致 (filter-reason #6B635A)
                    color: Color(0xFF6B635A),
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
