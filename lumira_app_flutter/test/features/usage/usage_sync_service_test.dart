import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/usage_dao.dart';
import 'package:lumira_app_flutter/features/usage/usage_sync_service.dart';

/// 建 usage_events / usage_stats 两表（与 database_provider._createUsageTables 同构）。
Future<void> _createUsageTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageEvents} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colClientEventId} TEXT NOT NULL UNIQUE,
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colItemSource} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colOccurredAt} INTEGER NOT NULL,
      ${Tables.colSynced} INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageStats} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colEventType})
    )
  ''');
}

/// 可编程 fake 网络：记录 postEvents 载荷，可抛错模拟离线。
class FakeUsageNetwork implements UsageNetwork {
  int postCalls = 0;
  int getCalls = 0;
  List<Map<String, dynamic>>? lastPosted;
  bool fail = false;
  Map<String, dynamic> statsResponse = {'items': <Map<String, dynamic>>[]};

  @override
  Future<void> postEvents(Map<String, dynamic> body) async {
    if (fail) throw Exception('network down');
    postCalls++;
    lastPosted = (body['events'] as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> fetchStats(Map<String, dynamic> query) async {
    if (fail) throw Exception('network down');
    getCalls++;
    return statsResponse;
  }
}

void main() {
  late Database db;
  late UsageDao dao;
  late FakeUsageNetwork network;
  late UsageSyncService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, _) async {
      await _createUsageTables(d);
    });
    dao = UsageDao(db);
    network = FakeUsageNetwork();
    service = UsageSyncService(dao, network);
  });

  tearDown(() async => db.close());

  test('runSync 上报未同步事件后标记已同步', () async {
    await dao.enqueueEvent(
      clientEventId: 'evt-1',
      itemType: UsageItemType.template,
      itemId: 'builtin_t1',
      itemSource: 'builtin',
      eventType: UsageEventType.openDetail,
      occurredAt: 1,
    );
    final ok = await service.runSync();
    expect(ok, isTrue);
    expect(network.postCalls, 1);
    expect(network.lastPosted, hasLength(1));
    expect(network.lastPosted!.first['clientEventId'], 'evt-1');
    expect(await dao.getUnsyncedEvents(), isEmpty);
  });

  test('runSync 无待同步事件不进行上报', () async {
    final ok = await service.runSync();
    expect(ok, isTrue);
    expect(network.postCalls, 0);
  });

  test('runSync 拉取模板+场景次数写入 usage_stats', () async {
    network.statsResponse = {
      'items': [
        {
          'itemId': 'builtin_t1',
          'useShoot': 3,
          'openDetail': 2,
          'sceneSelect': 0,
        },
      ],
    };
    final ok = await service.runSync();
    expect(ok, isTrue);
    expect(network.getCalls, 2); // template + scene
    // 模板次数已入快照
    expect(await dao.countFor('template', 'builtin_t1', 'use_shoot'), 3);
    expect(await dao.countFor('template', 'builtin_t1', 'open_detail'), 2);
  });

  test('runSync 离线（网络抛错）返回 false 且不标记已同步', () async {
    await dao.enqueueEvent(
      clientEventId: 'evt-offline',
      itemType: UsageItemType.scene,
      itemId: 'sys_s1',
      itemSource: 'system',
      eventType: UsageEventType.sceneSelect,
      occurredAt: 2,
    );
    network.fail = true;
    final ok = await service.runSync();
    expect(ok, isFalse);
    // 事件仍为待同步状态，下次可重试
    expect(await dao.getUnsyncedEvents(), hasLength(1));
  });
}