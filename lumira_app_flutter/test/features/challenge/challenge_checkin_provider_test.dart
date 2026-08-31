import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_dao.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_providers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Database db;
  late ChallengeDao dao;
  late ProviderContainer container;

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = ChallengeDao(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => db.close());

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 插入某天的一条"已完成"挑战记录
  Future<void> insertDone(DateTime day) async {
    final ts = day.millisecondsSinceEpoch;
    await dao.insert(ChallengeHistoryRecord(
      id: '${formatDate(day)}_done',
      date: formatDate(day),
      challengeId: 'challenge-done',
      category: ChallengeCategory.portrait,
      title: '测试挑战',
      rewardXP: 10,
      status: ChallengeStatus.done,
      selectedAt: ts,
      completedAt: ts,
    ));
  }

  /// 插入某天的一条"未完成"（pending）挑战记录：不应计入打卡
  Future<void> insertPending(DateTime day) async {
    await dao.insert(ChallengeHistoryRecord(
      id: '${formatDate(day)}_pending',
      date: formatDate(day),
      challengeId: 'challenge-pending',
      category: ChallengeCategory.portrait,
      title: '测试挑战',
      rewardXP: 10,
      status: ChallengeStatus.pending,
      selectedAt: day.millisecondsSinceEpoch,
    ));
  }

  Future<ChallengeCheckin> readCheckin() =>
      container.read(challengeCheckinProvider.future);

  test('空库：streak 0、本周全部未完成、今日未完成', () async {
    final checkin = await readCheckin();
    expect(checkin.streakDays, 0);
    expect(checkin.completedToday, isFalse);
    expect(checkin.weekDays, hasLength(7));
    expect(checkin.weekDays.where((d) => d.done), isEmpty);
  });

  test('今天已完成：streak 从今天起算，本周今天标记为已完成', () async {
    await insertDone(today());
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1);
    expect(checkin.completedToday, isTrue);
    expect(checkin.weekDays[today().weekday - 1].done, isTrue);
    expect(checkin.weekDays[today().weekday - 1].today, isTrue);
  });

  test('今天未完成、昨天已完成：streak 从昨天往回数（跨天保留连续性）', () async {
    await insertDone(today().subtract(const Duration(days: 1)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1);
    expect(checkin.completedToday, isFalse);
  });

  test('今天未完成、连续完成到昨天：streak 从昨天连续往回数', () async {
    await insertDone(today().subtract(const Duration(days: 1)));
    await insertDone(today().subtract(const Duration(days: 2)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 2);
    expect(checkin.completedToday, isFalse);
  });

  test('中间断签：断签后 streak 中断，只保留最近连续段', () async {
    // 今天、昨天完成，前天断签，更早（3/4 天前）又完成过 → streak 应为 2
    await insertDone(today());
    await insertDone(today().subtract(const Duration(days: 1)));
    await insertDone(today().subtract(const Duration(days: 3)));
    await insertDone(today().subtract(const Duration(days: 4)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 2);
    expect(checkin.completedToday, isTrue);
  });

  test('仅拍过照片/选中挑战但未完成的日子不计入打卡', () async {
    // 今天完成、昨天只有 pending（翻牌选中未提交）→ streak 只算今天
    await insertDone(today());
    await insertPending(today().subtract(const Duration(days: 1)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1);
    expect(checkin.completedToday, isTrue);
  });

  test('跨周连续：连续 8 天完成（跨越上周）不因周界断签', () async {
    for (var i = 0; i < 8; i++) {
      await insertDone(today().subtract(Duration(days: i)));
    }
    final checkin = await readCheckin();
    expect(checkin.streakDays, 8);
    expect(checkin.completedToday, isTrue);
  });

  test('本周状态：周内各天按是否完成挑战标记 done，仅今天标记 today', () async {
    final now = today();
    await insertDone(now);
    await insertDone(now.subtract(const Duration(days: 3)));
    final checkin = await readCheckin();
    final idx = now.weekday - 1;
    for (var i = 0; i < 7; i++) {
      final done = (i == idx) || (i == idx - 3);
      expect(checkin.weekDays[i].done, done,
          reason: 'index $i done should be $done');
      expect(checkin.weekDays[i].today, i == idx);
    }
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(ChallengeHistoryTable.createSql);
}
