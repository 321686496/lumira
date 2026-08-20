import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_detail_page.dart';
import '../../../test/helpers/test_http_overrides.dart';

/// 相册详情页「更多」菜单 →「添加水印」功能测试。
///
/// 覆盖点：
/// - 打开「更多」菜单出现「添加水印」项
/// - 点击后携带 photo / templateId 查询参数路由跳转到「galleryWatermarkApply」，
///   应用模式编辑器出现「添加水印」标题与「保存并应用」保存文本
///
/// 说明：编辑器真实页面在应用模式会 `File(photoPath).readAsBytes()`（real async dart:io），
/// 在 fake async 测试区内会挂起 pumpAndSettle（与既有测试用 filePath:null + dataUrl
/// 规避真 IO 同根因）。因此此处用 stub 路由（同 watermark_manage_page_test 模式）只验证
/// 「菜单 → 路由跳转 → photo 参数正确传递 → 应用模式标题/保存文本」这一接线逻辑。
void main() {
  late Database db;
  late GalleryDao dao;
  late ProviderContainer container;
  late GoRouter router;
  // 「添加水印」传递的照片本地路径（确定性假路径，不做真实文件 IO）
  const String testPhotoPath = 'test_photo.jpg';

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 同 gallery_detail_page_test.dart，改用 databaseFactoryFfiNoIsolate
    // 让 DB 操作在主 isolate 通过 FFI 同步执行，future 经 microtask 解析，
    // 避免 pumpAndSettle 10s 超时。
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Forced fix: DB 与容器必须在 testWidgets body（fake async zone）内创建，
  // 与 gallery_detail_page_test.dart 同根因。
  Future<void> initContainer() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      galleryDaoProvider.overrideWith((ref) async => dao),
    ]);
    await container.read(galleryDaoProvider.future);
  }

  void bindWindowSize(WidgetTester tester) {
    // Forced fix: setter 赋值形式（setPhysicalSizeTestValue 返回 void，await 会触发 lint）。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  /// 构造含 galleryDetail + galleryWatermarkApply(stub) 的最小路由。
  void buildRouter() {
    router = GoRouter(
      initialLocation: RouteNames.galleryDetail,
      routes: [
        GoRoute(
          path: RouteNames.galleryDetail,
          name: 'galleryDetail',
          builder: (_, __) => const GalleryDetailPage(photoId: 'p1'),
        ),
        // 应用模式编辑器 stub：按 photo 参数是否为传给「添加水印 / 编辑水印」标题
        GoRoute(
          path: RouteNames.galleryWatermarkApply,
          name: 'galleryWatermarkApply',
          builder: (_, state) {
            final photo = state.queryParams[RouteNames.paramPhoto];
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(photo != null ? '添加水印' : '编辑水印'),
                    const SizedBox(height: 8),
                    const Text('保存并应用'),
                    const SizedBox(height: 8),
                    Text(photo ?? ''),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> seedPhoto() async {
    await dao.insert(GalleryItemRecord(
      id: 'p1',
      // dataUrl 用于详情预览（NetworkImage + TestHttpOverrides），避免 FileImage 真 IO 挂起
      dataUrl: 'https://example.com/p1.jpg',
      // filePath 用于「添加水印」的 photoPath 传递
      filePath: testPhotoPath,
      sceneId: null,
      templateId: null,
      kitId: null,
      mood: null,
      lut: null,
      createdAt: 1700000000000,
    ));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('更多菜单出现「添加水印」项，点击后跳转到应用模式编辑器', (tester) async {
    bindWindowSize(tester);
    await initContainer();
    await seedPhoto();
    buildRouter();
    await pumpApp(tester);

    // 打开「更多」菜单
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    // 菜单出现「添加水印」项
    expect(find.text('添加水印'), findsOneWidget);

    // 点击「添加水印」→ 携带参数跳转到编辑器
    await tester.tap(find.text('添加水印'));
    await tester.pumpAndSettle();

    // stub 应用模式编辑器出现：标题「添加水印」（photo 非空）、保存文本「保存并应用」
    expect(find.text('添加水印'), findsOneWidget);
    expect(find.text('保存并应用'), findsOneWidget);
    // 进入编辑器后详情页 BottomSheet 已关闭，仅编辑器标题使用该文案；且编辑器按
    // photo 参数显示照片路径 → 验证 query 参数「photo」已正确传递
    expect(find.text(testPhotoPath), findsOneWidget);
  });

  testWidgets('未设置当前水印模板时点击「添加水印」仍能进入编辑器', (tester) async {
    bindWindowSize(tester);
    await initContainer();
    await seedPhoto();
    buildRouter();
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加水印'));
    await tester.pumpAndSettle();

    // 未设置当前水印模板（templateId 为空）仍需能进入编辑器（应用模式/新建模板路径）而非崩溃
    expect(find.text('保存并应用'), findsOneWidget);
    // photo 参数仍正确传递
    expect(find.text(testPhotoPath), findsOneWidget);
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
  // scenes（detail 页 _loadPhoto 经 scenesDaoProvider 查询全部场景列表）
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