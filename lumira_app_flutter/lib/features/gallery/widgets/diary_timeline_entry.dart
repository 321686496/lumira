import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../data/gallery_models.dart';
import 'diary_photo_cell.dart';

/// 日记时间轴单条 entry（左日期 + 右照片网格，微信朋友圈式布局）
///
/// 照片布局规则（仿微信朋友圈）：
/// - 1 张：单图横版（4:3）展示
/// - 2~4 张：四宫格（2 列，正方形）
/// - 5~9 张：九宫格（3 列，正方形）
/// - 超过 9 张：仍显示 9 格，最后一格显示 "+N 查看更多"，点击进入当日照片页
/// 标签（场景/模板/心情）叠加在所属照片内部（见 [DiaryPhotoCell]），
/// 不再统一排在网格下方。
class DiaryTimelineEntry extends ConsumerWidget {
  const DiaryTimelineEntry({
    super.key,
    required this.entry,
    this.onPhotoTap,
    this.onPhotoLongPress,
    this.onViewMore,
  });

  final DiaryEntry entry;

  /// 点击照片回调，参数为照片 ID（用于跳转详情页）
  final void Function(String photoId)? onPhotoTap;

  /// 长按照片回调，参数为照片 ID（用于删除照片）
  final void Function(String photoId)? onPhotoLongPress;

  /// 点击「查看更多」回调，参数为该天的日期（用于跳转当日照片页）
  final void Function(DateTime day)? onViewMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final allPhotos = entry.photos;
    final total = allPhotos.length;
    // 最多展示 9 格
    final displayPhotos = total > 9 ? allPhotos.sublist(0, 9) : allPhotos;

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
          // 右：照片网格（标签已叠加在照片内部）
          Expanded(
            child: _buildGrid(displayPhotos, total, tokens),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<DiaryPhoto> photos, int total, ThemeTokens tokens) {
    final count = photos.length;
    if (count == 1) {
      return DiaryPhotoCell(
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
                          onTap: onViewMore == null
                              ? null
                              : () => onViewMore!(entry.day),
                        )
                      : DiaryPhotoCell(
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

/// 九宫格最后一格：照片 + "+N 查看更多" 遮罩（点击进入当日照片页）
class _OverflowCell extends StatelessWidget {
  const _OverflowCell({
    required this.photo,
    required this.overflowCount,
    required this.tokens,
    this.onTap,
  });
  final DiaryPhoto photo;
  final int overflowCount;
  final ThemeTokens tokens;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _OverflowImage(photo: photo, tokens: tokens),
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

/// 溢出格的图片渲染（与 [DiaryPhotoCell] 内部逻辑一致，独立避免依赖）
class _OverflowImage extends StatelessWidget {
  const _OverflowImage({required this.photo, required this.tokens});
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
