import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_dao.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_models.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_providers.dart';
import 'package:lumira_app_flutter/features/checkin/pages/checkin_detail_page.dart';

void main() {
  late Database db;
  late CheckinDao dao;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 主 isolate FFI 直连，避免 pumpAndSettle 超时（同 gallery_detail_page_test）
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = CheckinDao(db);
    container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      checkinDaoProvider.overrideWith((ref) async => dao),
      galleryDaoProvider.overrideWith((ref) async => GalleryDao(db)),
    ]);
    await container.read(checkinDaoProvider.future);
    await container.read(galleryDaoProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// sqflite_common_ffi 的 DB 查询是真实 async：在 FakeAsync 中 pumpAndSettle 无法让
  /// 真实 Future 完成，必须先轮询 runAsync 推进（与 checkin_list_page_test 同模式）。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  void setViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Future<void> seed() async {
    await dao.insert(CheckinRecord(
      id: 'c1',
      name: 'Manner Coffee',
      place: '武康路',
      category: 'coffee',
      rating: 5,
      note: '燕麦拿铁很香',
      visitedAt: 3000,
      createdAt: 1,
      updatedAt: 2,
    ));
  }

  testWidgets('渲染足迹详情：店名/地点/分类/评分/心得', (tester) async {
    setViewport(tester);
    await seed();
    // 预解析详情 provider，避免 fake zone 中页面查询挂起
    await tester.runAsync(
        () => container.read(checkinDetailProvider('c1').future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckinDetailPage(checkinId: 'c1')),
    ));
    await settle(tester);

    expect(find.text('Manner Coffee'), findsOneWidget);
    expect(find.text('武康路'), findsOneWidget);
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.text('燕麦拿铁很香'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(5)); // rating 5
  });

  testWidgets('足迹不存在显示占位', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckinDetailPage(checkinId: 'none')),
    ));
    await settle(tester);
    expect(find.text('足迹不存在或已删除'), findsOneWidget);
  });

  testWidgets('删除流程：确认弹窗 → 删除 → 返回列表', (tester) async {
    setViewport(tester);
    await seed();
    await tester.runAsync(
        () => container.read(checkinDetailProvider('c1').future));
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('LIST_PAGE'))),
        ),
        GoRoute(
          path: '/checkin/detail',
          builder: (_, state) => CheckinDetailPage(
            checkinId: state.queryParams['checkinId'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await settle(tester);

    // 预解析详情 provider，避免 fake zone 中页面查询挂起
    await tester.runAsync(
        () => container.read(checkinDetailProvider('c1').future));
    await tester.pump();
    router.push('/checkin/detail?checkinId=c1');
    await settle(tester);
    expect(find.text('Manner Coffee'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);
    expect(find.text('删除足迹'), findsOneWidget); // 弹窗标题
    expect(find.textContaining('确定删除这条探店足迹吗'), findsOneWidget);

    await tester.tap(find.text('删除').last); // 弹窗确认按钮
    // 真实 DB 删除是 FFI 异步：需用 settle()（内部 runAsync 轮询）推进完成
    await settle(tester);

    // 库中已删除（真实 DB 查询需在 runAsync 中完成）
    final remaining = await tester.runAsync(() => dao.getById('c1'));
    expect(remaining, isNull);
    expect(find.text('LIST_PAGE'), findsOneWidget); // pop 回基页
  });
}

Future<void> _onCreate(Database d, int v) async {
  await d.execute(CheckinTable.createSql);
  await d.execute(CheckinTable.indexVisitedAtSql);
  await d.execute(CheckinPhotoTable.createSql);
  await d.execute(CheckinPhotoTable.indexCheckinSql);
  await d.execute('''
    CREATE TABLE gallery_items (
      id TEXT PRIMARY KEY,
      data_url TEXT,
      file_path TEXT,
      original_path TEXT,
      transform TEXT,
      post_process TEXT,
      scene_id TEXT,
      template_id TEXT,
      kit_id TEXT,
      mood TEXT,
      lut TEXT,
      is_favorite INTEGER DEFAULT 0,
      created_at INTEGER
    )
  ''');
}
