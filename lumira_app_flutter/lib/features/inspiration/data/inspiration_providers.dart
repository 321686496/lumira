import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../academy/data/academy_models.dart';
import 'inspiration_content.dart';

Future<String?> _topCategoryFromDao(GalleryDao dao) async {
  final counts = await dao.countByCategory();
  if (counts.isEmpty) return null;
  final entries = counts.entries.where((e) => e.value > 0).toList();
  if (entries.isEmpty) return null;
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

/// 今日可拍：本地拍摄统计 + 当前时段排序内置场景/模板
final todayShootProvider = FutureProvider<List<TodayShootItem>>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  String? top;
  try {
    top = await _topCategoryFromDao(dao);
  } catch (_) {}
  return InspirationContent.pickTodayShoot(top, DateTime.now());
});

/// 拍得更好：按主拍类别选择内置学院课程
final coursePicksProvider = FutureProvider<List<AcademyCourse>>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  String? top;
  try {
    top = await _topCategoryFromDao(dao);
  } catch (_) {}
  return InspirationContent.pickCourses(top);
});

/// 灵感图集：内置静态素材（无个性化、无网络）
final inspirationGalleryProvider = Provider<List<InspirationGalleryItem>>(
  (ref) => InspirationContent.galleryItems,
);
