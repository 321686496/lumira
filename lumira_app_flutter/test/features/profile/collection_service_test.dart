import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/collections_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/features/profile/services/collection_service.dart';

/// CollectionService 单元测试
///
/// 验证 [CollectionService.syncAutoCollections] 5 种 auto 类型派生逻辑，
/// 以及 manual 类型 CRUD 操作。使用 in-memory SQLite (FFI) 避免真实设备依赖。
void main() {
  late Database db;
  late CollectionsDao collectionsDao;
  late GalleryDao galleryDao;
  late ScenesDao scenesDao;
  late CollectionService service;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 使用 NoIsolate 避免 isolate 通信的 real async 不参与
    // fake async 时间推进的问题（与 gallery_page_test.dart 同模式）
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    collectionsDao = CollectionsDao(db);
    galleryDao = GalleryDao(db);
    scenesDao = ScenesDao(db);
    service = CollectionService(
      collectionsDao: collectionsDao,
      galleryDao: galleryDao,
      scenesDao: scenesDao,
    );
  });

  tearDown(() async => db.close());

  group('syncAutoCollections', () {
    test('空相册不生成任何 auto 精选集', () async {
      await service.syncAutoCollections();
      final all = await collectionsDao.getAll();
      expect(all, isEmpty);
    });

    test('autoRecent: 有照片时生成"最近精选"', () async {
      await _insertPhoto(db, 'p1', createdAt: DateTime.now().millisecondsSinceEpoch);
      await _insertPhoto(db, 'p2', createdAt: DateTime.now().millisecondsSinceEpoch - 1000);

      await service.syncAutoCollections();

      final recent = await collectionsDao.getById('auto_recent');
      expect(recent, isNotNull);
      expect(recent!.name, '最近精选');
      expect(recent.type, CollectionType.autoRecent);
      expect(recent.photoCount, 2);
      // cover = 最新照片
      expect(recent.coverPhotoId, 'p1');
    });

    test('autoMonthly: 当月照片生成月度精选', () async {
      final now = DateTime.now();
      await _insertPhoto(db, 'p1', createdAt: now.millisecondsSinceEpoch);

      await service.syncAutoCollections();

      // Forced fix: service 使用 strftime('%Y-%m') 返回的零填充月份字符串
      // 生成 id（如 'auto_monthly_202607'），而非 int month（如 'auto_monthly_20267'）。
      final expectedId =
          'auto_monthly_${now.year}${now.month.toString().padLeft(2, '0')}';
      final monthly = await collectionsDao.getById(expectedId);
      expect(monthly, isNotNull);
      expect(monthly!.type, CollectionType.autoMonthly);
      expect(monthly.sourceMeta?['year'], now.year.toString());
      expect(monthly.sourceMeta?['month'],
          now.month.toString().padLeft(2, '0'));
    });

    test('autoScene: 收藏场景生成场景精选', () async {
      await _insertScene(db, 'scene_cafe', name: '咖啡馆', isFavorite: 1);
      await _insertPhoto(db, 'p1', sceneId: 'scene_cafe', createdAt: 1000);
      await _insertPhoto(db, 'p2', sceneId: 'scene_cafe', createdAt: 2000);

      await service.syncAutoCollections();

      final sceneCol = await collectionsDao.getById('auto_scene_scene_cafe');
      expect(sceneCol, isNotNull);
      expect(sceneCol!.name, '咖啡馆精选');
      expect(sceneCol.type, CollectionType.autoScene);
      expect(sceneCol.photoCount, 2);
      expect(sceneCol.sourceMeta?['sceneId'], 'scene_cafe');
    });

    test('autoScene: 非收藏场景不生成精选', () async {
      await _insertScene(db, 'scene_other', name: '其他', isFavorite: 0);
      await _insertPhoto(db, 'p1', sceneId: 'scene_other', createdAt: 1000);

      await service.syncAutoCollections();

      final sceneCol = await collectionsDao.getById('auto_scene_scene_other');
      expect(sceneCol, isNull);
    });

    test('autoCategory: top 分类生成分类精选', () async {
      // portrait 分类有 2 张，food 分类有 1 张
      await _insertScene(db, 'scene_p1', name: '人像场景', relatedCategory: 'portrait');
      await _insertScene(db, 'scene_f1', name: '美食场景', relatedCategory: 'food');
      await _insertPhoto(db, 'p1', sceneId: 'scene_p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', sceneId: 'scene_p1', createdAt: 2000);
      await _insertPhoto(db, 'p3', sceneId: 'scene_f1', createdAt: 3000);

      await service.syncAutoCollections();

      final catCol = await collectionsDao.getById('auto_category_portrait');
      expect(catCol, isNotNull);
      expect(catCol!.name, '人像精选');
      expect(catCol.type, CollectionType.autoCategory);
      expect(catCol.sourceMeta?['category'], 'portrait');
    });

    test('autoFavorite: 收藏照片生成"我的收藏"', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 2000, isFavorite: true);

      await service.syncAutoCollections();

      final favCol = await collectionsDao.getById('auto_favorite');
      expect(favCol, isNotNull);
      expect(favCol!.name, '我的收藏');
      expect(favCol.type, CollectionType.autoFavorite);
      expect(favCol.photoCount, 1);
    });

    test('syncAutoCollections 幂等：重复调用不产生重复记录', () async {
      await _insertPhoto(db, 'p1', createdAt: DateTime.now().millisecondsSinceEpoch);

      await service.syncAutoCollections();
      final firstCount = (await collectionsDao.getAll()).length;

      await service.syncAutoCollections();
      final secondCount = (await collectionsDao.getAll()).length;

      expect(secondCount, firstCount);
    });

    test('syncAutoCollections 不影响 manual 类型精选集', () async {
      // 先创建 manual 精选集
      final manualId = await service.createManualCollection(name: '我的手动集');
      await service.addPhotoToCollection(manualId, 'p1');
      // 插入 p1
      await _insertPhoto(db, 'p1', createdAt: DateTime.now().millisecondsSinceEpoch);

      await service.syncAutoCollections();

      // manual 精选集应保留
      final manual = await collectionsDao.getById(manualId);
      expect(manual, isNotNull);
      expect(manual!.type, CollectionType.manual);
      expect(manual.name, '我的手动集');
      // 关联照片也应保留
      final photos = await collectionsDao.getPhotos(manualId);
      expect(photos.length, 1);
      expect(photos.first.photoId, 'p1');
    });
  });

  group('manual CRUD', () {
    test('createManualCollection 返回 id 并可查询', () async {
      final id = await service.createManualCollection(
        name: '测试集',
        description: '描述',
      );
      expect(id, isNotEmpty);

      final fetched = await service.getCollection(id);
      expect(fetched, isNotNull);
      expect(fetched!.name, '测试集');
      expect(fetched.description, '描述');
      expect(fetched.type, CollectionType.manual);
      expect(fetched.photoCount, 0);
    });

    test('updateManualCollection 更新名称和描述', () async {
      final id = await service.createManualCollection(name: '原名');
      final record = await service.getCollection(id);

      await service.updateManualCollection(
        CollectionRecord(
          id: id,
          name: '新名',
          description: '新描述',
          type: CollectionType.manual,
          photoCount: record!.photoCount,
          createdAt: record.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final updated = await service.getCollection(id);
      expect(updated!.name, '新名');
      expect(updated.description, '新描述');
    });

    test('addPhotoToCollection / removePhotoFromCollection 更新 photoCount', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 2000);

      final id = await service.createManualCollection(name: '测试集');
      await service.addPhotoToCollection(id, 'p1');
      await service.addPhotoToCollection(id, 'p2');

      var record = await service.getCollection(id);
      expect(record!.photoCount, 2);

      await service.removePhotoFromCollection(id, 'p1');
      record = await service.getCollection(id);
      expect(record!.photoCount, 1);
    });

    test('reorderPhotosInCollection 重新排序', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 2000);
      await _insertPhoto(db, 'p3', createdAt: 3000);

      final id = await service.createManualCollection(name: '测试集');
      await service.addPhotoToCollection(id, 'p1');
      await service.addPhotoToCollection(id, 'p2');
      await service.addPhotoToCollection(id, 'p3');

      await service.reorderPhotosInCollection(id, ['p3', 'p1', 'p2']);

      final photos = await collectionsDao.getPhotos(id);
      expect(photos[0].photoId, 'p3');
      expect(photos[1].photoId, 'p1');
      expect(photos[2].photoId, 'p2');
    });

    test('deleteCollection 删除精选集及关联', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      final id = await service.createManualCollection(name: '测试集');
      await service.addPhotoToCollection(id, 'p1');

      await service.deleteCollection(id);

      expect(await service.getCollection(id), isNull);
      expect((await collectionsDao.getPhotos(id)), isEmpty);
    });

    test('listCollections: auto 在上，manual 在下', () async {
      await _insertPhoto(db, 'p1', createdAt: DateTime.now().millisecondsSinceEpoch);
      await service.createManualCollection(name: '手动集1');

      await service.syncAutoCollections();

      final list = await service.listCollections();
      // auto 类型在前
      final firstManualIndex = list.indexWhere((c) => c.type == CollectionType.manual);
      final lastAutoIndex = list.lastIndexWhere((c) => c.type != CollectionType.manual);
      expect(firstManualIndex, greaterThan(lastAutoIndex));
    });

    test('getCollectionPhotos: manual 走关联表', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 2000);

      final id = await service.createManualCollection(name: '测试集');
      await service.addPhotoToCollection(id, 'p1');
      await service.addPhotoToCollection(id, 'p2');

      final photos = await service.getCollectionPhotos(id, limit: 9);
      expect(photos.length, 2);
      // 关联表按 sort_order ASC，p1 先添加
      expect(photos[0].id, 'p1');
      expect(photos[1].id, 'p2');
    });

    test('getCollectionPhotos: auto 走派生查询', () async {
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 2000);

      await service.syncAutoCollections();

      final photos = await service.getCollectionPhotos('auto_recent', limit: 9);
      expect(photos.length, 2);
      // autoRecent 按 created_at DESC，p2 最新
      expect(photos[0].id, 'p2');
      expect(photos[1].id, 'p1');
    });
  });
}

