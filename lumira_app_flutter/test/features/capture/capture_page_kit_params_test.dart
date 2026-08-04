import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_page.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task B3 — CapturePage 套件参数应用测试
///
/// 验证 CapturePage 接收 sceneId / templateId / kitId 三参数后：
/// 1. currentTemplateIdProvider 被设置为 kit.templateId
/// 2. activeScenePresetIdProvider 被设置为 kit.sceneId
///
/// 测试通过 override DAO providers 注入内存 DB，使用 tester.runAsync 让
/// sqflite_ffi 的真实异步 DB 操作在 FakeAsync 之外完成。
late Database _testDb;
CompositionKitsDao? _kitsDao;
TemplatesDao? _templatesDao;
ScenesDao? _scenesDao;

Future<void> _onCreate(Database db, int version) async {
  // Bug 2 fix: include is_builtin and is_recommended columns
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
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Bug 4 fix: DB creation in setUp (outside FakeAsync) so sqflite_ffi
  // real async operations don't get stuck under FakeAsync.
  setUp(() async {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final s = details.exception.toString();
      if (s.contains('NetworkImageLoadException') ||
          s.contains('MissingPluginException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    _kitsDao = CompositionKitsDao(_testDb);
    _templatesDao = TemplatesDao(_testDb);
    _scenesDao = ScenesDao(_testDb);
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  testWidgets('CapturePage 接收 scene/template/kit 三参数后应用到 CaptureState',
      (tester) async {
    // Bug 4 fix: use tester.runAsync for DB seed operations so sqflite_ffi
    // real async DB writes complete outside FakeAsync.
    await tester.runAsync(() async {
      // Bug 1 fix: include isBuiltin and isRecommended (required fields)
      await _templatesDao!.upsert(TemplateRecord(
        id: 'tpl_test_001',
        name: '柔光人像',
        author: 'tester',
        version: '1.0.0',
        category: 'portrait',
        classification: {},
        tags: [],
        tagIds: [],
        price: 0,
        cover: '',
        description: '',
        referenceSource: '',
        composition: {'overlayType': 'rule_of_thirds'},
        pose: {},
        camera: {
          'exposureCompensation': 0.5,
          'iso': 200,
          'shutterSpeed': '1/200',
        },
        sceneGuide: {},
        postProcess: {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isBuiltin: false,
        isRecommended: false,
      ));

      await _kitsDao!.insert(CompositionKit(
        id: 'kit_test_001',
        name: '咖啡馆+柔光人像',
        sceneId: 'scene_cafe',
        templateId: 'tpl_test_001',
        cameraOverrides: {'exposureCompensation': 0.7},
        note: '',
        coverUrl: null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    // Bug 3 fix: override the 3 DAO providers with test DAOs so the
    // production code's _applyRouteParamsToState() reads from the
    // in-memory test DB instead of the real database.
    final container = ProviderContainer(overrides: [
      compositionKitsDaoProvider.overrideWith((ref) async => _kitsDao!),
      templatesDaoProvider.overrideWith((ref) async => _templatesDao!),
      scenesDaoProvider.overrideWith((ref) async => _scenesDao!),
    ]);
    addTearDown(container.dispose);

    // Mock permission_handler method channel so Permission.camera.request()
    // does not throw MissingPluginException under tester.runAsync.
    // Returns denied (0) so the permission guide UI is shown (no real
    // CameraPreview is built). The CaptureState providers we assert on
    // are set synchronously before _requestCameraPermission() completes.
    const permChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
        .setMockMethodCallHandler(permChannel, (MethodCall call) async {
      if (call.method == 'requestPermissions') {
        final permissions = call.arguments as List;
        // 0 = PermissionStatus.denied for all requested permissions
        return {for (final p in permissions) p: 0};
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance!
        .defaultBinaryMessenger
        .setMockMethodCallHandler(permChannel, null));

    // Use GoRouter so GoRouterState.of(context) works in CapturePage.initState
    // (go_router 6.5.x throws GoError if there is no Page-based modal route
    // above the current context). The route builder reads the same query
    // params as the production router.dart.
    final router = GoRouter(
      initialLocation:
          '/capture?templateId=tpl_test_001&scene=scene_cafe&kitId=kit_test_001',
      routes: [
        GoRoute(
          path: '/capture',
          name: 'capture',
          builder: (_, state) {
            final templateId = state.queryParams['templateId'];
            final sceneId = state.queryParams['scene'];
            final kitId = state.queryParams['kitId'];
            return CapturePage(
              templateId: templateId,
              sceneId: sceneId,
              kitId: kitId,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Bug 4 fix: use runAsync for pump so addPostFrameCallback +
    // _applyRouteParamsToState (which awaits compositionKitsDaoProvider.future)
    // can complete their real async DB operations.
    await tester.runAsync(() async {
      await tester.pump();
      // Give time for addPostFrameCallback + _applyRouteParamsToState to
      // read the kit from the in-memory DB and update CaptureState.
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify CaptureState was updated:
    // - currentTemplateIdProvider set to kit.templateId ('tpl_test_001')
    // - activeScenePresetIdProvider set to kit.sceneId ('scene_cafe')
    expect(container.read(CaptureState.currentTemplateIdProvider),
        'tpl_test_001');
    expect(container.read(CaptureState.activeScenePresetIdProvider),
        'scene_cafe');
  });
}
