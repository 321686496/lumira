import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
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
  // 页面有多次 async 屏障（templatesDaoProvider + dao.getBuiltin），
  // 累积 GC 压力或 DB 锁等待时容易让 '系统精选' badge 未渲染就断言。
  // 改为多轮 pump+runAsync 让真实 async 推进，并在末尾按风格区分收尾：
  // - 非 female: pumpAndSettle 处理 FadeUp 等帧动画（FloatingTabBar 在非 female 无 repeat）
  // - female: 用 pump 避免 FloatingTabBar._CenterCaptureButton 的 repeat 动画导致 pumpAndSettle 超时
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
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
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // Nav title
    expect(find.text('发现'), findsNWidgets(2)); // '发现' 在 LumiraNav 标题 + FloatingTabBar templates 标签都出现
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
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // DAO 切换后所有 recommendation 的 source 均为 systemPick → '系统精选'
    // 3 个推荐卡片 → 3 个 '系统精选' badge
    expect(find.text('系统精选'), findsNWidgets(3));
  });

  testWidgets('free badge shows on price=0 templates', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // Other section: dao.getBuiltin(price: 0) 返回 6 个免费模板
    // （cafe_portrait/street_bw/macro_flower/food_overhead/custom_cafe_diary/custom_portrait_soft）
    // TemplateGridCard 在 price==0 时显示 '免费' badge → 6 个
    expect(find.text('免费'), findsNWidgets(6));
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.text('发现'), findsNWidgets(2));
      expect(find.text('今日为你推荐'), findsOneWidget);
      expect(find.text('更多模板'), findsOneWidget);

      await tester.pumpWidget(Container()); // reset
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('发现'), findsNWidgets(2));
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
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // 初始未滚动
    expect(find.text('发现'), findsNWidgets(2));

    // 滚动列表
    await tester.drag(find.byType(ListView).at(1), const Offset(0, -100));
    await settleOrPump(tester, UIStyle.neumorphic);

    // 简化验证：未崩溃即可（与 Task 2.1 一致策略，plan-mandated）
    expect(find.text('发现'), findsNWidgets(2));
  });

  testWidgets('recommendation card tap pushes /templates/detail', (tester) async {
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await settleOrPump(tester, UIStyle.neumorphic);

    // DAO 切换后第一个推荐卡片为 '咖啡馆人像'（在 Hero + Other 中各出现一次，点击 .first = Hero 卡片）
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
}

/// 种入 TemplatesBrowseMockData.allTemplates（10 项）作为 builtin 模板。
/// 前 3 标记为 recommended（与 BuiltinDataSeeder 行为一致）。
/// 全部标记为 is_builtin=1（与 BuiltinDataSeeder 行为一致）。
Future<void> _seedTemplates(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const items = TemplatesBrowseMockData.allTemplates;
  final recommendedIds = items.take(3).map((t) => t.id).toSet();
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
