import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/seeders/builtin_data_seeder.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 4, onCreate: _onCreate);
  });

  tearDown(() async => db.close());

  // 适配说明：
  // v10 重构后 seeder 数据源从 TemplatesBrowseMockData.allTemplates (10 项)
  // 改为 TemplateRegistry.allTemplates (29 项：16 免费 + 13 付费)。
  // 测试计数已按 TemplateRegistry 实际数据调整。
  test('seedAll returns true and inserts 7 scenes', () async {
    final inserted = await BuiltinDataSeeder.seedAll(db);
    expect(inserted, isTrue);

    final scenes = await db.query(Tables.scenes);
    expect(scenes.length, 7);
    // 全部标记为 system creator
    expect(scenes.every((s) => s[Tables.colCreator] == 'system'), isTrue);
  });

  test('seedAll inserts 132 templates with 86 free + 46 paid', () async {
    await BuiltinDataSeeder.seedAll(db);
    final all = await db.query(Tables.customTemplates);
    expect(all.length, 132);
    final free = all.where((t) => (t[Tables.colPrice] as num) == 0).length;
    final paid = all.where((t) => (t[Tables.colPrice] as num) > 0).length;
    expect(free, 86);
    expect(paid, 46);
    // 全部标记为 builtin
    expect(all.every((t) => t[Tables.colIsBuiltin] == 1), isTrue);
  });

  test('seedAll marks 3 templates as recommended', () async {
    await BuiltinDataSeeder.seedAll(db);
    final recommended = await db.rawQuery(
      'SELECT * FROM ${Tables.customTemplates} WHERE ${Tables.colIsRecommended} = 1',
    );
    expect(recommended.length, 3);
  });

  test('seedAll sets seed_v3_done=1 in user_settings', () async {
    await BuiltinDataSeeder.seedAll(db);
    final rows = await db.query(Tables.userSettings);
    expect(rows.first[Tables.colSeedV3Done], 1);
  });

  test('seedAll returns false if seed_v3_done already 1', () async {
    await BuiltinDataSeeder.seedAll(db);
    // 二次调用
    final second = await BuiltinDataSeeder.seedAll(db);
    expect(second, isFalse);
  });

  test('seedAll returns false if user has custom templates', () async {
    // 先插入 1 条用户自定义模板（is_builtin=0）
    await db.insert(Tables.customTemplates, {
      Tables.colId: 'user_test_1',
      Tables.colName: '用户模板',
      Tables.colCategory: 'portrait',
      Tables.colIsBuiltin: 0,
      Tables.colIsRecommended: 0,
      Tables.colCreatedAt: 1700000000000,
      Tables.colUpdatedAt: 1700000000000,
    });
    final inserted = await BuiltinDataSeeder.seedAll(db);
    expect(inserted, isFalse);
  });

  test('reseedBuiltinTemplates replaces builtin templates preserving custom', () async {
    // 先正常种子化
    await BuiltinDataSeeder.seedAll(db);
    // 插入 1 条用户自定义模板
    await db.insert(Tables.customTemplates, {
      Tables.colId: 'user_custom_1',
      Tables.colName: '用户自定义',
      Tables.colCategory: 'portrait',
      Tables.colIsBuiltin: 0,
      Tables.colIsRecommended: 0,
      Tables.colCreatedAt: 1700000000000,
      Tables.colUpdatedAt: 1700000000000,
    });
    // 强制重新种子化内置模板
    await BuiltinDataSeeder.reseedBuiltinTemplates(db);
    final all = await db.query(Tables.customTemplates);
    // 132 builtin + 1 custom = 133
    expect(all.length, 133);
    // 用户自定义模板保留
    final custom = all.where((t) => t[Tables.colIsBuiltin] == 0).toList();
    expect(custom.length, 1);
    expect(custom.first[Tables.colId], 'user_custom_1');
    // 内置模板数量正确
    final builtin = all.where((t) => t[Tables.colIsBuiltin] == 1).toList();
    expect(builtin.length, 132);
  });

  test('reseedPortraitCategoriesTo4level 将动漫温柔青归位清新治愈(非梦幻夜色)', () async {
    await BuiltinDataSeeder.reseedPortraitCategoriesTo4level(db);
    // 三级子风格节点 anime_tender 应挂在 fresh_healing(清新治愈) 下
    final rows = await db.query(
      Tables.templateCategories,
      where: '${Tables.colKey} = ? AND ${Tables.colIsActive} = 1',
      whereArgs: ['anime_tender'],
    );
    expect(rows, hasLength(1));
    expect(rows.first[Tables.colParentKey], 'fresh_healing');
    expect(rows.first[Tables.colLevel], 3);
    expect(rows.first[Tables.colName], '动漫温柔青');
    // 不应再残留挂在梦幻夜色(dreamy_night)下的两个同 key 分类
    final orphan = await db.query(
      Tables.templateCategories,
      where: '${Tables.colParentKey} = ? AND ${Tables.colKey} = ?',
      whereArgs: ['dreamy_night', 'anime_tender'],
    );
    expect(orphan, isEmpty);
    // 梦幻夜色(dreamy_night)下只保留其自身的子风格（blue_night/purple_dusk 等）
    final dreamyChildren = await db.query(
      Tables.templateCategories,
      where: '${Tables.colParentKey} = ? AND ${Tables.colKey} IN (?, ?)',
      whereArgs: [
        'dreamy_night',
        'blue_night',
        'purple_dusk',
      ],
    );
    expect(dreamyChildren.length, 2);
  });

  test('内置模板 anime_dream_portrait 种子化后 classification 落库 fresh_healing/anime_tender', () async {
    await BuiltinDataSeeder.seedAll(db);
    final rows = await db.query(
      Tables.customTemplates,
      where: '${Tables.colId} = ?',
      whereArgs: ['anime_dream_portrait'],
    );
    expect(rows, hasLength(1));
    final classification =
        jsonDecode(rows.first[Tables.colClassificationJson] as String) as Map;
    // 大风格应为 清新治愈(fresh_healing)，子风格/风格为 动漫温柔青(anime_tender)
    expect(classification['majorStyle'], 'fresh_healing');
    expect(classification['subStyle'], 'anime_tender');
    expect(classification['style'], 'anime_tender');
    // 不应是旧的梦幻夜色(dreamy_night)归属
    expect(classification['majorStyle'], isNot('dreamy_night'));
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
  await db.execute('''
    CREATE TABLE ${Tables.templateCategories} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colKey} TEXT NOT NULL,
      ${Tables.colName} TEXT NOT NULL DEFAULT '',
      ${Tables.colParentKey} TEXT,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colUpdatedAt} INTEGER NOT NULL DEFAULT 0,
      UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
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
  await db.execute('''
    CREATE TABLE ${Tables.userSettings} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colThemeKey} TEXT NOT NULL DEFAULT 'warmWhite',
      ${Tables.colUiStyle} TEXT NOT NULL DEFAULT 'neumorphic',
      ${Tables.colFollowSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCaptureFullscreen} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colGridEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLevelEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colShutterSound} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colWatermark} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSeedV3Done} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  // user_settings 行需提前插入
  await db.insert(Tables.userSettings, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}
