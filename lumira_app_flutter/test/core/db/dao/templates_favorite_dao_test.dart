import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_favorite_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late TemplatesFavoriteDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.templateFavorites} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
    });
    dao = TemplatesFavoriteDao(db);
  });

  tearDown(() => db.close());

  test('初始未收藏', () async {
    expect(await dao.isFavorite('t1'), false);
    expect(await dao.getFavoriteIds(), isEmpty);
  });

  test('addFavorite 后收藏且幂等', () async {
    await dao.addFavorite('t1');
    await dao.addFavorite('t1');
    expect(await dao.isFavorite('t1'), true);
    expect(await dao.countFavorites(), 1);
  });

  test('removeFavorite 取消收藏', () async {
    await dao.addFavorite('t1');
    await dao.removeFavorite('t1');
    expect(await dao.isFavorite('t1'), false);
    expect(await dao.getFavoriteIds(), isEmpty);
  });

  test('toggleFavorite 往返切换返回新状态', () async {
    expect(await dao.toggleFavorite('t1'), true);
    expect(await dao.isFavorite('t1'), true);
    expect(await dao.toggleFavorite('t1'), false);
    expect(await dao.isFavorite('t1'), false);
  });

  test('getFavoriteIds 按收藏时间倒序、多模板独立', () async {
    await dao.addFavorite('a');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await dao.addFavorite('b');
    expect(await dao.getFavoriteIds(), ['b', 'a']);
    expect(await dao.countFavorites(), 2);
  });
}