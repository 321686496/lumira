import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_page.dart';
import 'package:lumira_app_flutter/features/gallery/widgets/photo_cell.dart';
import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late Database db;
  late GalleryDao dao;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: databaseFactoryFfi 默认在后台 isolate 中执行 DB 操作，
    // isolate 通信使用 real async（Isolate.run / SendPort），不参与
    // pumpAndSettle 的 fake async 时间推进。导致 dao.getAll() 等返回的
    // future 在 pumpAndSettle 期间不解析（需 ~5s real time 隔离启动），
    // pumpAndSettle 10s 超时。改用 databaseFactoryFfiNoIsolate 让 DB 操作
    // 在主 isolate 通过 FFI 同步执行，future 通过 microtask 解析，
    // pumpAndSettle 的 pump(duration) 会推进 fake async 并处理 microtask。
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
    container = ProviderContainer(overrides: [
      galleryDaoProvider.overrideWith((ref) async => dao),
    ]);
    // Forced fix: gallery_page build 中 `ref.watch(galleryDaoProvider)` 在第一次 build 时
    // 返回 AsyncLoading，导致 daoAsync.when 显示 CircularProgressIndicator（无限动画），
    // pumpAndSettle 等待其完成而 timed out。预先让 provider 进入 data 状态，
    // 使首次 build 时 daoAsync 已是 data，跳过 loading 分支。
    await container.read(galleryDaoProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Forced fix: gallery_page 已重构为 state-variable-based loading（不再用 FutureBuilder）。
  // _isLoading=true 时显示 CircularProgressIndicator（无限动画）让 pumpAndSettle 持续 pump，
  // 直到 _loadPhotos() 的 await 解析 + setState 触发重建 → _isLoading=false →
  // CircularProgressIndicator 移除 → pumpAndSettle settle。
  // 前序 session 用 FutureBuilder，其内部 listener 在测试环境不可靠，永不从 waiting 切到 done，
  // 导致 pumpAndSettle timed out。改用 setState 后该问题解决。
  // 此外，setUpAll 改用 databaseFactoryFfiNoIsolate 避免 isolate 通信的 real async
  // 不参与 fake async 时间推进的问题（详见 setUpAll 注释）。

  testWidgets('renders empty state when no photos', (tester) async {
    // Forced fix: brief 用 `await tester.binding.window.setPhysicalSizeTestValue(...)`
    // 但 setPhysicalSizeTestValue 返回 void，await void 会触发 use_of_void_result lint 错误。
    // 改用 setter 赋值形式（与 challenge_page_test.dart / home_page_test.dart 同模式）。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×400，
    // Row（张数 + ViewToggle）会溢出。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await _pumpGalleryPage(tester, container);
    await tester.pumpAndSettle();

    expect(find.text('0 张照片'), findsOneWidget);
    expect(find.text('还没有照片，去拍一张吧'), findsOneWidget);
  });

  testWidgets('renders photos grid with 3 columns', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×400，
    // Row（张数 + ViewToggle）会溢出。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await dao.insert(GalleryItemRecord(
      id: 'p1',
      dataUrl: 'https://example.com/p1.jpg',
      filePath: null,
      sceneId: null,
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000000000,
    ));
    await dao.insert(GalleryItemRecord(
      id: 'p2',
      dataUrl: 'https://example.com/p2.jpg',
      filePath: null,
      sceneId: 'scene_cafe',
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000001000,
    ));

    await _pumpGalleryPage(tester, container);
    await tester.pumpAndSettle();

    expect(find.text('2 张照片'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('tapping photo pushes /gallery/detail with photoId', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×400，
    // Row（张数 + ViewToggle）会溢出。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await dao.insert(GalleryItemRecord(
      id: 'p1',
      dataUrl: 'https://example.com/p1.jpg',
      filePath: null,
      sceneId: null,
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000000000,
    ));

    final router = GoRouter(
      initialLocation: '/gallery',
      routes: [
        GoRoute(path: '/gallery', builder: (_, __) => UncontrolledProviderScope(container: container, child: const GalleryPage())),
        GoRoute(path: '/gallery/detail', builder: (_, __) => const Scaffold(body: Text('detail'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PhotoCell));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('gallery AppBar no longer shows 精选集 entry', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await _pumpGalleryPage(tester, container);
    await tester.pumpAndSettle();

    // 精选集入口已移到「我的」页，相册 AppBar 不再直接暴露
    expect(find.text('精选集'), findsNothing);
  });

  testWidgets('long press enters multi-select with 加入精选集 action', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×400，
    // Row（张数 + ViewToggle）会溢出。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await dao.insert(GalleryItemRecord(
      id: 'p1',
      dataUrl: 'https://example.com/p1.jpg',
      filePath: null,
      sceneId: null,
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000000000,
    ));

    await _pumpGalleryPage(tester, container);
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(PhotoCell));
    await tester.pumpAndSettle();

    expect(find.text('加入精选集'), findsOneWidget);
  });
}

Future<void> _pumpGalleryPage(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: GalleryPage(),
    ),
  ));
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
}
