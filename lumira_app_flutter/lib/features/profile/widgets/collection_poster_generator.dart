import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/images/lumira_image.dart';

/// 精选集海报内容 Widget（公开，供 PosterGenerator 包裹渲染）
///
/// 渲染品牌标、精选集名称、描述、照片拼图（最多 9 张）、统计信息与水印，
/// 与详情页九宫格保持一致，方便导出/分享到社交媒体。
class CollectionPosterContent extends StatelessWidget {
  const CollectionPosterContent({
    super.key,
    required this.tokens,
    required this.name,
    required this.description,
    required this.photoCount,
    required this.createdAt,
    required this.photos,
  });

  final ThemeTokens tokens;
  final String name;
  final String? description;
  final int photoCount;
  final int createdAt;
  final List<GalleryItemRecord> photos;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final urls = photos
        .map((p) => p.dataUrl ?? p.filePath)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .take(9)
        .toList();
    final created = DateFormat('yyyy-MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
    final desc = (description ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.surface],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 品牌标
          Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 18, color: t.brand),
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
          // 标题区
          Text(
            name.isEmpty ? '我的精选集' : name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Noto Serif SC',
              color: t.textPrimary,
            ),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: t.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          // 照片拼图
          if (urls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PhotoGrid(tokens: t, urls: urls),
            ),
          const SizedBox(height: 20),
          // 统计信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.collections_outlined, size: 16, color: t.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '共收录 $photoCount 张照片 · $created',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片拼图（自适应 1-9 张，3 列）
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tokens, required this.urls});
  final ThemeTokens tokens;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    int crossCount;
    if (count <= 1) {
      crossCount = 1;
    } else if (count <= 4) {
      crossCount = 2;
    } else {
      crossCount = 3;
    }

    final rows = (count / crossCount).ceil();
    final cellHeight = count <= 1 ? 240.0 : 200.0;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < crossCount; c++)
                Expanded(
                  child: (r * crossCount + c) < count
                      ? Container(
                          height: cellHeight,
                          margin: EdgeInsets.only(
                            right: c < crossCount - 1 ? 3 : 0,
                            bottom: r < rows - 1 ? 3 : 0,
                          ),
                          child: _buildImage(urls[r * crossCount + c]),
                        )
                      : SizedBox(height: cellHeight),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    final fallback = Container(
      color: tokens.brandSubtle,
      child: Icon(Icons.image_outlined, size: 24, color: tokens.brand),
    );
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
          url: url, fit: BoxFit.cover, errorWidget: fallback);
    }
    return LumiraImage(url, fit: BoxFit.cover, errorWidget: fallback);
  }
}