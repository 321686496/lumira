import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 日记时间轴单条 entry（左日期 + 右双照片）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/diary.vue line 56-103
class DiaryTimelineEntry extends ConsumerWidget {
  const DiaryTimelineEntry({super.key, required this.entry, this.onPhotoTap});

  final DiaryEntry entry;

  /// 点击照片回调，参数为照片 ID（用于跳转详情页）
  final void Function(String photoId)? onPhotoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左：日期列
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          const SizedBox(width: 12),
          // 右：双照片
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entry.photos
                  .map((p) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: entry.photos.last == p ? 0 : 8,
                          ),
                          child: _PhotoCard(
                            photo: p,
                            onTap: onPhotoTap == null ? null : () => onPhotoTap!(p.id),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends ConsumerWidget {
  const _PhotoCard({required this.photo, this.onTap});
  final DiaryPhoto photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
            child: AspectRatio(
              aspectRatio: 2 / 3, // 400×600
              child: _buildImage(tokens),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: photo.tags.map((t) => _DiaryTagChip(tag: t)).toList(),
          ),
        ],
      ),
    );
  }

  /// 图片源可能是网络 URL 或本地文件路径（与 PhotoCell 一致）
  Widget _buildImage(ThemeTokens tokens) {
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

class _DiaryTagChip extends ConsumerWidget {
  const _DiaryTagChip({required this.tag});
  final DiaryTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
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
