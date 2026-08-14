import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// 注意：不需要显式 import 'package:sqflite/sqflite.dart'，sqflite_common_ffi 已 re-export
// Database / openDatabase / Sqflite 等公共 API。

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      ':memory:',
      version: 1,
      onCreate: _onCreate,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TemplatesDao', () {
    test('upsert and getById', () async {
      final dao = TemplatesDao(db);
      final record = TemplateRecord(
        id: 'tpl_test_001',
        name: '测试模板',
        author: 'tester',
        version: '1.0.0',
        category: 'portrait',
        classification: {'type': 'portrait', 'style': 'soft', 'method': 'natural'},
        tags: ['人像', '柔光'],
        tagIds: ['tag_1'],
        price: 0,
        cover: 'assets/images/templates/cafe_portrait.jpg',
        description: '一个测试模板',
        referenceSource: '《摄影入门》第3章',
        composition: {'overlayType': 'rule_of_thirds', 'opacity': 0.5},
        pose: {'silhouette': {'type': 'builtin', 'data': 'standing'}},
        camera: {'iso': 200, 'shutterSpeed': '1/200'},
        sceneGuide: {'lightDirection': 'front', 'tips': ['保持稳定']},
        postProcess: {'lut': 'warm_film'},
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        isBuiltin: false,
        isRecommended: false,
      );

      await dao.upsert(record);

      final fetched = await dao.getById('tpl_test_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, '测试模板');
      expect(fetched.category, 'portrait');
      expect(fetched.referenceSource, '《摄影入门》第3章');
      expect(fetched.tags, ['人像', '柔光']);
      expect(fetched.composition['overlayType'], 'rule_of_thirds');
      expect(fetched.camera['iso'], 200);
    });

    test('getAll filters by category', () async {
      final dao = TemplatesDao(db);
      await dao.upsert(_makeTemplate('tpl_1', 'portrait'));
      await dao.upsert(_makeTemplate('tpl_2', 'landscape'));
      await dao.upsert(_makeTemplate('tpl_3', 'portrait'));

      final all = await dao.getAll();
      expect(all.length, 3);

      final portraits = await dao.getAll(category: 'portrait');
      expect(portraits.length, 2);
      expect(portraits.every((t) => t.category == 'portrait'), isTrue);
    });

    test('upsert replaces existing record (same id)', () async {
      final dao = TemplatesDao(db);
      await dao.upsert(_makeTemplate('tpl_1', 'portrait', name: '原始'));
      await dao.upsert(_makeTemplate('tpl_1', 'portrait', name: '更新后'));

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.name, '更新后');
    });

    test('delete removes record', () async {
      final dao = TemplatesDao(db);
      await dao.upsert(_makeTemplate('tpl_1', 'portrait'));
      expect(await dao.count(), 1);

      final deleted = await dao.delete('tpl_1');
      expect(deleted, 1);
      expect(await dao.count(), 0);
    });

    test('getById returns null for non-existent id', () async {
      final dao = TemplatesDao(db);
      final fetched = await dao.getById('non_existent');
      expect(fetched, isNull);
    });
  });

  group('ScenesDao', () {
    test('upsert and getCustomScenes', () async {
      final dao = ScenesDao(db);
      final record = SceneRecord(
        id: 'custom_cafe_vibe',
        name: '咖啡馆氛围',
        icon: 'ph-coffee',
        category: 'indoor',
        style: 'cafe',
        filter: {'lut': 'warm_film', 'reason': '暖色滤镜配咖啡馆'},
        vibe: '慵懒午后',
        description: '咖啡馆窗边的柔光人像',
        exampleImages: ['https://picsum.photos/1'],
        tips: ['利用窗光', '避免直射'],
        whereToShoot: '咖啡馆窗边座位',
        bestTime: '14:00-16:00',
        sceneGuide: {'lightDirection': 'side'},
        relatedCategory: 'portrait',
        recommendedTagIds: ['tag_cafe'],
        tagIds: ['tag_my'],
        creator: 'user',
        isFavorite: false,
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      await dao.upsert(record);

      final customs = await dao.getCustomScenes();
      expect(customs.length, 1);
      expect(customs.first.name, '咖啡馆氛围');
      expect(customs.first.filter['lut'], 'warm_film');
      expect(customs.first.tips, ['利用窗光', '避免直射']);
    });

    test('toggleFavorite creates minimal row for builtin scene', () async {
      final dao = ScenesDao(db);
      // 内置场景首次收藏：DB 中无记录，应插入最小行
      await dao.toggleFavorite('cafe-window', true);

      final favorites = await dao.getFavorites();
      expect(favorites.length, 1);
      expect(favorites.first.id, 'cafe-window');
      expect(favorites.first.isFavorite, isTrue);
      expect(favorites.first.creator, 'system');
    });

    test('toggleFavorite toggles existing scene', () async {
      final dao = ScenesDao(db);
      await dao.upsert(_makeScene('custom_1', isFavorite: false));

      await dao.toggleFavorite('custom_1', true);
      expect((await dao.getFavorites()).length, 1);

      await dao.toggleFavorite('custom_1', false);
      expect((await dao.getFavorites()).length, 0);
    });

    test('countCustom only counts creator=user', () async {
      final dao = ScenesDao(db);
      await dao.upsert(_makeScene('custom_1'));
      await dao.upsert(_makeScene('custom_2'));
      await dao.toggleFavorite('builtin_1', true); // creates system row

      expect(await dao.countCustom(), 2);
    });

    test('delete removes custom scene', () async {
      final dao = ScenesDao(db);
      await dao.upsert(_makeScene('custom_1'));
      expect(await dao.countCustom(), 1);

      await dao.delete('custom_1');
      expect(await dao.countCustom(), 0);
    });
  });

  group('GalleryDao', () {
    test('insert and getAll (newest first)', () async {
      final dao = GalleryDao(db);
      await dao.insert(_makePhoto('photo_1', createdAt: 1000));
      await dao.insert(_makePhoto('photo_2', createdAt: 2000));
      await dao.insert(_makePhoto('photo_3', createdAt: 1500));

      final all = await dao.getAll();
      expect(all.length, 3);
      expect(all[0].id, 'photo_2'); // newest first
      expect(all[1].id, 'photo_3');
      expect(all[2].id, 'photo_1');
    });

    test('getByScene filters by sceneId', () async {
      final dao = GalleryDao(db);
      await dao.insert(_makePhoto('photo_1', sceneId: 'cafe'));
      await dao.insert(_makePhoto('photo_2', sceneId: 'street'));
      await dao.insert(_makePhoto('photo_3', sceneId: 'cafe'));

      final cafePhotos = await dao.getByScene('cafe');
      expect(cafePhotos.length, 2);
      expect(cafePhotos.every((p) => p.sceneId == 'cafe'), isTrue);
    });

    test('updateScene changes sceneId', () async {
      final dao = GalleryDao(db);
      await dao.insert(_makePhoto('photo_1', sceneId: 'cafe'));

      await dao.updateScene('photo_1', 'street');
      final fetched = await dao.getById('photo_1');
      expect(fetched!.sceneId, 'street');
    });

    test('count and countByScene', () async {
      final dao = GalleryDao(db);
      await dao.insert(_makePhoto('photo_1', sceneId: 'cafe'));
      await dao.insert(_makePhoto('photo_2', sceneId: 'cafe'));
      await dao.insert(_makePhoto('photo_3', sceneId: 'street'));

      expect(await dao.count(), 3);
      expect(await dao.countByScene('cafe'), 2);
      expect(await dao.countByScene('street'), 1);
    });

    test('delete removes photo', () async {
      final dao = GalleryDao(db);
      await dao.insert(_makePhoto('photo_1'));
      expect(await dao.count(), 1);

      await dao.delete('photo_1');
      expect(await dao.count(), 0);
    });

    test('monthlyCounts groups by YYYY-MM', () async {
      final dao = GalleryDao(db);
      // 2024-01-15 UTC = 1705276800000 ms
      await dao.insert(_makePhoto('photo_1', createdAt: 1705276800000));
      await dao.insert(_makePhoto('photo_2', createdAt: 1705276800000));
      // 2024-02-20 UTC = 1708358400000 ms
      await dao.insert(_makePhoto('photo_3', createdAt: 1708358400000));

      final counts = await dao.monthlyCounts();
      expect(counts.length, 2);
      // Ordered DESC by month
      expect(counts[0]['month'], '2024-02');
      expect(counts[0]['cnt'], 1);
      expect(counts[1]['month'], '2024-01');
      expect(counts[1]['cnt'], 2);
    });
  });

  group('Schema integrity', () {
    test('user_progress table has default row', () async {
      final rows = await db.query(Tables.userProgress);
      expect(rows.length, 1);
      expect(rows.first[Tables.colId], 1);
      expect(rows.first[Tables.colLevel], 1);
      expect(rows.first[Tables.colThemeKey], isNull); // 不在此表
      expect(rows.first[Tables.colXp], 0);
    });

    test('user_settings table has default row with default theme/style', () async {
      final rows = await db.query(Tables.userSettings);
      expect(rows.length, 1);
      expect(rows.first[Tables.colThemeKey], 'warmWhite');
      expect(rows.first[Tables.colUiStyle], 'neumorphic');
      expect(rows.first[Tables.colFollowSystem], 0);
    });
  });
}

