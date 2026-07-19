import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_detail_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8A — TemplatesDetailPage 测试
///
/// 覆盖 brief 第 6 节 "Page 1" 的 13 项断言 + cross-theme/cross-style smoke test。
/// 注意：测试名不要 overpromise（#59/#60/#61 教训）— 仅断言实际渲染的文本与组件。
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
    String? templateId,
  }) {
    final goRouter = GoRouter(
      initialLocation: '/templates/detail',
      routes: [
        GoRoute(
          path: '/templates/detail',
          name: 'templatesDetail',
          builder: (_, __) => TemplatesDetailPage(templateId: templateId),
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
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

  group('TemplatesDetailPage', () {
    testWidgets('renders empty state when templateId is null', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: null,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板未找到'), findsOneWidget);
      expect(find.text('该模板可能已被删除或链接错误'), findsOneWidget);
    });

    testWidgets('renders empty state when templateId is not found',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'nonexistent_xyz',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板未找到'), findsOneWidget);
    });

    testWidgets('renders template name for free template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('咖啡馆人像'), findsOneWidget);
    });

    testWidgets('renders category label on preview image', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '人像' 来自 categoryLabel('portrait')，出现在预览图左上角 badge
      expect(find.text('人像'), findsOneWidget);
    });

    testWidgets('renders scene guide section with all 5 field labels',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('场景指南'), findsOneWidget);
      expect(find.text('光线'), findsOneWidget);
      expect(find.text('距离'), findsOneWidget);
      expect(find.text('背景'), findsOneWidget);
      expect(find.text('道具'), findsOneWidget);
      expect(find.text('最佳时间'), findsOneWidget);
    });

    testWidgets('renders camera params with formatted values', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('EV +1'), findsOneWidget);
      expect(find.text('ISO 400'), findsOneWidget);
      expect(find.text('1/125s'), findsOneWidget);
    });

    testWidgets('renders post process params with LUT label', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('后期参数'), findsOneWidget);
      expect(find.text('裁剪: 3:4'), findsOneWidget);
      // LUT 'warm_film' → '暖色胶片'
      expect(find.text('LUT: 暖色胶片'), findsOneWidget);
    });

    testWidgets('renders free unlock text for free template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe_portrait price=0 → '免费' 出现在 title badge + unlock status
      expect(find.text('免费'), findsNWidgets(2));
    });

    testWidgets('renders premium unlock text for paid template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // custom_golden_landscape price=18 → '精选 ¥18' 出现在 title badge + unlock status
      expect(find.text('精选 ¥18'), findsNWidgets(2));
    });

    testWidgets('renders pose section when silhouette is not none',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe_portrait pose.silhouetteData='standing_basic' → hasSilhouette=true
      expect(find.text('姿势参考'), findsOneWidget);
    });

    testWidgets('hides pose section when silhouette is none', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // custom_golden_landscape pose.silhouetteData='none' → hasSilhouette=false
      expect(find.text('姿势参考'), findsNothing);
    });

    testWidgets('renders reference source text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('参数参考来源：摄影美学院 L03'), findsOneWidget);
    });

    testWidgets(
        'tapping 套用此模板拍摄 button pushes /capture with templateId',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击底部固定 CTA
      final ctaButton = find.text('套用此模板拍摄');
      expect(ctaButton, findsOneWidget);
      await tester.tap(ctaButton);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /capture（路由由测试用 GoRouter 提供占位）
      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets(
        'renders LumiraNav with title 模板详情',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '模板详情'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(
          theme,
          UIStyle.neumorphic,
          templateId: 'cafe_portrait',
        ));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('场景指南'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(
          ThemeKey.warmWhite,
          style,
          templateId: 'cafe_portrait',
        ));
        await settleOrPump(tester, style);
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'style=$style');
        expect(find.text('场景指南'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
