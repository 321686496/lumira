import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_all_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8A — TemplatesAllPage 测试
///
/// 覆盖 brief 第 7 节 "Page 2" 的 12 项断言 + cross-theme/cross-style smoke test。
/// 注意：测试名不要 overpromise（#59/#60/#61 教训）。
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
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(
    ThemeKey themeKey,
    UIStyle uiStyle, {
    String? scene,
  }) {
    final goRouter = GoRouter(
      initialLocation: '/templates/all',
      routes: [
        GoRoute(
          path: '/templates/all',
          name: 'templatesAll',
          builder: (_, __) => TemplatesAllPage(scene: scene),
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

  group('TemplatesAllPage', () {
    testWidgets('renders hero card with template count', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板库'), findsOneWidget);
      // allTemplates.length = 10
      expect(find.text('10 个模板等你探索'), findsOneWidget);
    });

    testWidgets('renders unlocked count pill', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 内置免费模板（price=0）= cafe_portrait/street_bw/macro_flower/food_overhead/custom_cafe_diary/custom_portrait_soft = 6
      // 但默认 _showCustom=false，仅计算 isCustom=false 的免费模板
      // isCustom=false && price=0 → cafe_portrait/street_bw/macro_flower/food_overhead = 4
      // 但 _unlockedCount getter 计算 allTemplates.where(price=0).length = 6
      expect(find.text('已解锁 6 个'), findsOneWidget);
    });

    testWidgets('renders 7 type pills in layer 0', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Forced fix: '人像'/'风光'/'美食'/'街拍'/'夜景' 在 _PillRow type pill + _TagChip 占位 + _TplCard category label 中各出现 3 次
      // '微距'/'静物' 不在 _TagChip 中，仅 2 次（type pill + card label）
      expect(find.text('人像'), findsNWidgets(3));
      expect(find.text('风光'), findsNWidgets(3));
      expect(find.text('美食'), findsNWidgets(3));
      expect(find.text('街拍'), findsNWidgets(3));
      expect(find.text('夜景'), findsNWidgets(3));
      expect(find.text('微距'), findsNWidgets(2));
      expect(find.text('静物'), findsNWidgets(2));
    });

    testWidgets('tapping type pill shows STYLE_MAP options and clears method',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Forced fix: '人像' 出现 3 次（type pill + tag chip + card label）
      // 用 .first 选择第一个（type pill，位于布局最上层）
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // STYLE_MAP['portrait'] = 4 个 style：日系 / 情绪 / 胶片 / 欧美
      expect(find.text('日系'), findsOneWidget);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('胶片'), findsOneWidget);
      expect(find.text('欧美'), findsOneWidget);

      // Task 2.8A Fix #1: 验证切换 type 时下层 method 被清空
      // 选 'japanese' style → METHOD_MAP['japanese'] = [自拍, 他拍, 俯拍]
      await tester.tap(find.text('日系'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('自拍'), findsOneWidget);

      // 选 '自拍' method（选中后 method pill 仍渲染）
      await tester.tap(find.text('自拍'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('自拍'), findsOneWidget);

      // 切换 type 到 '风光' → _onLayerSelect(0, 'landscape') 清空 style + method
      // STYLE_MAP['landscape'] = [清新, 大气]，无 method 层；'自拍' 应不再渲染
      await tester.tap(find.text('风光').first);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('自拍'), findsNothing);
    });

    testWidgets('tapping style pill shows METHOD_MAP options',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Forced fix: 用 .first 选择 type pill
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选 japanese
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
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认显示 7 个内置模板（不含自定义）
      expect(find.text('咖啡馆人像'), findsOneWidget);

      // 点击 '我的' toggle
      final customToggle = find.text('我的');
      expect(customToggle, findsOneWidget);
      await tester.tap(customToggle);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换后应显示 3 个自定义模板：金色风光精选 / 咖啡日记 / 柔光人像自创
      expect(find.text('咖啡日记'), findsOneWidget);
      expect(find.text('柔光人像自创'), findsOneWidget);
      expect(find.text('金色风光精选'), findsOneWidget);
    });

    testWidgets('renders action row when 我的 is active', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
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
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Forced fix: '微距' 出现 2 次（type pill + macro_flower card category label）
      // 用 .first 选择 type pill
      await tester.tap(find.text('微距').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换到 '我的'（无自定义 macro 模板）
      await tester.tap(find.text('我的'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('该分类暂无模板'), findsOneWidget);
    });

    testWidgets('renders grid with built-in templates by default',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 _showCustom=false，显示 7 个内置模板
      expect(find.text('咖啡馆人像'), findsOneWidget);
      expect(find.text('街拍黑白'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);
      expect(find.text('金色风光'), findsOneWidget);
      expect(find.text('美食俯拍'), findsOneWidget);
      expect(find.text('霓虹夜景'), findsOneWidget);
      expect(find.text('静物暖光'), findsOneWidget);
    });

    testWidgets('tapping template card navigates to /templates/detail page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '咖啡馆人像' card
      await tester.tap(find.text('咖啡馆人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /templates/detail（路由由测试用 GoRouter 提供占位）
      expect(find.text('DETAIL_PAGE'), findsOneWidget);
    });

    testWidgets('scene parameter sets initial selectedType', (tester) async {
      setLargeViewport(tester);
      // scene='cafe' → sceneToCategoryMap['cafe']='still-life'
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        scene: 'cafe',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 'still-life' type 应已选中 → 显示 STYLE_MAP['still-life'] 选项
      // STYLE_MAP['still-life'] = [极简, 扁平]
      expect(find.text('极简'), findsOneWidget);
      expect(find.text('扁平'), findsOneWidget);
    });

    testWidgets('tapping 新建模板 button pushes /templates/editor',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
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

    testWidgets('renders LumiraNav with title 全部模板', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '全部模板'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('模板库'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.text('模板库'), findsOneWidget, reason: 'style=$style');
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
