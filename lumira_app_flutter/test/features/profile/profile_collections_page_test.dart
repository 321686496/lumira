import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_content_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_collections_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileCollections,
      routes: [
        GoRoute(
          path: RouteNames.profileCollections,
          name: 'profileCollections',
          builder: (_, __) => const ProfileCollectionsPage(),
        ),
        GoRoute(
          path: RouteNames.profileCollectionDetail,
          name: 'profileCollectionDetail',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('COLLECTION_DETAIL'))),
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
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileCollectionsPage', () {
    testWidgets('renders LumiraNav with title 我的精选集 and 4 collection cards', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileCollectionsPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我的精选集'), findsOneWidget);

      // 4 个 CollectionItem 对应 4 个 collection name
      // c1 我最爱的九张 / c2 旅行精选 / c3 穿搭合集 / c4 咖啡馆时光
      expect(find.text('我最爱的九张'), findsOneWidget);
      expect(find.text('旅行精选'), findsOneWidget);
      expect(find.text('穿搭合集'), findsOneWidget);
      expect(find.text('咖啡馆时光'), findsOneWidget);
    });

    testWidgets('renders collection names, counts, and updated dates', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // counts as '${count}张'
      expect(find.text('9张'), findsOneWidget);
      expect(find.text('24张'), findsOneWidget);
      expect(find.text('12张'), findsOneWidget);
      expect(find.text('8张'), findsOneWidget);

      // updated as '更新于 ${updated}'
      // c1: 7月10日, c2: 6月28日, c3: 7月10日, c4: 6月15日
      expect(find.text('更新于 6月28日'), findsOneWidget);
      expect(find.text('更新于 6月15日'), findsOneWidget);
      // '更新于 7月10日' 出现 2 次（c1 和 c3）
      expect(find.text('更新于 7月10日'), findsNWidgets(2));

      // 验证 mock 数据条目数与页面渲染一致
      expect(ProfileContentMockData.collections.length, 4);
    });

    testWidgets('tapping create button shows SnackBar with 新建精选集', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 找到 + 新建 按钮
      final createBtn = find.text('+ 新建');
      expect(createBtn, findsOneWidget);

      // 点击新建按钮
      await tester.tap(createBtn);
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 反馈
      expect(find.text('新建精选集'), findsOneWidget);
    });

    testWidgets('tapping a collection card pushes /profile/collection-detail', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击第一个 collection card
      await tester.tap(find.text('我最爱的九张'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应跳转到 collection-detail
      expect(find.text('COLLECTION_DETAIL'), findsOneWidget);
    });

    testWidgets('renders tip section with 精选集功能 hint', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('精选集功能'), findsOneWidget);
      expect(
        find.text('将喜欢的照片整理成集，一键导出九宫格拼图'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileCollectionsPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('旅行精选'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileCollectionsPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('旅行精选'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
