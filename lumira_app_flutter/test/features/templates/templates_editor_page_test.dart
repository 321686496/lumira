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
import 'package:lumira_app_flutter/features/templates/pages/templates_editor_page.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/form/lumira_dropdown.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/form/lumira_slider.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

/// Task 2.8C + Task A5 — TemplatesEditorPage 测试
///
/// 覆盖 brief 第 5.2 节 ≥25 项断言 + cross-theme/cross-style smoke test。
/// 10 个分类（35 tests）：
/// 1. 路由参数加载（4）
/// 2. Step 1 模板信息（5）
/// 3. Step 2 构图叠图（4）
/// 4. Step 3 姿势剪影（5）
/// 5. Step 4 相机参数（4）
/// 6. Step 5 场景指南（3）
/// 7. Step 6 后期参数（3）
/// 8. Footer 操作（5）
/// 9. 自动保存（1）
/// 10. Cross-theme/cross-style smoke（1，12 组合）
///
/// Task A5 适配：`_onSave` 现通过 `templatesDaoProvider` 调用 DAO 持久化，
/// 测试通过 sqflite_ffi + 共享内存 DB 覆盖 `templatesDaoProvider`，让
/// "tapping 保存 with valid name" 测试在不依赖文件系统的情况下完成 upsert。

/// 编辑器顶部 6 个 Tab 标题（Task 5 顶部 Tab 布局）。
const List<String> _editorAllTabs = [
  '基本信息', '封面与剪影', '构图', '相机参数', '场景引导', '后期处理',
];

