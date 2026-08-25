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
import 'package:lumira_app_flutter/features/profile/pages/profile_collection_detail_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/collection_providers.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// ProfileCollectionDetailPage DAO 集成测试
///
/// 验证页面从 [collectionDetailProvider]（基于真实 DAO + CollectionService）
/// 加载数据并渲染：
/// - autoRecent 精选集详情：标题 + 九宫格 + 仅导出按钮
/// - manual 精选集详情：标题 + 九宫格 + 编辑/导出/删除按钮
/// - 点击编辑跳转编辑页
/// - 8 主题 × 4 UIStyle 渲染稳定性
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
    // Forced fix: 预热 databaseProvider + collectionServiceProvider + 
    // collectionDetailProvider，避免页面首次 build 时卡在 AsyncLoading
    // （CircularProgressIndicator 无限动画导致 pumpAndSettle 超时）。
    // 预热后 widget build 时 provider 已是 AsyncData/AsyncError 状态。
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

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle, {required String collectionId}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation:
              RouteNames.build(RouteNames.profileCollectionDetail, {
            RouteNames.paramCollectionId: collectionId,
          }),
          routes: [
            GoRoute(
              path: RouteNames.profileCollectionDetail,
              name: 'profileCollectionDetail',
              pageBuilder: (_, state) => NoTransitionPage(
                child: ProfileCollectionDetailPage(
                  collectionId:
                      state.queryParams[RouteNames.paramCollectionId],
                ),
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
        ),
      ),
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  /// Forced fix: 使用 pump()（Duration.zero）代替 pumpAndSettle()。
  /// pumpAndSettle 和 pump(duration>0) 在此 Flutter 版本（3.7.12-ohos）中
  /// 均会 hang——pumpAndSettle 因 BackdropFilter 持续调度帧无法 settle；
  /// pump(duration>0) 推进 FakeAsync 时间后触发 BackdropFilter 动画循环
  /// 导致 hang。
  /// pump()（Duration.zero）不推进时间，只处理 microtask 队列 + 触发一帧。
  /// Provider 已在 seedAutoRecent/seedManual 中预热，widget build 时直接
  /// 获得 AsyncData。多次 pump() 确保 _CoverThumb 异步加载完成。
  Future<void> pumpAndSettleCompat(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  /// 创建 autoRecent 精选集：插入 [count] 张照片并同步 auto 派生
  /// Forced fix: 使用 tester.runAsync 在 real async zone 中执行 DB 操作，
  /// 避免 FakeAsync 拦截 databaseFactoryFfiNoIsolate 的 microtask/timer
  Future<void> seedAutoRecent(WidgetTester tester, int count) async {
    await tester.runAsync(() async {
      for (var i = 0; i < count; i++) {
        await _insertPhoto(db, 'p$i',
            createdAt: DateTime.now().millisecondsSinceEpoch - i * 1000);
      }
      final service = await container.read(collectionServiceProvider.future);
      await service.syncAutoCollections();
      // Forced fix: 预热 collectionDetailProvider，使 widget build 时
      // 直接获得 AsyncData 而非 AsyncLoading
      await container.read(collectionDetailProvider('auto_recent').future);
    });
  }

  /// 创建 manual 精选集：插入 [photoCount] 张照片并关联到精选集
  /// Forced fix: 使用 tester.runAsync（同 seedAutoRecent）
  Future<String> seedManual(
    WidgetTester tester, {
    required String name,
    String? description,
    int photoCount = 0,
  }) async {
    final id = await tester.runAsync(() async {
      for (var i = 0; i < photoCount; i++) {
        await _insertPhoto(db, 'm$i',
            createdAt: DateTime.now().millisecondsSinceEpoch - i * 1000);
      }
      final service = await container.read(collectionServiceProvider.future);
      final id = await service.createManualCollection(
        name: name,
        description: description,
        coverPhotoId: photoCount > 0 ? 'm0' : null,
      );
      for (var i = 0; i < photoCount; i++) {
        await service.addPhotoToCollection(id, 'm$i');
      }
      // Forced fix: 预热 collectionDetailProvider（同 seedAutoRecent）
      await container.read(collectionDetailProvider(id).future);
      return id;
    });
    return id!;
  }

  group('ProfileCollectionDetailPage - real DAO', () {
    testWidgets('autoRecent: 渲染标题"最近精选"和九宫格照片', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 3);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: 'auto_recent'));
      await pumpAndSettleCompat(tester);

      expect(find.byType(ProfileCollectionDetailPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '最近精选'), findsOneWidget);
      // 统计区显示照片数
      expect(find.text('3'), findsOneWidget);
      expect(find.text('张照片'), findsOneWidget);
      // 创建日标签
      expect(find.text('创建日'), findsOneWidget);
    });

    testWidgets('manual: 渲染自定义名称和九宫格照片', (tester) async {
      setLargeViewport(tester);
      final id = await seedManual(
        tester,
        name: '我最爱的九张',
        description: '精选回忆',
        photoCount: 2,
      );

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: id));
      await pumpAndSettleCompat(tester);

      expect(find.byType(ProfileCollectionDetailPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我最爱的九张'), findsOneWidget);
      // 描述
      expect(find.text('精选回忆'), findsOneWidget);
      // 统计区
      expect(find.text('2'), findsOneWidget);
      expect(find.text('张照片'), findsOneWidget);
    });

    testWidgets('渲染 3 列九宫格 GridView', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 5);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: 'auto_recent'));
      await pumpAndSettleCompat(tester);

      final gridView = find.byType(GridView);
      expect(gridView, findsOneWidget);
      final sliver = tester.widget<GridView>(gridView);
      expect(sliver.gridDelegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      final delegate =
          sliver.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('auto 类型仅显示"导出九宫格拼图"按钮（无编辑/删除）', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 2);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: 'auto_recent'));
      await pumpAndSettleCompat(tester);

      expect(find.text('导出九宫格拼图'), findsOneWidget);
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除精选集'), findsNothing);
    });

    testWidgets('manual 类型显示"编辑"+"导出九宫格拼图"+"删除精选集"按钮',
        (tester) async {
      setLargeViewport(tester);
      final id = await seedManual(tester, name: '手动集', photoCount: 1);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: id));
      await pumpAndSettleCompat(tester);

      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('导出九宫格拼图'), findsOneWidget);
      expect(find.text('删除精选集'), findsOneWidget);
    });

    testWidgets('点击"编辑"跳转编辑页', (tester) async {
      setLargeViewport(tester);
      final id = await seedManual(tester, name: '手动集', photoCount: 1);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: id));
      await pumpAndSettleCompat(tester);

      await tester.tap(find.text('编辑'));
      await pumpAndSettleCompat(tester);

      expect(find.text('COLLECTION_EDIT'), findsOneWidget);
    });

    testWidgets('点击"导出九宫格拼图"显示 SnackBar', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 1);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: 'auto_recent'));
      await pumpAndSettleCompat(tester);

      await tester.tap(find.text('导出九宫格拼图'));
      await pumpAndSettleCompat(tester);

      expect(find.text('导出功能即将上线'), findsOneWidget);
    });

    testWidgets('渲染导出提示文字', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 1);

      await tester.pumpWidget(
          wrap(ThemeKey.warmWhite, UIStyle.neumorphic, collectionId: 'auto_recent'));
      await pumpAndSettleCompat(tester);

      expect(find.text('导出的拼图可直接分享到社交媒体'), findsOneWidget);
    });

    testWidgets('不存在的 collectionId 显示错误状态', (tester) async {
      setLargeViewport(tester);
      // Forced fix: 预热 provider 使其进入 AsyncError 状态，
      // 避免 AsyncLoading 的 CircularProgressIndicator 导致超时。
      // 使用 tester.runAsync 在 real async zone 中执行 DB 操作
      await tester.runAsync(() async {
        try {
          await container.read(collectionDetailProvider('non_existent').future);
        } catch (_) {
          // 预期抛 StateError，忽略
        }
      });

      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic,
          collectionId: 'non_existent'));
      await pumpAndSettleCompat(tester);

      // collectionDetailProvider 抛 StateError → _ErrorState 显示"重试"
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('8 主题渲染稳定性', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 2);

      for (final theme in ThemeKey.values) {
        container.read(themeKeyProvider.notifier).state = theme;
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic,
            collectionId: 'auto_recent'));
        await pumpAndSettleCompat(tester);
        expect(find.byType(ProfileCollectionDetailPage), findsOneWidget,
            reason: 'theme=$theme');
        expect(find.widgetWithText(LumiraNav, '最近精选'), findsOneWidget,
            reason: 'theme=$theme');
      }
    });

    testWidgets('4 UIStyle 渲染稳定性', (tester) async {
      setLargeViewport(tester);
      await seedAutoRecent(tester, 2);

      for (final style in UIStyle.values) {
        container.read(uiStyleProvider.notifier).state = style;
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style,
            collectionId: 'auto_recent'));
        await pumpAndSettleCompat(tester);
        expect(find.byType(ProfileCollectionDetailPage), findsOneWidget,
            reason: 'style=$style');
        expect(find.widgetWithText(LumiraNav, '最近精选'), findsOneWidget,
            reason: 'style=$style');
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
      ${Tables.colGalleryItemHidden} INTEGER NOT NULL DEFAULT 0,
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
    // Forced fix: 不设置 dataUrl/filePath，避免 Image.network/Image.file
    // 异步加载导致 pumpAndSettle 超时。页面会显示占位图标。
    Tables.colSceneId: sceneId,
    Tables.colGalleryItemIsFavorite: isFavorite ? 1 : 0,
    Tables.colCreatedAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  });
}
