import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/home_mock_data.dart';

/// 最近拍摄卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 166-187 + style line 698-803
/// - 28rpx→14dp 圆角
/// - 图片 aspect ratio 3:4 (padding-bottom 133.33%)
/// - 标签左上：white 90% + blur 8px + brand 文字
/// - 匹配度右下：dark 60% bg + white 文字
/// - 进度右下：brand bg + white 文字
class RecentShotCard extends ConsumerWidget {
  const RecentShotCard({
    super.key,
    required this.recent,
    required this.onTap,
  });

  final RecentShot recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          // neumorphic 风格：surface 背景 + 双向凸起阴影，移除 border
          // 其他风格：canvas 背景 + divider 1dp 边框
          color: isNeumorphic ? tokens.surface : tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border: isNeumorphic
              ? null
              : Border.all(color: tokens.divider, width: 1),
          boxShadow: isNeumorphic ? tokens.shadowConvex : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://picsum.photos/seed/${recent.imageSeed}/400/600',
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
                    // 分类标签（左上）
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1000),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            color: Colors.white.withOpacity(0.9),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  recent.icon,
                                  size: 10, // 20rpx → 10dp
                                  color: tokens.brand,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  recent.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.brand,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 匹配度或进度（右下）
                    if (recent.match.isNotEmpty || recent.progress.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: recent.progress.isNotEmpty
                                ? tokens.brand
                                : const Color(0x991A1A1A),
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Text(
                            recent.progress.isNotEmpty
                                ? recent.progress
                                : recent.match,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recent.name,
                      style: TextStyle(
                        fontSize: 13, // 26rpx → 13dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_walk_outlined, // ph-footprints
                          size: 11, // 22rpx → 11dp
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recent.steps} 步',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textTertiary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
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
