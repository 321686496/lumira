import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/usage_dao.dart';
import 'package:lumira_app_flutter/features/scenes/scenes_sync_service.dart';

/// 建 scenes / usage_stats 两表（与 database_provider 同构，仅含测试所需列）。
Future<void> _createTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
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

/// 可编程 fake 网络：可返回指定响应，可抛错模拟离线。
class FakeScenesNetwork implements ScenesNetwork {
  FakeScenesNetwork(this.response);
  Map<String, dynamic> response;
  bool fail = false;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetchScenes() async {
    if (fail) throw Exception('network down');
    calls++;
    return response;
  }
}

void main() {
  late Database db;
  late ScenesDao scenesDao;
  late UsageDao usageDao;
  late FakeScenesNetwork network;
  late ScenesSyncService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, _) async {
      await _createTables(d);
    });
    scenesDao = ScenesDao(db);
    usageDao = UsageDao(db);
    network = FakeScenesNetwork({'scenes': <Map<String, dynamic>>[]});
    service = ScenesSyncService(scenesDao, usageDao, network);
  });

  tearDown(() async => db.close());

  test('syncSystem 逐条 upsert 场景并写入 usage_stats', () async {
    network.response = {
      'scenes': [
        {
          'id': 'sys_s1',
          'name': '窗光人像',
          'icon': 'wb_sunny',
          'category': 'light',
          'style': 'soft',
          'filter': {'contrast': 0.8},
          'vibe': '温柔',
          'description': '窗边自然光',
          'exampleImages': ['https://a/img1.jpg'],
          'tips': ['找逆光'],
          'whereToShoot': '窗边',
          'bestTime': '清晨',
          'relatedCategory': 'portrait',
          'recommendedTagIds': ['t1', 't2'],
          'updatedAt': 123,
          'usage': {'useShoot': 5, 'openDetail': 3, 'sceneSelect': 1},
        },
      ],
    };
    final ok = await service.syncSystem();
    expect(ok, isTrue);
    expect(network.calls, 1);

    final scene = await scenesDao.getById('sys_s1');
    expect(scene, isNotNull);
    expect(scene!.id, 'sys_s1');
    expect(scene.name, '窗光人像');
    expect(scene.creator, 'system');
    expect(scene.isFavorite, isFalse);
    expect(scene.filter['contrast'], 0.8);
    expect(scene.exampleImages, ['https://a/img1.jpg']);
    expect(scene.recommendedTagIds, ['t1', 't2']);
    expect(scene.tagIds, ['t1', 't2']);

    // usage_stats 已写入（itemType='scene'）
    expect(await usageDao.countFor('scene', 'sys_s1', 'use_shoot'), 5);
    expect(await usageDao.countFor('scene', 'sys_s1', 'open_detail'), 3);
    expect(await usageDao.countFor('scene', 'sys_s1', 'scene_select'), 1);
  });

  test('syncSystem 覆盖已存在的同名系统场景（幂等 upsert，不删除用户场景）', () async {
    // 预置一条同 id 的 system 场景 + 一条 user 场景
    final existingSystem = SceneRecord(
      id: 'sys_s1',
      name: '旧数据',
      icon: '',
      category: 'light',
      style: '',
      filter: <String, dynamic>{},
      vibe: '',
      description: '',
      exampleImages: <String>[],
      tips: <String>[],
      whereToShoot: '',
      bestTime: '',
      sceneGuide: <String, dynamic>{},
      relatedCategory: '',
      recommendedTagIds: <String>[],
      tagIds: <String>[],
      creator: 'system',
      isFavorite: true,
      createdAt: 1,
      updatedAt: 1,
    );
    await scenesDao.upsert(existingSystem);
    await scenesDao.upsert(SceneRecord(
      id: 'user_1',
      name: '我的场景',
      icon: '',
      category: 'light',
      style: '',
      filter: <String, dynamic>{},
      vibe: '',
      description: '',
      exampleImages: <String>[],
      tips: <String>[],
      whereToShoot: '',
      bestTime: '',
      sceneGuide: <String, dynamic>{},
      relatedCategory: '',
      recommendedTagIds: <String>[],
      tagIds: <String>[],
      creator: 'user',
      isFavorite: false,
      createdAt: 2,
      updatedAt: 2,
    ));

    network.response = {
      'scenes': [
        {
          'id': 'sys_s1',
          'name': '新数据',
          'icon': '',
          'category': 'light',
          'style': '',
          'vibe': '',
          'description': '',
          'exampleImages': <String>[],
          'tips': <String>[],
          'whereToShoot': '',
          'bestTime': '',
          'relatedCategory': '',
          'recommendedTagIds': <String>[],
          'updatedAt': 9,
          'usage': <String, dynamic>{},
        },
      ],
    };
    final ok = await service.syncSystem();
    expect(ok, isTrue);

    final updated = await scenesDao.getById('sys_s1');
    expect(updated!.name, '新数据');
    // 后端 updatedAt 为秒，M4 修复后换算为毫秒（9s -> 9000ms）
    expect(updated.updatedAt, 9000);
    // 用户场景不受影响
    final userScene = await scenesDao.getById('user_1');
    expect(userScene, isNotNull);
    expect(userScene!.creator, 'user');
  });

  test('syncSystem 离线（网络抛错）返回 false，不写库', () async {
    network.fail = true;
    final ok = await service.syncSystem();
    expect(ok, isFalse);
    expect(await scenesDao.getById('sys_s1'), isNull);
  });
}