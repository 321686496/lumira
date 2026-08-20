import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/db/dao/watermark_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/watermark/data/watermark_providers.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_settings.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/pages/watermark_manage_page.dart';
import 'package:lumira_app_flutter/features/watermark/widgets/watermark_preview.dart';
import 'package:lumira_app_flutter/shared/widgets/cards/neu_card.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// 测试用自定义水印 DAO（implements 接口，内存实现，无需真实 Database）。
class _FakeWatermarkDao implements WatermarkDao {
  _FakeWatermarkDao(this.templates);

  final List<WatermarkTemplate> templates;

  @override
  Future<List<WatermarkTemplate>> getAll() async => List.of(templates);

  @override
  Future<WatermarkTemplate?> getById(String id) async {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<void> insert(WatermarkTemplate template) async {
    templates.insert(0, template);
    lastInserted = template;
  }

  @override
  Future<int> update(WatermarkTemplate template) async {
    lastUpdated = template;
    return 1;
  }

  @override
  Future<int> delete(String id) async {
    lastDeletedId = id;
    return 1;
  }

  WatermarkTemplate? lastInserted;
  WatermarkTemplate? lastUpdated;
  String? lastDeletedId;
}

WatermarkTemplate _custom(String id, String name) {
  return WatermarkTemplate(
    id: id,
    name: name,
    type: WatermarkTemplateType.custom,
    createdAt: DateTime(2026, 8, 20),
    elements: [
      WatermarkElement(
        id: '${id}_t',
        type: WatermarkElementType.text,
        text: 'CUSTOM',
        x: 0.5,
        y: 0.5,
        fontSize: 0.05,
        color: const ui.Color(0xFF444444),
      ),
    ],
  );
}

// 预置模板「简约日期」的真实 id（与 preset_watermarks.dart 一致）
const _presetIdA = 'preset_minimal_date';

void main() {
  late GoRouter router;
  late _FakeWatermarkDao watermarkDao;

  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    watermarkDao = _FakeWatermarkDao([
      _custom('custom_1', '我的水印'),
      _custom('custom_2', '旅行水印'),
    ]);

    router = GoRouter(
      initialLocation: RouteNames.profileSettingsWatermark,
      routes: [
        GoRoute(
          path: RouteNames.profileSettingsWatermark,
          name: 'watermarkManage',
          builder: (_, __) =>
              const WatermarkManagePage(showPhotoBackground: false),
        ),
        GoRoute(
          path: RouteNames.profileSettingsWatermarkEdit,
          name: 'watermarkEdit',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('WATERMARK_EDIT'))),
        ),
      ],
    );

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

  ProviderContainer makeContainer({
    ThemeKey themeKey = ThemeKey.warmWhite,
    UIStyle uiStyle = UIStyle.neumorphic,
    WatermarkSettings? settings,
  }) {
    final container = ProviderContainer(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        watermarkSettingsProvider
            .overrideWith((ref) => settings ?? const WatermarkSettings()),
        watermarkDaoProvider.overrideWith((ref) async => watermarkDao),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget wrap(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('WatermarkManagePage', () {
    testWidgets('renders LumiraNav with title 水印管理 and 模板 header',
        (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(WatermarkManagePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '水印管理'), findsOneWidget);
      expect(find.text('模板'), findsOneWidget);
    });

    testWidgets('default layout is list (单列), toggle button shows grid icon',
        (tester) async {
      setLargeViewport(tester);
      final container = makeContainer(); // 默认 manageLayout = list
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(
        container.read(watermarkSettingsProvider).manageLayout,
        WatermarkManageLayout.list,
      );
      // 处于 list 布局时，右上角切换按钮提示切换到「双列」→ 显示 grid_view
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('watermark-layout-toggle')),
          matching: find.byIcon(Icons.grid_view),
        ),
        findsOneWidget,
      );
      // 列表布局下卡片展示名称文本
      expect(find.text('我的水印'), findsOneWidget);
    });

    testWidgets('merges preset and custom templates', (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 预置模板（来自 preset provider）+ 自定义模板（来自 fake dao）
      expect(find.text('简约日期'), findsOneWidget);
      expect(find.text('我的水印'), findsOneWidget);
      expect(find.text('旅行水印'), findsOneWidget);
    });

    testWidgets('tapping layout toggle switches to grid and back to list',
        (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切到双列
      await tester.tap(find.byKey(const ValueKey('watermark-layout-toggle')));
      await tester.pump(const Duration(milliseconds: 700)); // 等持久化 timer
      await tester.pumpAndSettle();

      expect(
        container.read(watermarkSettingsProvider).manageLayout,
        WatermarkManageLayout.grid,
      );
      // grid 布局下切换按钮提示回「单列」→ 显示 view_agenda
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('watermark-layout-toggle')),
          matching: find.byIcon(Icons.view_agenda),
        ),
        findsOneWidget,
      );

      // 再切回单列
      await tester.tap(find.byKey(const ValueKey('watermark-layout-toggle')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        container.read(watermarkSettingsProvider).manageLayout,
        WatermarkManageLayout.list,
      );
    });

    testWidgets('selecting a template sets active template id', (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 list 布局：点击模板名称文本即可触发选中（名称包裹在 onSelect 的 GestureDetector 内）
      await tester.tap(find.text('简约日期'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        container.read(watermarkSettingsProvider).activeTemplateId,
        _presetIdA,
      );
    });

    testWidgets('tapping ＋新建 pushes watermark edit page', (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('＋新建'));
      await tester.pumpAndSettle();

      expect(find.text('WATERMARK_EDIT'), findsOneWidget);
    });

    testWidgets('copy action inserts a new custom template via dao',
        (tester) async {
      setLargeViewport(tester);
      // 只放一条自定义模板便于定位其 ⋮ 菜单
      watermarkDao = _FakeWatermarkDao([_custom('custom_1', '我的水印')]);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 定位「我的水印」卡片内的 ⋮ 菜单（避免误点预置卡片的菜单）
      final customCard = find.ancestor(
        of: find.text('我的水印'),
        matching: find.byType(NeuCard),
      );
      final menuBtn = find.descendant(
        of: customCard,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menuBtn.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(watermarkDao.lastInserted, isNotNull);
      expect(watermarkDao.lastInserted!.type, WatermarkTemplateType.custom);
    });

    testWidgets('preview widgets render on manage page (custom + preset)',
        (tester) async {
      setLargeViewport(tester);
      final container = makeContainer();
      await tester.pumpWidget(wrap(container));
      await settleOrPump(tester, UIStyle.neumorphic);

      // showPhotoBackground=false → 不加载真实照片，但仍渲染 WatermarkPreview
      expect(find.byType(WatermarkPreview), findsWidgets);
    });

    testWidgets('renders across neumorphic / flat / glass / female styles',
        (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        final container = makeContainer(uiStyle: style);
        await tester.pumpWidget(wrap(container));
        await settleOrPump(tester, style);
        expect(find.byType(WatermarkManagePage), findsOneWidget,
            reason: 'style=$style');
        expect(find.widgetWithText(LumiraNav, '水印管理'), findsOneWidget,
            reason: 'style=$style');
      }
    });
  });
}