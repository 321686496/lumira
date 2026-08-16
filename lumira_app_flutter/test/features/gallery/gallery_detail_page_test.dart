import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_detail_page.dart';
import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late Database db;
  late GalleryDao dao;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: databaseFactoryFfi 默认在后台 isolate 中执行 DB 操作，
    // isolate 通信使用 real async（Isolate.run / SendPort），不参与
    // pumpAndSettle 的 fake async 时间推进。导致 dao.getById() 等返回的
    // future 在 pumpAndSettle 期间不解析（需 ~5s real time 隔离启动），
    // pumpAndSettle 10s 超时。改用 databaseFactoryFfiNoIsolate 让 DB 操作
    // 在主 isolate 通过 FFI 同步执行，future 通过 microtask 解析，
    // pumpAndSettle 的 pump(duration) 会推进 fake async 并处理 microtask。
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Forced fix: DB 与容器必须在 testWidgets body（fake async zone）内创建，
  // 否则页面内 await dao 查询在 fake zone 中挂起（pumpAndSettle 永久等待，
  // 与 gallery_diary_page_test.dart 排查同根因）。
  Future<void> initContainer() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      galleryDaoProvider.overrideWith((ref) async => dao),
    ]);
    // 预先让 provider 进入 data 状态，避免 pumpAndSettle 等待
    // CircularProgressIndicator（无限动画）而 timed out。详见 gallery_page_test.dart。
    await container.read(galleryDaoProvider.future);
  }

  // Forced fix: gallery_detail_page 已重构为 state-variable-based loading（不再用 FutureBuilder）。
  // _isLoading=true 时显示 CircularProgressIndicator（无限动画）让 pumpAndSettle 持续 pump，
  // 直到 _loadPhoto() 的 await 解析 + setState 触发重建 → _isLoading=false →
  // CircularProgressIndicator 移除 → pumpAndSettle settle。
  // 详见 gallery_page_test.dart 的注释。

  testWidgets('renders empty canvas when photoId is null', (tester) async {
    // Forced fix: brief 用 `await tester.binding.window.setPhysicalSizeTestValue(...)`
    // 但 setPhysicalSizeTestValue 返回 void，await void 会触发 use_of_void_result lint 错误。
    // 改用 setter 赋值形式（与 challenge_page_test.dart / home_page_test.dart 同模式）。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×466，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await initContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GalleryDetailPage(photoId: null)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('照片不存在或已被删除'), findsOneWidget);
  });

  testWidgets('renders empty canvas when photo not found', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×466，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await initContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GalleryDetailPage(photoId: 'nonexistent')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('照片不存在或已被删除'), findsOneWidget);
  });

  testWidgets('renders photo detail when photo exists', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×600，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await initContainer();
    // 场景：detail 页 _loadPhoto 会经 scenesDaoProvider 查询场景名
    await db.insert(Tables.scenes, {
      Tables.colId: 'cafe',
      Tables.colName: 'cafe',
      Tables.colCategory: '室内',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    });
    await dao.insert(GalleryItemRecord(
      id: 'p1',
      dataUrl: 'https://example.com/p1.jpg',
      filePath: null,
      sceneId: 'cafe',
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000000000,
    ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GalleryDetailPage(photoId: 'p1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('照片详情'), findsOneWidget);
    // 面板标题（合并后的"照片信息"面板）
    expect(find.text('照片信息'), findsOneWidget);
    // 场景名仅出现一次（分类行），已消除与来源 chips 的重复
    expect(find.text('cafe'), findsOneWidget);
    // 分类（场景）行提供"更换"操作
    expect(find.text('更换'), findsOneWidget);
    // 原图未保留时底部为只读提示（编辑能力已迁移至 GalleryEditPage）
    expect(find.text('原图未保留'), findsWidgets);
  });
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
  // scenes（detail 页 _loadPhoto 经 scenesDaoProvider 查询场景名/全量列表）
  await db.execute('''
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
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  // custom_templates（detail 页 _loadPhoto 经 templatesDaoProvider 查询模板名）
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
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
}
