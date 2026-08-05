import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// 注意：不需要显式 import 'package:sqflite/sqflite.dart'，sqflite_common_ffi 已 re-export
// Database / openDatabase / inMemoryDatabasePath 等公共 API。

import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_repository.dart';
import 'package:lumira_app_flutter/features/profile/services/profile_sync_service.dart';

class FakeProfileRepository implements ProfileRepository {
  ProfileData? remote;
  bool failUpdate = false;
  int updateCalls = 0;

  @override
  Future<ProfileData> fetch() async =>
      remote ?? const ProfileData(username: '远程默认', avatarSeed: 'lumira-avatar-01');

  @override
  Future<ProfileData> update({required String? username, required String? avatarSeed}) async {
    updateCalls++;
    if (failUpdate) throw const ApiException(ApiErrorKind.network, 'network error');
    remote = ProfileData(
      username: username ?? remote!.username,
      avatarSeed: avatarSeed ?? remote!.avatarSeed,
    );
    return remote!;
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late UserProfileDao dao;
  late FakeProfileRepository repo;
  late ProfileSyncService sync;

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
    repo = FakeProfileRepository();
    sync = ProfileSyncService(dao: dao, repository: repo);
  });

  tearDown(() async => db.close());

  test('save persists locally and syncs to backend', () async {
    final result = await sync.save(const ProfileData(username: '新昵称', avatarSeed: 'lumira-avatar-02'));
    expect(result.success, isTrue);
    expect(result.synced, isTrue);
    expect(repo.updateCalls, 1);
    expect(repo.remote!.username, '新昵称');
    expect((await dao.get())!.syncedAt, isNotNull);
  });

  test('save keeps local when backend fails and marks unsynced', () async {
    repo.failUpdate = true;
    final result = await sync.save(const ProfileData(username: '离线昵称', avatarSeed: 'lumira-avatar-03'));
    expect(result.success, isTrue);
    expect(result.synced, isFalse);
    expect((await dao.get())!.username, '离线昵称');
    expect(await dao.hasUnsynced(), isTrue);
  });

  test('ensureLoadedIfMissing fetches from backend when local empty', () async {
    await sync.ensureLoadedIfMissing();
    final loaded = await dao.get();
    expect(loaded!.username, '远程默认');
    expect(await dao.hasUnsynced(), isFalse);
  });

  test('ensureLoadedIfMissing skips when local exists', () async {
    await dao.upsert(const ProfileData(username: '本地昵称', avatarSeed: 'lumira-avatar-01'), 1700000000);
    await sync.ensureLoadedIfMissing();
    expect((await dao.get())!.username, '本地昵称');
  });

  test('syncPendingIfNeeded retries unsynced changes', () async {
    repo.failUpdate = true;
    await sync.save(const ProfileData(username: '待同步', avatarSeed: 'lumira-avatar-04'));
    expect(await dao.hasUnsynced(), isTrue);
    repo.failUpdate = false;
    await sync.syncPendingIfNeeded();
    expect(await dao.hasUnsynced(), isFalse);
    expect(repo.remote!.username, '待同步');
  });
}
