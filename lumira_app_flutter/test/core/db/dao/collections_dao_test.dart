import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/collections_dao.dart';

void main() {
  late Database db;
  late CollectionsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = CollectionsDao(db);
  });

  tearDown(() async => db.close());

  group('CollectionType serialization', () {
    test('value 与 fromString 互逆', () {
      for (final t in CollectionType.values) {
        expect(CollectionType.fromString(t.value), t);
      }
    });

    test('fromString 抛异常 on unknown', () {
      expect(() => CollectionType.fromString('unknown'), throwsStateError);
    });
  });

  group('CRUD', () {
    test('insert 返回 id，getById 取回', () async {
      final rec = _makeCollection('c1', name: '测试精选集');
      final id = await dao.insert(rec);
      expect(id, 'c1');

      final fetched = await dao.getById('c1');
      expect(fetched, isNotNull);
      expect(fetched!.name, '测试精选集');
      expect(fetched.type, CollectionType.manual);
      expect(fetched.photoCount, 0);
    });

    test('getById 不存在返回 null', () async {
      expect(await dao.getById('nonexistent'), isNull);
    });

    test('getAll 按 updated_at DESC 排序', () async {
      await dao.insert(_makeCollection('c1', updatedAt: 1000));
      await dao.insert(_makeCollection('c2', updatedAt: 3000));
      await dao.insert(_makeCollection('c3', updatedAt: 2000));

      final all = await dao.getAll();
      expect(all.length, 3);
      expect(all[0].id, 'c2');
      expect(all[1].id, 'c3');
      expect(all[2].id, 'c1');
    });

    test('getByType 筛选类型', () async {
      await dao.insert(_makeCollection('c1', type: CollectionType.manual));
      await dao.insert(_makeCollection('c2', type: CollectionType.autoRecent));
      await dao.insert(_makeCollection('c3', type: CollectionType.manual));

      final manuals = await dao.getByType(CollectionType.manual);
      expect(manuals.length, 2);
      final autos = await dao.getByType(CollectionType.autoRecent);
      expect(autos.length, 1);
      expect(autos.first.id, 'c2');
    });

    test('update 修改 name/description', () async {
      await dao.insert(_makeCollection('c1', name: '原名', description: '原描述'));
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.update(CollectionRecord(
        id: 'c1',
        name: '新名',
        description: '新描述',
        type: CollectionType.manual,
        photoCount: 5,
        createdAt: 1000,
        updatedAt: now,
      ));

      final fetched = await dao.getById('c1');
      expect(fetched!.name, '新名');
      expect(fetched.description, '新描述');
      expect(fetched.photoCount, 5);
      expect(fetched.updatedAt, now);
    });

    test('delete 删除主表记录', () async {
      await dao.insert(_makeCollection('c1'));
      expect(await dao.getById('c1'), isNotNull);

      await dao.delete('c1');
      expect(await dao.getById('c1'), isNull);
    });

    test('sourceMeta 序列化/反序列化', () async {
      await dao.insert(CollectionRecord(
        id: 'c1',
        name: '月度',
        type: CollectionType.autoMonthly,
        sourceMeta: {'year': 2024, 'month': 1},
        createdAt: 1000,
        updatedAt: 1000,
      ));

      final fetched = await dao.getById('c1');
      expect(fetched!.sourceMeta, isNotNull);
      expect(fetched.sourceMeta!['year'], 2024);
      expect(fetched.sourceMeta!['month'], 1);
    });
  });

  group('关联表', () {
    test('addPhoto / getPhotos / countPhotos', () async {
      await dao.insert(_makeCollection('c1'));
      await dao.addPhoto('c1', 'p1');
      await dao.addPhoto('c1', 'p2');
      await dao.addPhoto('c1', 'p3');

      expect(await dao.countPhotos('c1'), 3);

      final photos = await dao.getPhotos('c1');
      expect(photos.length, 3);
      // sort_order 递增：0, 1, 2
      expect(photos[0].photoId, 'p1');
      expect(photos[0].sortOrder, 0);
      expect(photos[1].photoId, 'p2');
      expect(photos[1].sortOrder, 1);
      expect(photos[2].photoId, 'p3');
      expect(photos[2].sortOrder, 2);
    });

    test('removePhoto 删除单张', () async {
      await dao.insert(_makeCollection('c1'));
      await dao.addPhoto('c1', 'p1');
      await dao.addPhoto('c1', 'p2');

      await dao.removePhoto('c1', 'p1');
      expect(await dao.countPhotos('c1'), 1);
      final photos = await dao.getPhotos('c1');
      expect(photos.first.photoId, 'p2');
    });

    test('reorderPhotos 重新排序', () async {
      await dao.insert(_makeCollection('c1'));
      await dao.addPhoto('c1', 'p1');
      await dao.addPhoto('c1', 'p2');
      await dao.addPhoto('c1', 'p3');

      // 反序
      await dao.reorderPhotos('c1', ['p3', 'p2', 'p1']);

      final photos = await dao.getPhotos('c1');
      expect(photos[0].photoId, 'p3');
      expect(photos[0].sortOrder, 0);
      expect(photos[1].photoId, 'p2');
      expect(photos[1].sortOrder, 1);
      expect(photos[2].photoId, 'p1');
      expect(photos[2].sortOrder, 2);
    });

    test('clearPhotos 清空', () async {
      await dao.insert(_makeCollection('c1'));
      await dao.addPhoto('c1', 'p1');
      await dao.addPhoto('c1', 'p2');

      await dao.clearPhotos('c1');
      expect(await dao.countPhotos('c1'), 0);
      expect((await dao.getPhotos('c1')), isEmpty);
    });
  });

  group('级联删除', () {
    test('delete collection 后 collection_photos 也清空', () async {
      await dao.insert(_makeCollection('c1'));
      await dao.addPhoto('c1', 'p1');
      await dao.addPhoto('c1', 'p2');
      expect(await dao.countPhotos('c1'), 2);

      await dao.delete('c1');
      expect(await dao.countPhotos('c1'), 0);
      expect((await dao.getPhotos('c1')), isEmpty);
    });
  });

  group('派生查询 getPhotoIdsForAuto', () {
    setUp(() async {
      // 插入 gallery_items 测试数据
      await _insertPhoto(db, 'p1', createdAt: 1000);
      await _insertPhoto(db, 'p2', createdAt: 3000);
      await _insertPhoto(db, 'p3', createdAt: 2000);
      // p2 收藏
      await _setFavorite(db, 'p2');
      // p4, p5 关联 scene1
      await _insertPhoto(db, 'p4', sceneId: 'scene1', createdAt: 5000);
      await _insertPhoto(db, 'p5', sceneId: 'scene1', createdAt: 4000);
      // p6 关联 scene2（related_category=portrait）
      await _insertPhoto(db, 'p6', sceneId: 'scene2', createdAt: 6000);
      // 月度测试：2024-01 的照片
      // 1705276800000 = 2024-01-15 00:00:00 UTC（月中，时区安全）
      await _insertPhoto(db, 'p7', createdAt: 1705276800000);
      // 1708358400000 = 2024-02-20 00:00:00 UTC
      await _insertPhoto(db, 'p8', createdAt: 1708358400000);

      // 插入 scenes（autoScene / autoCategory 需要）
      await _insertScene(db, 'scene1', relatedCategory: 'indoor');
      await _insertScene(db, 'scene2', relatedCategory: 'portrait');
    });

    test('autoRecent: 最新 N 张', () async {
      final col = _makeAutoCollection('rc', CollectionType.autoRecent);
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col, limit: 3);
      // 最新 3 张：p8(1708358400000) > p7(1705276800000) > p6(6000)
      expect(ids, ['p8', 'p7', 'p6']);
    });

    test('autoMonthly: 按年月筛选', () async {
      final col = CollectionRecord(
        id: 'mc',
        name: '2024年1月精选',
        type: CollectionType.autoMonthly,
        sourceMeta: {'year': '2024', 'month': '1'},
        createdAt: 1000,
        updatedAt: 1000,
      );
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col, limit: 9);
      // 仅 p7 在 2024-01
      expect(ids, ['p7']);
    });

    test('autoMonthly: 缺少 sourceMeta 返回空', () async {
      final col = _makeAutoCollection('mc2', CollectionType.autoMonthly);
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col);
      expect(ids, isEmpty);
    });

    test('autoScene: 按 sceneId 筛选', () async {
      final col = CollectionRecord(
        id: 'sc',
        name: '场景精选',
        type: CollectionType.autoScene,
        sourceMeta: {'sceneId': 'scene1'},
        createdAt: 1000,
        updatedAt: 1000,
      );
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col, limit: 9);
      // scene1 下：p4(5000), p5(4000)
      expect(ids, ['p4', 'p5']);
    });

    test('autoCategory: JOIN scenes.related_category', () async {
      final col = CollectionRecord(
        id: 'cc',
        name: '人像精选',
        type: CollectionType.autoCategory,
        sourceMeta: {'category': 'portrait'},
        createdAt: 1000,
        updatedAt: 1000,
      );
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col, limit: 9);
      // scene2 的 related_category=portrait，关联 p6
      expect(ids, ['p6']);
    });

    test('autoFavorite: is_favorite=1', () async {
      final col = _makeAutoCollection('fc', CollectionType.autoFavorite);
      await dao.insert(col);

      final ids = await dao.getPhotoIdsForAuto(col, limit: 9);
      // 仅 p2 被收藏
      expect(ids, ['p2']);
    });

    test('manual: 抛 ArgumentError', () async {
      final col = _makeCollection('manual_c', type: CollectionType.manual);
      await dao.insert(col);

      expect(
        () => dao.getPhotoIdsForAuto(col),
        throwsArgumentError,
      );
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
      ${Tables.colGalleryItemHidden} INTEGER NOT NULL DEFAULT 0,
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

CollectionRecord _makeCollection(
  String id, {
  String name = '精选集',
  String? description,
  CollectionType type = CollectionType.manual,
  int? createdAt,
  int? updatedAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return CollectionRecord(
    id: id,
    name: name,
    description: description,
    type: type,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

CollectionRecord _makeAutoCollection(String id, CollectionType type) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return CollectionRecord(
    id: id,
    name: 'auto',
    type: type,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _insertPhoto(
  Database db,
  String id, {
  String? sceneId,
  int? createdAt,
}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colFilePath: '/tmp/$id.jpg',
    Tables.colSceneId: sceneId,
    Tables.colCreatedAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> _setFavorite(Database db, String id) async {
  await db.update(
    Tables.galleryItems,
    {Tables.colGalleryItemIsFavorite: 1},
    where: '${Tables.colId} = ?',
    whereArgs: [id],
  );
}

Future<void> _insertScene(
  Database db,
  String id, {
  String relatedCategory = '',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.scenes, {
    Tables.colId: id,
    Tables.colName: '场景 $id',
    Tables.colCategory: 'indoor',
    Tables.colRelatedCategory: relatedCategory,
    Tables.colCreator: 'user',
    Tables.colIsFavorite: 0,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}
