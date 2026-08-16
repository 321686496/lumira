import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 日记时间轴单条 entry（左日期 + 右照片网格，微信朋友圈式布局）
///
/// 照片布局规则（仿微信朋友圈）：
/// - 1 张：单图横版（4:3）展示
/// - 2~4 张：四宫格（2 列，正方形）
/// - 5~9 张：九宫格（3 列，正方形）
/// - 超过 9 张：仍显示 9 格，最后一格显示 "+N 查看更多"
/// 标签（场景/模板/心情）去重后统一展示在照片网格下方，避免每张图重复。
class DiaryTimelineEntry extends ConsumerWidget {
  const DiaryTimelineEntry({
    super.key,
    required this.entry,
    this.onPhotoTap,
    this.onPhotoLongPress,
  });

  final DiaryEntry entry;

  /// 点击照片回调，参数为照片 ID（用于跳转详情页）
  final void Function(String photoId)? onPhotoTap;

  /// 长按照片回调，参数为照片 ID（用于删除照片）
  final void Function(String photoId)? onPhotoLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final allPhotos = entry.photos;
    final total = allPhotos.length;
    // 最多展示 9 格
    final displayPhotos = total > 9 ? allPhotos.sublist(0, 9) : allPhotos;
    // 标签去重（按 label），统一展示在网格下方
    final tags = <DiaryTag>[];
    final seen = <String>{};
    for (final p in allPhotos) {
      for (final t in p.tags) {
        if (seen.add(t.label)) tags.add(t);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左：日期列 + 时间轴节点
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间轴节点圆点（今天高亮）
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, bottom: 6),
                  decoration: BoxDecoration(
                    color: entry.isToday
                        ? tokens.brand
                        : tokens.textTertiary.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: entry.isToday
                        ? Border.all(color: tokens.brandLight, width: 2)
                        : null,
                  ),
                ),
                Text(
                  entry.weekday,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.date,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: entry.isToday ? tokens.brand : tokens.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // 时间轴引导线
          Container(
            width: 1,
            margin: const EdgeInsets.only(left: 4, right: 12),
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tokens.brand.withOpacity(0.5),
                  tokens.brand.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // 右：照片网格 + 标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGrid(displayPhotos, total, tokens),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        tags.map((t) => _DiaryTagChip(tag: t, tokens: tokens)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<DiaryPhoto> photos, int total, ThemeTokens tokens) {
    final count = photos.length;
    if (count == 1) {
      return _PhotoCell(
        photo: photos[0],
        aspectRatio: 4 / 3,
        tokens: tokens,
        onTap: onPhotoTap == null ? null : () => onPhotoTap!(photos[0].id),
        onLongPress:
            onPhotoLongPress == null ? null : () => onPhotoLongPress!(photos[0].id),
      );
    }
    final columns = count <= 4 ? 2 : 3;
    final rows = (count / columns).ceil();
    const spacing = 6.0;
    // 超过 9 张时最后一格显示 "+N"
    final overflowN = total > 9 ? total - 8 : 0;

    return Column(
      children: List.generate(rows, (r) {
        return Padding(
          padding: r == rows - 1
              ? EdgeInsets.zero
              : const EdgeInsets.only(bottom: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columns, (c) {
              final idx = r * columns + c;
              if (idx >= count) return const Expanded(child: SizedBox.shrink());
              final photo = photos[idx];
              final isOverflowCell = overflowN > 0 && idx == 8;
              return Expanded(
                child: Padding(
                  padding: c == columns - 1
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(right: spacing),
                  child: isOverflowCell
                      ? _OverflowCell(
                          photo: photo,
                          overflowCount: overflowN,
                          tokens: tokens,
                          onTap: () => onPhotoTap?.call(photo.id),
                          onLongPress: onPhotoLongPress == null
                              ? null
                              : () => onPhotoLongPress!(photo.id),
                        )
                      : _PhotoCell(
                          photo: photo,
                          aspectRatio: 1,
                          tokens: tokens,
                          onTap: onPhotoTap == null
                              ? null
                              : () => onPhotoTap!(photo.id),
                          onLongPress: onPhotoLongPress == null
                              ? null
                              : () => onPhotoLongPress!(photo.id),
                        ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

/// 单张照片卡片（横版 / 正方形），左上角叠加心情徽标
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.photo,
    required this.aspectRatio,
    required this.tokens,
    this.onTap,
    this.onLongPress,
  });
  final DiaryPhoto photo;
  final double aspectRatio;
  final ThemeTokens tokens;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _PhotoImage(photo: photo, tokens: tokens),
            ),
            // 心情浮在照片左上角
            if (photo.mood != null)
              Positioned(
                top: 6,
                left: 6,
                child: _MoodBadge(mood: photo.mood!, tokens: tokens),
              ),
          ],
        ),
      ),
    );
  }
}

/// 照片角上的心情徽标（圆角小胶囊：表情图标 + 心情名）
class _MoodBadge extends StatelessWidget {
  const _MoodBadge({required this.mood, required this.tokens});
  final String mood;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_moodIconFor(mood), size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            mood,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 心情名 → 图标映射（与 CapturePreviewMockData.moods 保持一致）
IconData _moodIconFor(String mood) {
  switch (mood) {
    case '开心':
      return Icons.sentiment_satisfied;
    case '甜酷':
      return Icons.wb_sunny_outlined;
    case '温柔':
      return Icons.local_florist_outlined;
    case '复古':
      return Icons.movie_outlined;
    case '清新':
      return Icons.eco_outlined;
    case '文艺':
      return Icons.palette_outlined;
    case '治愈':
      return Icons.grass_outlined;
    default:
      return Icons.sentiment_satisfied;
  }
}

/// 九宫格最后一格：照片 + "+N 查看更多" 遮罩
class _OverflowCell extends StatelessWidget {
  const _OverflowCell({
    required this.photo,
    required this.overflowCount,
    required this.tokens,
    this.onTap,
    this.onLongPress,
  });
  final DiaryPhoto photo;
  final int overflowCount;
  final ThemeTokens tokens;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PhotoImage(photo: photo, tokens: tokens),
              // 半透明遮罩 + "+N 查看更多"
              Container(
                color: Colors.black.withOpacity(0.45),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+$overflowCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '查看更多',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 提取图片渲染逻辑，让单图 / 网格 / 溢出格共用
class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.photo, required this.tokens});
  final DiaryPhoto photo;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final url = photo.img;
    if (url.isEmpty) {
      return Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.image_outlined, size: 24, color: tokens.textTertiary),
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: tokens.surfaceAlt,
          child: Icon(Icons.image_outlined, size: 24, color: tokens.textTertiary),
        ),
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.image_outlined, size: 24, color: tokens.textTertiary),
      ),
    );
  }
}

class _DiaryTagChip extends StatelessWidget {
  const _DiaryTagChip({required this.tag, required this.tokens});
  final DiaryTag tag;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colors = _TagColors.of(tag.color, tokens);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 10, color: colors.fg),
          const SizedBox(width: 2),
          Text(
            tag.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.fg,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TagColors {
  final Color fg;
  final Color bg;
  const _TagColors._(this.fg, this.bg);

  static _TagColors of(DiaryTagColor c, ThemeTokens tokens) {
    switch (c) {
      case DiaryTagColor.gold:
        return _TagColors._(tokens.brand, tokens.brandSubtle);
      case DiaryTagColor.green:
        return _TagColors._(tokens.success, tokens.successSubtle);
      case DiaryTagColor.red:
        return _TagColors._(tokens.danger, tokens.dangerSubtle);
    }
  }
}