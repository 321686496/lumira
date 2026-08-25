import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_presets_data.dart';
import 'package:lumira_app_flutter/features/home/services/scene_recommendation_service.dart';

void main() {
  late Database db;
  late GalleryDao galleryDao;
  late ScenesDao scenesDao;
  late SceneRecommendationService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('scene_reco_real_test_');
    final dbPath = p.join(tempDir.path, 'test.db');
    db = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    galleryDao = GalleryDao(db);
    scenesDao = ScenesDao(db);
    service = SceneRecommendationService(
      galleryDao: galleryDao,
      scenesDao: scenesDao,
    );
  });

  tearDown(() => db.close());

  test('自定义场景 coverUrl 透传到推荐结果', () async {
    await _seedScene(db,
        id: 'custom_x', name: '我的咖啡馆', category: 'indoor',
        coverUrl: 'data:image/png;base64,AAAA');
    final recos = await service.build();
    final target = recos.where((r) => r.id == 'custom_x').toList();
    expect(target, isNotEmpty);
    expect(target.first.coverUrl, 'data:image/png;base64,AAAA');
  });

  test('预设场景 coverUrl 取 exampleImages 首图', () async {
    final preset = ScenePresetsData.getScenePreset('cafe-window')!;
    await _seedGalleryItem(db, id: 'g1', sceneId: 'cafe-window');
    final recos = await service.build();
    expect(recos, isNotEmpty);
    expect(recos.first.id, 'cafe-window');
    expect(recos.first.coverUrl,
        preset.exampleImages.isNotEmpty ? preset.exampleImages.first : '');
  });

  test('自定义场景 coverUrl 为空时返回空串（不抛异常）', () async {
    await _seedScene(db,
        id: 'custom_y', name: '无封面场景', category: 'light', coverUrl: '');
    final recos = await service.build();
    final target = recos.where((r) => r.id == 'custom_y').toList();
    expect(target, isNotEmpty);
    expect(target.first.coverUrl, '');
  });
}

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
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

Future<void> _seedScene(Database db,
    {required String id,
    required String name,
    required String category,
    String coverUrl = ''}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.scenes, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colCreator: 'user',
    Tables.colCoverUrl: coverUrl,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}

Future<void> _seedGalleryItem(Database db,
    {required String id, required String sceneId}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colSceneId: sceneId,
    Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}