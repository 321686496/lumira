import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../gallery/data/gallery_models.dart';
import '../../gallery/widgets/photo_cell.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 某模板在本机拍摄的全部照片网格页。
///
/// 从模板详情页「用此模板拍摄的照片 → 查看全部」进入，
/// 复用 [PhotoCell] 格 + 点击进入 [RouteNames.galleryDetail]。
class TemplatePhotosPage extends ConsumerWidget {
  const TemplatePhotosPage({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final daoAsync = ref.watch(galleryDaoProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.canvas,
        elevation: 0,
        title: Text(
          '模板照片',
          style: TextStyle(color: tokens.textPrimary),
        ),
        leading: BackButton(color: tokens.textPrimary),
      ),
      body: daoAsync.when(
        loading: () => Center(child: LumiraProgress.circular()),
        error: (e, _) => Center(
          child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)),
        ),
        data: (dao) => FutureBuilder<List<GalleryItemRecord>>(
          future: dao.getByTemplate(templateId),
          builder: (context, snap) {
            final photos = snap.data ?? const <GalleryItemRecord>[];
            if (photos.isEmpty) {
              return Center(
                child: Text(
                  '还没有用此模板拍摄的照片',
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
                final record = photos[i];
                final galleryPhoto = GalleryPhoto.fromRecord(record);
                return PhotoCell(
                  photo: galleryPhoto,
                  onTap: () => GoRouter.of(context).push(
                    RouteNames.build(RouteNames.galleryDetail, {
                      RouteNames.paramPhotoId: record.id,
                    }),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}