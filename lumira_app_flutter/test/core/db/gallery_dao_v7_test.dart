import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v7 migration adds original_path, transform, post_process columns to gallery_items', () async {
    final dbPath = p.join((await Directory.systemTemp.createTemp('v7_test_')).path, 'test_v7.db');

    // Create v6 schema (without new columns)
    final db = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE ${Tables.galleryItems} (
            ${Tables.colId} TEXT PRIMARY KEY,
            ${Tables.colDataUrl} TEXT,
            ${Tables.colFilePath} TEXT,
            ${Tables.colSceneId} TEXT,
            ${Tables.colTemplateId} TEXT,
            ${Tables.colKitId} TEXT,
            ${Tables.colMood} TEXT,
            ${Tables.colLut} TEXT,
            ${Tables.colCreatedAt} INTEGER NOT NULL
          )
        ''');
      },
    );

    // Insert a v6-style record (no new columns)
    await db.insert(Tables.galleryItems, {
      Tables.colId: 'old_photo_1',
      Tables.colFilePath: '/tmp/old.jpg',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    await db.close();

    // Now open with v7 schema and run migration
    final db2 = await openDatabase(
      dbPath,
      version: 7,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colOriginalPath, 'TEXT');
          await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colTransform, 'TEXT');
          await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colPostProcess, 'TEXT');
        }
      },
    );

    // Verify columns exist
    final cols = await db2.rawQuery('PRAGMA table_info(${Tables.galleryItems})');
    final colNames = cols.map((c) => c['name'] as String).toList();
    expect(colNames, contains(Tables.colOriginalPath));
    expect(colNames, contains(Tables.colTransform));
    expect(colNames, contains(Tables.colPostProcess));

    // Verify old record has null new fields
    final rows = await db2.query(Tables.galleryItems);
    expect(rows.length, 1);
    expect(rows.first[Tables.colOriginalPath], isNull);
    expect(rows.first[Tables.colTransform], isNull);
    expect(rows.first[Tables.colPostProcess], isNull);

    await db2.close();
  });
}

Future<void> _addColumnIfNotExists(Database db, String table, String column, String typeClause) async {
  final cols = await db.rawQuery('PRAGMA table_info($table)');
  final exists = cols.any((c) => c['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $typeClause');
  }
}
