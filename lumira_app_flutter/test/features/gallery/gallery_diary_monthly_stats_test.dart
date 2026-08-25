import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/gallery/providers/gallery_diary_providers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 与 gallery_diary_page_test 保持一致，用 NoIsolate 工厂避免
    // isolate 通信的 real async 在测试 fake async 下不解析的问题。
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

  test('diaryMonthlyStats aggregates this month photos & days', () async {
    // 场景表：scene_cafe → 咖啡馆（验证「常去场景」展示名称而非 key）
    await db.insert(Tables.scenes, {
      Tables.colId: 'scene_cafe',
      Tables.colName: '咖啡馆',
      Tables.colCategory: '室内',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1, 12).millisecondsSinceEpoch;
    final sameDay = DateTime(now.year, now.month, 1, 18).millisecondsSinceEpoch;
    final lastMonth = DateTime(now.year, now.month - 1, 1, 12).millisecondsSinceEpoch;

    await db.insert(Tables.galleryItems, {
      'id': 'p1', 'scene_id': 'scene_cafe', 'mood': '开心', 'created_at': thisMonth,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p2', 'scene_id': 'scene_cafe', 'mood': '开心', 'created_at': sameDay,
    });
    await db.insert(Tables.galleryItems, {
      'id': 'p3', 'scene_id': 'scene_unknown', 'mood': '宁静', 'created_at': lastMonth,
    });

    final stats = await container.read(diaryMonthlyStatsProvider.future);
    expect(stats.thisMonthPhotos, 2);
    expect(stats.thisMonthDays, 1); // p1/p2 同一天
    expect(stats.mostCommonMood, '开心');
    // 常去场景显示场景名称「咖啡馆」（由 scene_cafe 解析），而非 key
    expect(stats.mostCommonScene, '咖啡馆');
  });

  test('diaryMonthlyStats handles empty month gracefully', () async {
    final stats = await container.read(diaryMonthlyStatsProvider.future);
    expect(stats.thisMonthPhotos, 0);
    expect(stats.thisMonthDays, 0);
    expect(stats.mostCommonMood, isNull);
    expect(stats.mostCommonScene, isNull);
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
  // scenes（diaryMonthlyStatsProvider 解析场景名称需要）
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
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}
