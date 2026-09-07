import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/reward_center_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileRedeem,
      routes: [
        GoRoute(
          path: RouteNames.profileRedeem,
          name: 'profileRedeem',
          builder: (_, __) => const RewardCenterPage(),
        ),
        // 占位路由：我的奖励 / 邀请有礼 会 push 到此路径
        GoRoute(
          path: RouteNames.profileRewards,
          name: 'profileRewards',
          builder: (_, __) => const Scaffold(body: Center(child: Text('REWARDS'))),
        ),
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

  group('RewardCenterPage', () {
    testWidgets('renders LumiraNav with title 兑换码', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(RewardCenterPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '兑换码'), findsOneWidget);
    });

    testWidgets('renders all sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 兑换码输入区
      expect(find.text('输入兑换码'), findsOneWidget);
      expect(find.text('立即兑换'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

      // 兑换说明
      expect(find.text('兑换说明'), findsOneWidget);
      expect(find.text('每个兑换码只能使用一次，兑换后即作废'), findsOneWidget);

      // 快捷入口
      expect(find.text('我的奖励'), findsOneWidget);
      expect(find.text('邀请有礼'), findsOneWidget);
    });

    testWidgets('tapping 我的奖励 pushes rewards page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('我的奖励'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('REWARDS'), findsOneWidget);
    });

    testWidgets('tapping 邀请有礼 pushes invite page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('邀请有礼'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('INVITE'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(RewardCenterPage), findsOneWidget,
            reason: 'theme=$theme');
        expect(find.text('立即兑换'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(RewardCenterPage), findsOneWidget,
            reason: 'style=$style');
        expect(find.text('立即兑换'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}