import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/database_provider.dart';
import '../services/collection_service.dart';

/// CollectionService Provider。
///
/// 参考 `galleryDaoProvider` 的现有模式：用 FutureProvider 异步注入 DAO，
/// 消费者侧通过 `ref.watch(collectionServiceProvider.future)` 取得 service 实例。
final collectionServiceProvider = FutureProvider<CollectionService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final collectionsDao = CollectionsDao(db);
  final galleryDao = GalleryDao(db);
  final scenesDao = ScenesDao(db);
  return CollectionService(
    collectionsDao: collectionsDao,
    galleryDao: galleryDao,
    scenesDao: scenesDao,
  );
});

/// 列表页用：watch 这个 provider 获取所有精选集。
///
/// 内部会先调用 [CollectionService.syncAutoCollections] 同步 auto 类型精选集，
/// 然后返回排序后的列表（auto 在上，manual 在下，按 updated_at DESC）。
final collectionsListProvider =
    FutureProvider<List<CollectionRecord>>((ref) async {
  final service = await ref.watch(collectionServiceProvider.future);
  await service.syncAutoCollections();
  return service.listCollections();
});

/// 精选集详情数据。
class CollectionDetailData {
  final CollectionRecord collection;
  final List<GalleryItemRecord> photos;

  const CollectionDetailData({
    required this.collection,
    required this.photos,
  });
}

/// 详情页用：根据 collectionId 获取精选集 + 照片列表。
final collectionDetailProvider =
    FutureProvider.family<CollectionDetailData, String>(
        (ref, collectionId) async {
  final service = await ref.watch(collectionServiceProvider.future);
  final collection = await service.getCollection(collectionId);
  // 若精选集不存在（可能 auto 类型尚未 sync），返回错误状态
  if (collection == null) {
    throw StateError('Collection not found: $collectionId');
  }
  final photos = await service.getCollectionPhotos(collectionId, limit: 9);
  return CollectionDetailData(collection: collection, photos: photos);
});
