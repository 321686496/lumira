import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 日记照片单元格：图片 + 左上心情徽标 + 底部场景/模板标签叠加。
///
/// 标签不再统一放在时间轴网格下方，而是叠加在所属照片内部（微信/小红书风格），
/// 便于一眼看出每张照片的场景/模板归属。心情徽标与标签均使用黑/白半透明底，
/// 属于「叠在照片上」的通用叠加视觉（跨风格通用，符合 UI 规范例外条款）。
class DiaryPhotoCell extends StatelessWidget {
  const DiaryPhotoCell({
    super.key,
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
            // 场景/模板标签浮在照片底部（最多 2 个，纵向堆叠避免窄格溢出）
            if (photo.tags.isNotEmpty)
              Positioned(
                left: 6,
                bottom: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < photo.tags.length && i < 2; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _TagBadge(tag: photo.tags[i], tokens: tokens),
                    ],
                  ],
                ),
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

/// 照片底部的场景/模板标签徽标：黑半透明底 + 白色文字，图标带主题色区分场景/模板
class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag, required this.tokens});
  final DiaryTag tag;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    // 标签图标色：随标签类型区分场景/模板（叠在照片上用亮色保证可读）
    Color iconColor;
    switch (tag.color) {
      case DiaryTagColor.green:
        iconColor = const Color(0xFF7EDB9C);
        break;
      case DiaryTagColor.red:
        iconColor = const Color(0xFFFF9B9B);
        break;
      case DiaryTagColor.gold:
        iconColor = tokens.brandLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 10, color: iconColor),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              tag.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.2,
              ),
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
      return CachedNetworkImage(
        url: url,
        fit: BoxFit.cover,
        errorWidget: Container(
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
