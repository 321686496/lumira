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
  //
  // Forced fix: 原 50ms 单次延迟在跨主题/风格循环测试中不够稳定——
  // 页面有两次 async 屏障（templatesDaoProvider + _loadData DAO 查询），
  // 累积 GC 压力或 DB 锁等待时容易让"浏览分类"未渲染就断言。
  // 改为轮询方式：每轮 pump+runAsync 让真实 async 推进，检测内容已渲染后退出。
  //
  // 关键问题：点击分类卡片后，_selectedType 改变触发 setState 重建，
  // 但 FutureBuilder 在新 _loadData future 完成前仍会渲染旧数据
  // （旧数据包含全部 7 个 builtin 模板，而非仅 portrait 1 个），
  // 导致 '风光' 出现 3 次（pill + tag + landscape 卡片）而非 2 次。
  // 解决：在内容出现后，再轮询等待数据稳定（widget 数量不再变化）。
  // 本页不含 FloatingTabBar / DailyFlipCard，无 repeat() 动画，pumpAndSettle 安全。
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    // 阶段 1：轮询等待内容渲染（最多 ~1.5s）。
    // 内容出现的标志：找到 '浏览分类' 文本（overview 模式）、
    // '全部模板' LumiraNav（category 模式）、或 '加载失败'（error 状态）。
    for (var i = 0; i < 15; i++) {
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      final loaded = find.text('浏览分类').evaluate().isNotEmpty ||
          find.widgetWithText(LumiraNav, '全部模板').evaluate().isNotEmpty ||
          find.text('加载失败').evaluate().isNotEmpty;
      if (loaded) break;
    }
    // 阶段 2：等待 FutureBuilder 用新 _loadData 结果重建。
    // 点击分类卡片后，FutureBuilder 仍持有旧 future 的快照（snapshot.inState(waiting) + 旧 data），
    // 会先用旧数据渲染 category view，直到新 future 完成。
    // 这里再轮询若干轮，让新 future 完成并触发重建。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
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

    testWidgets('renders style pills in category view', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // v17 后一级分类（type pills）已从分类视图移除，仅展示二三级级联筛选；
      // 人像分类下应渲染 4 个 style pills（来自 template_categories 二级数据）
      expect(find.text('日系'), findsOneWidget);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('胶片'), findsOneWidget);
      expect(find.text('欧美'), findsOneWidget);
      // 未选择 style 时无 method 层
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

    testWidgets('tapping 付费 filter shows only paid templates', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 风光 分类视图（golden_landscape 为免费 builtin；付费模板均为 custom）
      await tester.tap(find.text('风光').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认"全部"：显示免费 builtin golden_landscape
      expect(find.text('金色风光'), findsOneWidget);

      // 点击"付费"筛选
      await tester.tap(find.text('付费'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // builtin 视图无付费模板 → 空态
      expect(find.text('该分类暂无模板'), findsOneWidget);

      // 点击"免费" → 恢复显示免费 builtin 模板
      await tester.tap(find.text('免费').last);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('金色风光'), findsOneWidget);
    });

    testWidgets('tapping 免费 filter shows only free templates', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入 人像 分类视图（cafe_portrait 免费）
      await tester.tap(find.text('人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('咖啡馆人像'), findsOneWidget);

      // 点击"付费"筛选 → 人像分类无付费模板 → 空状态
      await tester.tap(find.text('付费'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('该分类暂无模板'), findsOneWidget);

      // 点击"免费"筛选（筛选行在网格上方，.last 排除卡片上的"免费"角标）→ 恢复显示免费模板
      await tester.tap(find.text('免费').last);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('咖啡馆人像'), findsOneWidget);
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

/// 种入 TemplatesBrowseMockData.allTemplates（10 项）。
/// - 7 builtin (isCustom=false) → is_builtin=1
/// - 3 custom (isCustom=true) → is_builtin=0
/// - 前 3 个 builtin 标记为 recommended（与 BuiltinDataSeeder 行为一致）
Future<void> _seedTemplates(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const categories = <Map<String, String>>[
    {'key': 'portrait', 'name': '人像'},
    {'key': 'landscape', 'name': '风光'},
    {'key': 'food', 'name': '美食'},
    {'key': 'street', 'name': '街拍'},
    {'key': 'night', 'name': '夜景'},
    {'key': 'macro', 'name': '微距'},
    {'key': 'still-life', 'name': '静物'},
  ];
  for (final c in categories) {
    await db.insert(Tables.templateCategories, {
      Tables.colKey: c['key'],
      Tables.colName: c['name'],
      Tables.colParentKey: null,
      Tables.colLevel: 1,
      Tables.colIconUrl: '',
      Tables.colSortOrder: 0,
      Tables.colIsSystem: 1,
      Tables.colIsActive: 1,
      Tables.colUpdatedAt: now,
    });
  }
  // 二级分类（style）：portrait / landscape / still-life
  const styles = <Map<String, String>>[
    {'key': 'japanese', 'name': '日系', 'parent': 'portrait'},
    {'key': 'emotional', 'name': '情绪', 'parent': 'portrait'},
    {'key': 'film', 'name': '胶片', 'parent': 'portrait'},
    {'key': 'european', 'name': '欧美', 'parent': 'portrait'},
    {'key': 'fresh', 'name': '清新', 'parent': 'landscape'},
    {'key': 'grand', 'name': '大气', 'parent': 'landscape'},
    {'key': 'minimal', 'name': '极简', 'parent': 'still-life'},
    {'key': 'flat', 'name': '扁平', 'parent': 'still-life'},
  ];
  for (final s in styles) {
    await db.insert(Tables.templateCategories, {
      Tables.colKey: s['key'],
      Tables.colName: s['name'],
      Tables.colParentKey: s['parent'],
      Tables.colLevel: 2,
      Tables.colIconUrl: '',
      Tables.colSortOrder: 0,
      Tables.colIsSystem: 1,
      Tables.colIsActive: 1,
      Tables.colUpdatedAt: now,
    });
  }
  // 三级分类（method）：japanese style 下
  const methods = <Map<String, String>>[
    {'key': 'selfie', 'name': '自拍', 'parent': 'japanese'},
    {'key': 'other', 'name': '他拍', 'parent': 'japanese'},
    {'key': 'overhead', 'name': '俯拍', 'parent': 'japanese'},
  ];
  for (final m in methods) {
    await db.insert(Tables.templateCategories, {
      Tables.colKey: m['key'],
      Tables.colName: m['name'],
      Tables.colParentKey: m['parent'],
      Tables.colLevel: 3,
      Tables.colIconUrl: '',
      Tables.colSortOrder: 0,
      Tables.colIsSystem: 1,
      Tables.colIsActive: 1,
      Tables.colUpdatedAt: now,
    });
  }
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
      Tables.colSource: t.isCustom ? 'custom' : 'builtin',
      Tables.colCreatedAt: now,
      Tables.colUpdatedAt: now,
    });
  }
}
