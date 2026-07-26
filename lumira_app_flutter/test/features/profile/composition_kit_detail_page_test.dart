import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/composition_kit_detail_page.dart';
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
  // Prior art: test/features/profile/composition_kits_page_test.dart setUp.
  setUp(() async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    _dao = CompositionKitsDao(_testDb);
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  // sqflite_common_ffi 的 DB 查询是真实 async 操作，在 FakeAsync 环境下
  // pumpAndSettle 无法让 FutureProvider 链（compositionKitByIdProvider →
  // compositionKitsDaoProvider.future）完成。改用 pump + runAsync
  // + pump 让真实 async 操作在 FakeAsync 之外执行后再 rebuild。
  // Prior art: test/features/profile/composition_kits_page_test.dart _settle.
  Future<void> settleOrPump(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('详情页显示套件名/场景/模板/参数表/拍照按钮', (tester) async {
    // DB 写入必须用 tester.runAsync 包裹：sqflite_ffi 的 insert 使用真实 Timer，
    // 在 testWidgets 的 FakeAsync zone 中会永久挂起（同 settleOrPump 中 pump 后
    // runAsync 的原因）。
    await tester.runAsync(() async {
      await _dao.insert(CompositionKit(
        id: 'kit_detail_1',
        name: '咖啡馆+柔光人像',
        sceneId: 'scene_cafe',
        templateId: 'tpl_cafe',
        cameraOverrides: {
          'exposureCompensation': 0.3,
          'iso': 400,
          'shutterSpeed': '1/80',
        },
        note: '下午窗边拍摄',
        coverUrl: null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    final goRouter = GoRouter(
      initialLocation: '/?kitId=kit_detail_1',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            final kitId = state.queryParams['kitId']!;
            return CompositionKitDetailPage(kitId: kitId);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => _dao),
        ],
        child: MaterialApp.router(routerConfig: goRouter),
      ),
    );
    // 触发导航到 /detail?kitId=kit_detail_1
    goRouter.go('/detail?kitId=kit_detail_1');
    await settleOrPump(tester);

    expect(find.text('咖啡馆+柔光人像'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('EV'), findsOneWidget);
    expect(find.text('+0.3'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('快门'), findsOneWidget);
    expect(find.text('1/80'), findsOneWidget);
    expect(find.text('下午窗边拍摄'), findsOneWidget);
    expect(find.text('立即使用此套件拍照'), findsOneWidget);
  });
}
