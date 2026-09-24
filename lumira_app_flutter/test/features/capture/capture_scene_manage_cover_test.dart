import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/seeders/builtin_data_seeder.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_scene_manage_page.dart';
import 'package:lumira_app_flutter/shared/widgets/images/lumira_image.dart';

import '../../helpers/test_http_overrides.dart';

/// 场景管理页封面取源 —— 回归测试
///
/// 背景：场景管理页封面此前直接取 exampleImages 首图，内置场景会落到
/// picsum 网络图（海外 + 302 跳转，冷启动要等好几秒）；App 内其实已打包同名
/// 本地封面 assets/images/scenes/scene_<id>.jpg。
/// 此处锁定：内置场景行必须走本地打包资产，而不是网络 URL。
void main() {
  FlutterExceptionHandler? originalErrorHandler;
  late Database sharedDb;
  ProviderContainer? seedContainer;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((call) async {
      if (call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.createTempSync('lumira_test').path;
      }
      return null;
    });
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbDir =
        Directory.systemTemp.createTempSync('lumira_manage_cover_test').path;
    await databaseFactory.setDatabasesPath(dbDir);
    final dbPath = p.join(dbDir, 'lumira.db');
    try {
      await databaseFactory.deleteDatabase(dbPath);
    } catch (_) {
      // 文件可能不存在，忽略
    }
    seedContainer = ProviderContainer();
    sharedDb = await seedContainer!.read(databaseProvider.future);
    await BuiltinDataSeeder.seedAll(sharedDb);
    // 收藏一个内置场景，使「我的收藏」Tab 有行可渲染
    await ScenesDao(sharedDb).setFavorite('cafe-window', true);
  });

  tearDownAll(() {
    seedContainer?.dispose();
  });

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap() {
    final goRouter = GoRouter(
      initialLocation: RouteNames.captureSceneManage,
      routes: [
        GoRoute(
          path: RouteNames.captureSceneManage,
          builder: (context, state) => CaptureSceneManagePage(
            initialTab: state.queryParams[RouteNames.paramTab],
          ),
        ),
        GoRoute(
          path: RouteNames.captureSceneDetail,
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: RouteNames.scenes,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        databaseProvider.overrideWith((ref) async => sharedDb),
        scenesDaoProvider.overrideWith((ref) async => ScenesDao(sharedDb)),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  testWidgets('我的收藏：内置场景封面走本地打包资产而非 picsum 网络图',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap());
    // DB 读取是真实异步 I/O，widget 测试默认的 FakeAsync 不会推进它；
    // 用 runAsync 让真实事件循环跑完，再 pump 出结果帧。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('咖啡馆'), findsOneWidget);

    // 行封面必须是 LumiraImage（统一处理 asset / data / http + 降采样）
    expect(find.byType(LumiraImage), findsWidgets);

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty, reason: '封面行应渲染出 Image');
    // LumiraImage 的降采样会给 provider 套一层 ResizeImage，需要拆出内层判断来源
    final provider = images.first.image;
    final inner = provider is ResizeImage ? provider.imageProvider : provider;
    expect(inner, isA<AssetImage>());
    expect(
      (inner as AssetImage).assetName,
      'assets/images/scenes/scene_cafe-window.jpg',
    );
  });
}