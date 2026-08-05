import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/features/profile/data/profile_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late UserProfileDao dao;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY DEFAULT 1,
            username TEXT NOT NULL,
            avatar_seed TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            synced_at INTEGER
          )
        ''');
      },
    );
    dao = UserProfileDao(db);
  });

  tearDown(() async => db.close());

  const profile = ProfileData(username: '测试昵称', avatarSeed: 'lumira-avatar-01');

  test('get returns null when no record', () async {
    expect(await dao.get(), isNull);
  });

  test('upsert then get returns profile', () async {
    await dao.upsert(profile, 1700000000);
    final loaded = await dao.get();
    expect(loaded, isNotNull);
    expect(loaded!.username, '测试昵称');
    expect(loaded.avatarSeed, 'lumira-avatar-01');
    expect(loaded.syncedAt, isNull);
  });

  test('upsert overwrites existing row (single row)', () async {
    await dao.upsert(profile, 1700000000);
    await dao.upsert(const ProfileData(username: '新昵称', avatarSeed: 'lumira-avatar-02'), 1700000001);
    final rows = await db.query('user_profile');
    expect(rows.length, 1);
    final loaded = await dao.get();
    expect(loaded!.username, '新昵称');
    expect(loaded.avatarSeed, 'lumira-avatar-02');
  });

  test('hasUnsynced is false after markSynced', () async {
    await dao.upsert(profile, 1700000000);
    expect(await dao.hasUnsynced(), isTrue);
    await dao.markSynced(1700000100);
    expect(await dao.hasUnsynced(), isFalse);
    expect((await dao.get())!.syncedAt, 1700000100);
  });
}
