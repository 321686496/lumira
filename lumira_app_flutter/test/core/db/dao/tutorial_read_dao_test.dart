import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/tutorial_read_dao.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TutorialReadDao dao;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE IF NOT EXISTS tutorial_reads (
              id TEXT PRIMARY KEY,
              read_at INTEGER
            )
          ''');
        },
      ),
    );
    dao = TutorialReadDao(db);
  });

  tearDown(() async => db.close());

  test('markRead 后 getReadIds 返回，重复 markRead 幂等', () async {
    await dao.markRead('tut_general_premium');
    await dao.markRead('tut_general_premium');
    await dao.markRead('tut_portrait_window');
    final ids = await dao.getReadIds();
    expect(ids, {'tut_general_premium', 'tut_portrait_window'});
  });

  test('markUnread 移除记录', () async {
    await dao.markRead('tut_general_premium');
    await dao.markUnread('tut_general_premium');
    expect(await dao.getReadIds(), isEmpty);
  });
}