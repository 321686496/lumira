import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/challenge_models.dart';

/// 明日挑战预览卡（带模糊层 + 遮罩 + "明日揭晓" badge）
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue line 70-87
/// - blur-layer: filter: blur(10rpx) 模糊文字
/// - preview-mask: 半透明遮罩 + backdrop-filter blur(4rpx)
/// - 中央 badge "明日揭晓"
class TomorrowPreviewCard extends ConsumerWidget {
  const TomorrowPreviewCard({super.key, required this.preview});

  final TomorrowPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    // Forced fix: neumorphic 风格下添加 shadowConvexSubtle 双向阴影
    final isNeumorphic = style == UIStyle.neumorphic;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
        boxShadow: isNeumorphic ? tokens.shadowConvexSubtle : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
        child: Stack(
          children: [
            // 卡片底色
            Container(
              color: tokens.canvas,
              padding: const EdgeInsets.all(20), // 40rpx → 20dp
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主标题（模糊）
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                    child: Text(
                      preview.mainTitle,
                      style: TextStyle(
                        fontSize: 16, // 32rpx → 16dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 附加挑战列表（模糊）
                  ...preview.subTitles.map(
                    (title) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13, // 26rpx → 13dp
                            color: tokens.textSecondary,
                            height: 1.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 半透明遮罩
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: tokens.canvas.withOpacity(0.4),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '明日揭晓',
                      style: TextStyle(
                        fontSize: 11, // 22rpx → 11dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textInverse,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
