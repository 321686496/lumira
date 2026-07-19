import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/home_mock_data.dart';

/// 场景推荐卡片
///
/// 视觉规格来源：lumira-app/src/components/ScenePresetView.vue card variant
/// + lumira-app/src/pages/home/index.vue line 132-150
/// - 2 列网格（home 页负责 GridView，本卡片只负责单个卡片）
/// - 28rpx→14dp 圆角
/// - 图片 aspect ratio 3:4 (padding-bottom 133.33%)
/// - 标签：左上角，圆角 9999rpx，brand bg 或 dark bg
class SceneRecoCard extends ConsumerWidget {
  const SceneRecoCard({
    super.key,
    required this.scene,
    required this.onTap,
    this.showPhotoCount = true,
    this.footer,
  });

  final SceneReco scene;
  final VoidCallback onTap;
  final bool showPhotoCount;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
          border: Border.all(color: tokens.divider, width: 1), // 2rpx → 1dp
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区
              AspectRatio(
                aspectRatio: 3 / 4, // padding-bottom 133.33% → 3:4
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // picsum 图片（占位）
                    Image.network(
                      'https://picsum.photos/seed/${scene.imageSeed}/400/600',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ),
                    // 标签
                    Positioned(
                      top: 8, // 16rpx → 8dp
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, // 16rpx → 8dp
                          vertical: 3, // 6rpx → 3dp
                        ),
                        decoration: BoxDecoration(
                          color: scene.badgeBrand
                              ? tokens.brand
                              : const Color(0x991A1A1A), // rgba(26,26,26,0.6)
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        child: Text(
                          scene.badgeText,
                          style: const TextStyle(
                            fontSize: 10, // 20rpx → 10dp
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0.04 * 10,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 文字区
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), // 28/24/28/28 rpx → 14/12/14/14 dp
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scene.name,
                      style: TextStyle(
                        fontSize: 14, // 28rpx → 14dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4), // 8rpx → 4dp
                    Text(
                      scene.vibe,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11, // 22rpx → 11dp
                        color: tokens.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    // 照片数行：条件渲染（home 页默认 showPhotoCount=true 行为不变）
                    if (showPhotoCount) ...[
                      const SizedBox(height: 6), // 12rpx → 6dp
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 12, // 24rpx → 12dp
                            color: Color(0xFFC9A876), // scene-stat-icon 色
                          ),
                          const SizedBox(width: 4), // 8rpx → 4dp
                          Text(
                            '${scene.photoCount}',
                            style: const TextStyle(
                              fontSize: 11, // 22rpx → 11dp
                              color: Color(0xFF6B635A),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // footer widget：条件渲染（home 页默认 footer=null 不渲染）
                    if (footer != null) ...[
                      const SizedBox(height: 6),
                      footer!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
