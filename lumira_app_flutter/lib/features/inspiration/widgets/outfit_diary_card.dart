import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/feedback/lumira_progress.dart';
import '../../gallery/providers/gallery_diary_providers.dart';
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
    final dataAsync = ref.watch(outfitDiaryCardProvider);

    return NeuCard(
      child: dataAsync.when(
        loading: () => SizedBox(
          height: 200,
          child: Center(child: LumiraProgress.circular()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(
            child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)),
          ),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(tokens),
            const SizedBox(height: 16),
            _buildStreakRow(tokens, data.streak),
            const SizedBox(height: 16),
            _buildPhotosRow(tokens, data.photos),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.checkroom_outlined,
              size: 18,
              color: tokens.brand,
            ),
            const SizedBox(width: 8),
            Text(
              '穿搭日记',
              style: TextStyle(
                fontSize: 17,
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
                  fontSize: 13,
                  color: tokens.textTertiary,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakRow(ThemeTokens tokens, int streak) {
    return Row(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$streak',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: tokens.brand,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '天',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          '连续打卡',
          style: TextStyle(fontSize: 13, color: tokens.textSecondary),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_outlined, size: 12, color: tokens.brandText),
              const SizedBox(width: 3),
              Text(
                '连续打卡',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.brandText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosRow(ThemeTokens tokens, List<OutfitPhoto> photos) {
    return Row(
      children: photos.map((photo) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: photo == photos.first ? 10 : 0,
            ),
            child: _OutfitPhotoView(photo: photo),
          ),
        );
      }).toList(),
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
