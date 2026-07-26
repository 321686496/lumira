import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/widgets/add_to_composition_sheet.dart';

late Database _testDb;
late CompositionKitsDao _kitsDao;
late TemplatesDao _templatesDao;

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
}

// sqflite_common_ffi 的 DB 查询是真实 async 操作，在 FakeAsync 环境下 pumpAndSettle
// 会超时。必须用 tester.runAsync 让真实 async 操作完成。
// 参见 templates_page_test.dart:94-101 的 settleOrPump 同类说明。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // db 必须在 setUp（FakeAsync 之外）中创建：sqflite_ffi 的 openDatabase 使用真实
  // Timer / isolate 通信，在 testWidgets 的 FakeAsync zone 中会永久挂起。
  // 参见 templates_page_test.dart:33-37 的同类做法（setUpAll 中 openDatabase）。
  setUp(() async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    _kitsDao = CompositionKitsDao(_testDb);
    _templatesDao = TemplatesDao(_testDb);
  });

  tearDown(() async {
    if (_testDb.isOpen) {
      await _testDb.close();
    }
  });

  testWidgets('AddToCompositionSheet 显示名称/备注/模板下拉/保存按钮',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 直接用 override 注入测试 DAO
          compositionKitsDaoProvider.overrideWith(
            (ref) async => _kitsDao,
          ),
          templatesDaoProvider.overrideWith(
            (ref) async => _templatesDao,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddToCompositionSheet.show(
                  ctx,
                  sceneId: 'cafe-window',
                  sceneName: '咖啡馆窗边',
                  sceneCoverUrl: 'https://picsum.photos/seed/cafe/400/600',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.text('加入组合'), findsOneWidget);
    expect(find.text('套件名称'), findsOneWidget);
    expect(find.text('关联模板（可选）'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('保存套件'), findsOneWidget);

    // 默认名称应为 "场景名-模板名" 模式
    expect(find.text('咖啡馆窗边-自由拍摄'), findsOneWidget);
  });

  testWidgets('点击保存按钮写入 DAO 并关闭 sheet', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => _kitsDao),
          templatesDaoProvider.overrideWith((ref) async => _templatesDao),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddToCompositionSheet.show(
                  ctx,
                  sceneId: 'street-night',
                  sceneName: '夜景街拍',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.tap(find.text('保存套件'));
    await _settle(tester);

    // 必须用 tester.runAsync 包裹真实 DB 查询：sqflite_ffi 的 getAll 使用真实 Timer，
    // 在 testWidgets 的 FakeAsync zone 中会永久挂起（同 _settle 中 pump 后 runAsync 的原因）。
    final all = await tester.runAsync(() => _kitsDao.getAll());
    expect(all!.length, 1);
    expect(all.first.sceneId, 'street-night');
    expect(all.first.name, '夜景街拍-自由拍摄');
    expect(all.first.templateId, isNull);
  });
}
