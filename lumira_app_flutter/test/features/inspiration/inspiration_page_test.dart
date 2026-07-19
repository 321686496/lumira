import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/pages/inspiration_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

// Forced fix: brief 的 import 路径 '../../../helpers/test_http_overrides.dart' 不正确（缺 test/ 前缀），
// 与其他 test/features/X/ 下的测试文件统一为 '../../../test/helpers/test_http_overrides.dart'。
// Forced fix: brief 漏掉 package:flutter/foundation.dart import（FlutterExceptionHandler 类型来源），
// 与 challenge_page_test.dart 同模式补齐。
import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.inspiration,
      routes: [
        GoRoute(
          path: RouteNames.inspiration,
          name: 'inspiration',
          builder: (_, __) => const InspirationPage(),
        ),
        GoRoute(
          path: RouteNames.captureSceneDetail,
          name: 'captureSceneDetail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SCENE_DETAIL'))),
        ),
        GoRoute(
          path: RouteNames.captureSceneManage,
          name: 'captureSceneManage',
          builder: (_, __) => const Scaffold(body: Center(child: Text('SCENE_MANAGE'))),
        ),
        GoRoute(
          path: RouteNames.galleryDiary,
          name: 'galleryDiary',
          builder: (_, __) => const Scaffold(body: Center(child: Text('GALLERY_DIARY'))),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) return;
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
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
    // Forced fix: brief 用 800x1800，但 _RecommendScenesCard 的 2x2 SceneRecoCard 网格
    // childAspectRatio=0.56 使单卡高度 ~627dp，2 行 ~1264dp，加上其他 section 总高 ~2600dp。
    // 「发现更多场景」链接位于 y≈2155，1800 视口下 tester.tap 无法 hit-test。
    // 增大视口到 800x2800 让所有内容（包括「发现更多场景」）进入可视区。
    tester.binding.window.physicalSizeTestValue = const Size(800, 2800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('InspirationPage', () {
    testWidgets('renders LumiraNav with title 灵感', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(InspirationPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '灵感'), findsOneWidget);
    });

    testWidgets('renders all 5 sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 1. 今日心情
      expect(find.text('今日心情'), findsOneWidget);
      // 7 mood labels
      expect(find.text('开心'), findsOneWidget);
      expect(find.text('甜酷'), findsOneWidget);
      expect(find.text('温柔'), findsOneWidget);
      expect(find.text('复古'), findsOneWidget);
      expect(find.text('清新'), findsOneWidget);
      expect(find.text('文艺'), findsOneWidget);
      expect(find.text('治愈'), findsOneWidget);

      // 2. 穿搭日记
      expect(find.text('穿搭日记'), findsOneWidget);
      expect(find.text('查看日记'), findsOneWidget);
      expect(find.text('连续打卡'), findsNWidgets(2)); // streak text + tag
      // Forced fix: brief 期望 findsOneWidget，但 mood pill '治愈' count 也是 7，
      // 与 outfit streak days 7 共渲染 2 个 Text('7')。改为 findsNWidgets(2)。
      expect(find.text('7'), findsNWidgets(2)); // streak days + mood 治愈 count
      expect(find.text('天'), findsOneWidget);
      expect(find.text('7月8日'), findsOneWidget);
      expect(find.text('7月7日'), findsOneWidget);

      // 3. 推荐场景
      expect(find.text('根据你的喜好推荐'), findsOneWidget);
      expect(find.text('基于你最近 30 天的拍摄记录'), findsOneWidget);
      expect(find.text('发现更多场景'), findsOneWidget);
      // 4 scene names (badgeText + name = 2 处每个)
      expect(find.text('咖啡馆'), findsNWidgets(2));
      expect(find.text('图书馆'), findsNWidgets(2));
      expect(find.text('居家温馨'), findsNWidgets(2));
      expect(find.text('黄昏剪影'), findsNWidgets(2));
      // scene tags
      expect(find.text('你最常去'), findsOneWidget);
      expect(find.text('新场景推荐'), findsOneWidget);
      expect(find.text('图书馆拍摄'), findsOneWidget);
      expect(find.text('黄昏剪影拍摄'), findsOneWidget);

      // 4. 探店打卡
      expect(find.text('探店打卡'), findsOneWidget);
      expect(find.text('23'), findsOneWidget); // checkin stat
      expect(find.text('个探店足迹'), findsOneWidget);
      expect(find.text('Manner Coffee 武康路店'), findsOneWidget);
      expect(find.text('野兽派花园'), findsOneWidget);
      expect(find.text('上海当代艺术博物馆'), findsOneWidget);

      // 5. 加载更多
      expect(find.text('加载更多灵感'), findsOneWidget);
    });

    testWidgets('tapping 查看日记 pushes /gallery/diary', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('查看日记'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('GALLERY_DIARY'), findsOneWidget);
    });

    testWidgets('tapping 发现更多场景 pushes /capture/scene-manage', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('发现更多场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('SCENE_MANAGE'), findsOneWidget);
    });

    testWidgets('tapping a scene card pushes /capture/scene-detail?sceneId=xxx', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击第一个场景卡片（咖啡馆）— 用 name 文本定位其祖先 SceneRecoCard
      // 由于 badge 和 name 都有「咖啡馆」，用 find.ancestor 精确定位卡片
      final card = find.ancestor(of: find.text('咖啡馆').first, matching: find.byType(GestureDetector));
      await tester.tap(card.first);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('SCENE_DETAIL'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(InspirationPage), findsOneWidget);
        expect(find.text('今日心情'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(InspirationPage), findsOneWidget);
        expect(find.text('今日心情'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
