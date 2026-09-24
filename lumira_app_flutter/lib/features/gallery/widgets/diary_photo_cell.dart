import 'package:flutter/material.dart';

import '../../../shared/widgets/images/lumira_image.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 日记照片单元格：图片 + 左上心情徽标 + 底部场景/模板标签叠加。
///
/// 标签默认叠加在所属照片内部（微信/小红书风格），便于一眼看出每张照片的
/// 场景/模板归属；三列窄格（时间轴 ≥5 张）时可读性差，由调用方通过
/// [showTags] 关闭照片内叠加，改排在网格下方（见 DiaryTimelineEntry）。
/// 心情徽标与照片内标签均使用黑/白半透明底，属于「叠在照片上」的通用叠加
/// 视觉（跨风格通用，符合 UI 规范例外条款）。
class DiaryPhotoCell extends StatelessWidget {
  const DiaryPhotoCell({
    super.key,
    required this.photo,
    required this.aspectRatio,
    required this.tokens,
    this.onTap,
    this.onLongPress,
    this.showTags = true,
  });

  final DiaryPhoto photo;
  final double aspectRatio;
  final ThemeTokens tokens;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 是否在照片内部底部叠加场景/模板标签（默认 true）。
  /// 三列窄格时关闭，标签改由时间轴 entry 汇总排在网格下方。
  final bool showTags;

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
            // 场景/模板标签浮在照片底部（最多 2 个，纵向堆叠）
            // 用 right + Align 把标签最大宽度约束在照片宽度内，避免窄格溢出被裁剪
            if (showTags && photo.tags.isNotEmpty)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < photo.tags.length && i < 2; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        DiaryTagBadge(tag: photo.tags[i], tokens: tokens),
                      ],
                    ],
                  ),
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

/// 场景/模板标签徽标。
/// [overlay] 为 true（默认）时叠在照片上：黑半透明底 + 白色文字，图标用亮色
/// 保证可读（跨风格通用叠加视觉）；为 false 时排在画布上（时间轴三列网格下方）：
/// 跟随主题的 surface 底 + 分隔线 + 主题色图标，与页面内筛选 chip 取向一致。
class DiaryTagBadge extends StatelessWidget {
  const DiaryTagBadge({
    super.key,
    required this.tag,
    required this.tokens,
    this.overlay = true,
  });
  final DiaryTag tag;
  final ThemeTokens tokens;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    if (overlay) {
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
            // 文字占剩余空间，超出照片宽度时以省略号收尾，避免标签溢出照片
            Flexible(
              child: Text(
                tag.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
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

    // 画布态：图标色映射到主题色板（金=品牌色 / 绿=成功 / 红=危险）
    Color iconColor;
    switch (tag.color) {
      case DiaryTagColor.green:
        iconColor = tokens.success;
        break;
      case DiaryTagColor.red:
        iconColor = tokens.danger;
        break;
      case DiaryTagColor.gold:
        iconColor = tokens.brand;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(1000),
        border: Border.all(color: tokens.divider, width: 1),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            tag.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
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
    final err = Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 24, color: tokens.textTertiary),
    );
    return LumiraImage(
      url,
      fit: BoxFit.cover,
      errorWidget: err,
    );
  }
}
