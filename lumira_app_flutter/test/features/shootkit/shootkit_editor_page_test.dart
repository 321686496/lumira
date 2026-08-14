import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/shootkit/data/shootkit_mock_data.dart';
import 'package:lumira_app_flutter/features/shootkit/pages/shootkit_editor_page.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/form/lumira_slider.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.12 — ShootkitEditorPage 测试
///
/// 覆盖 brief §"测试要求"：≥10 项 widget 测试，含：
/// 1. 关键 UI 元素渲染（标题/输入框/选择卡/参数表单/按钮）
/// 2. 路由参数传递（kitId 加载已有组合 / 无 kitId 创建新组合 / sceneId 预绑定 / 无效 kitId）
/// 3. 用户交互（输入名称/选择场景/选择模板/修改参数/重置/保存）
/// 4. 表单验证（名称为空 / 未绑定场景 / 未选择模板 / 全部通过）
/// 5. 跨主题/风格 smoke test
void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
    // 重置 mock 数据，避免跨用例污染
    ShootKitMockData.reset();
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String initialLocation = '/shootkit/editor',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.shootkitEditor,
          name: 'shootkitEditor',
          builder: (context, state) {
            final kitId = state.queryParams[RouteNames.paramKitId];
            final sceneId = state.queryParams[RouteNames.paramSceneId];
            return ShootkitEditorPage(kitId: kitId, sceneId: sceneId);
          },
        ),
        GoRoute(
          path: RouteNames.home,
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
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

  // ============================================================
  // 分类 1: 关键 UI 元素渲染
  // ============================================================
  group('ShootkitEditorPage — UI rendering', () {
    testWidgets('renders LumiraNav with title 新建组合 in new mode',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '新建组合'), findsOneWidget);
    });

    testWidgets('renders 4 form section labels', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('组合名称'), findsOneWidget);
      expect(find.text('绑定场景'), findsOneWidget);
      expect(find.text('选择模板'), findsOneWidget);
      expect(find.text('参数覆盖（可选）'), findsOneWidget);
    });

    testWidgets('renders 3 slider labels (EV/WB(K)/ISO)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('EV'), findsOneWidget);
      expect(find.text('WB(K)'), findsOneWidget);
      expect(find.text('ISO'), findsOneWidget);
    });

    testWidgets('renders reset button and 保存 nav action', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 重置按钮（在参数覆盖区内）
      expect(find.text('重置'), findsOneWidget);
      // 顶部导航栏的保存按钮
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('renders 6 template cards from TemplatesMockData',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // TemplatesMockData.otherTemplates 6 项的 name 都应出现
      expect(find.text('街拍黑白'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);
      expect(find.text('静物暖光'), findsOneWidget);
      expect(find.text('人像散景'), findsOneWidget);
      expect(find.text('全景风光'), findsOneWidget);
      expect(find.text('霓虹夜景'), findsOneWidget);
    });

    testWidgets('new mode shows placeholder 未选择 for bound scene',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('未选择'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 路由参数
  // ============================================================
  group('ShootkitEditorPage — route parameters', () {
    testWidgets('kitId loads existing kit (edit mode)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/shootkit/editor?${RouteNames.paramKitId}=kit_001',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 编辑模式：标题为 编辑组合
      expect(find.widgetWithText(LumiraNav, '编辑组合'), findsOneWidget);
      // 已加载组合名称（TextField 内文本）
      expect(find.text('咖啡馆人像套件'), findsOneWidget);
      // 已绑定场景（cafe-window → 咖啡馆）
      expect(find.text('咖啡馆'), findsOneWidget);
    });

    testWidgets('sceneId pre-binds scene in new mode', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/shootkit/editor?${RouteNames.paramSceneId}=sunset-silhouette',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 仍为新建模式
      expect(find.widgetWithText(LumiraNav, '新建组合'), findsOneWidget);
      // 预绑定场景 sunset-silhouette → 黄昏剪影
      expect(find.text('黄昏剪影'), findsOneWidget);
      // 不显示未选择占位
      expect(find.text('未选择'), findsNothing);
    });

    testWidgets('invalid kitId falls back to new mode', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/shootkit/editor?${RouteNames.paramKitId}=nonexistent',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 无效 kitId：回退到新建模式
      expect(find.widgetWithText(LumiraNav, '新建组合'), findsOneWidget);
      // 名称字段为空
      expect(find.text('给这个组合起个名字'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 3: 用户交互
  // ============================================================
  group('ShootkitEditorPage — interactions', () {
    testWidgets('entering kit name updates TextField', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 通过 hintText 定位名称输入框
      final nameField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '给这个组合起个名字',
      );
      expect(nameField, findsOneWidget);

      await tester.enterText(nameField, '我的测试组合');
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('我的测试组合'), findsOneWidget);
    });

    testWidgets('tapping template selects it and shows preview',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选中前：预览区不可见
      expect(find.text('预览'), findsNothing);

      // 点击 '街拍黑白' 模板
      await tester.tap(find.text('街拍黑白'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选中后：预览区出现
      expect(find.text('预览'), findsOneWidget);
    });

    testWidgets('tapping bound scene card opens picker', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '未选择' 区域打开场景选择底部弹窗
      await tester.tap(find.text('未选择'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗标题
      expect(find.text('选择场景'), findsOneWidget);
      // 弹窗中应包含至少一个场景名（如 咖啡馆）
      expect(find.text('咖啡馆'), findsWidgets);
    });

    testWidgets('selecting scene from picker updates bound scene display',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 打开场景选择器
      await tester.tap(find.text('未选择'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 在弹窗中点击 '黄昏剪影'（弹窗内的列表项）
      // 弹窗内 '黄昏剪影' 是 ListTile 的 title，弹窗外不可见
      await tester.tap(find.text('黄昏剪影').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗关闭，绑定场景显示 '黄昏剪影'
      expect(find.text('黄昏剪影'), findsOneWidget);
      expect(find.text('未选择'), findsNothing);
    });

    testWidgets('dragging EV slider updates value text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 EV=0.0，valueText '0.00'
      expect(find.text('0.00'), findsOneWidget);

      // 通过 ancestor + descendant 定位 EV slider
      final evRow = find.ancestor(
        of: find.text('EV'),
        matching: find.byType(Row),
      );
      final evSlider = find.descendant(
        of: evRow,
        matching: find.byType(LumiraSlider),
      );
      expect(evSlider, findsOneWidget);

      // 滚动到可见区域（避免视口外 hit test 失效）
      await tester.ensureVisible(evSlider);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 拖动 slider 到最右端（value → 3.0）
      await tester.drag(evSlider, const Offset(500, 0));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：valueText 从 '0.00' 变为 '+3.00'
      expect(find.text('+3.00'), findsOneWidget);
      expect(find.text('0.00'), findsNothing);
    });

    testWidgets('tapping reset clears overrides and shows SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先拖动 EV slider 使其有非零值
      final evRow = find.ancestor(
        of: find.text('EV'),
        matching: find.byType(Row),
      );
      final evSlider = find.descendant(
        of: evRow,
        matching: find.byType(LumiraSlider),
      );
      await tester.ensureVisible(evSlider);
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.drag(evSlider, const Offset(500, 0));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('+3.00'), findsOneWidget);

      // 滚动到重置按钮并点击
      await tester.ensureVisible(find.text('重置'));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('重置'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 提示
      expect(find.text('参数已重置'), findsOneWidget);
      // EV 值回到 '0.00'
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('0.00'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 表单验证 + 保存
  // ============================================================
  group('ShootkitEditorPage — validation & save', () {
    testWidgets('saving with empty name shows 请填写组合名称 SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 直接点保存（名称为空）
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('请填写组合名称'), findsOneWidget);
    });

    testWidgets(
        'saving with name but no scene shows 未绑定场景 SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 输入名称
      final nameField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '给这个组合起个名字',
      );
      await tester.enterText(nameField, '测试组合');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 不选场景直接保存 → 应报错
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('未绑定场景'), findsOneWidget);
    });

    testWidgets(
        'saving with name+scene but no template shows 请选择模板 SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 输入名称
      final nameField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '给这个组合起个名字',
      );
      await tester.enterText(nameField, '测试组合');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择场景
      await tester.tap(find.text('未选择'));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('咖啡馆').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 不选模板直接保存 → 应报错
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('请选择模板'), findsOneWidget);
    });

    testWidgets(
        'saving with valid data shows 保存成功 SnackBar and pops after 600ms',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 输入名称
      final nameField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '') == '给这个组合起个名字',
      );
      await tester.enterText(nameField, '测试组合');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择场景
      await tester.tap(find.text('未选择'));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('咖啡馆').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择模板
      await tester.tap(find.text('街拍黑白'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击保存
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '保存成功' SnackBar
      expect(find.text('保存成功'), findsOneWidget);

      // 推进时间 600ms（_onSave 内 Future.delayed(600ms) 触发 pop）
      await tester.pump(const Duration(milliseconds: 600));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证：编辑器页已 pop（LumiraNav 标题 '新建组合' 不再显示）
      expect(find.widgetWithText(LumiraNav, '新建组合'), findsNothing);
    });
  });

  // ============================================================
  // 分类 5: 跨主题/风格 smoke test
  // ============================================================
  group('ShootkitEditorPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
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

        expect(find.widgetWithText(LumiraNav, '新建组合'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('组合名称'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('选择模板'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
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
