import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';

// 参考现有迁移测试（migration_v4_test.dart / gallery_dao_v7_test.dart）：
// 不直接 import database_provider.dart 以避免 CPF-Flutter sqflite fork 在测试环境的复杂依赖，
// 手写 v7 schema + v8 迁移逻辑验证幂等性与表结构。

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v8 migration: gallery_items.is_favorite 列存在', () async {
    final db = await _openV7AndMigrateToV8();

    final cols = await db.rawQuery('PRAGMA table_info(${Tables.galleryItems})');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    expect(colNames, contains(Tables.colGalleryItemIsFavorite));

    await db.close();
  });

  test('v8 migration: collections 表存在且列结构正确', () async {
    final db = await _openV7AndMigrateToV8();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [Tables.tableCollections],
    );
    expect(tables, isNotEmpty);

    final cols = await db.rawQuery('PRAGMA table_info(${Tables.tableCollections})');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    expect(colNames, containsAll([
      Tables.colCollectionId,
      Tables.colCollectionName,
      Tables.colCollectionDescription,
      Tables.colCollectionCoverPhotoId,
      Tables.colCollectionType,
      Tables.colCollectionSourceMeta,
      Tables.colCollectionPhotoCount,
      Tables.colCollectionCreatedAt,
      Tables.colCollectionUpdatedAt,
    ]));

    await db.close();
  });

  test('v8 migration: collection_photos 表存在且列结构正确', () async {
    final db = await _openV7AndMigrateToV8();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [Tables.tableCollectionPhotos],
    );
    expect(tables, isNotEmpty);

    final cols = await db.rawQuery('PRAGMA table_info(${Tables.tableCollectionPhotos})');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    expect(colNames, containsAll([
      Tables.colCollectionPhotoCollectionId,
      Tables.colCollectionPhotoPhotoId,
      Tables.colCollectionPhotoSortOrder,
      Tables.colCollectionPhotoAddedAt,
    ]));

    await db.close();
  });

  test('v8 migration: 索引存在', () async {
    final db = await _openV7AndMigrateToV8();

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name IN (?, ?, ?, ?, ?)",
      [
        'idx_gallery_items_is_favorite',
        'idx_collections_type',
        'idx_collections_updated_at',
        'idx_collection_photos_collection',
        'idx_gallery_items_created_at',
      ],
    );
    final indexNames = indexes.map((r) => r['name'] as String).toSet();
    expect(indexNames, containsAll([
      'idx_gallery_items_is_favorite',
      'idx_collections_type',
      'idx_collections_updated_at',
      'idx_collection_photos_collection',
    ]));

    await db.close();
  });

  test('v8 migration: 幂等性（迁移两次不报错）', () async {
    final tempDir = await Directory.systemTemp.createTemp('v8_idempotent_test_');
    final dbPath = p.join(tempDir.path, 'test_v8_idempotent.db');

    // 1. 创建 v7 schema
    final db1 = await openDatabase(dbPath, version: 7, onCreate: _onCreateV7);
    await db1.close();

    // 2. 第一次 v7→v8 迁移
    final db2 = await openDatabase(
      dbPath,
      version: 8,
      onUpgrade: _onUpgradeV8,
    );
    // 验证迁移成功
    final cols1 = await db2.rawQuery('PRAGMA table_info(${Tables.galleryItems})');
    expect(cols1.any((c) => c['name'] == Tables.colGalleryItemIsFavorite), isTrue);
    await db2.close();

    // 3. 手动再次执行 v8 迁移 SQL（模拟重复迁移，验证幂等）
    final db3 = await openDatabase(dbPath, version: 8);
    await _onUpgradeV8(db3, 7, 8); // 手动再跑一次
    // 验证不报错且结构完整
    final cols2 = await db3.rawQuery('PRAGMA table_info(${Tables.galleryItems})');
    expect(cols2.any((c) => c['name'] == Tables.colGalleryItemIsFavorite), isTrue);
    final tables = await db3.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN (?, ?)",
      [Tables.tableCollections, Tables.tableCollectionPhotos],
    );
    expect(tables.length, 2);
    await db3.close();
  });

  test('v8 migration: GalleryDao.getFavorites 返回空列表（默认 is_favorite=0）', () async {
    final db = await _openV7AndMigrateToV8();

    // 插入一条 v7 风格的旧数据（无 is_favorite，默认 0）
    await db.insert(Tables.galleryItems, {
      Tables.colId: 'old_photo_1',
      Tables.colFilePath: '/tmp/old.jpg',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    final dao = GalleryDao(db);
    final favorites = await dao.getFavorites();
    expect(favorites, isEmpty);

    await db.close();
  });

  test('v8 migration: 旧数据 is_favorite 默认为 0（false）', () async {
    final db = await _openV7AndMigrateToV8();

    await db.insert(Tables.galleryItems, {
      Tables.colId: 'old_photo_2',
      Tables.colFilePath: '/tmp/old2.jpg',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    final dao = GalleryDao(db);
    final fetched = await dao.getById('old_photo_2');
    expect(fetched, isNotNull);
    expect(fetched!.isFavorite, isFalse);

    await db.close();
  });
}

// === Helpers ===

/// 打开 v7 DB 并迁移到 v8，返回已迁移的 db
Future<Database> _openV7AndMigrateToV8() async {
  final tempDir = await Directory.systemTemp.createTemp('v8_test_');
  final dbPath = p.join(tempDir.path, 'test_v8.db');

  // 创建 v7 schema
  final db1 = await openDatabase(dbPath, version: 7, onCreate: _onCreateV7);
  await db1.close();

  // 打开 v8 触发迁移
  final db2 = await openDatabase(
    dbPath,
    version: 8,
    onUpgrade: _onUpgradeV8,
  );
  return db2;
}

/// v7 schema：gallery_items 含 v7 列但无 is_favorite；无 collections / collection_photos
Future<void> _onCreateV7(Database db, int version) async {
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
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_gallery_items_created_at ON ${Tables.galleryItems}(${Tables.colCreatedAt} DESC)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_gallery_items_scene_id ON ${Tables.galleryItems}(${Tables.colSceneId})',
  );
}

/// v8 迁移逻辑（与 database_provider.dart 的 v7→v8 分支保持一致）
Future<void> _onUpgradeV8(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 8) {
    // gallery_items 新增 is_favorite 列
    await _addColumnIfNotExists(
      db,
      Tables.galleryItems,
      Tables.colGalleryItemIsFavorite,
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gallery_items_is_favorite ON ${Tables.galleryItems}(${Tables.colGalleryItemIsFavorite})',
    );

    // collections 精选集主表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.tableCollections} (
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_type ON ${Tables.tableCollections}(${Tables.colCollectionType})');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON ${Tables.tableCollections}(${Tables.colCollectionUpdatedAt})');

    // collection_photos 精选集-照片关联表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.tableCollectionPhotos} (
        ${Tables.colCollectionPhotoCollectionId} TEXT NOT NULL,
        ${Tables.colCollectionPhotoPhotoId} TEXT NOT NULL,
        ${Tables.colCollectionPhotoSortOrder} INTEGER NOT NULL DEFAULT 0,
        ${Tables.colCollectionPhotoAddedAt} INTEGER NOT NULL,
        PRIMARY KEY (${Tables.colCollectionPhotoCollectionId}, ${Tables.colCollectionPhotoPhotoId}),
        FOREIGN KEY (${Tables.colCollectionPhotoCollectionId}) REFERENCES ${Tables.tableCollections}(${Tables.colCollectionId}) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_collection_photos_collection ON ${Tables.tableCollectionPhotos}(${Tables.colCollectionPhotoCollectionId})');
  }
}

Future<void> _addColumnIfNotExists(
  Database db,
  String table,
  String column,
  String typeClause,
) async {
  final cols = await db.rawQuery('PRAGMA table_info($table)');
  final exists = cols.any((c) => c['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $typeClause');
  }
}
