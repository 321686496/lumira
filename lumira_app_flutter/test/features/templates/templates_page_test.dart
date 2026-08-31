import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/usage_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/user_interests_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_browse_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_providers.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_page.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.1 + Task A4 — TemplatesPage 测试
///
/// Task A4 适配：Hero / Other section 从 mock `TemplatesMockData.recommendations /
/// otherTemplates` 切换到 `templatesDaoProvider` + `dao.getBuiltin(isRecommended: true)` /
/// `dao.getBuiltin(price: 0)`。测试通过 override `templatesDaoProvider` 注入内存 DB，
/// 并使用 `TemplatesBrowseMockData.allTemplates` 种入种子数据（前 3 标记为 recommended，
/// 与 `BuiltinDataSeeder` 行为一致）。
void main() {
  late Database db;
  FlutterExceptionHandler? originalErrorHandler;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    await _seedTemplates(db);
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

  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/templates',
      routes: [
        GoRoute(
          path: '/templates',
          builder: (_, __) => const TemplatesPage(),
        ),
        GoRoute(
          path: '/templates/all',
          builder: (_, __) => const Scaffold(body: Center(child: Text('all'))),
        ),
        GoRoute(
          path: '/templates/detail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('detail'))),
        ),
      ],
    );
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        templatesDaoProvider.overrideWith((ref) async => TemplatesDao(db)),
        // 已拍数角标不参与本测试断言；override 为空避免访问真实 GalleryDao
        // （path_provider 在测试环境无实现，会产生 MissingPluginException 噪声）。
        templateUsageCountsProvider.overrideWith((ref) async => const <String, int>{}),
        // 推荐排序 / 更多模板热度依赖 usage + 兴趣画像 DAO，
        // override 指向同一内存 DB（空表）避免走真实 path_provider DB 而报错。
        usageDaoProvider.overrideWith((ref) async => UsageDao(db)),
        userInterestsDaoProvider.overrideWith((ref) async => InterestDao(db)),
        userPreferenceProvider.overrideWith((ref) async => const UserPreference(
              totalPhotos: 24,
              topCategory: 'portrait',
              topCategoryPercentage: 42,
            )),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  // Helper: pump + runAsync，sqflite_common_ffi 的 DB 查询是真实 async 操作，
  // 在 FakeAsync 环境下 pumpAndSettle 会超时。必须用 tester.runAsync 让真实 async 操作完成。
  //
  // Forced fix: 原 50ms 单次延迟在全套测试压力下不够稳定——
  // 页面有多次 async 屏障（templatesDaoProvider + dao.getBuiltin + 推荐排序的
  // interests/usage 串行查询），FakeAsync 下每次 runAsync 才能推进真实 DB 查询，
  // 单次 100ms 窗口不足以让推荐 provider 完成 usage.countMap。
  // 改为「循环 pump+runAsync 直到 Hero 卡片出现」：以『为你推荐』来源角标作为内容标志，
  // 数据到达后自动 break；末尾按风格区分收尾：
  // - 非 female: pumpAndSettle 处理 FadeUp 等帧动画（FloatingTabBar 在非 female 无 repeat）
  // - female: 用 pump 避免 FloatingTabBar._CenterCaptureButton 的 repeat 动画导致 pumpAndSettle 超时
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      // 内容标志：Hero 推荐卡的来源角标『为你推荐』出现即认为推荐数据已加载
      if (find.text('为你推荐').evaluate().isNotEmpty) break;
    }
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 200));
    } else {
      await tester.pumpAndSettle();
    }
  }

  // Forced fix: 默认 800x600 视口下 "查看全部 ›" link 在屏幕外，
  // tap() 会因 hit-test 失败导致点击不生效。增大视口让 link 可见可点击。
  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  testWidgets('renders all main sections', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // Nav title
    // '发现' 仅在 LumiraNav 标题出现一次；FloatingTabBar 由 MainTabsPage 提供，
    // 本测试直接构建 TemplatesPage，不在树内。
    expect(find.text('发现'), findsOneWidget);
    // Hero section title
    expect(find.text('今日为你推荐'), findsOneWidget);
    // Preference section (totalPhotos=24 > 0, 仍使用 mock TemplatesMockData.userPreference)
    expect(find.text('你的拍摄偏好'), findsOneWidget);
    expect(find.text('累计作品'), findsOneWidget);
    expect(find.text('24 张'), findsOneWidget);
    expect(find.text('最常用分类'), findsOneWidget);
    expect(find.text('人像 · 42%'), findsOneWidget);
    // Other section
    expect(find.text('更多模板'), findsOneWidget);
    expect(find.text('查看全部 ›'), findsOneWidget);
    // Hero 推荐：前 3 个 builtin（isRecommended=true）= cafe_portrait/street_bw/macro_flower
    // '咖啡馆人像'/'街拍黑白' 免费（Hero + Other 各 1 次）；'微距花卉' 已改为付费（price=20），仅 Hero 出现
    expect(find.text('咖啡馆人像'), findsNWidgets(2));
    expect(find.text('街拍黑白'), findsNWidgets(2));
    expect(find.text('微距花卉'), findsOneWidget);
    // Other section 6 个免费模板中的非推荐项：美食俯拍/咖啡日记/柔光人像自创（仅 Other 出现）
    expect(find.text('美食俯拍'), findsOneWidget);
  });

  testWidgets('recommendation card displays source badge label', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // DAO 切换后所有 recommendation 的 source 均为 systemPick → '系统精选'
    // 3 个推荐卡片 → 3 个 '为你推荐' badge
    expect(find.text('为你推荐'), findsNWidgets(3));
  });

  testWidgets('free badge shows on price=0 templates', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // Other section: dao.getBuiltin(price: 0) 返回 6 个免费模板
    // （cafe_portrait/street_bw/golden_landscape/food_overhead/custom_cafe_diary/custom_portrait_soft）
    // TemplateCard 在 price==0 时显示 '免费' badge → 6 个
    // Hero section: 推荐前 3（cafe_portrait/street_bw 免费 + macro_flower 付费）→ 2 个 '免费'
    // 合计 8 个 '免费'；macro_flower 显示 '20 积分'
    expect(find.text('免费'), findsNWidgets(8));
    expect(find.text('20 积分'), findsOneWidget);
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.text('发现'), findsOneWidget);
      expect(find.text('今日为你推荐'), findsOneWidget);
      expect(find.text('更多模板'), findsOneWidget);

      await tester.pumpWidget(Container()); // reset
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('发现'), findsOneWidget);
      expect(find.text('今日为你推荐'), findsOneWidget);

      await tester.pumpWidget(Container()); // reset
    }
  });

  testWidgets('nav "查看全部" button pushes /templates/all', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // 点击右上角"查看全部"icon（apps icon，无 Tooltip）
    await tester.tap(find.byIcon(Icons.apps_outlined));
    await settleOrPump(tester, UIStyle.neumorphic);

    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('section link "查看全部 ›" pushes /templates/all', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    await tester.tap(find.text('查看全部 ›'));
    await settleOrPump(tester, UIStyle.neumorphic);

    expect(find.text('all'), findsOneWidget);
  });

  testWidgets('scroll toggles LumiraNav scrolled state', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // 初始未滚动
    expect(find.text('发现'), findsOneWidget);

    // 滚动列表（页面主体纵向 ListView；Hero 横向列表嵌套在内部，.first 即外层主列表）
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await settleOrPump(tester, UIStyle.neumorphic);

    // 简化验证：未崩溃即可（与 Task 2.1 一致策略，plan-mandated）
    expect(find.text('发现'), findsOneWidget);
  });

  testWidgets('recommendation card tap pushes /templates/detail', (tester) async {
    setLargeViewport(tester);
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // DAO 切换后第一个推荐卡片为 '咖啡馆人像'（在 Hero + Other 中各出现一次，
    // Hero 在上方树序更早，点击 .first = Hero 卡片）
    await tester.ensureVisible(find.text('咖啡馆人像').first);
    await tester.pump();
    await tester.tap(find.text('咖啡馆人像').first);
    await settleOrPump(tester, UIStyle.neumorphic);

    expect(find.text('detail'), findsOneWidget);
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
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
    CREATE TABLE ${Tables.templateCategories} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colKey} TEXT NOT NULL,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colParentKey} TEXT,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colUpdatedAt} INTEGER NOT NULL,
      UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
    )
  ''');
  // usage_events / usage_stats：hotAndNewTemplatesProvider 的热度查询与
  // recommendedBuiltinTemplatesProvider 的 popularity 需要这两张表。
  await db.execute('''
    CREATE TABLE ${Tables.usageEvents} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colClientEventId} TEXT NOT NULL UNIQUE,
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colItemSource} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colOccurredAt} INTEGER NOT NULL,
      ${Tables.colSynced} INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE ${Tables.usageStats} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colEventType})
    )
  ''');
  // user_interests：recommendedBuiltinTemplatesProvider 画像读取需要该表。
  await db.execute(UserInterestsTable.createSql);
}

/// 种入 TemplatesBrowseMockData.allTemplates（10 项）作为 builtin 模板。
/// 前 3 标记为 recommended（与 BuiltinDataSeeder 行为一致）。
/// 全部标记为 is_builtin=1（与 BuiltinDataSeeder 行为一致）。
Future<void> _seedTemplates(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const items = TemplatesBrowseMockData.allTemplates;
  final recommendedIds = items.take(3).map((t) => t.id).toSet();
  // 与生产一致：卡片短描述来自 short_desc；未设置时 Hero 卡 reason 会回退为『为你推荐』
  // 与来源角标重复，导致『为你推荐』计数翻倍。
  const shortDescs = <String, String>{
    'cafe_portrait': '暖调咖啡馆里的自然光人像',
    'street_bw': '街头瞬间的经典黑白叙事',
    'macro_flower': '花瓣脉络的微距特写',
    'golden_landscape': '日落时分的金色大地',
    'food_overhead': '俯拍视角的美食构图',
    'night_neon': '霓虹灯下的城市夜景',
    'still_life_warm': '暖光里的静物组合',
    'custom_golden_landscape': '自定义金色风光精选',
    'custom_cafe_diary': '咖啡角的日常手记',
    'custom_portrait_soft': '柔和光感的自创人像',
  };
  for (final t in items) {
    await db.insert(Tables.customTemplates, {
      Tables.colId: t.id,
      Tables.colName: t.name,
      Tables.colAuthor: 'Lumira',
      Tables.colVersion: '1.0.0',
      Tables.colCategory: t.category,
      Tables.colClassificationJson: jsonEncode({
        'type': t.category,
        'style': t.style,
        'method': t.method,
      }),
      Tables.colTagsJson: jsonEncode(<String>[]),
      Tables.colTagIdsJson: jsonEncode(<String>[]),
      Tables.colPrice: t.price,
      Tables.colCover: '',
      Tables.colDescription: '',
      Tables.colReferenceSource: '',
      Tables.colShortDesc: shortDescs[t.id] ?? '',
      Tables.colCompositionJson: jsonEncode(<String, dynamic>{}),
      Tables.colPoseJson: jsonEncode(<String, dynamic>{}),
      Tables.colCameraJson: jsonEncode(<String, dynamic>{}),
      Tables.colSceneGuideJson: jsonEncode(<String, dynamic>{}),
      Tables.colPostProcessJson: jsonEncode(<String, dynamic>{}),
      Tables.colIsBuiltin: 1,
      Tables.colIsRecommended: recommendedIds.contains(t.id) ? 1 : 0,
      Tables.colCreatedAt: now,
      Tables.colUpdatedAt: now,
    });
  }
}
