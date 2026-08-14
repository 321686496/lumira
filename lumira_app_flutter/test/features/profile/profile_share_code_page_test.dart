import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_share_code_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileShareCode,
      routes: [
        GoRoute(
          path: RouteNames.profileShareCode,
          name: 'profileShareCode',
          builder: (_, __) => const ProfileShareCodePage(),
        ),
        // 占位路由：邀请好友按钮会 push 到此路径
        GoRoute(
          path: RouteNames.profileInvite,
          name: 'profileInvite',
          builder: (_, __) => const Scaffold(body: Center(child: Text('INVITE'))),
        ),
      ],
    );
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

  /// female 风格的 FloatingTabBar / 多渐变卡片有循环动画，
  /// 用 pump 代替 pumpAndSettle 避免超时。
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

  group('ProfileShareCodePage', () {
    testWidgets('renders LumiraNav with title 分享码', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileShareCodePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '分享码'), findsOneWidget);
    });

    testWidgets('renders all 4 sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Section 1: 输入区
      expect(find.text('输入分享码 / 邀请码'), findsOneWidget);
      expect(find.text('导入'), findsOneWidget);
      expect(find.text('打开模板导入'), findsOneWidget);

      // Section 2: 奖励说明（4 项）
      expect(find.text('输入分享码能获得什么'), findsOneWidget);
      expect(find.text('解锁对应分类的精选模板（限免 7 天）'), findsOneWidget);
      expect(find.text('获得 50 积分（可兑换其他模板）'), findsOneWidget);
      expect(find.text('解锁场景拍摄指导'), findsOneWidget);
      expect(find.text('优先体验新功能'), findsOneWidget);

      // Section 3: 使用规则（4 项）
      expect(find.text('使用规则'), findsOneWidget);
      expect(find.text('每个分享码只能使用一次'), findsOneWidget);
      expect(find.text('分享码有效期 30 天'), findsOneWidget);
      expect(find.text('同一分类分享码不能重复使用'), findsOneWidget);
      expect(find.text('奖励将在导入后自动入账'), findsOneWidget);

      // Section 4: 获取更多分享码
      expect(find.text('获取更多分享码'), findsOneWidget);
      expect(
        find.text('关注官方账号 / 邀请好友 / 完成挑战任务可获得更多分享码'),
        findsOneWidget,
      );
      expect(find.text('邀请好友'), findsOneWidget);
    });

    testWidgets('tapping 导入 with empty code shows error SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('导入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // LumiraToast（自定义 Overlay，非原生 SnackBar）
      expect(find.text('请输入分享码'), findsOneWidget);
    });

    testWidgets('tapping 导入 with invalid code shows error SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.enterText(
        find.byType(TextField),
        'INVALID-CODE',
      );
      await tester.pump();

      await tester.tap(find.text('导入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // LumiraToast（自定义 Overlay，非原生 SnackBar）
      expect(find.text('分享码格式无效'), findsOneWidget);
    });

    testWidgets('tapping 导入 with valid code shows recognized SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.enterText(
        find.byType(TextField),
        'LUMIRA-portrait-mood',
      );
      await tester.pump();

      await tester.tap(find.text('导入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // LumiraToast（自定义 Overlay，非原生 SnackBar）
      expect(
        find.textContaining('分享码已识别：LUMIRA-portrait-mood'),
        findsOneWidget,
      );
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileShareCodePage), findsOneWidget,
            reason: 'theme=$theme');
        expect(find.text('输入分享码 / 邀请码'), findsOneWidget,
            reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileShareCodePage), findsOneWidget,
            reason: 'style=$style');
        expect(find.text('输入分享码 / 邀请码'), findsOneWidget,
            reason: 'style=$style');
      }
    });
  });
}
