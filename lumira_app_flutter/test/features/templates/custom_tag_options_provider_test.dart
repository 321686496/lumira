import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/templates/data/custom_tag_options_provider.dart';

/// Task 3 — 候选标签数据源（聚合自定义模板标签）
///
/// 复用模板 DAO 测试的内存 DB + seed 模式（sqfliteFfiInit + databaseFactoryFfi + `:memory:`），
/// 通过 override `databaseProvider` 让 provider 读取 seed 后的内存库。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    final now = DateTime.now().millisecondsSinceEpoch;
    // 两个自定义模板（source='custom'）：tags=['A','B'] 与 tags=['A','C']
    final templates = [
      {
        Tables.colId: 'tpl_1',
        Tables.colName: '模板 1',
        Tables.colCategory: 'portrait',
        Tables.colTagsJson: '["A","B"]',
        Tables.colTagIdsJson: '[]',
        Tables.colIsBuiltin: 0,
        Tables.colIsRecommended: 0,
        Tables.colSource: 'custom',
        Tables.colCreatedAt: now,
        Tables.colUpdatedAt: now,
      },
      {
        Tables.colId: 'tpl_2',
        Tables.colName: '模板 2',
        Tables.colCategory: 'portrait',
        Tables.colTagsJson: '["A","C"]',
        Tables.colTagIdsJson: '[]',
        Tables.colIsBuiltin: 0,
        Tables.colIsRecommended: 0,
        Tables.colSource: 'custom',
        Tables.colCreatedAt: now + 1,
        Tables.colUpdatedAt: now + 1,
      },
    ];
    for (final t in templates) {
      await db.insert(Tables.customTemplates, t);
    }
  });

  tearDown(() async => db.close());

  test('聚合自定义模板标签，去重并按 count 降序', () async {
    final container = ProviderContainer(
      overrides: [
        // Riverpod 2.3.6 的 FutureProvider 无 overrideWithValue，用 overrideWith 注入内存 DB
        databaseProvider.overrideWith((ref) async => db),
      ],
    );
    addTearDown(container.dispose);

    final candidates = await container.read(customTagCandidatesProvider.future);

    expect(candidates.map((e) => e.name).toList(), ['A', 'B', 'C']);
    expect(candidates.map((e) => e.count).toList(), [2, 1, 1]);
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