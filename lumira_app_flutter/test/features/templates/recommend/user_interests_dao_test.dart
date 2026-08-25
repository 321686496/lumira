import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/dao/user_interests_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('upsert then getAll returns portrait; replace overwrites score', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(UserInterestsTable.createSql);
    final dao = InterestDao(db);

    await dao.upsert(scope: 'category', key: 'portrait', score: 3.0, at: 1000);
    await dao.upsert(scope: 'style', key: 'fresh', score: 0.6, at: 1000);

    final all = await dao.getAll();
    expect(all['category:portrait']!.score, 3.0);
    expect(all['style:fresh']!.score, 0.6);

    // replace 语义：同 key 覆盖
    await dao.upsert(scope: 'category', key: 'portrait', score: 5.0, at: 2000);
    final updated = await dao.getAll();
    expect(updated['category:portrait']!.score, 5.0);

    // 无记录 read 返回 null
    expect(await dao.read('category', 'nope'), isNull);
    // 有记录 read 回读
    expect((await dao.read('category', 'portrait'))!.lastSignalAt, 2000);

    await db.close();
  });
}