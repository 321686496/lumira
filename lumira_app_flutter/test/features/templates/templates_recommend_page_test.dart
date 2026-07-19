import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_recommend_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8A — TemplatesRecommendPage 测试
///
/// 覆盖 brief 第 8 节 "Page 3" 的 8 项断言 + cross-theme/cross-style smoke test。
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

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    final goRouter = GoRouter(
      initialLocation: '/templates/recommend',
      routes: [
        GoRoute(
          path: '/templates/recommend',
          name: 'templatesRecommend',
          builder: (_, __) => const TemplatesRecommendPage(),
        ),
        GoRoute(
          path: RouteNames.templatesDetail,
          name: 'templatesDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('DETAIL_PAGE'))),
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

  group('TemplatesRecommendPage', () {
    testWidgets('renders style analysis section header', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('根据你的拍摄风格'), findsOneWidget);
      expect(
        find.text('分析你过往的 128 张作品，我们发现你偏爱以下风格'),
        findsOneWidget,
      );
    });

    testWidgets('renders 3 style analysis bars with labels and percents',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 3 个风格标签：温柔 / 清新 / 复古
      expect(find.text('温柔'), findsOneWidget);
      expect(find.text('清新'), findsOneWidget);
      expect(find.text('复古'), findsOneWidget);
      // 3 个百分比文本
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('32%'), findsOneWidget);
    });

    testWidgets('renders 猜你喜欢 section with 6 items', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('猜你喜欢'), findsOneWidget);
      expect(find.text('换一换'), findsOneWidget);
      // 6 项：牡丹花下 / 茶园春色 / 民国风情 / 白纱轻舞 / 植物园记 / 旧上海
      expect(find.text('牡丹花下'), findsOneWidget);
      expect(find.text('茶园春色'), findsOneWidget);
      expect(find.text('民国风情'), findsOneWidget);
      expect(find.text('白纱轻舞'), findsOneWidget);
      expect(find.text('植物园记'), findsOneWidget);
      expect(find.text('旧上海'), findsOneWidget);
    });

    testWidgets('renders 相似用户也在拍 section with 4 items', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('相似用户也在拍'), findsOneWidget);
      expect(find.text('查看全部'), findsOneWidget);
      // 4 项
      expect(find.text('晨雾森林'), findsOneWidget);
      expect(find.text('向日葵田'), findsOneWidget);
      expect(find.text('书香午后'), findsOneWidget);
      expect(find.text('海边栈道'), findsOneWidget);
    });

    testWidgets('renders similar user usage count with formatThousands',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个 usageCount：1200 / 980 / 850 / 720
      // 仅 1200 是 4+ 位数，formatThousands → '1,200'
      expect(find.text('1,200+ 用户使用'), findsOneWidget);
      // 980 / 850 / 720 不满 4 位，formatThousands 原样返回
      expect(find.text('980+ 用户使用'), findsOneWidget);
      expect(find.text('850+ 用户使用'), findsOneWidget);
      expect(find.text('720+ 用户使用'), findsOneWidget);
    });

    testWidgets('renders 根据最近拍摄 section with recent info', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('根据最近拍摄'), findsOneWidget);
      expect(find.text('你昨天在咖啡馆拍了 3 张照片'), findsOneWidget);
      expect(find.text('试试这些咖啡馆模板吧'), findsOneWidget);
    });

    testWidgets('renders recent templates with theme label', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个 recentTemplates 都有 theme='咖啡馆主题'
      // 出现在 _ThemeBadge 中 4 次
      expect(find.text('咖啡馆主题'), findsNWidgets(4));
      // 4 个 name
      expect(find.text('咖啡角落'), findsOneWidget);
      expect(find.text('拉花艺术'), findsOneWidget);
      expect(find.text('窗边阅读'), findsOneWidget);
      expect(find.text('咖啡物语'), findsOneWidget);
    });

    testWidgets('tapping template card pushes /templates/detail',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击猜你喜欢第一张卡片
      await tester.tap(find.text('牡丹花下'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /templates/detail（无 templateId 参数，对齐 recommend.vue 原行为）
      expect(find.text('DETAIL_PAGE'), findsOneWidget);
    });

    testWidgets('renders LumiraNav with title 为你推荐', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '为你推荐'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('根据你的拍摄风格'), findsOneWidget,
            reason: 'theme=$theme');
        expect(find.text('猜你喜欢'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.text('根据你的拍摄风格'), findsOneWidget,
            reason: 'style=$style');
        expect(find.text('猜你喜欢'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
