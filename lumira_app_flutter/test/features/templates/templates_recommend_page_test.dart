import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_dao.dart';
import 'package:lumira_app_flutter/features/templates/data/owned_templates_repository.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_recommend_page.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// 为你推荐页 widget 测试（改造后）
///
/// 策略：sqflite 内存 DB 种入模板 / 场景 / 照片数据，
/// override `galleryDaoProvider` 等读取 provider，验证 4 个 section 真实渲染。
///
/// 建表注意（与 DAO fromRow 的真实列名对齐）：
/// - custom_templates 使用 classification_json / tags_json / tag_ids_json /
///   post_process_json / cover_data，且必须有 is_builtin / is_recommended
///   （getBuiltinAndRemote 的 SQL 引用 is_builtin 列）
/// - scenes 必须有 category / created_at / updated_at（fromRow 直接强转）
void main() {
  late Database db;
  FlutterExceptionHandler? originalErrorHandler;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    await _seed(db);
  });

  tearDownAll(() async {
    await db.close();
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

  /// 加大视口，避免折叠区以下文本被 GridView 懒加载截断
  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  /// 等待真实 async（DAO 查询 + owned loader 网络请求）完成并渲染内容
  ///
  /// sqflite_common_ffi 的 DB 查询与 HTTP 请求是真实 async，
  /// 在 FakeAsync 环境下 pump(Duration) 无法让真实 Future 完成，
  /// 必须用 tester.runAsync 让真实 async 操作完成（参考 templates_all_page_test.dart）。
  Future<void> settleOrPump(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      // 内容标志：有照片渲染风格卡 / 冷启动渲染引导文案 / 出错渲染错误视图
      final loaded = find.text('根据你的拍摄风格').evaluate().isNotEmpty ||
          find.text('完成 3 张拍摄后生成你的风格分析').evaluate().isNotEmpty ||
          find.text('推荐数据加载失败').evaluate().isNotEmpty;
      if (loaded) break;
    }
    // FadeUp 延迟动画（0/80/160/240ms）在 pumpAndSettle 中推进完成
    await tester.pumpAndSettle();
  }

  /// 共享种子 DB 的页面包装（含路由，供点卡片跳转使用）
  Widget wrap({List<Override> extraOverrides = const []}) {
    final goRouter = GoRouter(
      initialLocation: '/templates/recommend',
      routes: [
        GoRoute(
          path: '/templates/recommend',
          builder: (_, __) => const TemplatesRecommendPage(),
        ),
        GoRoute(
          path: '/templates',
          builder: (_, __) => const Scaffold(body: Text('templates root')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        galleryDaoProvider.overrideWith((ref) async => GalleryDao(db)),
        templatesDaoProvider.overrideWith((ref) async => TemplatesDao(db)),
        scenesDaoProvider.overrideWith((ref) async => ScenesDao(db)),
        questionnaireDaoProvider
            .overrideWith((ref) async => QuestionnaireDao(db)),
        ...extraOverrides,
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  testWidgets('冷启动（无照片无问卷）：显示引导文案且推荐非空', (tester) async {
    setLargeViewport(tester);
    // 独立内存 DB：只种模板，不种照片（真实 async 打开，需 runAsync）
    // 注意：必须 singleInstance: false——sqflite 按 path 缓存单例，
    // 与共享 DB 同用 ':memory:' 会返回同一实例导致种子数据被共享
    final emptyDb = (await tester.runAsync<Database>(() => openDatabase(
        ':memory:',
        singleInstance: false,
        version: 1,
        onCreate: (db, v) async {
      await _onCreate(db, v);
      await _seedTemplates(db);
    })))!;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        galleryDaoProvider.overrideWith((ref) async => GalleryDao(emptyDb)),
        templatesDaoProvider
            .overrideWith((ref) async => TemplatesDao(emptyDb)),
        scenesDaoProvider.overrideWith((ref) async => ScenesDao(emptyDb)),
        questionnaireDaoProvider
            .overrideWith((ref) async => QuestionnaireDao(emptyDb)),
      ],
      child: const MaterialApp(home: TemplatesRecommendPage()),
    ));
    await settleOrPump(tester);

    expect(find.text('完成 3 张拍摄后生成你的风格分析'), findsOneWidget);
    expect(find.text('猜你喜欢'), findsOneWidget);
    // 冷启动卡片 showMatch=true 渲染 "匹配 0%"
    expect(find.textContaining('匹配'), findsWidgets);
    await tester.runAsync(() => emptyDb.close());
  });

  testWidgets('有照片：风格分析显示真实场景风格', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap());
    await settleOrPump(tester);

    expect(find.text('根据你的拍摄风格'), findsOneWidget);
    expect(find.text('清新'), findsWidgets); // 种子场景风格
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('猜你喜欢排除已用模板且渲染推荐卡片', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap());
    await settleOrPump(tester);

    // 种子：照片用了 tpl-used（近期），推荐中不应出现
    expect(find.text('已用模板'), findsNothing);
    expect(find.text('推荐模板A'), findsWidgets);
  });

  testWidgets('已拥有模板被排除不出现在页面', (tester) async {
    setLargeViewport(tester);
    // override 已拥有集合：tpl-recommend-a 未用过、应进猜你喜欢，
    // 但被"已拥有排除"链路剔除（owned loader 在测试环境必然失败走降级，
    // ownedTemplateIdsProvider 保持此 override 值）
    await tester.pumpWidget(wrap(extraOverrides: [
      ownedTemplateIdsProvider.overrideWith((ref) => const {'tpl-recommend-a'}),
    ]));
    await settleOrPump(tester);

    expect(find.text('推荐模板A'), findsNothing);
    // 页面仍正常渲染：导航标题 + 旧爱回归区（tpl-recall 90 天前用过被召回）
    expect(find.text('为你推荐'), findsOneWidget);
    expect(find.text('旧爱回归'), findsWidgets);
  });

  testWidgets('旧爱回归 section 渲染', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap());
    await settleOrPump(tester);

    // 种子含 90 天前用过 tpl-recall（tag street-tag、style urban），
    // 匹配分 ≈ 0.35*catSim + 0.30*tagSim(1.0) ≈ 0.317 >= 0.3 → 被召回
    expect(find.text('旧爱回归'), findsWidgets);
  });

  testWidgets('换一换：候选不足时展示 toast 且页面不崩溃', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap());
    await settleOrPump(tester);

    // 种子仅 1 个未用过模板 → 候选 < 6 → hasMore=false
    expect(find.text('推荐模板A'), findsWidgets);
    // 点击「换一换」（猜你喜欢 section 的链接，树序第一个）
    await tester.ensureVisible(find.text('换一换').first);
    await tester.pump();
    await tester.tap(find.text('换一换').first);
    // toast 入场（1000ms auto-dismiss）
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已展示全部推荐'), findsOneWidget);
    // 让 auto-dismiss(1000ms) + dismiss 动画 timer(220ms) 都触发，避免 pending Timer
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    // 无崩溃
    expect(find.byType(TemplatesRecommendPage), findsOneWidget);
  });
}

