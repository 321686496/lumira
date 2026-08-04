import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/seeders/builtin_data_seeder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('reseedBuiltinCovers updates 12 builtin covers from picsum to asset paths', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 1,
        onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE ${Tables.customTemplates} (
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
          ${Tables.colCreatedAt} INTEGER NOT NULL,
          ${Tables.colUpdatedAt} INTEGER NOT NULL
        )
      ''');
    });

    // Insert a builtin template with old picsum URL
    await db.insert(Tables.customTemplates, {
      Tables.colId: 'cafe_portrait',
      Tables.colName: '咖啡馆人像',
      Tables.colCategory: 'portrait',
      Tables.colCover: 'https://picsum.photos/seed/template-cafe-portrait/400/600',
      Tables.colIsBuiltin: 1,
      Tables.colCreatedAt: 1700000000000,
      Tables.colUpdatedAt: 1700000000000,
    });

    await BuiltinDataSeeder.reseedBuiltinCovers(db);

    final rows = await db.query(Tables.customTemplates,
        where: '${Tables.colId} = ?', whereArgs: ['cafe_portrait']);
    expect(rows, isNotEmpty);
    expect(rows.first[Tables.colCover], 'assets/images/templates/cafe_portrait.jpg');
    await db.close();
  });
}
