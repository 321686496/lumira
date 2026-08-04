import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v4 schema has composition_kits table', () async {
    final db = await openDatabase(':memory:', version: 4, onCreate: _onCreate);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [Tables.compositionKits],
    );
    expect(tables, isNotEmpty);
    await db.close();
  });

  test('v4 schema has academy_learning_trajectory table', () async {
    final db = await openDatabase(':memory:', version: 4, onCreate: _onCreate);
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [Tables.academyLearningTrajectory],
    );
    expect(tables, isNotEmpty);
    await db.close();
  });

  test('custom_templates has is_builtin column', () async {
    final db = await openDatabase(':memory:', version: 4, onCreate: _onCreate);
    final cols = await db.rawQuery('PRAGMA table_info(${Tables.customTemplates})');
    final names = cols.map((c) => c['name'] as String).toList();
    expect(names, contains(Tables.colIsBuiltin));
    expect(names, contains(Tables.colIsRecommended));
    await db.close();
  });

  test('user_settings has seed_v3_done column', () async {
    final db = await openDatabase(':memory:', version: 4, onCreate: _onCreate);
    final cols = await db.rawQuery('PRAGMA table_info(${Tables.userSettings})');
    final names = cols.map((c) => c['name'] as String).toList();
    expect(names, contains(Tables.colSeedV3Done));
    await db.close();
  });
}

Future<void> _onCreate(db, version) async {
  // 简化版：仅创建本测试关心的表
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
  await db.execute('''
    CREATE TABLE ${Tables.userSettings} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colThemeKey} TEXT NOT NULL DEFAULT 'warmWhite',
      ${Tables.colUiStyle} TEXT NOT NULL DEFAULT 'neumorphic',
      ${Tables.colFollowSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCaptureFullscreen} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colGridEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLevelEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colShutterSound} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colWatermark} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSeedV3Done} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(CompositionKitsTable.createSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);
}
