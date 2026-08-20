import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/search_history_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late SearchHistoryDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute(SearchHistoryTable.createSql);
      await d.execute(SearchHistoryTable.indexSql);
    });
    dao = SearchHistoryDao(db);
  });

  tearDown(() => db.close());

  test('upsert 同 scope+keyword 去重累加并刷新时间', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('template', '人像');
    final rows = await dao.recent('template');
    expect(rows.length, 1);
    expect(rows.first.keyword, '人像');
    expect(rows.first.searchCount, 2);
  });

  test('scope 隔离互不串扰', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('scene', '人像');
    expect((await dao.recent('template')).length, 1);
    expect((await dao.recent('scene')).length, 1);
    expect((await dao.recent('academy')).length, 0);
  });

  test('recent 按 last_searched_at 倒序且限长', () async {
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'B');
    await dao.upsert('template', 'C');
    final rows = await dao.recent('template', limit: 2);
    expect(rows.map((e) => e.keyword).toList(), ['C', 'B']);
  });

  test('recentUnion 跨 scope 按 keyword 去重（保留最新）', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('scene', '人像');
    await dao.upsert('scene', '窗光');
    final union = await dao.recentUnion();
    expect(union.length, 2);
    expect(union.map((e) => e.keyword).toSet(), {'人像', '窗光'});
  });

  test('topByCount 按搜索次数降序', () async {
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'A');
    await dao.upsert('template', 'B');
    final rows = await dao.topByCount('template');
    expect(rows.first.keyword, 'A');
  });

  test('delete / clear 定向删除', () async {
    await dao.upsert('template', '人像');
    await dao.upsert('template', '窗光');
    await dao.delete('template', '人像');
    expect((await dao.recent('template')).length, 1);
    await dao.clear('template');
    expect((await dao.recent('template')).length, 0);
  });
}
