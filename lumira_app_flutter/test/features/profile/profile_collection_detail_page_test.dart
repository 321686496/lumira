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
import 'package:lumira_app_flutter/features/profile/pages/profile_collection_detail_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileCollectionDetail,
      routes: [
        GoRoute(
          path: RouteNames.profileCollectionDetail,
          name: 'profileCollectionDetail',
          builder: (_, __) =>
              const ProfileCollectionDetailPage(collectionId: 'c1'),
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

  group('ProfileCollectionDetailPage', () {
    testWidgets('renders LumiraNav with title 我最爱的九张 and 9 photo cells', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileCollectionDetailPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我最爱的九张'), findsOneWidget);

      // 9 张照片（mock 数据 9 个 PhotoItem）
      expect(ProfileContentMockData.photos.length, 9);
      // 9 个 Image.network widget（网络图片加载失败显示 broken_image_outlined）
      expect(
        find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
        findsNWidgets(9),
      );
    });

    testWidgets('renders 3-column grid with 9 photo cells', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证 GridView 存在且 crossAxisCount 为 3
      final gridView = find.byType(GridView);
      expect(gridView, findsOneWidget);
      final sliver = tester.widget<GridView>(gridView);
      expect(sliver.gridDelegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      final delegate = sliver.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('renders stats section with 9 / 7.9 / 7/1', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 3 个统计数字
      expect(find.text('9'), findsOneWidget);
      expect(find.text('7.9'), findsOneWidget);
      expect(find.text('7/1'), findsOneWidget);

      // 3 个标签
      expect(find.text('张照片'), findsOneWidget);
      expect(find.text('平均评分'), findsOneWidget);
      expect(find.text('创建日'), findsOneWidget);
    });

    testWidgets('renders export section with export button text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 导出按钮
      expect(find.text('导出九宫格拼图'), findsOneWidget);
      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
      // 提示文字
      expect(
        find.text('导出的拼图可直接分享到社交媒体'),
        findsOneWidget,
      );
    });

    testWidgets('tapping edit button shows SnackBar with 编辑精选集', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      final editBtn = find.text('编辑');
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('编辑精选集'), findsOneWidget);
    });

    testWidgets('tapping export button shows SnackBar with 导出九宫格拼图', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 导出按钮是包含 '导出九宫格拼图' 文字的 GestureDetector
      final exportBtn = find.text('导出九宫格拼图');
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 也显示 '导出九宫格拼图'，所以应该有 2 个匹配
      expect(find.text('导出九宫格拼图'), findsNWidgets(2));
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileCollectionDetailPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('我最爱的九张'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('7.9'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileCollectionDetailPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('我最爱的九张'), findsOneWidget, reason: 'style=$style');
        expect(find.text('7.9'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
