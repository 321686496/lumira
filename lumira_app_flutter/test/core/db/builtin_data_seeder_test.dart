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

  test('seedAll inserts 29 templates with 16 free + 13 paid', () async {
    await BuiltinDataSeeder.seedAll(db);
    final all = await db.query(Tables.customTemplates);
    expect(all.length, 29);
    final free = all.where((t) => (t[Tables.colPrice] as num) == 0).length;
    final paid = all.where((t) => (t[Tables.colPrice] as num) > 0).length;
    expect(free, 16);
    expect(paid, 13);
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
    // 29 builtin + 1 custom = 30
    expect(all.length, 30);
    // 用户自定义模板保留
    final custom = all.where((t) => t[Tables.colIsBuiltin] == 0).toList();
    expect(custom.length, 1);
    expect(custom.first[Tables.colId], 'user_custom_1');
    // 内置模板数量正确
    final builtin = all.where((t) => t[Tables.colIsBuiltin] == 1).toList();
    expect(builtin.length, 29);
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
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
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
