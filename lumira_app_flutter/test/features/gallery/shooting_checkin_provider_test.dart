import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/gallery/providers/gallery_diary_providers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // 与 gallery_diary_monthly_stats_test 保持一致：用 NoIsolate 工厂，
    // 避免 isolate 通信的 real async 在测试 fake async 下不解析的问题。
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
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

  /// 向 gallery_items 插入某天的一张照片（当天任意时刻）
  Future<void> insertPhoto(DateTime day) async {
    final ts = DateTime(day.year, day.month, day.day, 12)
        .millisecondsSinceEpoch;
    await db.insert(Tables.galleryItems, {
      'id': 'p-${day.millisecondsSinceEpoch}',
      'created_at': ts,
    });
  }

  Future<ShootingCheckin> readCheckin() =>
      container.read(shootingCheckinProvider.future);

  test('空库：streak 0、本周全部未完成、今天未拍', () async {
    final checkin = await readCheckin();
    expect(checkin.streakDays, 0);
    expect(checkin.shotToday, isFalse);
    expect(checkin.weekDays, hasLength(7));
    expect(checkin.weekDays.where((d) => d.done), isEmpty);
  });

  test('今天已拍：streak 从今天起算，本周今天标记为已完成', () async {
    await insertPhoto(today());
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1);
    expect(checkin.shotToday, isTrue);
    expect(checkin.weekDays[today().weekday - 1].done, isTrue);
    expect(checkin.weekDays[today().weekday - 1].today, isTrue);
  });

  test('今天未拍、昨天已拍：streak 从昨天往回数（跨天保留连续性）', () async {
    await insertPhoto(today().subtract(const Duration(days: 1)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1);
    expect(checkin.shotToday, isFalse);
  });

  test('今天未拍、连续拍到昨天：streak 从昨天连续往回数', () async {
    await insertPhoto(today().subtract(const Duration(days: 1)));
    await insertPhoto(today().subtract(const Duration(days: 2)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 2);
    expect(checkin.shotToday, isFalse);
  });

  test('跨周连续：连续 8 天拍摄（跨越上周）不因周界断签', () async {
    for (var i = 0; i < 8; i++) {
      await insertPhoto(today().subtract(Duration(days: i)));
    }
    final checkin = await readCheckin();
    expect(checkin.streakDays, 8);
    expect(checkin.shotToday, isTrue);
  });

  test('隔天断签：断签后 streak 中断并重新起算', () async {
    await insertPhoto(today());
    await insertPhoto(today().subtract(const Duration(days: 2)));
    final checkin = await readCheckin();
    expect(checkin.streakDays, 1); // 只从今天起算
    expect(checkin.shotToday, isTrue);
  });

  test('本周状态：周内各天按是否有照片标记 done，仅今天标记 today', () async {
    final now = today();
    await insertPhoto(now);
    await insertPhoto(now.subtract(const Duration(days: 3)));
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
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colGalleryItemHidden} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
}
