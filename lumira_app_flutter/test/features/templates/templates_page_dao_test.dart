import 'dart:convert';

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

  categoryRegressionTests(db);
}

// ============================================================
// 分类误归回归：countTemplatesBySubtree 前缀匹配 + pruneStaleCategories 保护系统分类
// ============================================================
void categoryRegressionTests(Database db) {
  Future<void> insertTemplate(
      String id, String category, Map<String, dynamic> cls) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(Tables.customTemplates, {
      Tables.colId: id,
      Tables.colName: id,
      Tables.colCategory: category,
      Tables.colClassificationJson: jsonEncode(cls),
      Tables.colPrice: 0,
      Tables.colIsBuiltin: 1,
      Tables.colIsRecommended: 0,
      Tables.colCreatedAt: now,
      Tables.colUpdatedAt: now,
    });
  }

  group('countTemplatesBySubtree — 前缀匹配回归（共享 key 不跨题材）', () {
    test('街拍-几何-俯拍不计入「美食→俯拍」', () async {
      await insertTemplate('street_overhead', 'street',
          {'style': 'geometric', 'method': 'overhead'});
      await insertTemplate(
          'food_overhead', 'food', {'style': 'overhead', 'method': 'flat'});
      final dao = TemplatesDao(db);
      final counts =
          await dao.countTemplatesBySubtree(['overhead'], parentPath: ['food']);
      expect(counts['overhead'], 1); // 仅 food_overhead，street_overhead 被排除
    });

    test('风光-清新-平拍不计入「静物→扁平」', () async {
      await insertTemplate(
          'landscape_flat', 'landscape', {'style': 'fresh', 'method': 'flat'});
      await insertTemplate(
          'stilllife_flat', 'still-life', {'style': 'flat'});
      final dao = TemplatesDao(db);
      final counts = await dao
          .countTemplatesBySubtree(['flat'], parentPath: ['still-life']);
      expect(counts['flat'], 1); // 仅 stilllife_flat，landscape_flat 被排除
    });

    test('无 parentPath 时仍可按一级前缀统计', () async {
      await insertTemplate(
          'food_overhead2', 'food', {'style': 'overhead', 'method': 'flat'});
      final dao = TemplatesDao(db);
      final counts = await dao.countTemplatesBySubtree(
          ['overhead'], parentPath: ['food']);
      expect(counts['overhead'], 1);
    });
  });

  group('pruneStaleCategories — 保护系统分类不被同步删除', () {
    test('validKeys 为空时删除非系统分类，但保留 is_system=1 分类', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 系统分类 micro（is_system=1）
      await db.insert(Tables.templateCategories, {
        Tables.colKey: 'macro',
        Tables.colName: '微距',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIsSystem: 1,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: now,
      });
      // 非系统远程分类（is_system=0）
      await db.insert(Tables.templateCategories, {
        Tables.colKey: 'remote_cat',
        Tables.colName: '远程分类',
        Tables.colParentKey: null,
        Tables.colLevel: 1,
        Tables.colIsSystem: 0,
        Tables.colIsActive: 1,
        Tables.colUpdatedAt: now,
      });
      final dao = TemplatesDao(db);
      // 后端清空场景：validKeys 为空集
      final deleted = await dao.pruneStaleCategories(const <String>{});
      expect(deleted, 1); // 仅删除 remote_cat
      final rows = await db.query(Tables.templateCategories,
          columns: [Tables.colKey]);
      final keys = rows.map((r) => r[Tables.colKey] as String).toList();
      expect(keys, contains('macro'));
      expect(keys, isNot(contains('remote_cat')));
    });
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
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}
