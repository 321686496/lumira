import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/tags/pages/my_tags_page.dart';

/// Task 7 — MyTagsPage 测试
///
/// override databaseProvider 注入空内存 DB，断言导航标题与 tab（模板/场景）渲染。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() async => db.close());

  testWidgets('渲染标题与模板/场景 tab', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    await container.read(userTagsDaoProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MyTagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的标签'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    // 空态引导
    expect(find.text('还没有标签，去给模板/场景打上标签吧'), findsOneWidget);
  });
}

Future<void> _onCreate(Database db, int version) async {
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