void main() {
  FlutterExceptionHandler? originalErrorHandler;
  // 共享 DB 实例：在 setUpAll 中创建，所有测试通过 override 复用。
  // `_onSave` 测试会写入数据，每个测试前清空表保证隔离。
  late Database sharedDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    sharedDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    await _seedCategories(sharedDb);
  });

  tearDownAll(() async {
    await sharedDb.close();
  });

  setUp(() async {
    // 清空 custom_templates 表，保证 _onSave 测试间状态隔离
    await sharedDb.delete(Tables.customTemplates, where: '1=1');
    HttpOverrides.global = _TestHttpOverrides();
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
    String initialLocation = '/templates/editor',
    List<String>? capturedPreviewUrls,
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/templates/editor',
          name: 'templatesEditor',
          builder: (context, state) {
            final templateId = state.queryParams[RouteNames.paramTemplateId];
            final draftId = state.queryParams['draftId'];
            return TemplatesEditorPage(
              templateId: templateId,
              draftId: draftId,
            );
          },
        ),
        GoRoute(
          path: RouteNames.templates,
          name: 'templates',
          builder: (_, __) => const _StubPage(text: 'TEMPLATES_PAGE'),
        ),
        GoRoute(
          path: RouteNames.templatesDrafts,
          name: 'templatesDrafts',
          builder: (_, __) => const _StubPage(text: 'DRAFTS_PAGE'),
        ),
        GoRoute(
          path: RouteNames.capturePreviewTemplate,
          name: 'capturePreviewTemplate',
          builder: (context, state) {
            // 捕获 preview 路由 URL（含 draftId 查询参数），用于 Finding #3 验证 _currentDraftId
            if (capturedPreviewUrls != null) {
              capturedPreviewUrls.add(state.location);
            }
            return const _StubPage(text: 'PREVIEW_TEMPLATE_PAGE');
          },
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        // 复用 sharedDb，避免每个测试重新打开 DB 文件
        databaseProvider.overrideWith((ref) async => sharedDb),
        // 直接覆盖 templatesDaoProvider，避免 FutureProvider 异步解析时序问题
        templatesDaoProvider.overrideWith((ref) async => TemplatesDao(sharedDb)),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    // Task A5 适配：sqflite_common_ffi 的 DB 查询是真实 async 操作，
    // 在 FakeAsync 环境下 pump(Duration) 无法让真实 Future 完成。
    // 必须用 tester.runAsync 让真实 async 操作（DAO 查询 / 写入）完成。
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    } else {
      // 先让真实 async（DAO 查询/写入）完成，再 settle；顺序颠倒会导致 pumpAndSettle 超时
      // 并行全量负载下 _loadStyleOptions 的 DB 查询可能超过单次 50ms，轮询多次以稳定通过
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }
  }

  Future<void> switchTab(
      WidgetTester tester, UIStyle style, String title) async {
    // 点击顶部 tab chip 切到对应 tab（AnimatedSwitcher 220ms 动画后内容可见）
    await tester.tap(find.text(title).first);
    await settleOrPump(tester, style);
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 4000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 路由参数加载（4 tests）
  // ============================================================
  group('TemplatesEditorPage — route parameter loading', () {
    testWidgets('new mode: renders with title 新建模板 and blank form',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      // 空白模板：name 输入框为空（占位符可见）
      expect(find.text('输入模板名称'), findsOneWidget);
    });

    testWidgets('edit mode: templateId loads existing template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/templates/editor?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 编辑模式：标题为 编辑模板
      expect(find.widgetWithText(LumiraNav, '编辑模板'), findsOneWidget);
      // 已加载模板名称
      expect(find.text('咖啡馆人像'), findsOneWidget);
    });

    testWidgets('draft recovery: draftId loads draft form', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/templates/editor?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 草稿模式：仍为新建模板（草稿不属于已存在模板）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      // 已加载草稿名称
      expect(find.text('咖啡馆人像草稿'), findsOneWidget);
    });

    testWidgets(
        'invalid templateId falls back to new mode with blank form',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/templates/editor?${RouteNames.paramTemplateId}=nonexistent-id',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 无效 templateId：返回新建模式（_isEditMode=false）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      expect(find.text('输入模板名称'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: Step 1 模板信息（5 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 1 模板信息', () {
    testWidgets('renders 6 top tabs; each tab shows its card',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 顶部 Tab 条渲染 6 个 tab 标题
      expect(find.text('基本信息'), findsOneWidget);
      expect(find.text('封面与剪影'), findsOneWidget);
      expect(find.text('构图'), findsOneWidget);
      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('场景引导'), findsOneWidget);
      expect(find.text('后期处理'), findsOneWidget);

      // 默认 tab（基本信息）：模板信息 卡片
      expect(find.text('模板信息'), findsOneWidget);

      // 封面与剪影 tab：封面 + 姿势剪影 两张卡
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');
      expect(find.text('封面'), findsOneWidget);
      expect(find.text('姿势剪影'), findsOneWidget);

      // 逐个切换验证其余卡片标题
      await switchTab(tester, UIStyle.neumorphic, '构图');
      expect(find.text('构图叠图'), findsOneWidget);

      await switchTab(tester, UIStyle.neumorphic, '相机参数');
      // tab chip + 卡片标题均为 '相机参数'
      expect(find.text('相机参数'), findsNWidgets(2));

      await switchTab(tester, UIStyle.neumorphic, '场景引导');
      expect(find.text('场景指南'), findsOneWidget);

      await switchTab(tester, UIStyle.neumorphic, '后期处理');
      // tab chip '后期处理' + 卡片标题 '后期参数'
      expect(find.text('后期处理'), findsOneWidget);
      expect(find.text('后期参数'), findsOneWidget);
    });

    testWidgets('Step 1: name input accepts text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 名称字段：占位符为 '输入模板名称'
      expect(find.text('输入模板名称'), findsOneWidget);
      // 通过 hintText 精确定位 name 字段（避免 .first 的非确定性）
      // 注：name 字段使用 TextFormField（_FieldInput 无 controller 分支），
      // TextFormField 内部构建 TextField（其 decoration.hintText 与传入一致），故用 TextField 匹配
      final nameFieldFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '输入模板名称',
      );
      expect(nameFieldFinder, findsOneWidget);
      // 输入文本
      await tester.enterText(nameFieldFinder, '我的新模板');
      await settleOrPump(tester, UIStyle.neumorphic);
      // 验证：输入的文本已显示
      expect(find.text('我的新模板'), findsOneWidget);
    });

    testWidgets('Step 1: renders 4 field labels (名称/分类/标签/简介)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('名称'), findsOneWidget);
      expect(find.text('分类'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('简介'), findsOneWidget);
      expect(find.text('参数参考来源'), findsOneWidget);
    });

    testWidgets('Step 1: default category is portrait (人像)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // DropdownButton 显示当前选中项 '人像'
      expect(find.text('人像'), findsWidgets);
    });

    // Finding #4 — Step 1 行为测试：切换分类 → dropdown label 更新
    testWidgets('Step 1: switching category to 风光 updates dropdown label',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 category='portrait'，dropdown 显示 '人像'
      expect(find.text('人像'), findsWidgets);

      // 通过 ancestor 模式定位 category LumiraDropdown（包裹 '人像' 文字）
      final categoryDropdown = find.ancestor(
        of: find.text('人像').first,
        matching: find.byType(LumiraDropdown<String>),
      );
      expect(categoryDropdown, findsOneWidget);

      // 点击 dropdown 打开菜单
      await tester.tap(categoryDropdown);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 菜单弹出后，点击 '风光' 菜单项
      await tester.tap(find.text('风光').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：dropdown 现在显示 '风光'（value 已更新为 'landscape'）
      final updatedDropdown = find.ancestor(
        of: find.text('风光'),
        matching: find.byType(LumiraDropdown<String>),
      );
      expect(updatedDropdown, findsOneWidget);
    });

    // Task6 — 基本信息 tab 新字段（短简介/四级下拉/ambience chips/标签新增）
    testWidgets(
        'Step 1: renders new basic info fields (短简介/四级下拉/ambience chips/标签新增)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 短简介：label + 输入框（≤20 字占位）
      expect(find.text('短简介'), findsOneWidget);
      expect(find.text('一句话介绍（推荐 ≤20 字）'), findsOneWidget);

      // 四级级联下拉：风格/子风格/方法
      expect(find.text('风格'), findsWidgets);
      expect(find.text('子风格'), findsOneWidget);
      expect(find.text('方法'), findsOneWidget);

      // ambience chips
      expect(find.text('适用季节/天气/时段'), findsOneWidget);
      expect(find.text('季节'), findsOneWidget);
      expect(find.text('春'), findsOneWidget);
      expect(find.text('冬'), findsOneWidget);
      expect(find.text('天气'), findsOneWidget);
      expect(find.text('晴'), findsOneWidget);
      expect(find.text('雨'), findsOneWidget);
      expect(find.text('时段'), findsOneWidget);
      expect(find.text('黄金小时'), findsOneWidget);
      expect(find.text('夜晚'), findsOneWidget);

      // 标签：label + 新增输入（无候选标签时显示空态提示）
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('+ 新增标签（回车添加）'), findsOneWidget);
      expect(find.text('暂无候选标签，可在下方新增'), findsOneWidget);
    });

    testWidgets('Step 1: renders tag candidate chip from custom template',
        (tester) async {
      setLargeViewport(tester);
      // 先种一条带标签的自定义模板，作为候选标签数据源（setUp 已清空表）
      await tester.runAsync(() =>
          _insertCustomTemplate(sharedDb, name: '候选模板', tags: const ['夜景', '街头']));
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 候选标签 chip 可见，且无空态提示
      expect(find.text('夜景'), findsWidgets);
      expect(find.text('街头'), findsOneWidget);
      expect(find.text('暂无候选标签，可在下方新增'), findsNothing);
      // 新增输入仍可见
      expect(find.text('+ 新增标签（回车添加）'), findsOneWidget);
    });

    testWidgets('Step 1: saving persists shortDesc/ambience/tags smoke',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 名称（必填）
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '输入模板名称'),
        '冒烟模板',
      );
      // 短简介
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '一句话介绍（推荐 ≤20 字）'),
        '适合自然光人像',
      );
      // 选 春 ambience chip
      await tester.tap(find.text('春'));
      // 新增标签
      await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '+ 新增标签（回车添加）'),
        '胶片感',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // 点击 保存（DAO upsert 为真实 async，走 runAsync 让其完成）
      await tester.tap(find.text('保存'));
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester
          .runAsync(() => Future.delayed(const Duration(milliseconds: 200)));

      TemplateRecord? saved;
      await tester.runAsync(() async {
        final dao = TemplatesDao(sharedDb);
        final all = await dao.getAll();
        final matches =
            all.where((t) => t.name == '冒烟模板').toList();
        saved = matches.isNotEmpty ? matches.first : null;
      });
      expect(saved, isNotNull);
      expect(saved!.shortDesc, '适合自然光人像');
      final amb = TemplateMapper.ambienceFromJson(saved!.ambienceJson);
      expect(amb.seasons, contains('spring'));
      expect(saved!.tags, contains('胶片感'));

      // 让 _onSave 内的 800ms 定时器触发并返回，避免测试收尾时报 pending timer
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await settleOrPump(tester, UIStyle.neumorphic);
    });
  });

  // ============================================================
  // 分类 3: Step 2 构图叠图（4 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 2 构图叠图', () {
    testWidgets('renders overlay type dropdown with default 三分法',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '构图');

      // 默认 overlayType = 'rule_of_thirds'，显示 '三分法'
      expect(find.text('构图类型'), findsOneWidget);
      expect(find.text('三分法'), findsWidgets);
    });

    testWidgets('renders opacity slider with default 0.5', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await switchTab(tester, UIStyle.neumorphic, '构图');

      expect(find.text('透明度'), findsOneWidget);
      // 默认 opacity=0.5，valueText 为 '0.5'
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('renders aspect ratio input with default 3:4', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '构图');

      expect(find.text('宽高比'), findsOneWidget);
      // Tab 布局下仅构图 tab 可见，'3:4' 仅出现 1 次（后期参数 tab 未渲染）
      expect(find.text('3:4'), findsOneWidget);
    });

    // Finding #4 — Step 2 行为测试：拖动透明度滑块 → valueText 更新
    testWidgets('Step 2: dragging 透明度 slider updates value text',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '构图');

      // 默认 opacity=0.5，valueText '0.5'
      expect(find.text('透明度'), findsOneWidget);
      expect(find.text('0.5'), findsOneWidget);

      // 通过 ancestor + descendant 模式定位 透明度 slider
      final opacityRow = find.ancestor(
        of: find.text('透明度'),
        matching: find.byType(Row),
      );
      final opacitySlider = find.descendant(
        of: opacityRow,
        matching: find.byType(LumiraSlider),
      );
      expect(opacitySlider, findsOneWidget);

      // 拖动 slider 到最右端（value → 1.0）
      await tester.drag(opacitySlider, const Offset(500, 0));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：valueText 从 '0.5' 变为 '1.0'
      expect(find.text('1.0'), findsOneWidget);
      // '0.5' 应已不再显示（位置 X/Y 的 '0.50' 是 toStringAsFixed(2)，不冲突）
      expect(find.text('0.5'), findsNothing);
    });
  });

  // ============================================================
  // 分类 4: Step 3 姿势剪影（5 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 3 姿势剪影', () {
    testWidgets('renders 3 source pills (内置库/导入图片/绘制剪影)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      expect(find.text('来源'), findsOneWidget);
      expect(find.text('内置库'), findsOneWidget);
      expect(find.text('导入图片'), findsOneWidget);
      expect(find.text('绘制剪影'), findsOneWidget);
    });

    testWidgets('builtin source: renders 5 silhouette thumbnails',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      // 默认 source=builtin，显示 '选择剪影' 标签 + 5 个 thumbnail
      expect(find.text('选择剪影'), findsOneWidget);
      // 5 个 key 文本：none / standing-profile / sitting-cafe / walking-street / soft-portrait
      expect(find.text('none'), findsOneWidget);
      expect(find.text('standing-profile'), findsOneWidget);
      expect(find.text('sitting-cafe'), findsOneWidget);
      expect(find.text('walking-street'), findsOneWidget);
      expect(find.text('soft-portrait'), findsOneWidget);
    });

    testWidgets('switching to image source shows 选择图片 button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      // 点击 '导入图片' pill
      await tester.tap(find.text('导入图片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '导入图片' 字段标签和 '选择图片' 按钮
      expect(find.text('选择图片'), findsOneWidget);
    });

    testWidgets('switching to svg source shows 打开画布 button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      // 点击 '绘制剪影' pill
      await tester.tap(find.text('绘制剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '绘制剪影' 字段标签和 '打开画布' 按钮
      expect(find.text('打开画布'), findsOneWidget);
    });

    testWidgets('tapping 打开画布 opens SilhouetteEditorDialog', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      // 切换到 svg 源
      await tester.tap(find.text('绘制剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 滚动到 打开画布 按钮（新增封面图选择器增加了 Step 1 高度，
      // 需要滚动确保按钮在可见区域）
      await tester.ensureVisible(find.text('打开画布'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 打开画布
      await tester.tap(find.text('打开画布'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗内容：标题 '绘制剪影'（dialog 标题） + 工具按钮 + 提示
      expect(find.text('画笔'), findsOneWidget);
      expect(find.text('橡皮'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);
      expect(find.text('重做'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 5: Step 4 相机参数（4 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 4 相机参数', () {
    testWidgets('renders EV slider with default 0.0', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '相机参数');

      // EV 默认值 0.0，valueText 为 '0.0'
      expect(find.text('EV'), findsOneWidget);
      expect(find.text('0.0'), findsWidgets);
    });

    testWidgets('renders ISO mode pills (自动/手动)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '相机参数');

      expect(find.text('ISO 模式'), findsOneWidget);
      // 默认 isoMode='auto'，'自动' pill 显示
      expect(find.text('自动'), findsWidgets);
      expect(find.text('手动'), findsWidgets);
    });

    testWidgets('renders white balance dropdown with default 日光',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '相机参数');

      expect(find.text('白平衡'), findsOneWidget);
      // 默认 whiteBalance='daylight'，显示 '日光'
      expect(find.text('日光'), findsWidgets);
    });

    // Finding #4 — Step 4 行为测试：点击 '手动' ISO 模式 pill → pill 激活
    testWidgets('Step 4: tapping 手动 ISO mode pill activates it',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '相机参数');

      final tokens = ThemeTokens.of(ThemeKey.warmWhite);

      // '手动' 出现在两处：ISO 模式 _PillGroup（Wrap）+ 对焦 DropdownButton 内
      // IndexedStack 中的 DropdownMenuItem（focusModeOptions 也有 '手动'）。
      // 仅 _PillGroup 使用 Wrap 组件，故用 find.descendant(of: Wrap) 精确定位
      // ISO 模式的 '手动' pill（silhouetteSourceOptions 无 '手动' 标签）。
      final isoManualText = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('手动'),
      );

      // 默认 isoMode='auto'，'手动' pill 非激活：文字颜色 = textSecondary
      final manualTextBefore = tester.widget<Text>(isoManualText);
      expect(manualTextBefore.style?.color, equals(tokens.textSecondary));

      // '手动' pill 在页面深处（y≈3678），视口外，需先滚动到可见区域再点击，
      // 否则 tap 中心点超出 root bounds 会跳过 hit test 导致点击无效。
      await tester.ensureVisible(isoManualText);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '手动' pill（通过 Wrap 后裔精确定位，避免误触 DropdownButton 内项）
      await tester.tap(isoManualText);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：'手动' pill 已激活：文字颜色 = textInverse（与 tokens.brand 形成对比）
      final manualTextAfter = tester.widget<Text>(isoManualText);
      expect(manualTextAfter.style?.color, equals(tokens.textInverse));
    });
  });

  // ============================================================
  // 分类 6: Step 5 场景指南（3 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 5 场景指南', () {
    testWidgets('renders 6 field labels (光线方向/拍摄距离/背景/最佳时间/道具/贴士)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '场景引导');

      expect(find.text('光线方向'), findsOneWidget);
      expect(find.text('拍摄距离'), findsOneWidget);
      expect(find.text('背景'), findsOneWidget);
      expect(find.text('最佳时间'), findsOneWidget);
      expect(find.text('道具'), findsOneWidget);
      expect(find.text('贴士'), findsOneWidget);
    });

    testWidgets('draft form loads scene guide fields with props/tips',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/templates/editor?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '场景引导');

      // draftForm 已填充：lightDirection='侧面柔光 45°' / shootingDistance='1.5-2m' / bestTime='14:00-16:00'
      expect(find.text('侧面柔光 45°'), findsOneWidget);
      expect(find.text('1.5-2m'), findsOneWidget);
      expect(find.text('14:00-16:00'), findsOneWidget);
      // props 已解析：'咖啡杯, 书'（逗号分隔）
      expect(find.text('咖啡杯, 书'), findsOneWidget);
    });

    // Finding #4 — Step 5 行为测试：输入 道具 字段 → 文本显示
    testWidgets('Step 5: entering text in 道具 field shows the text',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '场景引导');

      // 道具 字段：占位符 '道具1, 道具2'
      expect(find.text('道具'), findsOneWidget);
      expect(find.text('道具1, 道具2'), findsOneWidget);

      // 通过 hintText 定位 道具 输入字段（_FieldInput 用 controller → 返回 TextField）
      final propsFieldFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '道具1, 道具2',
      );
      expect(propsFieldFinder, findsOneWidget);

      // 输入文本
      await tester.enterText(propsFieldFinder, '咖啡杯, 书, 花');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：输入的文本已显示
      expect(find.text('咖啡杯, 书, 花'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 7: Step 6 后期参数（3 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 6 后期参数', () {
    testWidgets('renders LUT dropdown with default 无', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '后期处理');

      expect(find.text('LUT'), findsOneWidget);
      // 默认 lut='none'，显示 '无'
      expect(find.text('无'), findsWidgets);
    });

    testWidgets('renders 9 slider labels (亮度/对比/饱和/色温/色调/磨皮/锐化/暗角/颗粒 + 裁剪比)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '后期处理');

      expect(find.text('裁剪比'), findsOneWidget);
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('对比'), findsOneWidget);
      expect(find.text('饱和'), findsOneWidget);
      expect(find.text('色温'), findsOneWidget);
      expect(find.text('色调'), findsOneWidget);
      expect(find.text('磨皮'), findsOneWidget);
      expect(find.text('锐化'), findsOneWidget);
      expect(find.text('暗角'), findsOneWidget);
      expect(find.text('颗粒'), findsOneWidget);
    });

    // Finding #4 — Step 6 行为测试：拖动亮度滑块 → valueText 更新
    testWidgets('Step 6: dragging 亮度 slider updates value text',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '后期处理');

      // 默认 brightness=0，valueText '0'（多个 slider 默认 '0'，用 findsWidgets）
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      // '+100' 不应出现
      expect(find.text('+100'), findsNothing);

      // 通过 ancestor + descendant 模式定位 亮度 slider
      final brightnessRow = find.ancestor(
        of: find.text('亮度'),
        matching: find.byType(Row),
      );
      final brightnessSlider = find.descendant(
        of: brightnessRow,
        matching: find.byType(LumiraSlider),
      );
      expect(brightnessSlider, findsOneWidget);

      // 亮度 slider 在页面深处（y≈5124.5），远在 2400 视口外，
      // tester.drag 中心点超出 root bounds 会跳过 hit test，需先滚动到可见区域。
      await tester.ensureVisible(brightnessSlider);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 拖动 slider 到最右端（value → 100）
      await tester.drag(brightnessSlider, const Offset(500, 0));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：valueText 从 '0' 变为 '+100'
      expect(find.text('+100'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 8: Footer 操作（5 tests）
  // ============================================================
  group('TemplatesEditorPage — Footer 操作', () {
    testWidgets('renders 3 footer buttons (草稿/预览/保存) in new mode',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      // 新建模式下不显示导出按钮
      expect(find.text('导出'), findsNothing);
    });

    testWidgets('tapping 保存 with empty name shows 请输入模板名称 SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 保存 按钮（空白模板，name 为空）
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示错误 SnackBar
      expect(find.text('请输入模板名称'), findsOneWidget);
    });

    // Finding #1 — 名称非空时点保存 → 显示 '保存成功' SnackBar + 800ms 后 pop
    testWidgets(
        'tapping 保存 with valid name shows 保存成功 SnackBar and pops after 800ms',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 通过 hintText 定位 name 字段
      // 注：name 字段使用 TextFormField，内部 TextField 的 decoration.hintText 一致
      final nameFieldFinder = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '输入模板名称',
      );
      // 输入非空名称
      await tester.enterText(nameFieldFinder, '我的新模板');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 保存 按钮
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '保存成功' SnackBar
      expect(find.text('保存成功'), findsOneWidget);

      // 推进时间 800ms（_onSave 内 Future.delayed(800ms) 触发 pop）
      await tester.pump(const Duration(milliseconds: 800));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：编辑器页已 pop（LumiraNav 标题 '新建模板' 不再显示）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsNothing);
    });

    testWidgets('tapping 草稿 shows 草稿已保存 SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('草稿'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('草稿已保存'), findsOneWidget);
    });

    testWidgets('tapping 预览 navigates to preview-template page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('预览'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PREVIEW_TEMPLATE_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 9: 自动保存（1 test）
  // ============================================================
  group('TemplatesEditorPage — 自动保存', () {
    // Finding #3 — 加强 test 28：通过 Option B（preview 导航 URL 捕获）验证 _currentDraftId 赋值
    testWidgets(
        'auto-save assigns _currentDraftId (verified via preview URL draftId param)',
        (tester) async {
      setLargeViewport(tester);
      final capturedUrls = <String>[];
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        capturedPreviewUrls: capturedUrls,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);
      await switchTab(tester, UIStyle.neumorphic, '封面与剪影');

      // 触发表单变更（切换 silhouette source → _onChange → _scheduleAutoSave）
      await tester.tap(find.text('导入图片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 推进时间至 1000ms 之后（auto-save timer 触发，应设置 _currentDraftId）
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证：auto-save 静默执行（无崩溃，仍在编辑器页）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      expect(find.text('选择图片'), findsOneWidget);

      // 点击 预览 → 应导航至 /capture/preview-template?draftId=draft-editor-...
      await tester.tap(find.text('预览'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：preview 路由被触发（stub 渲染）
      expect(find.text('PREVIEW_TEMPLATE_PAGE'), findsOneWidget);

      // 验证 Option B：捕获的 URL 包含 draftId= 且有非空值（_currentDraftId 已被 auto-save 赋值）
      expect(capturedUrls, isNotEmpty,
          reason: 'preview 路由应被触发');
      final url = capturedUrls.last;
      expect(url, contains('draftId='),
          reason: 'preview URL 必须包含 draftId 参数');
      final draftIdMatch = RegExp(r'draftId=([^&]+)').firstMatch(url);
      expect(draftIdMatch, isNotNull,
          reason: 'draftId 参数必须存在');
      final draftIdValue = draftIdMatch!.group(1)!;
      expect(draftIdValue, isNotEmpty,
          reason: 'draftId 不能为空字符串（_currentDraftId 应已被 auto-save 赋值）');
      expect(draftIdValue, startsWith('draft-editor-'),
          reason: 'draftId 应为 auto-save 生成的格式');
    });
  });

  // ============================================================
  // 分类 10: Cross-theme/cross-style smoke（1 test，12 组合）
  // ============================================================
  group('TemplatesEditorPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      // 8 主题 × 1 风格 (neumorphic) + 1 主题 (warmWhite) × 4 风格 = 12 组合
      // Dart 2.19 兼容：不用 record 类型，用 _ThemeStyleCombo 类
      final combinations = <_ThemeStyleCombo>[
        for (final t in ThemeKey.values)
          _ThemeStyleCombo(theme: t, style: UIStyle.neumorphic),
        for (final s in UIStyle.values)
          if (s != UIStyle.neumorphic)
            _ThemeStyleCombo(theme: ThemeKey.warmWhite, style: s),
      ];

      for (final combo in combinations) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: combo.theme, uiStyle: combo.style));
        await settleOrPump(tester, combo.style);

        // 默认 tab（基本信息）卡片 + 顶部 6 个 tab chip 正常渲染
        expect(find.text('模板信息'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        for (final tabTitle in _editorAllTabs) {
          expect(find.text(tabTitle), findsOneWidget,
              reason: 'theme=${combo.theme}, style=${combo.style}, tab=$tabTitle');
        }
        // 重置 viewport 为下一次迭代
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

/// 主题 × 风格组合（Dart 2.19 兼容：不用 record 类型）
class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

/// 占位页（用于测试 pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}

/// 测试用 HttpOverrides（避免网络图片异常）
class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return client;
  }
}

/// 创建 custom_templates 表（与 database_provider._onCreate 中对应部分一致）
///
/// Task A5：`_onSave` 通过 `templatesDaoProvider` 调用 `dao.upsert(record)`，
/// 测试需要预先建表才能写入。仅创建 editor 实际使用的 `custom_templates` 表，
/// 其他表（scenes/gallery/...）editor 不访问，省略以保持测试聚焦。
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

/// 种入一级分类（editor Step 1 分类下拉框数据源）
Future<void> _seedCategories(Database db) async {
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
}

/// 种入一条自定义模板（Task6：标签候选 chip 数据源）。
Future<void> _insertCustomTemplate(
  Database db, {
  required String name,
  List<String> tags = const [],
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.customTemplates, {
    Tables.colId: 'test-${DateTime.now().microsecondsSinceEpoch}',
    Tables.colName: name,
    Tables.colAuthor: '',
    Tables.colVersion: '1.0.0',
    Tables.colCategory: 'portrait',
    Tables.colClassificationJson: '{}',
    Tables.colTagsJson: _jsonEncode(tags),
    Tables.colTagIdsJson: '[]',
    Tables.colPrice: 0,
    Tables.colCover: '',
    Tables.colCoverData: null,
    Tables.colDescription: '',
    Tables.colReferenceSource: '',
    Tables.colShortDesc: '',
    Tables.colAmbienceJson: '{}',
    Tables.colCompositionJson: '{}',
    Tables.colPoseJson: '{}',
    Tables.colCameraJson: '{}',
    Tables.colSceneGuideJson: '{}',
    Tables.colPostProcessJson: '{}',
    Tables.colIsBuiltin: 0,
    Tables.colIsRecommended: 0,
    Tables.colSource: 'custom',
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}

String _jsonEncode(List<String> list) {
  final buf = StringBuffer('[');
  for (var i = 0; i < list.length; i++) {
    if (i > 0) buf.write(', ');
    buf.write('"${list[i]}"');
  }
  buf.write(']');
  return buf.toString();
}
