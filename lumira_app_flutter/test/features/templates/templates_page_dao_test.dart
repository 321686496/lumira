import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';

/// Plan A Task A4 — TemplatesDao.getBuiltin 筛选测试
///
/// 验证 `TemplatesDao.getBuiltin({isRecommended, price, paidOnly, category})`
/// 与 `TemplatesDao.getCustomOnly()` 的 SQL 筛选行为。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    // 插入测试数据：3 recommended + 5 free + 4 paid
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 12; i++) {
      await db.insert(Tables.customTemplates, {
        Tables.colId: 'tpl_$i',
        Tables.colName: '模板 $i',
        Tables.colCategory: 'portrait',
        Tables.colPrice: i < 8 ? 0 : 100,
        Tables.colIsBuiltin: 1,
        Tables.colIsRecommended: i < 3 ? 1 : 0,
        Tables.colCreatedAt: now + i,
        Tables.colUpdatedAt: now + i,
      });
    }
  });

  tearDown(() async => db.close());

  test('getBuiltin returns all 12 builtin templates', () async {
    final dao = TemplatesDao(db);
    final all = await dao.getBuiltin();
    expect(all.length, 12);
  });

  test('getBuiltin isRecommended=true returns 3', () async {
    final dao = TemplatesDao(db);
    final rec = await dao.getBuiltin(isRecommended: true);
    expect(rec.length, 3);
    expect(rec.every((t) => t.isRecommended), isTrue);
  });

  test('getBuiltin price=0 returns 8 free', () async {
    final dao = TemplatesDao(db);
    final free = await dao.getBuiltin(price: 0);
    expect(free.length, 8);
  });

  test('getBuiltin price>0 returns 4 paid', () async {
    final dao = TemplatesDao(db);
    final paid = await dao.getBuiltin(paidOnly: true);
    expect(paid.length, 4);
  });
}

Future<void> _onCreate(Database db, int version) async {
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
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}
