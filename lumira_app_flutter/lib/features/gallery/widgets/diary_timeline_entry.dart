import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 日記時間軸單條 entry（左日期 + 右雙照片，固定佈局）
///
/// 視覺規格來源：lumira-app/src/pages/gallery/diary.vue（固定雙照片佈局）
/// 修復：不再無限制地用 Expanded 平鋪所有照片，始終保持 2 列。
/// 僅 1 張時左對齊 + 右側留空；≥3 張時第二張顯示 "+N" 遮罩。
class DiaryTimelineEntry extends ConsumerWidget {
  const DiaryTimelineEntry({super.key, required this.entry, this.onPhotoTap, this.onPhotoLongPress});

  final DiaryEntry entry;

  /// 點擊照片回調，參數為照片 ID（用於跳轉詳情頁）
  final void Function(String photoId)? onPhotoTap;

  /// 長按照片回調，參數為照片 ID（用於刪除照片）
  final void Function(String photoId)? onPhotoLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final allPhotos = entry.photos;

    // 固定顯示前 2 張，第 3 張起用 +N 遮罩提示
    final displayPhotos = allPhotos.length <= 2
        ? allPhotos
        : allPhotos.sublist(0, 2);
    final overflow = allPhotos.length > 2 ? allPhotos.length - 2 : 0;

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
          // 右：照片區域（0 張、1 張、2+ 張三種情況）
          Expanded(
            child: _buildPhotosRow(displayPhotos, overflow, tokens),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosRow(List<DiaryPhoto> photos, int overflow, ThemeTokens tokens) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }
    if (photos.length == 1) {
      // 單張：首图横版（4:3）展示，右半邊留空保持對齊
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PhotoCard(
              photo: photos[0],
              tokens: tokens,
              isFirst: true,
              onTap: onPhotoTap == null ? null : () => onPhotoTap!(photos[0].id),
              onLongPress: onPhotoLongPress == null ? null : () => onPhotoLongPress!(photos[0].id),
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      );
    }
    // 雙照片：第一張横版引导，第二張可能有 +N 遮罩
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PhotoCard(
            photo: photos[0],
            tokens: tokens,
            isFirst: true,
            onTap: onPhotoTap == null ? null : () => onPhotoTap!(photos[0].id),
            onLongPress: onPhotoLongPress == null ? null : () => onPhotoLongPress!(photos[0].id),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: overflow > 0
              ? _OverflowCard(
                  photo: photos[1],
                  overflowCount: overflow,
                  tokens: tokens,
                  onTap: () => onPhotoTap?.call(photos[1].id),
                  onLongPress: onPhotoLongPress == null ? null : () => onPhotoLongPress!(photos[1].id),
                )
              : _PhotoCard(
                  photo: photos[1],
                  tokens: tokens,
                  onTap: onPhotoTap == null ? null : () => onPhotoTap!(photos[1].id),
                  onLongPress: onPhotoLongPress == null ? null : () => onPhotoLongPress!(photos[1].id),
                ),
        ),
      ],
    );
  }
}

/// 第二張照片 + 溢出數量遮罩
class _OverflowCard extends StatelessWidget {
  const _OverflowCard({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PhotoImage(photo: photo, tokens: tokens),
                  // 半透明遮罩 + "+N"
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
                            '更多',
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
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: photo.tags.map((t) => _DiaryTagChip(tag: t, tokens: tokens)).toList(),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.tokens,
    this.isFirst = false,
    this.onTap,
    this.onLongPress,
  });
  final DiaryPhoto photo;
  final ThemeTokens tokens;
  final bool isFirst;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              // 每日首张横版引导（4:3），其余保持竖版（2:3）
              aspectRatio: isFirst ? 4 / 3 : 2 / 3,
              child: _PhotoImage(photo: photo, tokens: tokens),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: photo.tags.map((t) => _DiaryTagChip(tag: t, tokens: tokens)).toList(),
          ),
        ],
      ),
    );
  }
}

/// 提取圖片渲染邏輯，讓 _PhotoCard 和 _OverflowCard 共用
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