// === Helpers ===

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.tableCollections} (
      ${Tables.colCollectionId} TEXT PRIMARY KEY,
      ${Tables.colCollectionName} TEXT NOT NULL,
      ${Tables.colCollectionDescription} TEXT,
      ${Tables.colCollectionCoverPhotoId} TEXT,
      ${Tables.colCollectionType} TEXT NOT NULL,
      ${Tables.colCollectionSourceMeta} TEXT,
      ${Tables.colCollectionPhotoCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionCreatedAt} INTEGER NOT NULL,
      ${Tables.colCollectionUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.tableCollectionPhotos} (
      ${Tables.colCollectionPhotoCollectionId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoPhotoId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionPhotoAddedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colCollectionPhotoCollectionId}, ${Tables.colCollectionPhotoPhotoId})
    )
  ''');
}

Future<void> _insertPhoto(
  Database db,
  String id, {
  String? sceneId,
  int? createdAt,
  bool isFavorite = false,
}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colFilePath: '/tmp/$id.jpg',
    Tables.colSceneId: sceneId,
    Tables.colGalleryItemIsFavorite: isFavorite ? 1 : 0,
    Tables.colCreatedAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> _insertScene(
  Database db,
  String id, {
  String name = '场景',
  String relatedCategory = '',
  int isFavorite = 0,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.scenes, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: 'indoor',
    Tables.colRelatedCategory: relatedCategory,
    Tables.colCreator: 'user',
    Tables.colIsFavorite: isFavorite,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}
