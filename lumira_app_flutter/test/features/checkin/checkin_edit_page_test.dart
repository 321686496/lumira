import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_dao.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_providers.dart';
import 'package:lumira_app_flutter/features/checkin/pages/checkin_edit_page.dart';

void main() {
  late Database db;
  late CheckinDao dao;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 主 isolate FFI 直连（同 gallery_detail_page_test）
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
    tester.binding.window.physicalSizeTestValue = const Size(800, 1600);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Future<void> seedGallery({int n = 2}) async {
    final g = GalleryDao(db);
    for (var i = 0; i < n; i++) {
      await g.insert(GalleryItemRecord(
        id: 'p$i',
        dataUrl: 'https://example.com/p$i.jpg',
        filePath: null,
        originalPath: null,
        transform: null,
        postProcess: null,
        sceneId: null,
        templateId: null,
        kitId: null,
        mood: null,
        lut: null,
        isFavorite: false,
        createdAt: 1000 * (i + 1),
      ));
    }
  }

  testWidgets('店名为空时保存拦截', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckinEditPage()),
    ));
    await settle(tester);

    await tester.tap(find.text('保存'));
    await settle(tester);
    expect(find.text('请输入店名'), findsOneWidget);
    expect(await dao.countAll(), 0);
  });

  testWidgets('新增保存成功：店名/分类/评分写入', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckinEditPage()),
    ));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '新咖啡馆');
    // 选分类「书店」
    await tester.tap(find.text('书店'));
    await tester.pump();
    // 点第 3 颗星
    await tester.tap(find.byIcon(Icons.star_border).at(2));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await settle(tester);

    expect(find.text('已保存'), findsOneWidget);
    expect(await dao.countAll(), 1);
    final rec = (await dao.getAll()).first;
    expect(rec.name, '新咖啡馆');
    expect(rec.category, 'bookstore');
    expect(rec.rating, 3);
  });

  testWidgets('photoId 参数自动预填', (tester) async {
    setViewport(tester);
    await tester.runAsync(() => seedGallery(n: 1));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckinEditPage(photoId: 'p0')),
    ));
    await settle(tester);

    expect(find.text('1/9'), findsOneWidget); // 照片 section 计数
    // 保存后照片关联写入
    await tester.enterText(find.byType(TextField).first, '预填店铺');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 600));
    final rec = (await dao.getAll()).first;
    expect(await dao.getPhotoIds(rec.id), ['p0']);
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
