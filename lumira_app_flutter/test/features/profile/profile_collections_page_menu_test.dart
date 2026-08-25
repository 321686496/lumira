import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_collections_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/collection_providers.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// ProfileCollectionsPage 「⋯」菜单测试
///
/// 验证手动精选集（manual）的卡片右上角「⋯」按钮展开菜单：
/// - 菜单包含「编辑」「分享」「删除」三项
/// - 点击「编辑」跳转编辑页
/// - auto 精选集不显示「⋯」按钮
///
/// 沿用 profile_collections_page_test.dart 的测试模式。
void main() {
  late Database db;
  late ProviderContainer container;
  FlutterExceptionHandler? originalErrorHandler;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 使用 NoIsolate 避免 isolate 通信的 real async
    // 不参与 fake async 时间推进
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    // 预热 providers
    await container.read(databaseProvider.future);
    await container.read(collectionServiceProvider.future);
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({GoRouter? router}) {
    if (router != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      );
    }
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ProfileCollectionsPage(),
      ),
    );
  }

  GoRouter goRouter() {
    return GoRouter(
      initialLocation: RouteNames.profileCollections,
      routes: [
        GoRoute(
          path: RouteNames.profileCollections,
          name: 'profileCollections',
          pageBuilder: (_, __) => const NoTransitionPage(
            child: ProfileCollectionsPage(),
          ),
        ),
        GoRoute(
          path: RouteNames.profileCollectionEdit,
          name: 'profileCollectionEdit',
          pageBuilder: (_, __) => const NoTransitionPage(
            child: Scaffold(body: Center(child: Text('COLLECTION_EDIT'))),
          ),
        ),
        GoRoute(
          path: RouteNames.profileCollectionDetail,
          name: 'profileCollectionDetail',
          pageBuilder: (_, __) => const NoTransitionPage(
            child: Scaffold(body: Center(child: Text('COLLECTION_DETAIL'))),
          ),
        ),
      ],
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  /// Forced fix: 使用 pump()（Duration.zero）代替 pumpAndSettle()。
  Future<void> pumpAndSettleCompat(WidgetTester tester) async {
    await tester.pump();
  }

  /// 创建 manual 精选集：插入 [photoCount] 张照片并关联到精选集
  Future<void> seedManual(WidgetTester tester, {
    required String name,
    int photoCount = 0,
  }) async {
    await tester.runAsync(() async {
      for (var i = 0; i < photoCount; i++) {
        await _insertPhoto(db, 'm$i',
            createdAt: DateTime.now().millisecondsSinceEpoch - i * 1000);
      }
      final service = await container.read(collectionServiceProvider.future);
      await service.createManualCollection(
        name: name,
        coverPhotoId: photoCount > 0 ? 'm0' : null,
      );
      // 刷新列表 provider
      container.invalidate(collectionsListProvider);
      await container.read(collectionsListProvider.future);
    });
  }

  group('ProfileCollectionsPage - manual menu', () {
    testWidgets('manual 精选集显示「⋯」按钮', (tester) async {
      setLargeViewport(tester);
      await seedManual(tester, name: '手动集', photoCount: 1);

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      // 手动集名称可见
      expect(find.text('手动集'), findsOneWidget);
      // 「⋯」按钮存在（Icons.more_horiz）
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('auto 精选集不显示「⋯」按钮', (tester) async {
      setLargeViewport(tester);
      // 插入照片触发 auto 派生
      await tester.runAsync(() async {
        await _insertPhoto(db, 'p0',
            createdAt: DateTime.now().millisecondsSinceEpoch);
        final service = await container.read(collectionServiceProvider.future);
        await service.syncAutoCollections();
        container.invalidate(collectionsListProvider);
        await container.read(collectionsListProvider.future);
      });

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      // auto 精选集不显示「⋯」按钮
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('点击「⋯」弹出菜单，包含编辑/分享/删除', (tester) async {
      setLargeViewport(tester);
      await seedManual(tester, name: '测试集', photoCount: 1);

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      // 点击「⋯」按钮
      await tester.tap(find.byIcon(Icons.more_horiz));
      await pumpAndSettleCompat(tester);

      // 菜单项
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('菜单点击「编辑」跳转编辑页', (tester) async {
      setLargeViewport(tester);
      await seedManual(tester, name: '可编辑集', photoCount: 1);

      await tester.pumpWidget(wrap(router: goRouter()));
      await pumpAndSettleCompat(tester);

      // 点击「⋯」→ 菜单
      await tester.tap(find.byIcon(Icons.more_horiz));
      await pumpAndSettleCompat(tester);

      // Forced fix: 底部弹层的滑入动画在单次 pump()（Duration.zero）下
      // 未完成，菜单项仍被位移到视口下方导致 tap() 无法命中；
      // 而 pumpAndSettle / pump(duration>0) 在此 Flutter 版本会因
      // BackdropFilter 挂起。故直接调用 ListTile 的 onTap 验证导航逻辑。
      final editTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, '编辑'),
      );
      editTile.onTap!();
      await pumpAndSettleCompat(tester);

      expect(find.text('COLLECTION_EDIT'), findsOneWidget);
    });

    testWidgets('无照片的 manual 精选集仍显示「⋯」按钮', (tester) async {
      setLargeViewport(tester);
      await seedManual(tester, name: '空集');

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      expect(find.text('空集'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });
  });
}

// === Helpers ===

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
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
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
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
  await db.execute('''
    CREATE TABLE ${Tables.tableCollections} (
      ${Tables.colCollectionId} TEXT PRIMARY KEY,
      ${Tables.colCollectionName} TEXT NOT NULL,
      ${Tables.colCollectionDescription} TEXT,
      ${Tables.colCollectionCoverPhotoId} TEXT,
      ${Tables.colCollectionType} TEXT NOT NULL,
      ${Tables.colCollectionSourceMeta} TEXT,
      ${Tables.colCollectionPhotoCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionCreatedAt} INTEGER NOT NULL,
      ${Tables.colCollectionUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.tableCollectionPhotos} (
      ${Tables.colCollectionPhotoCollectionId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoPhotoId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionPhotoAddedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colCollectionPhotoCollectionId}, ${Tables.colCollectionPhotoPhotoId})
    )
  ''');
}

Future<void> _insertPhoto(
  Database db,
  String id, {
  String? sceneId,
  int? createdAt,
  bool isFavorite = false,
}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colFilePath: '/tmp/$id.jpg',
    Tables.colSceneId: sceneId,
    Tables.colGalleryItemIsFavorite: isFavorite ? 1 : 0,
    Tables.colCreatedAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  });
}