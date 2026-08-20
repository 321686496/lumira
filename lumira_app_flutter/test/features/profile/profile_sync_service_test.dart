import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// 注意：不需要显式 import 'package:sqflite/sqflite.dart'，sqflite_common_ffi 已 re-export
// Database / openDatabase / inMemoryDatabasePath 等公共 API。

import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/profile/data/builtin_profiles.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_models.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_repository.dart';
import 'package:lumira_app_flutter/features/profile/services/profile_sync_service.dart';

class FakeProfileRepository implements ProfileRepository {
  ProfileData? remote;
  bool failUpdate = false;
  int updateCalls = 0;
  bool failUpload = false;

  @override
  Future<ProfileData> fetch() async =>
      remote ?? const ProfileData(username: '远程默认', avatarSeed: 'lumira-avatar-01');

  @override
  Future<ProfileData> update({
    required String? username,
    required String? avatarSeed,
    String? gender,
    List<String>? favoriteCategories,
    List<String>? painPoints,
    String? skillLevel,
    List<String>? expectations,
    List<String>? commonScenes,
    String? shootFrequency,
    String? avatarUrl,
  }) async {
    updateCalls++;
    if (failUpdate) throw const ApiException(ApiErrorKind.network, 'network error');
    final base = remote ?? const ProfileData(username: '', avatarSeed: '');
    remote = ProfileData(
      username: username ?? base.username,
      avatarSeed: avatarSeed ?? base.avatarSeed,
      gender: gender ?? base.gender,
      favoriteCategories: favoriteCategories ?? base.favoriteCategories,
      painPoints: painPoints ?? base.painPoints,
      skillLevel: skillLevel ?? base.skillLevel,
      expectations: expectations ?? base.expectations,
      commonScenes: commonScenes ?? base.commonScenes,
      shootFrequency: shootFrequency ?? base.shootFrequency,
      avatarUrl: avatarUrl ?? base.avatarUrl,
    );
    return remote!;
  }

  @override
  Future<String> uploadAvatarBytes(Uint8List bytes, String filename) async {
    if (failUpload) throw const ApiException(ApiErrorKind.network, 'network error');
    return 'https://cdn.example.com/avatar/uploaded.png';
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

  test('fromJson/toJson roundtrip preserves new fields', () {
    const p = ProfileData(
      username: '昵称',
      avatarSeed: 'seed',
      gender: 'female',
      favoriteCategories: ['portrait', 'food'],
      painPoints: ['blurry'],
      skillLevel: 'intermediate',
      expectations: ['growth'],
      commonScenes: ['street', 'night'],
      shootFrequency: 'weekly',
      avatarUrl: 'https://cdn.example.com/avatar/a.png',
    );
    final r = ProfileData.fromJson(p.toJson());
    expect(r.username, '昵称');
    expect(r.gender, 'female');
    expect(r.favoriteCategories, ['portrait', 'food']);
    expect(r.painPoints, ['blurry']);
    expect(r.skillLevel, 'intermediate');
    expect(r.expectations, ['growth']);
    expect(r.commonScenes, ['street', 'night']);
    expect(r.shootFrequency, 'weekly');
    expect(r.avatarUrl, 'https://cdn.example.com/avatar/a.png');
    // 缺失的列表字段应解析为空列表
    final empty = ProfileData.fromJson({'username': 'x', 'avatarSeed': 'y'});
    expect(empty.favoriteCategories, isEmpty);
    expect(empty.painPoints, isEmpty);
    expect(empty.gender, isNull);
  });

  test('save passes through new fields to backend', () async {
    const p = ProfileData(
      username: '偏好昵称',
      avatarSeed: 'seed',
      gender: 'male',
      favoriteCategories: ['portrait'],
      painPoints: ['light'],
      skillLevel: 'advanced',
      expectations: ['career'],
      commonScenes: ['studio'],
      shootFrequency: 'daily',
      avatarUrl: 'https://cdn.example.com/avatar/b.png',
    );
    final result = await sync.save(p);
    expect(result.success, isTrue);
    expect(repo.remote!.gender, 'male');
    expect(repo.remote!.favoriteCategories, ['portrait']);
    expect(repo.remote!.painPoints, ['light']);
    expect(repo.remote!.skillLevel, 'advanced');
    expect(repo.remote!.expectations, ['career']);
    expect(repo.remote!.commonScenes, ['studio']);
    expect(repo.remote!.shootFrequency, 'daily');
    expect(repo.remote!.avatarUrl, 'https://cdn.example.com/avatar/b.png');
  });

  test('BuiltinProfiles.avatarUrl prefers customUrl', () {
    expect(
      BuiltinProfiles.avatarUrl('seed', customUrl: 'https://cdn.example.com/c.png'),
      'https://cdn.example.com/c.png',
    );
    expect(
      BuiltinProfiles.avatarUrl('seed', customUrl: ''),
      'https://picsum.photos/seed/seed/200/200',
    );
    expect(BuiltinProfiles.avatarUrl('seed'), 'https://picsum.photos/seed/seed/200/200');
  });

  test('uploadAvatar delegates and returns url', () async {
    final url = await sync.uploadAvatar(Uint8List.fromList([1, 2, 3]), 'a.png');
    expect(url, 'https://cdn.example.com/avatar/uploaded.png');
  });
}
