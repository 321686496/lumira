import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/search/pages/global_search_page.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_scope.dart';

/// GlobalSearchPage 最小验收：搜索框、scope 切换栏、空态渲染。
/// 通过 override databaseProvider 注入空内存 DB（仅建搜索页依赖表）。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester, SearchScope scope) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    await container.read(templatesDaoProvider.future);
    await container.read(scenesDaoProvider.future);
    await container.read(userTagsDaoProvider.future);
    await container.read(searchHistoryDaoProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GlobalSearchPage(scope: scope),
        ),
      ),
    );
    await tester.pump();
    // FfiNoIsolate 的 DB 查询是真实 async，需让事件循环真实推进完成页面 _load()。
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('渲染搜索框与 scope 切换栏', (tester) async {
    await pumpPage(tester, SearchScope.all);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('美学院'), findsOneWidget);
  });

  testWidgets('输入无匹配关键词后进入结果态（空数据 → 空结果引导）', (tester) async {
    await pumpPage(tester, SearchScope.all);
    await tester.enterText(find.byType(TextField), 'zzz不存在关键词');
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('换个关键词试试'), findsOneWidget);
  });
}

/// 与 v29 迁移一致的表结构：仅建搜索页依赖的表。
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
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
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(SearchHistoryTable.createSql);
  await db.execute(SearchHistoryTable.indexSql);
  await db.execute('''
    CREATE TABLE ${Tables.templateCategories} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colKey} TEXT NOT NULL,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colParentKey} TEXT,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colUpdatedAt} INTEGER NOT NULL,
      UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
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
