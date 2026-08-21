import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/tags_dao.dart';
import 'package:lumira_app_flutter/shared/widgets/tags/user_tags_section.dart';

void main() {
  late Database db;
  late TagsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    // databaseFactoryFfiNoIsolate: DB 操作主 isolate 同步执行，future 通过
    // microtask 解析，可在 widget 测试(fake-async zone)中 pump 推进
    // （与 test/features/gallery/gallery_diary_page_test.dart 同模式）。
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = TagsDao(db);
  });

  tearDown(() async => db.close());

  testWidgets('UserTagsSection 仅处理用户自定义标签（系统标签由详情页自身展示）', (tester) async {
    // 容器必须在 testWidgets body（fake-async zone）内创建，否则 provider 体内的
    // sqflite FFI 调用在 fake zone 中 await 会挂起（pumpAndSettle 永久等待）。
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    // 预热 userTagsDaoProvider（内部 watch databaseProvider），使 initState 的 future 已 resolve
    await container.read(userTagsDaoProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: UserTagsSection(
              itemType: TagItemType.template,
              itemId: 'tpl-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 无用户自定义标签时不展示任何系统标签（去重后由详情页展示）
    expect(find.byType(TextField), findsNothing);
    // 输入框未展开时展示"添加标签"入口
    expect(find.text('添加标签，方便日后查找'), findsOneWidget);
  });
}

/// 与 v24 迁移一致的两张标签表（仅建标签表即可）。
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