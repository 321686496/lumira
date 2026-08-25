import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_content_mock_data.dart';

/// Plan A Task A5 — Profile My Templates 页接入 DAO 验证测试
///
/// 验证 `TemplatesDao.upsert` / `getCustomOnly` / `delete` 行为，保证
/// `customTemplatesProvider` 切换到 DAO 后，编辑器保存的模板能正确出现在
/// My Templates 页列表中，删除后能正确移除。
///
/// 注：Task A4 已为 `TemplateRecord` 添加 `isBuiltin` / `isRecommended`
/// 字段并为 `TemplatesDao` 添加 `getCustomOnly` 方法，因此本测试的 RED
/// 步骤实际为 PASS（见 brief Step 2 说明）。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDown(() async => db.close());

  test('upsert custom template and query via getCustomOnly', () async {
    final dao = TemplatesDao(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = TemplateRecord(
      id: 'user_tpl_1',
      name: '我的胶片人像',
      author: 'user',
      version: '1.0.0',
      category: 'portrait',
      classification: {},
      tags: ['胶片'],
      tagIds: [],
      price: 0,
      cover: '',
      description: '',
      referenceSource: '',
      composition: {'overlayType': 'rule_of_thirds'},
      pose: {},
      camera: {'iso': 200, 'shutterSpeed': '1/200'},
      sceneGuide: {},
      postProcess: {},
      createdAt: now,
      updatedAt: now,
      isBuiltin: false,
      isRecommended: false,
      source: 'custom',
    );

    await dao.upsert(record);
    final customs = await dao.getCustomOnly();
    expect(customs.length, 1);
    expect(customs.first.name, '我的胶片人像');
    expect(customs.first.isBuiltin, isFalse);
  });

  test('delete custom template removes from getCustomOnly', () async {
    final dao = TemplatesDao(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.upsert(TemplateRecord(
      id: 'user_tpl_1', name: 'T1', author: 'u', version: '1', category: 'portrait',
      classification: {}, tags: [], tagIds: [], price: 0, cover: '', description: '',
      referenceSource: '', composition: {}, pose: {}, camera: {}, sceneGuide: {},
      postProcess: {}, createdAt: now, updatedAt: now, isBuiltin: false, isRecommended: false,
      source: 'custom',
    ));
    expect((await dao.getCustomOnly()).length, 1);

    await dao.delete('user_tpl_1');
    expect((await dao.getCustomOnly()).length, 0);
  });

  // 引用 ProfileContentMockData 防止 tree-shaking 移除对该模块的依赖
  // （customTemplates 已标记为 deprecated，但仍保留供向后兼容）。
  test('ProfileContentMockData.customTemplates still accessible (deprecated)', () {
    // ignore: deprecated_member_use_from_same_package
    expect(ProfileContentMockData.customTemplates, isNotEmpty);
  });
}

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
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
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
}
