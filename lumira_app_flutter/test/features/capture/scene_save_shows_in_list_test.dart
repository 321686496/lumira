import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_scene_manage_page.dart';

/// 回归保护：场景管理页「新建场景 → 保存」后，列表必须立即显示新场景。
/// 走真实 DAO/provider（内存库），覆盖保存后 invalidate 刷新链路。
Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final db = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
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
      },
    ),
  );

  testWidgets('保存后列表应显示新场景', (tester) async {
    addTearDown(db.close);
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(home: CaptureSceneManagePage(initialTab: 'custom')),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();

    // 初始空态
    expect(find.text('还没有自定义场景'), findsOneWidget);

    // 打开新建表单（空态按钮为「+ 新建场景」）
    await tester.tap(find.textContaining('新建场景'));
    await tester.pump();
    await tester.pump();
    expect(find.text('场景名称'), findsOneWidget);

    // 填名称并保存
    await tester.enterText(find.byType(TextField).first, '测试新场景');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await settle();

    // 落库成功
    final rows = await ScenesDao(db).getCustomScenes();
    expect(rows.any((r) => r.name == '测试新场景'), isTrue);

    // 列表立即显示新场景（不残留空态）
    expect(find.text('测试新场景'), findsOneWidget);
    expect(find.text('还没有自定义场景'), findsNothing);
  });
}