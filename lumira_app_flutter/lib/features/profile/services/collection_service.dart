import 'dart:math';

import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';

/// 分类标签映射（与 uni-app 模板分类对应）
const Map<String, String> _categoryLabelMap = {
  'portrait': '人像',
  'landscape': '风光',
  'food': '美食',
  'street': '街拍',
  'night': '夜景',
  'macro': '微距',
  'still-life': '静物',
};

/// 精选集统一服务：智能派生（auto）+ 手动管理（manual）的统一入口。
///
/// - auto 类型：由 [syncAutoCollections] 在用户进入精选集页面时同步生成，
///   不写 `collection_photos` 表；详情页通过 [CollectionsDao.getPhotoIdsForAuto]
///   动态查询 gallery_items。
/// - manual 类型：由用户手动创建/编辑，照片关联存储在 `collection_photos` 表。
class CollectionService {
  CollectionService({
    required CollectionsDao collectionsDao,
    required GalleryDao galleryDao,
    required ScenesDao scenesDao,
  })  : _collectionsDao = collectionsDao,
        _galleryDao = galleryDao,
        _scenesDao = scenesDao;

  final CollectionsDao _collectionsDao;
  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;

  /// 同步所有 auto 类型精选集。
  ///
  /// 流程：删除所有 auto 类型旧记录 → 重新计算并插入新 auto 记录。
  /// 不写 collection_photos 表（auto 类型详情页通过 getPhotoIdsForAuto 动态查询）。
  Future<void> syncAutoCollections() async {
    // 1. 删除所有 auto 类型旧记录（type != 'manual'）
    final all = await _collectionsDao.getAll();
    for (final c in all) {
      if (c.type != CollectionType.manual) {
        await _collectionsDao.delete(c.id);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 2. autoRecent：固定 1 个，最新 9 张
    await _syncAutoRecent(now);

    // 3. autoMonthly：近 3 个月
    await _syncAutoMonthly(now);

    // 4. autoScene：每个收藏场景 1 个
    await _syncAutoScene(now);

    // 5. autoCategory：top 1 分类 1 个
    await _syncAutoCategory(now);

    // 6. autoFavorite：固定 1 个，最新 9 张收藏
    await _syncAutoFavorite(now);
  }

  Future<void> _syncAutoRecent(int now) async {
    final photos = await _galleryDao.getRecent(limit: 9);
    if (photos.isEmpty) return;
    await _collectionsDao.insert(CollectionRecord(
      id: 'auto_recent',
      name: '最近精选',
      coverPhotoId: photos.first.id,
      type: CollectionType.autoRecent,
      photoCount: photos.length,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _syncAutoMonthly(int now) async {
    final monthlyCounts = await _galleryDao.monthlyCounts();
    if (monthlyCounts.isEmpty) return;

    // 取近 3 个月有照片的月份（monthlyCounts 已按 month DESC 排序）
    final recentMonths = monthlyCounts.take(3).toList();
    for (final row in recentMonths) {
      final monthStr = row['month'] as String?;
      if (monthStr == null) continue;
      // monthStr 形如 '2026-07'
      final parts = monthStr.split('-');
      if (parts.length != 2) continue;
      final year = parts[0];
      final month = parts[1];
      final yearInt = int.tryParse(year);
      final monthInt = int.tryParse(month);
      if (yearInt == null || monthInt == null) continue;

      final photos = await _galleryDao.getByMonth(yearInt, monthInt, limit: 9);
      if (photos.isEmpty) continue;

      await _collectionsDao.insert(CollectionRecord(
        id: 'auto_monthly_$year$month',
        name: '$yearInt年$monthInt月精选',
        coverPhotoId: photos.first.id,
        type: CollectionType.autoMonthly,
        sourceMeta: {'year': year, 'month': month},
        photoCount: photos.length,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  Future<void> _syncAutoScene(int now) async {
    final favoriteScenes = await _scenesDao.getFavorites();
    if (favoriteScenes.isEmpty) return;

    for (final scene in favoriteScenes) {
      final photos = await _galleryDao.getByScene(scene.id);
      if (photos.isEmpty) continue;
      final top9 = photos.take(9).toList();
      await _collectionsDao.insert(CollectionRecord(
        id: 'auto_scene_${scene.id}',
        name: '${scene.name}精选',
        coverPhotoId: top9.first.id,
        type: CollectionType.autoScene,
        sourceMeta: {'sceneId': scene.id},
        photoCount: top9.length,
        createdAt: now,
        updatedAt: now,
      ));
    }
  }

  Future<void> _syncAutoCategory(int now) async {
    final categoryCounts = await _galleryDao.countByCategory();
    if (categoryCounts.isEmpty) return;

    // 取 top 1 分类
    final sortedEntries = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntry = sortedEntries.first;
    final category = topEntry.key;

    final photos = await _galleryDao.getByCategory(category, limit: 9);
    if (photos.isEmpty) return;

    final label = _categoryLabelMap[category] ?? category;
    await _collectionsDao.insert(CollectionRecord(
      id: 'auto_category_$category',
      name: '$label精选',
      coverPhotoId: photos.first.id,
      type: CollectionType.autoCategory,
      sourceMeta: {'category': category},
      photoCount: photos.length,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _syncAutoFavorite(int now) async {
    final favorites = await _galleryDao.getFavorites(limit: 9);
    if (favorites.isEmpty) return;
    await _collectionsDao.insert(CollectionRecord(
      id: 'auto_favorite',
      name: '我的收藏',
      coverPhotoId: favorites.first.id,
      type: CollectionType.autoFavorite,
      photoCount: favorites.length,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// 创建 manual 类型精选集，返回新 id。
  Future<String> createManualCollection({
    required String name,
    String? description,
    String? coverPhotoId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _generateManualId();
    await _collectionsDao.insert(CollectionRecord(
      id: id,
      name: name,
      description: description,
      coverPhotoId: coverPhotoId,
      type: CollectionType.manual,
      photoCount: 0,
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// 更新 manual 类型精选集元信息。
  Future<void> updateManualCollection(CollectionRecord record) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = CollectionRecord(
      id: record.id,
      name: record.name,
      description: record.description,
      coverPhotoId: record.coverPhotoId,
      type: CollectionType.manual,
      sourceMeta: record.sourceMeta,
      photoCount: record.photoCount,
      createdAt: record.createdAt,
      updatedAt: now,
    );
    await _collectionsDao.update(updated);
  }

  /// 给 manual 精选集添加照片，并更新 photo_count。
  Future<void> addPhotoToCollection(String collectionId, String photoId) async {
    await _collectionsDao.addPhoto(collectionId, photoId);
    await _refreshPhotoCount(collectionId);
  }

  /// 从 manual 精选集移除照片，并更新 photo_count。
  Future<void> removePhotoFromCollection(
      String collectionId, String photoId) async {
    await _collectionsDao.removePhoto(collectionId, photoId);
    await _refreshPhotoCount(collectionId);
  }

  /// 重排序 manual 精选集照片。
  Future<void> reorderPhotosInCollection(
      String collectionId, List<String> photoIds) async {
    await _collectionsDao.reorderPhotos(collectionId, photoIds);
  }

  /// 删除精选集（manual 会级联清空 collection_photos）。
  Future<void> deleteCollection(String id) async {
    await _collectionsDao.delete(id);
  }

  /// 获取精选集列表（auto 在上，manual 在下，按 updated_at DESC 排序）。
  Future<List<CollectionRecord>> listCollections() async {
    final all = await _collectionsDao.getAll();
    // getAll 已按 updated_at DESC 排序，再分组：auto 在上，manual 在下
    final autos = all.where((c) => c.type != CollectionType.manual).toList();
    final manuals = all.where((c) => c.type == CollectionType.manual).toList();
    return [...autos, ...manuals];
  }

  /// 获取精选集详情。
  Future<CollectionRecord?> getCollection(String id) async {
    return _collectionsDao.getById(id);
  }

  /// 获取精选集照片记录列表（manual 走关联表，auto 走派生查询）。
  Future<List<GalleryItemRecord>> getCollectionPhotos(
    String collectionId, {
    int limit = 9,
  }) async {
    final collection = await _collectionsDao.getById(collectionId);
    if (collection == null) return const [];

    if (collection.type == CollectionType.manual) {
      // 走关联表
      final photoRecords = await _collectionsDao.getPhotos(collectionId);
      final results = <GalleryItemRecord>[];
      for (final pr in photoRecords.take(limit)) {
        final photo = await _galleryDao.getById(pr.photoId);
        if (photo != null) results.add(photo);
      }
      return results;
    }

    // auto 类型走派生查询
    final ids = await _collectionsDao.getPhotoIdsForAuto(collection, limit: limit);
    final results = <GalleryItemRecord>[];
    for (final id in ids) {
      final photo = await _galleryDao.getById(id);
      if (photo != null) results.add(photo);
    }
    return results;
  }

  /// 重新计算并更新 manual 精选集的 photo_count。
  Future<void> _refreshPhotoCount(String collectionId) async {
    final count = await _collectionsDao.countPhotos(collectionId);
    final record = await _collectionsDao.getById(collectionId);
    if (record == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _collectionsDao.update(CollectionRecord(
      id: record.id,
      name: record.name,
      description: record.description,
      coverPhotoId: record.coverPhotoId,
      type: CollectionType.manual,
      sourceMeta: record.sourceMeta,
      photoCount: count,
      createdAt: record.createdAt,
      updatedAt: now,
    ));
  }

  /// 生成 manual 类型精选集 id：时间戳 + 随机数，保证唯一。
  String _generateManualId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rng = Random();
    final suffix = rng.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return 'manual_${now.toRadixString(16)}_$suffix';
  }
}
