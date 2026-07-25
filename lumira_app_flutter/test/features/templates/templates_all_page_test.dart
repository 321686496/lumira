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
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_browse_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_all_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8A + Task A4 — TemplatesAllPage 测试
///
/// Task A4 适配：页面从 mock `TemplatesBrowseMockData.allTemplates` 切换到
/// `templatesDaoProvider` + `dao.getBuiltin()` / `dao.getCustomOnly()`。
/// 默认显示分类概览（7 个大卡片），点击分类后才显示 Hero + Filter + Grid。
/// 测试通过 override `templatesDaoProvider` 注入内存 DB，
/// 并使用 `TemplatesBrowseMockData.allTemplates` 种入种子数据
/// （7 builtin + 3 custom，前 3 builtin 标记为 recommended，与 `BuiltinDataSeeder` 行为一致）。
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

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String? scene,
    String? category,
  }) {
    final goRouter = GoRouter(
      initialLocation: '/templates/all',
      routes: [
        GoRoute(
          path: '/templates/all',
          name: 'templatesAll',
          builder: (_, __) =>
              TemplatesAllPage(scene: scene, category: category),
        ),
        GoRoute(
          path: RouteNames.templatesDetail,
          name: 'templatesDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('DETAIL_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.templatesEditor,
          name: 'templatesEditor',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('EDITOR_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.templates,
          name: 'templates',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATES_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        templatesDaoProvider.overrideWith((ref) async => TemplatesDao(db)),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  // 使用 pump + runAsync：sqflite_common_ffi 的 DB 查询是真实 async 操作，
  // 在 FakeAsync 环境下 pump(Duration) 无法让真实 Future 完成。
  // 必须用 tester.runAsync 让真实 async 操作（DAO 查询）完成。
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 分类概览（默认视图）
  // ============================================================
  group('TemplatesAllPage — category overview (default)', () {
    testWidgets('renders LumiraNav with title 模板库', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '模板库'), findsOneWidget);
    });

    testWidgets('renders overview summary with template count', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 摘要文本：'$allCount 个模板等你探索 · 已解锁 $unlockedCount 个'
      // allCount=10 (7 builtin + 3 custom), unlockedCount=6 (price=0)
      expect(find.textContaining('10 个模板等你探索'), findsOneWidget);
      expect(find.textContaining('已解锁 6 个'), findsOneWidget);
      expect(find.text('浏览分类'), findsOneWidget);
    });

    testWidgets('renders 7 category cards', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 7 个一级分类卡片名称
      expect(find.text('人像'), findsOneWidget);
      expect(find.text('风光'), findsOneWidget);
      expect(find.text('美食'), findsOneWidget);
      expect(find.text('街拍'), findsOneWidget);
      expect(find.text('夜景'), findsOneWidget);
      expect(find.text('微距'), findsOneWidget);
      expect(find.text('静物'), findsOneWidget);
    });

    testWidgets('renders category card counts from DAO', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 分类计数（基于种子数据）：
      // portrait=2 (cafe_portrait + custom_portrait_soft)
      // landscape=2 (golden_landscape + custom_golden_landscape)
      // still-life=2 (still_life_warm + custom_cafe_diary)
      // food=1, street=1, night=1, macro=1
      expect(find.text('2 个模板'), findsNWidgets(3));
      expect(find.text('1 个模板'), findsNWidgets(4));
    });

    testWidgets('renders nav back icon', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 分类视图（点击分类卡片后）
  // ============================================================
  group('TemplatesAllPage — category view (after tap)', () {
    testWidgets('tapping 人像 category shows hero + filter + grid',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认分类概览
      expect(find.text('浏览分类'), findsOneWidget);

      // 点击 '人像' category card（在概览中仅出现 1 次）
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换到 category view：LumiraNav 标题变为 '全部模板'
      expect(find.widgetWithText(LumiraNav, '全部模板'), findsOneWidget);

      // HeroCard: '模板库' + '10 个模板等你探索' + '已解锁 6 个'（独立文本）
      expect(find.text('模板库'), findsOneWidget);
      expect(find.text('10 个模板等你探索'), findsOneWidget);
      expect(find.text('已解锁 6 个'), findsOneWidget);

      // FilterSection: STYLE_MAP['portrait'] = [日系, 情绪, 胶片, 欧美]
      expect(find.text('日系'), findsOneWidget);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('胶片'), findsOneWidget);
      expect(find.text('欧美'), findsOneWidget);

      // TemplateGrid: builtin portraits = [咖啡馆人像]（_showCustom=false）
      expect(find.text('咖啡馆人像'), findsOneWidget);
    });

    testWidgets('renders 7 type pills in category view', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Forced fix: '人像'/'风光'/'美食'/'街拍'/'夜景' 在 _PillRow type pill + _TagChip 占位 + _TplCard category label 中各出现 3 次
      // '微距'/'静物' 不在 _TagChip 中，仅 2 次（type pill + card label；当前 portrait 视图无 macro/still-life 卡片，仅 1 次 = type pill）
      // 注：portrait 视图中 _TplCard category label = '人像'，故 '微距'/'静物' 仅 type pill 1 次
      expect(find.text('人像'), findsNWidgets(3));
      expect(find.text('风光'), findsNWidgets(2)); // type pill + tag chip
      expect(find.text('美食'), findsNWidgets(2)); // type pill + tag chip
      expect(find.text('街拍'), findsNWidgets(2)); // type pill + tag chip
      expect(find.text('夜景'), findsNWidgets(2)); // type pill + tag chip
      expect(find.text('微距'), findsOneWidget); // type pill only
      expect(find.text('静物'), findsOneWidget); // type pill only
    });

    testWidgets('tapping type pill switches category and clears style/method',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选 'japanese' style → METHOD_MAP['japanese'] = [自拍, 他拍, 俯拍]
      await tester.tap(find.text('日系'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('自拍'), findsOneWidget);

      // 选 '自拍' method（选中后 method pill 仍渲染）
      await tester.tap(find.text('自拍'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('自拍'), findsOneWidget);

      // 切换 type 到 '风光' → _onLayerSelect(0, 'landscape') 清空 style + method
      // '风光' 出现 2 次（type pill + tag chip），用 .first 选择 type pill
      await tester.tap(find.text('风光').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // STYLE_MAP['landscape'] = [清新, 大气]，无 method 层；'自拍' 应不再渲染
      expect(find.text('清新'), findsOneWidget);
      expect(find.text('大气'), findsOneWidget);
      expect(find.text('自拍'), findsNothing);
    });

    testWidgets('tapping style pill shows METHOD_MAP options', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选 japanese style
      await tester.tap(find.text('日系'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // METHOD_MAP['japanese'] = 3 个 method：自拍 / 他拍 / 俯拍
      expect(find.text('自拍'), findsOneWidget);
      expect(find.text('他拍'), findsOneWidget);
      expect(find.text('俯拍'), findsOneWidget);
    });

    testWidgets('tapping 我的 toggle filters to custom templates only',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图，默认显示 builtin '咖啡馆人像'
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('咖啡馆人像'), findsOneWidget);

      // 点击 '我的' toggle
      final customToggle = find.text('我的');
      expect(customToggle, findsOneWidget);
      await tester.tap(customToggle);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换后应显示 custom portraits = [柔光人像自创]
      expect(find.text('柔光人像自创'), findsOneWidget);
    });

    testWidgets('renders action row when 我的 is active', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认不显示 ActionRow
      expect(find.text('导入模板'), findsNothing);
      expect(find.text('新建模板'), findsNothing);

      // 点击 '我的' toggle
      await tester.tap(find.text('我的'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换后应显示 ActionRow
      expect(find.text('导入模板'), findsOneWidget);
      expect(find.text('新建模板'), findsOneWidget);
    });

    testWidgets('renders empty state when no templates match filter',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 微距 分类视图（builtin macro = macro_flower，无 custom macro）
      await tester.tap(find.text('微距'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('微距花卉'), findsOneWidget);

      // 切换到 '我的'（无自定义 macro 模板）
      await tester.tap(find.text('我的'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('该分类暂无模板'), findsOneWidget);
    });

    testWidgets('tapping template card navigates to /templates/detail page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '咖啡馆人像' card
      await tester.tap(find.text('咖啡馆人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /templates/detail
      expect(find.text('DETAIL_PAGE'), findsOneWidget);
    });

    testWidgets('tapping 新建模板 button pushes /templates/editor',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先切到 '我的'
      await tester.tap(find.text('我的'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '新建模板'
      await tester.tap(find.text('新建模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /templates/editor
      expect(find.text('EDITOR_PAGE'), findsOneWidget);
    });

    testWidgets('scene parameter sets initial selectedType', (tester) async {
      setLargeViewport(tester);
      // scene='cafe' → sceneToCategoryMap['cafe']='still-life'
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        scene: 'cafe',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 'still-life' type 应已选中 → 直接进入 category view
      // STYLE_MAP['still-life'] = [极简, 扁平]
      expect(find.text('极简'), findsOneWidget);
      expect(find.text('扁平'), findsOneWidget);

      // TemplateGrid: builtin still-life = [静物暖光]
      expect(find.text('静物暖光'), findsOneWidget);
    });

    testWidgets('renders LumiraNav with title 全部模板 in category view',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '全部模板'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 跨主题 / 跨风格 smoke test
  // ============================================================
  group('TemplatesAllPage — smoke tests', () {
    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(
          themeKey: theme,
          uiStyle: UIStyle.neumorphic,
        ));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('浏览分类'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('人像'), findsOneWidget, reason: 'theme=$theme');

        await tester.pumpWidget(Container()); // reset
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: style,
        ));
        await settleOrPump(tester, style);
        expect(find.text('浏览分类'), findsOneWidget, reason: 'style=$style');
        expect(find.text('人像'), findsOneWidget, reason: 'style=$style');

        await tester.pumpWidget(Container()); // reset
      }
    });
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

/// 种入 TemplatesBrowseMockData.allTemplates（10 项）。
/// - 7 builtin (isCustom=false) → is_builtin=1
/// - 3 custom (isCustom=true) → is_builtin=0
/// - 前 3 个 builtin 标记为 recommended（与 BuiltinDataSeeder 行为一致）
Future<void> _seedTemplates(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const items = TemplatesBrowseMockData.allTemplates;
  // 前 3 个 builtin 标记为 recommended
  final builtinItems = items.where((t) => !t.isCustom).toList();
  final recommendedIds = builtinItems.take(3).map((t) => t.id).toSet();
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
      // Key difference from templates_page_test.dart:
      // use isCustom flag to split builtin vs custom (page uses getCustomOnly)
      Tables.colIsBuiltin: t.isCustom ? 0 : 1,
      Tables.colIsRecommended: recommendedIds.contains(t.id) ? 1 : 0,
      Tables.colCreatedAt: now,
      Tables.colUpdatedAt: now,
    });
  }
}
