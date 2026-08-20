import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/usage_dao.dart';

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

void main() {
  late Database db;
  late UsageDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, _) async {
      await _createUsageTables(d);
    });
    dao = UsageDao(db);
  });

  tearDown(() async => db.close());

  test('enqueueEvent 记录未同步事件，client_event_id 幂等去重', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.enqueueEvent(
      clientEventId: 'evt-1',
      itemType: UsageItemType.template,
      itemId: 'tpl-1',
      itemSource: 'builtin',
      eventType: UsageEventType.useShoot,
      occurredAt: now,
    );
    // 重复上报同一 client_event_id 不应再插入
    await dao.enqueueEvent(
      clientEventId: 'evt-1',
      itemType: UsageItemType.template,
      itemId: 'tpl-1',
      itemSource: 'builtin',
      eventType: UsageEventType.useShoot,
      occurredAt: now,
    );

    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colClientEventId], 'evt-1');
    expect(events.first[Tables.colSynced], 0);
  });

  test('getUnsyncedEvents 只返回未同步事件，按发生时间升序', () async {
    await dao.enqueueEvent(
      clientEventId: 'e1', itemType: UsageItemType.template, itemId: 't1',
      itemSource: 'builtin', eventType: UsageEventType.openDetail, occurredAt: 100,
    );
    await dao.enqueueEvent(
      clientEventId: 'e2', itemType: UsageItemType.scene, itemId: 's1',
      itemSource: 'builtin', eventType: UsageEventType.sceneSelect, occurredAt: 200,
    );
    await dao.markSynced(['e1']);

    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colClientEventId], 'e2');
  });

  test('markSynced 将指定事件标记为已同步，且忽略空列表', () async {
    await dao.markSynced(<String>[]);
    await dao.enqueueEvent(
      clientEventId: 'e1', itemType: UsageItemType.template, itemId: 't1',
      itemSource: 'builtin', eventType: UsageEventType.useShoot, occurredAt: 1,
    );
    await dao.enqueueEvent(
      clientEventId: 'e2', itemType: UsageItemType.template, itemId: 't1',
      itemSource: 'builtin', eventType: UsageEventType.useShoot, occurredAt: 2,
    );
    await dao.markSynced(['e1', 'e2']);
    expect(await dao.getUnsyncedEvents(), isEmpty);
  });

  test('setStats 覆盖写入快照，重复写已存在主键用 replace', () async {
    await dao.setStats([
      UsageStat('template', 'tpl-1', 'use_shoot', 10),
      UsageStat('template', 'tpl-1', 'open_detail', 5),
    ]);
    // 再次写入同一 key 覆盖 count（模拟拉取最新全站快照）
    await dao.setStats([
      UsageStat('template', 'tpl-1', 'use_shoot', 99),
    ]);

    expect(await dao.countFor('template', 'tpl-1', 'use_shoot'), 99);
    expect(await dao.countFor('template', 'tpl-1', 'open_detail'), 5);
  });

  test('countFor 未命中返回 0', () async {
    expect(await dao.countFor('template', 'no-such', 'use_shoot'), 0);
    expect(await dao.countFor('scene', 's1', 'scene_select'), 0);
  });

  test('setStats 空列表直接返回，不写库', () async {
    await dao.setStats(const <UsageStat>[]);
    expect(await dao.countFor('template', 't1', 'use_shoot'), 0);
  });
}