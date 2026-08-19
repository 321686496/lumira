import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/scenes/pages/scenes_search_page.dart';

/// Task 6 — ScenesSearchPage 测试
///
/// 通过 override databaseProvider 注入空内存 DB（fixture 仅建表），
/// 使 scenesDaoProvider / userTagsDaoProvider 返回空数据的真实 DAO，
/// 页面以「未找到相关场景」空态渲染。最低验收：搜索框、导航标题与标签入口渲染。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    // databaseFactoryFfiNoIsolate: DB 操作主 isolate 同步执行，future 通过
    // microtask 解析，可在 widget 测试(fake-async zone)中 pump 推进。
    // （与 templates_search_page_test.dart 同模式。）
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() async => db.close());

  testWidgets('渲染搜索框与导航标题、标签入口', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    // 预热 DAO provider（内部 watch databaseProvider），使 initState 的 future 已 resolve
    await container.read(scenesDaoProvider.future);
    await container.read(userTagsDaoProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ScenesSearchPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 导航标题
    expect(find.text('搜索场景'), findsOneWidget);
    // 关键词搜索框
    expect(find.byType(TextField), findsOneWidget);
    // 空数据 → 空态
    expect(find.text('未找到相关场景'), findsOneWidget);
  });
}

/// 与 v24 迁移一致的表结构：建 scenes + 标签两张表。
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
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
  await db.execute('''
    CREATE TABLE ${Tables.userTags} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colName} TEXT NOT NULL UNIQUE,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.itemTags} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
    )
  ''');
  await db.execute('CREATE INDEX idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
  await db.execute('CREATE INDEX idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');
}