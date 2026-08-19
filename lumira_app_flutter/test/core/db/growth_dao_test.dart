import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
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

  test('getTotalXP sums xp_events ledger only (not user_progress.xp)', () async {
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: 80, XpEventsTable.colRefId: 'c1',
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    await db.insert(XpEventsTable.name, {
      'id': 'course:c2', XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: 120, XpEventsTable.colRefId: 'c2',
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    // 即便 user_progress.xp 有残留，也以台账为准
    await db.update(Tables.userProgress, {Tables.colXp: 999},
        where: '${Tables.colId} = ?', whereArgs: [1]);
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 200); // 80 + 120，忽略 user_progress.xp=999
  });

  test('getTotalXP is idempotent: same source+ref inserts only once', () async {
    for (var i = 0; i < 2; i++) {
      await db.insert(XpEventsTable.name, {
        'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
        XpEventsTable.colAmount: 80, XpEventsTable.colRefId: 'c1',
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final dao = GrowthDao(db);
    expect(await dao.getTotalXP(), 80);
  });

  test('getLevel uses threshold table boundaries', () async {
    Future<int> levelAt(int xp) async {
      // 每个边界独立评估：清空台账，使总XP恰为 xp
      await db.delete(XpEventsTable.name);
      await db.insert(XpEventsTable.name, {
        'id': 'shoot_daily:t$xp', XpEventsTable.colSource: 'shoot_daily',
        XpEventsTable.colAmount: xp, XpEventsTable.colRefId: 't$xp',
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      });
      return GrowthDao(db).getLevel();
    }
    expect(await levelAt(0), 1);
    expect(await levelAt(99), 1);
    expect(await levelAt(100), 2);
    expect(await levelAt(300), 3);
    expect(await levelAt(999), 4);
    expect(await levelAt(1000), 5);
  });

  test('getSummary computes level progress against threshold table', () async {
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: 100, XpEventsTable.colRefId: 'c1',
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    final s = await GrowthDao(db).getSummary();
    expect(s.level, 2);          // 100 → Lv.2
    expect(s.currentXp, 100);
    expect(s.xpToNextLevel, 200); // Lv.3 阈值 300 - 100
    expect(s.levelName, isNotEmpty);
  });

  test('getXpBreakdown groups and computes ratios', () async {
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:c1', XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: 60, XpEventsTable.colRefId: 'c1',
      XpEventsTable.colCreatedAt: 1,
    });
    await db.insert(XpEventsTable.name, {
      'id': 'course:c2', XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: 40, XpEventsTable.colRefId: 'c2',
      XpEventsTable.colCreatedAt: 2,
    });
    final list = await GrowthDao(db).getXpBreakdown();
    expect(list.length, 2);
    expect(list.first.source, 'challenge');
    expect(list.first.amount, 60);
    expect(list.first.ratio, closeTo(0.6, 0.001));
    expect(list.last.source, 'course');
    expect(list.last.ratio, closeTo(0.4, 0.001));
  });

  test('getXpBreakdown returns empty when no ledger', () async {
    expect(await GrowthDao(db).getXpBreakdown(), isEmpty);
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
      ChallengeHistoryTable.colStatus: 'done',
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
  await db.execute(XpEventsTable.createSql);
  await db.execute(XpEventsTable.indexSql);
}
