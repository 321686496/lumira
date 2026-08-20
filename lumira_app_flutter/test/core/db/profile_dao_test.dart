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
            synced_at INTEGER,
            gender TEXT,
            favorite_categories_json TEXT,
            pain_points_json TEXT,
            skill_level TEXT,
            expectations_json TEXT,
            common_scenes_json TEXT,
            shoot_frequency TEXT,
            avatar_url TEXT
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

  test('upsert/get roundtrip preserves new fields (json lists, null, empty)', () async {
    const full = ProfileData(
      username: '丰富昵称',
      avatarSeed: 'seed',
      gender: 'female',
      favoriteCategories: ['portrait', 'food'],
      painPoints: ['blurry', 'light'],
      skillLevel: 'intermediate',
      expectations: ['growth'],
      commonScenes: ['street'],
      shootFrequency: 'weekly',
      avatarUrl: 'https://cdn.example.com/avatar/a.png',
    );
    await dao.upsert(full, 1700000000);
    final loaded = await dao.get();
    expect(loaded!.username, '丰富昵称');
    expect(loaded.gender, 'female');
    expect(loaded.favoriteCategories, ['portrait', 'food']);
    expect(loaded.painPoints, ['blurry', 'light']);
    expect(loaded.skillLevel, 'intermediate');
    expect(loaded.expectations, ['growth']);
    expect(loaded.commonScenes, ['street']);
    expect(loaded.shootFrequency, 'weekly');
    expect(loaded.avatarUrl, 'https://cdn.example.com/avatar/a.png');
  });

  test('upsert/get roundtrip with empty lists and null optionals', () async {
    await dao.upsert(const ProfileData(username: '空资料', avatarSeed: 'seed2'), 1700000001);
    final loaded = await dao.get();
    expect(loaded!.username, '空资料');
    expect(loaded.gender, isNull);
    expect(loaded.favoriteCategories, isEmpty);
    expect(loaded.painPoints, isEmpty);
    expect(loaded.skillLevel, isNull);
    expect(loaded.expectations, isEmpty);
    expect(loaded.commonScenes, isEmpty);
    expect(loaded.shootFrequency, isNull);
    expect(loaded.avatarUrl, isNull);
  });
}
