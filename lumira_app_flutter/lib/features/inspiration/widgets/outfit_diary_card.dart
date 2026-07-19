import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/inspiration_mock_data.dart';

/// 穿搭日记卡片
///
/// 视觉规格来源：lumira-app/src/pages/inspiration/index.vue line 26-59
/// - 标题行：「穿搭日记」+ 「查看日记」链接
/// - streak 行：大数字「7」+「天」+「连续打卡」+ 右侧「连续打卡」tag
/// - 2 张照片横排，3:4 aspect，左下角日期 overlay
class OutfitDiaryCard extends ConsumerWidget {
  const OutfitDiaryCard({super.key, required this.onViewDiary});

  final VoidCallback onViewDiary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.checkroom_outlined, // ph-t-shirt 替代
                    size: 18, // 36rpx → 18dp
                    color: tokens.brand,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '穿搭日记',
                    style: TextStyle(
                      fontSize: 17, // 34rpx → 17dp
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onViewDiary,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      '查看日记',
                      style: TextStyle(
                        fontSize: 13, // 26rpx → 13dp
                        color: tokens.textTertiary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right, // ph-caret-right 替代
                      size: 14,
                      color: tokens.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // streak 行
          Row(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${InspirationMockData.outfitStreakDays}',
                    style: TextStyle(
                      fontSize: 28, // lumira-stat-num 56rpx → 28dp
                      fontWeight: FontWeight.w600,
                      color: tokens.brand,
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(width: 4), // 8rpx → 4dp
                  Text(
                    '天',
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary), // 26rpx → 13dp
                  ),
                ],
              ),
              const SizedBox(width: 12), // 24rpx → 12dp
              Text(
                '连续打卡',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const Spacer(),
              // 连续打卡 tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), // 20rpx/6rpx → 10dp/3dp
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_outlined, size: 12, color: tokens.brandText), // ph-fire 替代
                    const SizedBox(width: 3),
                    Text(
                      '连续打卡',
                      style: TextStyle(
                        fontSize: 11, // 22rpx → 11dp
                        fontWeight: FontWeight.w600,
                        color: tokens.brandText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // 2 张照片横排
          Row(
            children: InspirationMockData.outfitPhotos.map((photo) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: photo == InspirationMockData.outfitPhotos.first ? 10 : 0, // 20rpx → 10dp gap
                  ),
                  child: _OutfitPhotoView(photo: photo),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _OutfitPhotoView extends ConsumerWidget {
  const _OutfitPhotoView({required this.photo});
  final OutfitPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return AspectRatio(
      aspectRatio: 3 / 4, // padding-bottom 133.33% → 3:4
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://picsum.photos/seed/${photo.imageSeed}/400/533',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: tokens.surfaceAlt,
                child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
              ),
            ),
            // 日期 overlay
            Positioned(
              bottom: 8, // 16rpx → 8dp
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // 16rpx/4rpx → 8dp/2dp
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), // rgba(0,0,0,0.4)
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text(
                  photo.date,
                  style: const TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    color: Colors.white,
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