/// 建表（仅测试所需表；列名与 DAO fromRow 读取的真实列名一致）
Future<void> _onCreate(Database db, int version) async {
  // scenes：category / created_at / updated_at 为 SceneRecord.fromRow 强转列，必须有
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL DEFAULT '',
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
  // custom_templates：is_builtin / is_recommended 为 getBuiltinAndRemote 引用列
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
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
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
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.questionnaire} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSubmittedAt} INTEGER,
      ${Tables.colSyncedAt} INTEGER
    )
  ''');
}

/// 种子：模板（含未用/已用/召回）、场景、照片
Future<void> _seed(Database db) async {
  await _seedTemplates(db);
  await _seedPhotos(db);
}

Future<void> _seedTemplates(Database db) async {
  // 模板：分类 food（未用过 → 猜你喜欢候选）
  await db.insert(Tables.customTemplates, {
    Tables.colId: 'tpl-recommend-a',
    Tables.colName: '推荐模板A',
    Tables.colCover: 'https://picsum.photos/seed/a/400/400',
    Tables.colCoverData: '',
    Tables.colCategory: 'food',
    Tables.colTagsJson: jsonEncode(<String>[]),
    Tables.colTagIdsJson: jsonEncode(['food-tag']),
    Tables.colClassificationJson: jsonEncode(
        {'type': 'food', 'style': 'overhead', 'method': 'normal'}),
    Tables.colPostProcessJson: jsonEncode(
        {'saturation': 20, 'temperature': 0, 'contrast': 0, 'brightness': 0}),
    Tables.colPrice: 0,
    Tables.colSource: 'remote',
    Tables.colIsBuiltin: 0,
    Tables.colIsRecommended: 0,
    Tables.colCreatedAt: 100,
    Tables.colUpdatedAt: 200,
  });
  // 模板：分类 portrait（近期用过 → 进入候选池后由引擎 used 排除逻辑剔除）
  await db.insert(Tables.customTemplates, {
    Tables.colId: 'tpl-used',
    Tables.colName: '已用模板',
    Tables.colCover: 'https://picsum.photos/seed/b/400/400',
    Tables.colCoverData: '',
    Tables.colCategory: 'portrait',
    Tables.colTagsJson: jsonEncode(<String>[]),
    Tables.colTagIdsJson: jsonEncode(<String>[]),
    Tables.colClassificationJson: jsonEncode(
        {'type': 'portrait', 'style': 'fresh', 'method': 'normal'}),
    Tables.colPostProcessJson: jsonEncode(<String, dynamic>{}),
    Tables.colPrice: 0,
    Tables.colSource: 'remote',
    Tables.colIsBuiltin: 0,
    Tables.colIsRecommended: 0,
    Tables.colCreatedAt: 100,
    Tables.colUpdatedAt: 200,
  });
  // 模板：分类 street（90 天前用过 → 旧爱回归）
  await db.insert(Tables.customTemplates, {
    Tables.colId: 'tpl-recall',
    Tables.colName: '街拍回忆',
    Tables.colCover: 'https://picsum.photos/seed/c/400/400',
    Tables.colCoverData: '',
    Tables.colCategory: 'street',
    Tables.colTagsJson: jsonEncode(<String>[]),
    Tables.colTagIdsJson: jsonEncode(['street-tag']),
    Tables.colClassificationJson: jsonEncode(
        {'type': 'street', 'style': 'urban', 'method': 'normal'}),
    Tables.colPostProcessJson: jsonEncode(
        {'saturation': 0, 'temperature': 10, 'contrast': 0, 'brightness': 0}),
    Tables.colPrice: 0,
    Tables.colSource: 'remote',
    Tables.colIsBuiltin: 0,
    Tables.colIsRecommended: 0,
    Tables.colCreatedAt: 100,
    Tables.colUpdatedAt: 300,
  });
}

Future<void> _seedPhotos(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const dayMs = 24 * 3600 * 1000;
  // 场景：清新/still-life（category/created_at/updated_at 为 fromRow 强转列，必须提供）
  await db.insert(Tables.scenes, {
    Tables.colId: 'scene-cafe',
    Tables.colName: '咖啡馆',
    Tables.colStyle: '清新',
    Tables.colRelatedCategory: 'still-life',
    Tables.colCategory: 'still-life',
    Tables.colCreator: 'system',
    Tables.colIsFavorite: 0,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
  // 近期照片：用 tpl-used（1 天前）
  await db.insert(Tables.galleryItems, {
    Tables.colId: 'g1',
    Tables.colSceneId: 'scene-cafe',
    Tables.colTemplateId: 'tpl-used',
    Tables.colGalleryItemIsFavorite: 0,
    Tables.colCreatedAt: now - dayMs,
  });
  // 很久前照片：用 tpl-recall（90 天前）
  await db.insert(Tables.galleryItems, {
    Tables.colId: 'g2',
    Tables.colSceneId: 'scene-cafe',
    Tables.colTemplateId: 'tpl-recall',
    Tables.colGalleryItemIsFavorite: 0,
    Tables.colCreatedAt: now - 90 * dayMs,
  });
}
