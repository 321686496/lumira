import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/growth_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() async => db.close());

  test('getTotalXP returns user_progress.xp when row exists', () async {
    await db.update(Tables.userProgress, {Tables.colXp: 350},
        where: '${Tables.colId} = ?', whereArgs: [1]);
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 350);
  });

  test('getTotalXP falls back to challenge_history sum when xp=0', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: 'ch_1',
      ChallengeHistoryTable.colDate: '2026-07-25',
      ChallengeHistoryTable.colChallengeId: 'c1',
      ChallengeHistoryTable.colCategory: 'portrait',
      ChallengeHistoryTable.colTitle: 'T1',
      ChallengeHistoryTable.colRewardXp: 80,
      ChallengeHistoryTable.colStatus: 'completed',
      ChallengeHistoryTable.colSelectedAt: now,
      ChallengeHistoryTable.colCompletedAt: now,
    });
    await db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: 'ch_2',
      ChallengeHistoryTable.colDate: '2026-07-25',
      ChallengeHistoryTable.colChallengeId: 'c2',
      ChallengeHistoryTable.colCategory: 'landscape',
      ChallengeHistoryTable.colTitle: 'T2',
      ChallengeHistoryTable.colRewardXp: 50,
      ChallengeHistoryTable.colStatus: 'completed',
      ChallengeHistoryTable.colSelectedAt: now,
      ChallengeHistoryTable.colCompletedAt: now,
    });
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 130); // 80 + 50
  });

  test('getLevel returns xp/500 + 1', () async {
    await db.update(Tables.userProgress, {Tables.colXp: 1200},
        where: '${Tables.colId} = ?', whereArgs: [1]);
    final dao = GrowthDao(db);
    expect(await dao.getLevel(), 3); // 1200/500 + 1 = 3 (整数除法)
  });

  test('getAchievements returns 6 placeholder when achievements_json is []', () async {
    final dao = GrowthDao(db);
    final ach = await dao.getAchievements();
    expect(ach.length, 6);
    expect(ach.every((a) => !a.unlocked), isTrue);
  });

  test('getGrowthTrajectory unions challenge + gallery events DESC LIMIT 4', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: 'ch_1',
      ChallengeHistoryTable.colDate: '2026-07-25',
      ChallengeHistoryTable.colChallengeId: 'c1',
      ChallengeHistoryTable.colCategory: 'portrait',
      ChallengeHistoryTable.colTitle: '挑战 T1',
      ChallengeHistoryTable.colRewardXp: 80,
      ChallengeHistoryTable.colStatus: 'completed',
      ChallengeHistoryTable.colSelectedAt: now,
      ChallengeHistoryTable.colCompletedAt: now,
    });
    await db.insert(Tables.galleryItems, {
      Tables.colId: 'g_1',
      Tables.colCreatedAt: now + 1000,
    });
    final dao = GrowthDao(db);
    final traj = await dao.getGrowthTrajectory();
    expect(traj.length, 2);
    // 时间倒序：gallery(较晚) 在前
    expect(traj.first.type, 'milestone');
    expect(traj.last.type, 'challenge');
  });
}

Future<void> _onCreate(db, version) async {
  await db.execute('''
    CREATE TABLE ${Tables.userProgress} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colLevelName} TEXT NOT NULL DEFAULT '新手',
      ${Tables.colXp} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colXpToNextLevel} INTEGER NOT NULL DEFAULT 100,
      ${Tables.colTotalPhotos} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUsedTemplates} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colFavorites} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colStreakDays} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLastCheckInDate} TEXT,
      ${Tables.colFragmentsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colAchievementsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.insert(Tables.userProgress, {Tables.colId: 1, Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch});
  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(AcademyTables.cpCreateSql);
}
