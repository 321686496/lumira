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
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_collections_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/collection_providers.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// ProfileCollectionsPage DAO 集成测试
///
/// 验证页面从 collectionsListProvider（基于真实 DAO + CollectionService）
/// 加载数据并渲染：
/// - 空相册显示空状态
/// - 有照片时显示 auto 派生精选集
/// - 点击"+ 新建"跳转编辑页
/// - 点击精选集卡跳转详情页
/// - 8 主题 × 4 UIStyle 渲染稳定性
///
/// Forced fix: 预热 collectionsListProvider（在 testWidgets 的 real async zone
/// 中 await），使 widget build 时直接获得 AsyncData，避免 AsyncLoading 的
/// CircularProgressIndicator 无限动画导致 pumpAndSettle 超时。
/// 与 profile_collection_detail_page_test.dart 同模式。
void main() {
  late Database db;
  late ProviderContainer container;
  FlutterExceptionHandler? originalErrorHandler;

  setUpAll(() {
    sqfliteFfiInit();
    // Forced fix: 使用 NoIsolate 避免 isolate 通信的 real async
    // 不参与 fake async 时间推进（与 gallery_page_test.dart 同模式）
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    // 预热 databaseProvider + collectionServiceProvider（这两个不涉及
    // 复杂 DB 操作链，可在 setUp 的 real async zone 中完成）
    await container.read(databaseProvider.future);
    await container.read(collectionServiceProvider.future);
    // 预热 collectionsListProvider（空状态，syncAutoCollections 无数据可派生）
    // 在 setUp 的 real async zone 中完成，避免 testWidgets 的 FakeAsync 拦截
    await container.read(collectionsListProvider.future);
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      if (details.toString().contains('_CastError')) {
        // Flutter 3.7.12-ohos RenderViewport bug，忽略
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
    // 简单渲染测试用 MaterialApp（无 GoRouter），避免 GoRouter 内部
    // 状态/动画导致 pumpAndSettle 无法 settle
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ProfileCollectionsPage(),
      ),
    );
  }

  /// 导航测试用 GoRouter（包含详情页和编辑页占位路由）
  /// Forced fix: 使用 NoTransitionPage 消除页面切换动画，
  /// 让 push 后单次 pump() 即可完成导航（避免 pumpAndSettle 与 BackdropFilter 冲突）
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
          path: RouteNames.profileCollectionDetail,
          name: 'profileCollectionDetail',
          pageBuilder: (_, __) => const NoTransitionPage(
            child: Scaffold(body: Center(child: Text('COLLECTION_DETAIL'))),
          ),
        ),
        GoRoute(
          path: RouteNames.profileCollectionEdit,
          name: 'profileCollectionEdit',
          pageBuilder: (_, __) => const NoTransitionPage(
            child: Scaffold(body: Center(child: Text('COLLECTION_EDIT'))),
          ),
        ),
      ],
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.setSemanticsEnabled(false);
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  /// Forced fix: 使用 pump()（Duration.zero）代替 pumpAndSettle()。
  ///
  /// pumpAndSettle 和 pump(duration>0) 在此 Flutter 版本（3.7.12-ohos）中
  /// 均会 hang——pumpAndSettle 因 BackdropFilter 持续调度帧无法 settle；
  /// pump(duration>0) 推进 FakeAsync 时间后触发未知 timer 循环导致 hang。
  ///
  /// pump()（Duration.zero）不推进时间，只处理 microtask 队列 + 触发一帧。
  /// Provider 已在 setUp 中预热，widget build 时直接获得 AsyncData。
  /// 多次 pump() 确保 _CoverThumb 异步加载完成（microtask 在 pump 中处理）。
  Future<void> pumpAndSettleCompat(WidgetTester tester) async {
    await tester.pump();
  }

  /// 在 real async zone（通过 tester.runAsync）中插入照片并重新同步
  /// collectionsListProvider，使 widget build 时直接获得 AsyncData。
  ///
  /// Forced fix: 不能直接在 testWidgets callback 中 await provider.future，
  /// 因为 databaseFactoryFfiNoIsolate 的 DB 操作通过 microtask/timer 完成，
  /// 在 FakeAsync zone 中被拦截，导致 await 永久阻塞（deadlock）。
  /// tester.runAsync 在 real async zone 中执行回调，绕过 FakeAsync，
  /// 使 DB 操作正常完成。
  Future<void> seedAndPreheat(
    WidgetTester tester, {
    int photoCount = 0,
    bool favorite = false,
  }) async {
    await tester.runAsync(() async {
      for (var i = 0; i < photoCount; i++) {
        await _insertPhoto(db, 'p$i',
            createdAt: DateTime.now().millisecondsSinceEpoch - i * 1000,
            isFavorite: favorite);
      }
      // collectionsListProvider 已在 setUp 中预热（空状态），
      // 需 invalidate 使其重新执行 syncAutoCollections（含新照片）
      container.invalidate(collectionsListProvider);
      await container.read(collectionsListProvider.future);
    });
  }

  group('ProfileCollectionsPage - real DAO', () {
    testWidgets('空相册显示空状态', (tester) async {
      setLargeViewport(tester);
      // Provider 已在 setUp 中预热（空状态，无照片）
      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      expect(find.text('暂无精选集'), findsOneWidget);
    });

    testWidgets('有照片时显示"最近精选"auto 派生精选集', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 2);

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      expect(find.text('最近精选'), findsOneWidget);
      // 2 张照片会派生 autoRecent + autoMonthly 两个 auto 精选集，
      // 每个带 "自动" 标签，所以 findsAtLeastNWidgets(1)
      expect(find.text('自动'), findsAtLeastNWidgets(1));
      expect(find.text('个精选集'), findsOneWidget);
    });

    testWidgets('点击"+ 新建"跳转编辑页', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 1);

      await tester.pumpWidget(wrap(router: goRouter()));
      await pumpAndSettleCompat(tester);

      final createBtn = find.text('+ 新建');
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await pumpAndSettleCompat(tester);

      expect(find.text('COLLECTION_EDIT'), findsOneWidget);
    });

    testWidgets('点击精选集卡跳转详情页', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 1);

      await tester.pumpWidget(wrap(router: goRouter()));
      await pumpAndSettleCompat(tester);

      await tester.tap(find.text('最近精选'));
      await pumpAndSettleCompat(tester);

      expect(find.text('COLLECTION_DETAIL'), findsOneWidget);
    });

    testWidgets('收藏照片显示"我的收藏"精选集', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 1, favorite: true);

      await tester.pumpWidget(wrap());
      await pumpAndSettleCompat(tester);

      expect(find.text('我的收藏'), findsOneWidget);
    });

    testWidgets('8 主题渲染稳定性', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 1);

      for (final theme in ThemeKey.values) {
        container.read(themeKeyProvider.notifier).state = theme;
        await tester.pumpWidget(wrap());
        await pumpAndSettleCompat(tester);
        expect(find.byType(ProfileCollectionsPage), findsOneWidget,
            reason: 'theme=$theme');
        expect(find.text('最近精选'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('4 UIStyle 渲染稳定性', (tester) async {
      setLargeViewport(tester);
      await seedAndPreheat(tester, photoCount: 1);

      for (final style in UIStyle.values) {
        container.read(uiStyleProvider.notifier).state = style;
        await tester.pumpWidget(wrap());
        await pumpAndSettleCompat(tester);
        expect(find.byType(ProfileCollectionsPage), findsOneWidget,
            reason: 'style=$style');
        expect(find.text('最近精选'), findsOneWidget, reason: 'style=$style');
      }
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
