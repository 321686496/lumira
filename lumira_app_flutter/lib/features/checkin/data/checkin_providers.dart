import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import 'checkin_dao.dart';
import 'checkin_models.dart';

/// CheckinDao 实例（注入内存库便于测试 override）
final checkinDaoProvider = FutureProvider<CheckinDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CheckinDao(db);
});

/// 全部足迹（含封面 URL，列表/卡片用）
final checkinsProvider = FutureProvider<List<CheckinListItem>>((ref) async {
  final dao = await ref.watch(checkinDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final records = await dao.getAll();
  final items = <CheckinListItem>[];
  for (final r in records) {
    String? cover;
    final ids = await dao.getPhotoIds(r.id);
    if (ids.isNotEmpty) {
      final p = await galleryDao.getById(ids.first);
      cover = p?.dataUrl ?? p?.filePath;
    }
    items.add(CheckinListItem(record: r, coverPhotoUrl: cover));
  }
  return items;
});

/// 足迹总数（卡片 stat）
final checkinTotalCountProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(checkinDaoProvider.future);
  return dao.countAll();
});

/// 足迹统计汇总
class CheckinStats {
  final int total;
  final int highRated;
  final double avgRating;
  final int thisYear;

  const CheckinStats({
    required this.total,
    required this.highRated,
    required this.avgRating,
    required this.thisYear,
  });
}

/// 足迹统计 Provider
final checkinStatsProvider = FutureProvider<CheckinStats>((ref) async {
  final dao = await ref.watch(checkinDaoProvider.future);
  final total = await dao.countAll();
  final highRated = await dao.countHighRated();
  final avg = await dao.avgRating();
  final thisYear = await dao.countThisYear();
  return CheckinStats(
    total: total,
    highRated: highRated,
    avgRating: avg,
    thisYear: thisYear,
  );
});

/// 足迹分类列表（去重，非空）
final checkinCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final dao = await ref.watch(checkinDaoProvider.future);
  return dao.getAllCategories();
});

/// 足迹详情（含关联照片）
final checkinDetailProvider = FutureProvider.family<CheckinDetail?, String>(
  (ref, id) async {
    final dao = await ref.watch(checkinDaoProvider.future);
    final galleryDao = await ref.watch(galleryDaoProvider.future);
    final record = await dao.getById(id);
    if (record == null) return null;
    final ids = await dao.getPhotoIds(id);
    final photos = <GalleryItemRecord>[];
    for (final pid in ids) {
      final p = await galleryDao.getById(pid);
      if (p != null) photos.add(p);
    }
    return CheckinDetail(record: record, photos: photos);
  },
);
