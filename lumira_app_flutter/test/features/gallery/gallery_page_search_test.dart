import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 与 gallery_page_test 保持一致，用 NoIsolate 工厂避免
    // isolate 通信的 real async 在测试 fake async 下不解析的问题。
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Database db;
  late GalleryDao dao;

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
  });

  tearDown(() => db.close());

  test('search by scene_id', () async {
    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'scene_id': '咖啡厅', 'created_at': 1000,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p2', 'scene_id': '公园', 'created_at': 2000,
    });
    final results = await dao.search('咖啡');
    expect(results.length, 1);
    expect(results.first.id, 'p1');
  });

  test('search by template_id', () async {
    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'template_id': '人像模板', 'created_at': 1000,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p2', 'template_id': '风光模板', 'created_at': 2000,
    });
    final results = await dao.search('人像');
    expect(results.length, 1);
    expect(results.first.id, 'p1');
  });

  test('search by mood', () async {
    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'mood': '开心', 'created_at': 1000,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p2', 'mood': '宁静', 'created_at': 2000,
    });
    final results = await dao.search('开心');
    expect(results.length, 1);
    expect(results.first.id, 'p1');
  });

  test('search returns newest first', () async {
    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'scene_id': '咖啡厅', 'created_at': 1000,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p2', 'scene_id': '咖啡厅', 'created_at': 3000,
    });
    final results = await dao.search('咖啡厅');
    expect(results.length, 2);
    expect(results.first.id, 'p2');
  });

  test('search returns empty for no match', () async {
    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'scene_id': '咖啡厅', 'created_at': 1000,
    });
    final results = await dao.search('不存在的');
    expect(results, isEmpty);
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
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
      ${Tables.colGalleryItemHidden} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
}
