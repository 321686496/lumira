import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';

void main() {
  late Database db;
  late GalleryDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
  });

  tearDown(() async => db.close());

  group('isFavorite field', () {
    test('insert 默认 isFavorite=false', () async {
      await dao.insert(_makePhoto('p1'));
      final fetched = await dao.getById('p1');
      expect(fetched, isNotNull);
      expect(fetched!.isFavorite, isFalse);
    });

    test('insert 显式 isFavorite=true 并取回', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        isFavorite: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      final fetched = await dao.getById('p1');
      expect(fetched!.isFavorite, isTrue);
    });

    test('toRow 写入 is_favorite=1', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        isFavorite: true,
        createdAt: 1000,
      ));
      final rows = await db.query(Tables.galleryItems,
          where: '${Tables.colId} = ?', whereArgs: ['p1']);
      expect(rows.first[Tables.colGalleryItemIsFavorite], 1);
    });
  });

  group('toggleFavorite', () {
    test('false → true', () async {
      await dao.insert(_makePhoto('p1'));
      await dao.toggleFavorite('p1');
      final fetched = await dao.getById('p1');
      expect(fetched!.isFavorite, isTrue);
    });

    test('true → false', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        isFavorite: true,
        createdAt: 1000,
      ));
      await dao.toggleFavorite('p1');
      final fetched = await dao.getById('p1');
      expect(fetched!.isFavorite, isFalse);
    });

    test('多次 toggle 交替', () async {
      await dao.insert(_makePhoto('p1'));
      await dao.toggleFavorite('p1');
      expect((await dao.getById('p1'))!.isFavorite, isTrue);
      await dao.toggleFavorite('p1');
      expect((await dao.getById('p1'))!.isFavorite, isFalse);
      await dao.toggleFavorite('p1');
      expect((await dao.getById('p1'))!.isFavorite, isTrue);
    });
  });

  group('setFavorite', () {
    test('设置为 true', () async {
      await dao.insert(_makePhoto('p1'));
      await dao.setFavorite('p1', true);
      expect((await dao.getById('p1'))!.isFavorite, isTrue);
    });

    test('设置为 false', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        isFavorite: true,
        createdAt: 1000,
      ));
      await dao.setFavorite('p1', false);
      expect((await dao.getById('p1'))!.isFavorite, isFalse);
    });
  });

  group('getFavorites', () {
    test('仅返回 is_favorite=1 的照片，按 created_at DESC', () async {
      await dao.insert(_makePhoto('p1', createdAt: 1000));
      await dao.insert(GalleryItemRecord(
        id: 'p2',
        filePath: '/tmp/p2.jpg',
        isFavorite: true,
        createdAt: 3000,
      ));
      await dao.insert(GalleryItemRecord(
        id: 'p3',
        filePath: '/tmp/p3.jpg',
        isFavorite: true,
        createdAt: 2000,
      ));

      final favorites = await dao.getFavorites();
      expect(favorites.length, 2);
      expect(favorites[0].id, 'p2'); // createdAt=3000 最新
      expect(favorites[1].id, 'p3'); // createdAt=2000
    });

    test('limit 限制数量', () async {
      for (var i = 0; i < 5; i++) {
        await dao.insert(GalleryItemRecord(
          id: 'p$i',
          filePath: '/tmp/p$i.jpg',
          isFavorite: true,
          createdAt: 1000 + i,
        ));
      }
      final favorites = await dao.getFavorites(limit: 3);
      expect(favorites.length, 3);
      // 最新在前：p4, p3, p2
      expect(favorites[0].id, 'p4');
      expect(favorites[2].id, 'p2');
    });

    test('无收藏返回空列表', () async {
      await dao.insert(_makePhoto('p1'));
      final favorites = await dao.getFavorites();
      expect(favorites, isEmpty);
    });
  });

  group('getByCategory', () {
    test('JOIN scenes.related_category 筛选', () async {
      await _insertScene(db, 'scene1', relatedCategory: 'portrait');
      await _insertScene(db, 'scene2', relatedCategory: 'landscape');

      await dao.insert(_makePhoto('p1', sceneId: 'scene1', createdAt: 1000));
      await dao.insert(_makePhoto('p2', sceneId: 'scene2', createdAt: 2000));
      await dao.insert(_makePhoto('p3', sceneId: 'scene1', createdAt: 3000));
      // 无场景的照片不应出现
      await dao.insert(_makePhoto('p4', createdAt: 4000));

      final portraits = await dao.getByCategory('portrait');
      expect(portraits.length, 2);
      expect(portraits[0].id, 'p3'); // createdAt=3000 最新
      expect(portraits[1].id, 'p1');

      final landscapes = await dao.getByCategory('landscape');
      expect(landscapes.length, 1);
      expect(landscapes.first.id, 'p2');
    });

    test('limit 限制数量', () async {
      await _insertScene(db, 'scene1', relatedCategory: 'portrait');
      for (var i = 0; i < 5; i++) {
        await dao.insert(_makePhoto('p$i', sceneId: 'scene1', createdAt: 1000 + i));
      }

      final portraits = await dao.getByCategory('portrait', limit: 2);
      expect(portraits.length, 2);
      expect(portraits[0].id, 'p4'); // 最新
      expect(portraits[1].id, 'p3');
    });

    test('无匹配返回空列表', () async {
      await _insertScene(db, 'scene1', relatedCategory: 'portrait');
      await dao.insert(_makePhoto('p1', sceneId: 'scene1'));

      final result = await dao.getByCategory('nonexistent');
      expect(result, isEmpty);
    });
  });

  group('getByTemplate', () {
    test('按 template_id 筛选，按 created_at DESC', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        templateId: 'tpl_a',
        createdAt: 1000,
      ));
      await dao.insert(GalleryItemRecord(
        id: 'p2',
        filePath: '/tmp/p2.jpg',
        templateId: 'tpl_b',
        createdAt: 2000,
      ));
      await dao.insert(GalleryItemRecord(
        id: 'p3',
        filePath: '/tmp/p3.jpg',
        templateId: 'tpl_a',
        createdAt: 3000,
      ));

      final result = await dao.getByTemplate('tpl_a');
      expect(result.length, 2);
      expect(result[0].id, 'p3'); // 最新
      expect(result[1].id, 'p1');
    });

    test('limit 限制数量', () async {
      for (var i = 0; i < 5; i++) {
        await dao.insert(GalleryItemRecord(
          id: 'p$i',
          filePath: '/tmp/p$i.jpg',
          templateId: 'tpl_a',
          createdAt: 1000 + i,
        ));
      }
      final result = await dao.getByTemplate('tpl_a', limit: 2);
      expect(result.length, 2);
      expect(result[0].id, 'p4');
    });

    test('无匹配返回空列表', () async {
      await dao.insert(GalleryItemRecord(
        id: 'p1',
        filePath: '/tmp/p1.jpg',
        templateId: 'tpl_a',
        createdAt: 1000,
      ));
      final result = await dao.getByTemplate('nonexistent');
      expect(result, isEmpty);
    });
  });

  group('getByMonth', () {
    test('按年月筛选', () async {
      // 1705276800000 = 2024-01-15 00:00:00 UTC（月中，时区安全）
      await dao.insert(_makePhoto('p1', createdAt: 1705276800000));
      // 1705363200000 = 2024-01-16 00:00:00 UTC
      await dao.insert(_makePhoto('p2', createdAt: 1705363200000));
      // 1708358400000 = 2024-02-20 00:00:00 UTC
      await dao.insert(_makePhoto('p3', createdAt: 1708358400000));

      final jan2024 = await dao.getByMonth(2024, 1);
      expect(jan2024.length, 2);
      expect(jan2024[0].id, 'p2'); // 更新
      expect(jan2024[1].id, 'p1');

      final feb2024 = await dao.getByMonth(2024, 2);
      expect(feb2024.length, 1);
      expect(feb2024.first.id, 'p3');
    });

    test('limit 限制数量', () async {
      await dao.insert(_makePhoto('p1', createdAt: 1705276800000));
      await dao.insert(_makePhoto('p2', createdAt: 1705363200000));
      await dao.insert(_makePhoto('p3', createdAt: 1705449600000));

      final result = await dao.getByMonth(2024, 1, limit: 2);
      expect(result.length, 2);
    });

    test('无匹配返回空列表', () async {
      await dao.insert(_makePhoto('p1', createdAt: 1705276800000));
      final result = await dao.getByMonth(2023, 6);
      expect(result, isEmpty);
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
}

GalleryItemRecord _makePhoto(String id, {String? sceneId, int? createdAt}) {
  return GalleryItemRecord(
    id: id,
    filePath: '/tmp/$id.jpg',
    sceneId: sceneId,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
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
