import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_content.dart';

/// v26 迁移测试：验证建 xp_events 表 + 唯一索引、user_progress 加
/// xp_reward_claimed_level 默认 0，以及回填历史挑战/课程经验。
///
/// 仿 migration_v15_test.dart 模式：在测试内复制迁移逻辑（私有方法无法直接调用）。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 26,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v26 creates xp_events table with columns + unique index', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='xp_events'",
    );
    expect(tables.length, 1);
    final cols = await db.rawQuery('PRAGMA table_info(xp_events)');
    final names = cols.map((c) => c['name'] as String).toSet();
    expect(names, containsAll(['id', 'source', 'amount', 'ref_id', 'created_at']));
    final idx = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name='uq_xp_events_source_ref'",
    );
    expect(idx.length, 1);
  });

  test('v26 adds xp_reward_claimed_level to user_progress default 0', () async {
    final cols = await db.rawQuery('PRAGMA table_info(user_progress)');
    final col = cols.firstWhere((c) => c['name'] == 'xp_reward_claimed_level');
    expect(col['dflt_value'], '0');
    expect(col['notnull'], 1);
  });

  test('backfill: challenge_history done → xp_events.challenge', () async {
    await db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: 'ch_9',
      ChallengeHistoryTable.colDate: '2026-08-01',
      ChallengeHistoryTable.colChallengeId: 'c9',
      ChallengeHistoryTable.colCategory: 'portrait',
      ChallengeHistoryTable.colTitle: 'T9',
      ChallengeHistoryTable.colRewardXp: 60,
      ChallengeHistoryTable.colStatus: 'done',
      ChallengeHistoryTable.colSelectedAt: 1,
      ChallengeHistoryTable.colCompletedAt: 2,
    });
    await _backfillXpLedger(db);
    final rows = await db.query(XpEventsTable.name);
    expect(rows.length, 1);
    expect(rows.first['source'], 'challenge');
    expect(rows.first['amount'], 60);
    expect(rows.first['ref_id'], 'ch_9');
  });

  test('backfill: completed course known in AcademyContent → xp_events.course', () async {
    final known = AcademyContent.courses.first;
    await db.insert(AcademyTables.courseProgress, {
      AcademyTables.cpColCourseId: known.id,
      AcademyTables.cpColStatus: 'completed',
    });
    await _backfillXpLedger(db);
    final rows = await db.query(XpEventsTable.name);
    expect(rows.length, 1);
    expect(rows.first['source'], 'course');
    expect(rows.first['amount'], known.rewardXP);
    expect(rows.first['ref_id'], known.id);
  });

  test('backfill: unknown course id is skipped (no inflated xp)', () async {
    await db.insert(AcademyTables.courseProgress, {
      AcademyTables.cpColCourseId: 'not-a-real-course',
      AcademyTables.cpColStatus: 'completed',
    });
    await _backfillXpLedger(db);
    expect(await db.query(XpEventsTable.name), isEmpty);
  });
}

/// 复制 v26 迁移（_onCreate 段）的最小结构：建 user_progress（含新列）、
/// challenge_history、academy_course_progress、xp_events + 唯一索引，并回填。
Future<void> _onCreate(Database db, int version) async {
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
  await db.execute(
    'ALTER TABLE ${Tables.userProgress} ADD COLUMN ${Tables.colXpRewardClaimedLevel} INTEGER NOT NULL DEFAULT 0',
  );
  await db.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });
  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(XpEventsTable.createSql);
  await db.execute(XpEventsTable.indexSql);
  await _backfillXpLedger(db);
}

/// 复制 v26 迁移的 _onUpgrade 逻辑（oldVersion < 26 时最小迁移 + 回填）。
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 26) {
    await db.execute(XpEventsTable.createSql);
    await db.execute(XpEventsTable.indexSql);
    await db.execute(
      'ALTER TABLE ${Tables.userProgress} ADD COLUMN ${Tables.colXpRewardClaimedLevel} INTEGER NOT NULL DEFAULT 0',
    );
    await _backfillXpLedger(db);
  }
}

/// 复制 database_provider.dart 的私有 _backfillXpLedger 语义。
Future<void> _backfillXpLedger(Database db) async {
  // --- challenge ---
  final chRows = await db.rawQuery('''
    SELECT ${ChallengeHistoryTable.colId} AS id,
           ${ChallengeHistoryTable.colRewardXp} AS xp
    FROM ${ChallengeHistoryTable.name}
    WHERE ${ChallengeHistoryTable.colStatus} = 'done'
  ''');
  for (final r in chRows) {
    final id = r['id'] as String?;
    final xp = (r['xp'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:$id',
      XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: id,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // --- course（id→rewardXP 映射来自 AcademyContent.courses） ---
  final Map<String, int> courseXp = {};
  for (final c in AcademyContent.courses) {
    courseXp[c.id] = c.rewardXP;
  }
  final cpRows = await db.rawQuery('''
    SELECT ${AcademyTables.cpColCourseId} AS cid
    FROM ${AcademyTables.courseProgress}
    WHERE ${AcademyTables.cpColStatus} = 'completed'
  ''');
  for (final r in cpRows) {
    final cid = r['cid'] as String?;
    final xp = cid == null ? 0 : (courseXp[cid] ?? 0);
    if (cid == null || cid.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'course:$cid',
      XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: cid,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}