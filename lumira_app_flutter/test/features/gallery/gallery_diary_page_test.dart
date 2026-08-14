import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_diary_page.dart';
import 'package:lumira_app_flutter/features/gallery/providers/gallery_diary_providers.dart';
import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late Database db;
  late GalleryDao dao;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    // databaseFactoryFfiNoIsolate: DB 操作在主 isolate 通过 FFI 同步执行，
    // future 通过 microtask 解析，pumpAndSettle 的 pump(duration) 会推进 fake
    // async 并处理 microtask（与 gallery_page_test.dart 同模式）。
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = GalleryDao(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // 预热 DAO providers，使首次 build 时 diaryEntriesProvider 已是 data 状态，
  // 跳过 loading 分支的 CircularProgressIndicator（无限动画）。
  // Forced fix: 容器必须在 testWidgets body（fake async zone）内创建，
  // 否则 provider 体内的 sqflite FFI 调用在 fake zone 中 await 会挂起
  // （pumpAndSettle 永久等待，详见 _probe_hang_test 排查记录）。
  Future<void> initContainer() async {
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    await container.read(galleryDaoProvider.future);
    await container.read(scenesDaoProvider.future);
    await container.read(templatesDaoProvider.future);
  }

  // 视口配置：逻辑视口 800x1800（dpr=1.0），容纳 toggle + banner + 2 篇 entry。
  void setViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Future<void> seedData() async {
    // 场景（用于 outfit tab 的 sceneId 筛选 + 标签派生）
    await db.insert(Tables.scenes, {
      Tables.colId: 'scene_cafe',
      Tables.colName: '咖啡馆',
      Tables.colCategory: '室内',
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));

    // p1: 今天，带 sceneId（outfit tab 可见）
    await dao.insert(GalleryItemRecord(
      id: 'p1',
      dataUrl: 'https://example.com/p1.jpg',
      sceneId: 'scene_cafe',
      mood: '放松',
      createdAt: today.millisecondsSinceEpoch,
    ));
    // p2: 今天，无 sceneId（仅 shoot tab 可见）
    await dao.insert(GalleryItemRecord(
      id: 'p2',
      dataUrl: 'https://example.com/p2.jpg',
      createdAt: today.millisecondsSinceEpoch + 1,
    ));
    // p3: 昨天，带 sceneId（outfit tab 可见）
    await dao.insert(GalleryItemRecord(
      id: 'p3',
      dataUrl: 'https://example.com/p3.jpg',
      sceneId: 'scene_cafe',
      createdAt: yesterday.millisecondsSinceEpoch,
    ));
    // p4: 今天，带 sceneId（outfit tab 可见）+ mood（心情筛选）
    await dao.insert(GalleryItemRecord(
      id: 'p4',
      dataUrl: 'https://example.com/p4.jpg',
      sceneId: 'scene_cafe',
      mood: '开心',
      createdAt: today.millisecondsSinceEpoch + 2,
    ));

    // 预热 diary providers，避免 loading spinner 导致 pumpAndSettle 超时
    await container.read(
        diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabOutfit)).future);
    await container.read(
        diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabShoot)).future);
    await container.read(diaryStreakProvider.future);
  }

  Future<void> pumpDiaryPage(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GalleryDiaryPage()),
    ));
  }

  testWidgets('renders diary entries timeline from DB', (tester) async {
    setViewport(tester);
    await initContainer();
    await seedData();

    await pumpDiaryPage(tester);
    await tester.pumpAndSettle();

    // outfit tab（默认）：仅含 sceneId 的照片 → p1(今天) + p3(昨天) → 2 篇
    expect(find.text('穿搭日记'), findsWidgets); // AppBar title + toggle item
    expect(find.text('时间轴'), findsOneWidget);
    expect(find.text('2篇'), findsOneWidget);

    // 2 篇 entry 的日期标签（M月d日）
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));
    expect(find.text(DateFormat('M月d日').format(today)), findsOneWidget);
    expect(find.text(DateFormat('M月d日').format(yesterday)), findsOneWidget);
  });

  testWidgets('renders streak banner with dynamic streak', (tester) async {
    setViewport(tester);
    await initContainer();
    await seedData();

    await pumpDiaryPage(tester);
    await tester.pumpAndSettle();

    // 连续打卡 = 2（今天 + 昨天均有照片）
    expect(find.textContaining('连续打卡 2'), findsOneWidget);
    expect(find.text('继续保持，解锁「周更达人」徽章'), findsOneWidget);
  });

  testWidgets('toggles between outfit and shoot tabs', (tester) async {
    setViewport(tester);
    await initContainer();
    await seedData();

    await pumpDiaryPage(tester);
    await tester.pumpAndSettle();

    // 默认 outfit tab 激活：title='穿搭日记' + toggle '穿搭日记' = 2 处
    expect(find.text('穿搭日记'), findsWidgets);

    await tester.tap(find.text('拍摄日记').first);
    await tester.pumpAndSettle();

    // shoot tab 激活后：title 动态切换为 '拍摄日记'，仅 toggle 中 '穿搭日记' 文字保留
    expect(find.text('穿搭日记'), findsOneWidget);
  });

  testWidgets('filters diary by mood pill and clears on re-tap', (tester) async {
    setViewport(tester);
    await initContainer();
    await seedData();

    await pumpDiaryPage(tester);
    await tester.pumpAndSettle();

    // 未筛选：outfit tab 下 p1/p4 今天、p3 昨天 → 2 篇
    expect(find.text('时间轴'), findsOneWidget);
    expect(find.text('2篇'), findsOneWidget);

    // 点击心情 pill「开心」→ 仅 p4（今天）可见；pill 位于时间轴条目之前，
    // 且 p4 的 mood 标签也含「开心」，故用 .first 命中树序靠前的 pill
    await tester.ensureVisible(find.text('开心').first);
    await tester.tap(find.text('开心').first);
    await tester.pumpAndSettle();
    expect(find.text('1篇'), findsOneWidget);

    // 再次点击取消 → 恢复全部
    await tester.tap(find.text('开心').first);
    await tester.pumpAndSettle();
    expect(find.text('2篇'), findsOneWidget);
  });
}

Future<void> _onCreate(Database db, int version) async {
  // gallery_items（含 v7/v8 扩展列，匹配生产 schema）
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
  // scenes（用于 sceneId → 场景名标签派生）
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
  // custom_templates（templatesDaoProvider 派生需要，本测试不写入数据）
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
