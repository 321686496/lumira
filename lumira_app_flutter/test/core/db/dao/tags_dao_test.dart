import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/tags_dao.dart';

void main() {
  late Database db;
  late TagsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 24, onCreate: _onCreate);
    dao = TagsDao(db);
  });

  tearDown(() async => db.close());

  test('addTag 同名标签跨条目复用同一个 tag id', () async {
    final t1 = await dao.addTag(
        itemType: TagItemType.template, itemId: 'tpl-1', name: '人像');
    final t2 = await dao.addTag(
        itemType: TagItemType.template, itemId: 'tpl-2', name: ' 人像 ');
    expect(t1, t2, reason: 'trim 后同名应复用同一标签');

    final tags = await dao.tagsFor(
        itemType: TagItemType.template, itemId: 'tpl-1');
    expect(tags, hasLength(1));
    expect(tags.first.name, '人像');
  });

  test('tagsFor 只返回指定条目的标签', () async {
    await dao.addTag(itemType: TagItemType.scene, itemId: 's1', name: '淘气泡');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's2', name: '鲸鱼');
    final tags = await dao.tagsFor(itemType: TagItemType.scene, itemId: 's1');
    expect(tags.map((t) => t.name), ['淘气泡']);
  });

  test('itemIdsByTag 返回该标签下所有条目并区分类型', () async {
    final tagId = await dao.addTag(
        itemType: TagItemType.template, itemId: 't-1', name: '人像');
    await dao.addTag(itemType: TagItemType.template, itemId: 't-2', name: '人像');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's-1', name: '人像');
    final templates =
        await dao.itemIdsByTag(itemType: TagItemType.template, tagId: tagId);
    expect(templates.toSet(), {'t-1', 't-2'});
    final scenes =
        await dao.itemIdsByTag(itemType: TagItemType.scene, tagId: tagId);
    expect(scenes, ['s-1']);
  });

  test('allTags 返回标签及 count 并按 itemType 过滤', () async {
    await dao.addTag(itemType: TagItemType.template, itemId: 't1', name: 'a');
    await dao.addTag(itemType: TagItemType.template, itemId: 't2', name: 'a');
    await dao.addTag(itemType: TagItemType.template, itemId: 't3', name: 'b');
    await dao.addTag(itemType: TagItemType.scene, itemId: 's1', name: 'a');
    final tags = await dao.allTags(itemType: TagItemType.template);
    expect(tags, hasLength(2));
    final a = tags.firstWhere((t) => t.tag.name == 'a');
    expect(a.count, 2);
  });

  test('removeTag / deleteTag / renameTag', () async {
    final tagId = await dao.addTag(
        itemType: TagItemType.template, itemId: 't1', name: '原标签');
    await dao.renameTag(tagId, '新标签');
    final tags = await dao.tagsFor(
        itemType: TagItemType.template, itemId: 't1');
    expect(tags.first.name, '新标签');

    await dao.removeTag(
        itemType: TagItemType.template, itemId: 't1', tagId: tagId);
    expect(await dao.tagsFor(itemType: TagItemType.template, itemId: 't1'),
        isEmpty);

    final t2 = await dao.addTag(
        itemType: TagItemType.scene, itemId: 's1', name: '待删');
    await dao.deleteTag(t2);
    expect(await dao.itemIdsByTag(itemType: TagItemType.scene, tagId: t2),
        isEmpty);
  });

  test('matchingTagIds 关键词匹配标签名', () async {
    await dao.addTag(itemType: TagItemType.template, itemId: 't1', name: '日系');
    await dao.addTag(itemType: TagItemType.template, itemId: 't2', name: '复古');
    final hits = await dao.matchingTagIds('日');
    expect(hits, hasLength(1));
  });
}

/// 与 v24 迁移一致的标签建表逻辑（仅建两张标签表）。
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