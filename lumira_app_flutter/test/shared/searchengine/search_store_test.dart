import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/search_history_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_scope.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_store.dart';

void main() {
  late Database db;
  late SearchStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute(SearchHistoryTable.createSql);
      await d.execute(SearchHistoryTable.indexSql);
    });
    store = SearchStore(SearchHistoryDao(db));
  });

  tearDown(() => db.close());

  test('record scope=all 时写入三个真实 scope', () async {
    await store.record(SearchScope.all, '人像');
    expect((await store.recentKeywords(SearchScope.template)), ['人像']);
    expect((await store.recentKeywords(SearchScope.scene)), ['人像']);
    expect((await store.recentKeywords(SearchScope.academy)), ['人像']);
  });

  test('record 去重并置顶', () async {
    await store.record(SearchScope.template, 'A');
    await store.record(SearchScope.template, 'B');
    await store.record(SearchScope.template, 'A');
    final keywords = await store.recentKeywords(SearchScope.template);
    expect(keywords, ['A', 'B']);
  });

  test('recentKeywords scope=all 返回跨 scope 去重并集', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.scene, '人像');
    await store.record(SearchScope.scene, '窗光');
    final all = await store.recentKeywords(SearchScope.all);
    expect(all.length, 2);
    expect(all.toSet(), {'人像', '窗光'});
  });

  test('hotKeywords = 预置词 ∪ 高频历史，去重且限长', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.template, '高频自造词');
    final hot = await store.hotKeywords(SearchScope.template, limit: 20);
    expect(hot.first, '人像'); // 预置词在前
    expect(hot, contains('高频自造词')); // 高频历史并入
    expect(hot.toSet().length, hot.length);
  });

  test('deleteKeyword / clear 按 scope 定向操作，all 时三写全删', () async {
    await store.record(SearchScope.template, '人像');
    await store.record(SearchScope.scene, '人像');
    await store.deleteKeyword(SearchScope.all, '人像');
    expect((await store.recentKeywords(SearchScope.all)).length, 0);

    await store.record(SearchScope.template, '窗光');
    await store.record(SearchScope.scene, '夜景');
    await store.clear(SearchScope.all);
    expect((await store.recentKeywords(SearchScope.template)).length, 0);
    expect((await store.recentKeywords(SearchScope.scene)).length, 0);
    expect((await store.recentKeywords(SearchScope.academy)).length, 0);
  });
}
