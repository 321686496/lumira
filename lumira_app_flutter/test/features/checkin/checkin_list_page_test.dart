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

  /// 在 seed 之后预解析列表/统计/分类 provider（避免 FakeAsync 中 future 不 resolve 导致 loading 态超时）
  Future<void> preload() async {
    await container.read(checkinsProvider.future);
    await container.read(checkinTotalCountProvider.future);
    await container.read(checkinStatsProvider.future);
    await container.read(checkinCategoriesProvider.future);
  }

  /// sqflite_common_ffi 的 DB 查询是真实 async：在 FakeAsync 中 pumpAndSettle 无法让
  /// 真实 Future 完成，必须先轮询 runAsync 推进（与 templates_all_page_test 同模式）。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('空态显示引导', (tester) async {
    setViewport(tester);
    await tester.runAsync(() => preload());
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await settle(tester);
    expect(find.text('还没有探店足迹'), findsOneWidget);
    expect(find.text('记录第一笔'), findsOneWidget);
  });

  testWidgets('列表渲染足迹与统计', (tester) async {
    setViewport(tester);
    await seed(n: 3);
    // seed 后失效缓存并重新预解析，避免 loading 态无限动画拖垮 pumpAndSettle
    container.invalidate(checkinsProvider);
    container.invalidate(checkinTotalCountProvider);
    container.invalidate(checkinStatsProvider);
    container.invalidate(checkinCategoriesProvider);
    await tester.runAsync(() => preload());
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await settle(tester);
    // 统计卡：足迹总数 / 好评店铺 / 平均评分 / 今年新增
    expect(find.text('足迹总数'), findsOneWidget);
    expect(find.text('好评店铺'), findsOneWidget);
    expect(find.text('平均评分'), findsOneWidget);
    expect(find.text('今年新增'), findsOneWidget);
    // 店铺 0 评分 5 → 好评店铺 1
    expect(find.text('1'), findsWidgets);
    // 排序切换 & 分类筛选入口
    expect(find.text('按时间'), findsOneWidget);
    expect(find.text('按评分'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('咖啡'), findsNWidgets(4)); // 1 个分类 pill + 3 个卡片标签
    expect(find.text('店铺 0'), findsOneWidget);
    expect(find.text('店铺 1'), findsOneWidget);
    expect(find.text('店铺 2'), findsOneWidget);
  });

  testWidgets('按评分排序：高评分在前', (tester) async {
    setViewport(tester);
    // 3 家店评分 2/4/5
    await dao.insert(CheckinRecord(id: 'c0', name: '低分店', place: 'p', category: 'coffee', rating: 2, visitedAt: 3000, createdAt: 1, updatedAt: 1));
    await dao.insert(CheckinRecord(id: 'c1', name: '中分店', place: 'p', category: 'coffee', rating: 4, visitedAt: 2000, createdAt: 1, updatedAt: 1));
    await dao.insert(CheckinRecord(id: 'c2', name: '高分店', place: 'p', category: 'coffee', rating: 5, visitedAt: 1000, createdAt: 1, updatedAt: 1));
    container.invalidate(checkinsProvider);
    container.invalidate(checkinTotalCountProvider);
    container.invalidate(checkinStatsProvider);
    container.invalidate(checkinCategoriesProvider);
    await tester.runAsync(() => preload());
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await settle(tester);

    // 点击「按评分」
    await tester.tap(find.text('按评分'));
    await settle(tester);

    // 高分的「值得一去」徽章出现（评分 ≥ 4 共 2 家）
    expect(find.text('值得一去'), findsNWidgets(2));

    // 排序后高分店应排在最前：获取卡片列表 Y 坐标对比
    final highY = tester.getTopLeft(find.text('高分店')).dy;
    final midY = tester.getTopLeft(find.text('中分店')).dy;
    final lowY = tester.getTopLeft(find.text('低分店')).dy;
    expect(highY < midY, isTrue);
    expect(midY < lowY, isTrue);
  });

  testWidgets('分类筛选与空筛选态', (tester) async {
    setViewport(tester);
    await dao.insert(CheckinRecord(id: 'c0', name: '咖啡店', place: 'p', category: 'coffee', rating: 4, visitedAt: 3000, createdAt: 1, updatedAt: 1));
    await dao.insert(CheckinRecord(id: 'c1', name: '甜品店', place: 'p', category: 'dessert', rating: 4, visitedAt: 2000, createdAt: 1, updatedAt: 1));
    container.invalidate(checkinsProvider);
    container.invalidate(checkinTotalCountProvider);
    container.invalidate(checkinStatsProvider);
    container.invalidate(checkinCategoriesProvider);
    await tester.runAsync(() => preload());
    await tester.pumpWidget(wrap(const CheckinListPage()));
    await settle(tester);

    // 分类 pill：全部 / 咖啡 / 甜品美食
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('咖啡'), findsWidgets);
    expect(find.text('甜品美食'), findsNWidgets(2)); // 1 个分类 pill + 1 个卡片标签

    // 点击「咖啡」筛选 → 只显示咖啡店
    await tester.tap(find.text('咖啡').first);
    await settle(tester);
    expect(find.text('咖啡店'), findsOneWidget);
    expect(find.text('甜品店'), findsNothing);

    // 再次点击同一分类 → 取消筛选（回到全部）
    await tester.tap(find.text('咖啡').first);
    await settle(tester);
    expect(find.text('甜品店'), findsOneWidget);
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
