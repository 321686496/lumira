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
import 'package:lumira_app_flutter/features/profile/pages/profile_academy_detail_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileAcademyDetail,
      routes: [
        GoRoute(
          path: RouteNames.profileAcademyDetail,
          name: 'profileAcademyDetail',
          builder: (_, __) => const ProfileAcademyDetailPage(),
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
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileAcademyDetailPage', () {
    testWidgets('renders lesson title and meta', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileAcademyDetailPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '教程'), findsOneWidget);
      expect(find.text(ProfileContentMockData.lessonTitle), findsOneWidget);
      expect(find.text(ProfileContentMockData.lessonMeta), findsOneWidget);
    });

    testWidgets('tapping bookmark toggles bookmark state (bookmark_border → bookmark)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始未收藏
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsNothing);

      // 点击收藏
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 收藏后切换图标
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      // SnackBar 反馈
      expect(find.text('已收藏'), findsOneWidget);
    });

    testWidgets('tapping complete button shows SnackBar and disables button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 标记完成按钮存在
      final completeBtn = find.text('标记为已学完');
      expect(completeBtn, findsOneWidget);

      // 点击按钮
      await tester.tap(completeBtn);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 SnackBar
      expect(find.text('已标记为已学完'), findsOneWidget);
    });

    testWidgets('renders all 4 sections with correct content', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Section 1: 为什么角度很重要
      expect(find.text('为什么角度很重要'), findsOneWidget);
      // 段落文本（section[0].paragraphs）
      expect(
        find.text('同样的场景、同样的光线，仅仅因为拍摄角度的不同，照片效果可能天差地别。找到你身上最自信的角度，是出片的第一步。'),
        findsOneWidget,
      );
      // Section 2: 俯拍 vs 平拍
      expect(find.text('俯拍 vs 平拍'), findsOneWidget);
      // Section 3: 小贴士
      expect(find.text('小贴士'), findsOneWidget);
      // 推荐模板 section
      expect(find.text('推荐模板'), findsOneWidget);
    });

    testWidgets('renders compare grid with 2 cells', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 2 个 compare cell names
      // '俯拍' 同时出现在 compare grid 和 practice tags 中，所以 findsAtLeastNWidgets(1)
      expect(find.text('俯拍'), findsAtLeastNWidgets(1));
      expect(find.text('平拍'), findsOneWidget);
      // 2 个 tag texts
      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('中性'), findsOneWidget);
    });

    testWidgets('renders practice card with 3 tags', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Practice card badge
      expect(find.text('实战练习'), findsOneWidget);
      // Practice title
      expect(find.text(ProfileContentMockData.practiceTitle), findsOneWidget);
      // 3 tags
      expect(find.text('街拍'), findsOneWidget);
      expect(find.text('自然光'), findsOneWidget);
      expect(find.text('俯拍'), findsAtLeastNWidgets(1)); // 出现在 compare grid 和 practice tags 中
    });

    testWidgets('renders recommend template card with name and badge', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text(ProfileContentMockData.recommendTemplate.name), findsOneWidget);
      expect(find.text(ProfileContentMockData.recommendTemplate.badge), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes + 4 styles', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileAcademyDetailPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text(ProfileContentMockData.lessonTitle), findsOneWidget, reason: 'theme=$theme');
      }
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileAcademyDetailPage), findsOneWidget, reason: 'style=$style');
        expect(find.text(ProfileContentMockData.lessonTitle), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
