import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/usage_dao.dart';
import 'package:lumira_app_flutter/features/usage/usage_event_recorder.dart';

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
}

void main() {
  late Database db;
  late UsageDao dao;
  late UsageEventRecorder recorder;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, _) async {
      await _createUsageTables(d);
    });
    dao = UsageDao(db);
    recorder = UsageEventRecorder(dao);
  });

  tearDown(() async => db.close());

  test('recordTemplate source=custom 不写库（events 表空）', () async {
    await recorder.recordTemplate(
      templateId: 'custom_t1',
      source: 'custom',
      event: UsageEventType.openDetail,
    );
    expect(await dao.getUnsyncedEvents(), isEmpty);
  });

  test('recordTemplate source=builtin 写库且 itemType=template', () async {
    await recorder.recordTemplate(
      templateId: 'builtin_t1',
      source: 'builtin',
      event: UsageEventType.openDetail,
    );
    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colItemType], UsageItemType.template.name);
    expect(events.first[Tables.colItemId], 'builtin_t1');
    expect(events.first[Tables.colItemSource], 'builtin');
  });

  test('recordTemplate source=remote 写库且 itemType=template', () async {
    await recorder.recordTemplate(
      templateId: 'remote_t1',
      source: 'remote',
      event: UsageEventType.useShoot,
    );
    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colItemType], UsageItemType.template.name);
    expect(events.first[Tables.colItemId], 'remote_t1');
    expect(events.first[Tables.colItemSource], 'remote');
  });

  test('recordScene creator=user 不写库（events 表空）', () async {
    await recorder.recordScene(
      sceneId: 'user_s1',
      creator: 'user',
      event: UsageEventType.sceneSelect,
    );
    expect(await dao.getUnsyncedEvents(), isEmpty);
  });

  test('recordScene creator=system 写库且 itemSource=system', () async {
    await recorder.recordScene(
      sceneId: 'system_s1',
      creator: 'system',
      event: UsageEventType.sceneSelect,
    );
    final events = await dao.getUnsyncedEvents();
    expect(events, hasLength(1));
    expect(events.first[Tables.colItemType], UsageItemType.scene.name);
    expect(events.first[Tables.colItemId], 'system_s1');
    expect(events.first[Tables.colItemSource], 'system');
    expect(events.first[Tables.colEventType], 'scene_select');
  });
}