import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import 'checkin_common.dart';

/// 展示海报：可直接调用 [showCheckinPoster] 生成/导出/分享探店足迹海报。
Future<void> showCheckinPoster({
  required BuildContext context,
  required ThemeTokens tokens,
  required CheckinListItem item,
  required GlobalKey posterKey,
}) {
  return PosterGenerator.showPoster(
    context: context,
    tokens: tokens,
    title: '探店足迹海报',
    content: CheckinPosterContent(tokens: tokens, item: item),
    posterKey: posterKey,
    shareSubject: '如画 LUMIRA · 探店足迹',
    shareText: '推荐你这家店：${item.record.name}',
    fileNamePrefix: 'checkin_${item.record.id}',
  );
}

/// 探店足迹海报内容 Widget（公开，供 PosterGenerator 包裹渲染）
///
/// 顶部品牌标 + 封面大图 + 店名 / 评分 / 分类 / 地点 / 打卡时间 + 品牌水印。
class CheckinPosterContent extends StatelessWidget {
  const CheckinPosterContent({
    super.key,
    required this.tokens,
    required this.item,
  });

  final ThemeTokens tokens;
  final CheckinListItem item;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final record = item.record;
    final category = checkinCategoryOf(record.category);
    final rating = record.rating;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.canvas],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 品牌标
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: t.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 封面大图
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CheckinPhotoImage(
                url: item.coverPhotoUrl,
                tokens: t,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 店名
          Text(
            record.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 评分 + 分类
          Row(
            children: [
              if (rating > 0) ...[
                Text(
                  '$rating.0',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: t.brand,
                    fontFamily: 'Courier New',
                  ),
                ),
                const SizedBox(width: 8),
                CheckinRatingStars(rating: rating, tokens: t, size: 16),
                const SizedBox(width: 12),
              ],
              CheckinCategoryTag(category: category, tokens: t),
            ],
          ),
          const SizedBox(height: 16),
          // 地点
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: t.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  record.place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: t.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (record.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              record.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: t.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 打卡时间 + 水印
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: t.textTertiary),
              const SizedBox(width: 4),
              Text(
                formatCheckinDate(record.visitedAt),
                style: TextStyle(fontSize: 12, color: t.textTertiary),
              ),
              const Spacer(),
              Text(
                '如画 LUMIRA · 探店足迹',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: t.brand.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}