import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_dao.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Database db;
  late CheckinDao dao;

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE ${CheckinTable.name} (
          ${CheckinTable.colId} TEXT PRIMARY KEY,
          ${CheckinTable.colName} TEXT NOT NULL,
          ${CheckinTable.colPlace} TEXT NOT NULL DEFAULT '',
          ${CheckinTable.colCategory} TEXT NOT NULL DEFAULT '',
          ${CheckinTable.colRating} INTEGER NOT NULL DEFAULT 0,
          ${CheckinTable.colNote} TEXT NOT NULL DEFAULT '',
          ${CheckinTable.colVisitedAt} INTEGER NOT NULL,
          ${CheckinTable.colCreatedAt} INTEGER NOT NULL,
          ${CheckinTable.colUpdatedAt} INTEGER NOT NULL
        )
      ''');
    });
    dao = CheckinDao(db);
  });

  tearDown(() => db.close());

  Future<void> insert(CheckinRecord r) => dao.insert(r);

  test('countHighRated 只统计评分 ≥ 4 的足迹', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insert(CheckinRecord(id: '1', name: 'a', rating: 5, visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '2', name: 'b', rating: 3, visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '3', name: 'c', rating: 4, visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '4', name: 'd', rating: 0, visitedAt: now, createdAt: now, updatedAt: now));
    expect(await dao.countHighRated(), 2);
  });

  test('avgRating 只对已评分足迹求平均', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insert(CheckinRecord(id: '1', name: 'a', rating: 4, visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '2', name: 'b', rating: 2, visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '3', name: 'c', rating: 0, visitedAt: now, createdAt: now, updatedAt: now));
    expect(await dao.avgRating(), closeTo(3.0, 0.1));
  });

  test('countThisYear 只统计当年足迹', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final thisYear = DateTime(DateTime.now().year, 6, 1).millisecondsSinceEpoch;
    final lastYear = DateTime(DateTime.now().year - 1, 6, 1).millisecondsSinceEpoch;
    await insert(CheckinRecord(id: '1', name: 'a', visitedAt: thisYear, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '2', name: 'b', visitedAt: lastYear, createdAt: now, updatedAt: now));
    expect(await dao.countThisYear(), 1);
  });

  test('getAllCategories 去重且过滤空分类', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insert(CheckinRecord(id: '1', name: 'a', category: 'coffee', visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '2', name: 'b', category: 'coffee', visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '3', name: 'c', category: 'dessert', visitedAt: now, createdAt: now, updatedAt: now));
    await insert(CheckinRecord(id: '4', name: 'd', category: '', visitedAt: now, createdAt: now, updatedAt: now));
    final cats = await dao.getAllCategories();
    expect(cats.length, 2);
    expect(cats, containsAll(['coffee', 'dessert']));
  });

  test('getByCategory 按分类筛选并倒序', () async {
    await insert(CheckinRecord(id: '1', name: 'a', category: 'coffee', visitedAt: 2000, createdAt: 1, updatedAt: 1));
    await insert(CheckinRecord(id: '2', name: 'b', category: 'coffee', visitedAt: 1000, createdAt: 1, updatedAt: 1));
    await insert(CheckinRecord(id: '3', name: 'c', category: 'dessert', visitedAt: 3000, createdAt: 1, updatedAt: 1));
    final rows = await dao.getByCategory('coffee');
    expect(rows.length, 2);
    expect(rows.first.id, '1');
  });

  test('getByRatingDesc 按评分倒序', () async {
    await insert(CheckinRecord(id: '1', name: 'a', rating: 3, visitedAt: 1000, createdAt: 1, updatedAt: 1));
    await insert(CheckinRecord(id: '2', name: 'b', rating: 5, visitedAt: 2000, createdAt: 1, updatedAt: 1));
    await insert(CheckinRecord(id: '3', name: 'c', rating: 4, visitedAt: 3000, createdAt: 1, updatedAt: 1));
    final rows = await dao.getByRatingDesc();
    expect(rows.map((r) => r.id).toList(), ['2', '3', '1']);
  });
}
