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
import 'package:lumira_app_flutter/features/checkin/pages/checkin_list_page.dart';

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
    // Forced fix: 预解析基础 provider，避免 loading 态 CircularProgressIndicator（无限动画）拖垮 pumpAndSettle
    await container.read(checkinDaoProvider.future);
    await container.read(galleryDaoProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void setViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Future<void> seed({int n = 3}) async {
    for (var i = 0; i < n; i++) {
      await dao.insert(CheckinRecord(
        id: 'c$i',
        name: '店铺 $i',
        place: '地点 $i',
        category: 'coffee',
        rating: i == 0 ? 5 : 0,
        note: '',
        visitedAt: 1000 * (i + 1),
        createdAt: 1,
        updatedAt: 1,
      ));
    }
  }

  Widget wrap(Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    );
  }

  /// 在 seed 之后预解析列表/总数 provider（避免 FakeAsync 中 future 不 resolve 导致 loading 态超时）
  Future<void> preload() async {
    await container.read(checkinsProvider.future);
    await container.read(checkinTotalCountProvider.future);
  }

  testWidgets('空态显示引导', (tester) async {
    setViewport(tester);
    await preload();
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await tester.pumpAndSettle();
    expect(find.text('还没有探店足迹'), findsOneWidget);
    expect(find.text('记录第一笔'), findsOneWidget);
  });

  testWidgets('列表渲染足迹与总数', (tester) async {
    setViewport(tester);
    await seed(n: 3);
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await tester.pumpAndSettle();
    expect(find.text('个探店足迹'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('店铺 0'), findsOneWidget);
    expect(find.text('店铺 1'), findsOneWidget);
    expect(find.text('店铺 2'), findsOneWidget);
    expect(find.text('咖啡'), findsNWidgets(3));
  });

  testWidgets('空态点击记录第一笔跳新增', (tester) async {
    setViewport(tester);
    await preload();
    final router = GoRouter(
      initialLocation: '/checkin/list',
      routes: [
        GoRoute(
          path: '/checkin/list',
          builder: (_, __) => const CheckinListPage(),
        ),
        GoRoute(
          path: '/checkin/edit',
          builder: (_, __) => const Scaffold(body: Text('edit-page')),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录第一笔'));
    await tester.pumpAndSettle();
    expect(find.text('edit-page'), findsOneWidget);
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
