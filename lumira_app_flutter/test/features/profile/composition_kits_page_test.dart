import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/composition_kits_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/composition_kits_providers.dart';

late Database _testDb;
late CompositionKitsDao _dao;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // DB 必须在 setUp（FakeAsync 之外）中创建：sqflite_ffi 的 openDatabase 使用真实
  // Timer / isolate 通信，在 testWidgets 的 FakeAsync zone 中会永久挂起。
  // Prior art: test/features/capture/add_to_composition_sheet_test.dart setUp.
  setUp(() async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    _dao = CompositionKitsDao(_testDb);
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  // sqflite_common_ffi 的 DB 查询是真实 async 操作，在 FakeAsync 环境下
  // pumpAndSettle 无法让 FutureProvider 链（compositionKitsProvider →
  // compositionKitsDaoProvider.future → statsProvider）完成。改用 pump + runAsync
  // + pump 让真实 async 操作在 FakeAsync 之外执行后再 rebuild。
  // Prior art: test/features/capture/add_to_composition_sheet_test.dart _settle.
  Future<void> settleOrPump(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('空状态显示"还没有组合套件"提示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => _dao),
        ],
        child: const MaterialApp(home: CompositionKitsPage()),
      ),
    );
    await settleOrPump(tester);

    expect(find.text('还没有组合套件'), findsOneWidget);
    expect(find.text('在场景详情页点击"加入组合"即可创建'), findsOneWidget);
  });

  testWidgets('列表显示套件卡片 + StatsBar', (tester) async {
    // DB 写入必须用 tester.runAsync 包裹：sqflite_ffi 的 insert 使用真实 Timer，
    // 在 testWidgets 的 FakeAsync zone 中会永久挂起（同 _settle 中 pump 后
    // runAsync 的原因）。
    await tester.runAsync(() async {
      await _dao.insert(CompositionKit(
        id: 'kit_1',
        name: '咖啡馆+柔光人像',
        sceneId: 'scene_cafe',
        templateId: 'tpl_cafe',
        cameraOverrides: {},
        note: '下午窗边',
        coverUrl: null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        usageCount: 3,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      await _dao.insert(CompositionKit(
        id: 'kit_2',
        name: '夜景街拍+黑白',
        sceneId: 'scene_street',
        templateId: 'tpl_bw',
        cameraOverrides: {},
        note: '',
        coverUrl: null,
        createdAt: DateTime.now().millisecondsSinceEpoch - 1000,
        usageCount: 0,
      ));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => _dao),
        ],
        child: const MaterialApp(home: CompositionKitsPage()),
      ),
    );
    await settleOrPump(tester);

    expect(find.text('咖啡馆+柔光人像'), findsOneWidget);
    expect(find.text('夜景街拍+黑白'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // StatsBar 总数
    expect(find.text('3'), findsOneWidget); // StatsBar 总使用次数
  });
}
