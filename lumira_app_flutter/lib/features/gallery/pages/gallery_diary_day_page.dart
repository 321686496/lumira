import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../providers/gallery_diary_providers.dart';
import '../widgets/diary_photo_cell.dart';

/// 拍摄日记某一天的当日照片页。
///
/// 从时间轴「查看更多」进入：展示该天拍摄的全部照片（不受 9 格上限限制），
/// 每张照片复用 [DiaryPhotoCell]（心情徽标 + 场景/模板标签叠加在照片内部），
/// 点击进入相册详情页。
class GalleryDiaryDayPage extends ConsumerWidget {
  const GalleryDiaryDayPage({super.key, required this.day});

  /// 具体日期（仅取年月日，用于 diaryDayProvider 查询该天全部照片）
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final dayOnly = DateTime(day.year, day.month, day.day);
    final photosAsync = ref.watch(diaryDayProvider(dayOnly));

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.canvas,
        elevation: 0,
        title: Text(
          '${DateFormat('M月d日').format(dayOnly)} · 拍摄',
          style: TextStyle(color: tokens.textPrimary),
        ),
        leading: BackButton(color: tokens.textPrimary),
      ),
      body: photosAsync.when(
        loading: () => Center(child: LumiraProgress.circular()),
        error: (e, _) => Center(
          child: Text(
            '加载失败：$e',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Text(
                '这一天还没有照片',
                style: TextStyle(color: tokens.textSecondary),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final photo = photos[i];
              return DiaryPhotoCell(
                photo: photo,
                aspectRatio: 1,
                tokens: tokens,
                onTap: () => GoRouter.of(context).push(
                  RouteNames.build(RouteNames.galleryDetail, {
                    RouteNames.paramPhotoId: photo.id,
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