// === Helpers ===

Future<void> _onCreate(Database db, int version) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
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

  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.galleryItems} (
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

  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userProgress} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colLevelName} TEXT NOT NULL DEFAULT '新手',
      ${Tables.colXp} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colXpToNextLevel} INTEGER NOT NULL DEFAULT 100,
      ${Tables.colTotalPhotos} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUsedTemplates} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colFavorites} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colStreakDays} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLastCheckInDate} TEXT,
      ${Tables.colFragmentsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colAchievementsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  batch.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userSettings} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colThemeKey} TEXT NOT NULL DEFAULT 'warmWhite',
      ${Tables.colUiStyle} TEXT NOT NULL DEFAULT 'neumorphic',
      ${Tables.colFollowSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCaptureFullscreen} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colGridEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLevelEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colShutterSound} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colWatermark} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  batch.insert(Tables.userSettings, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  await batch.commit(noResult: true);
}

TemplateRecord _makeTemplate(String id, String category, {String name = '测试'}) {
  return TemplateRecord(
    id: id,
    name: name,
    author: 'tester',
    version: '1.0.0',
    category: category,
    classification: {},
    tags: [],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {},
    pose: {},
    camera: {},
    sceneGuide: {},
    postProcess: {},
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    isBuiltin: false,
    isRecommended: false,
  );
}

SceneRecord _makeScene(String id, {bool isFavorite = false}) {
  return SceneRecord(
    id: id,
    name: '场景 $id',
    icon: '',
    category: 'indoor',
    style: '',
    filter: {},
    vibe: '',
    description: '',
    exampleImages: [],
    tips: [],
    whereToShoot: '',
    bestTime: '',
    sceneGuide: {},
    relatedCategory: '',
    recommendedTagIds: [],
    tagIds: [],
    creator: 'user',
    isFavorite: isFavorite,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}

GalleryItemRecord _makePhoto(String id, {String? sceneId, int? createdAt}) {
  return GalleryItemRecord(
    id: id,
    dataUrl: null,
    filePath: '/tmp/$id.jpg',
    sceneId: sceneId,
    templateId: null,
    kitId: null,
    mood: null,
    lut: null,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  );
}
