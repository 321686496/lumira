import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/home/widgets/hero_card.dart';

void main() {
  Widget _wrap({
    required HeroInspiration inspiration,
    VoidCallback? onCapture,
  }) {
    final router = GoRouter(
      initialLocation: RouteNames.home,
      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (_, __) =>
              Center(child: HeroCard(onCapture: onCapture ?? () {})),
        ),
        GoRoute(
          path: RouteNames.capture,
          builder: (context, state) {
            final tid = state.queryParams[RouteNames.paramTemplateId] ?? '';
            return Scaffold(body: Center(child: Text('CAPTURE:$tid')));
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        homeInspirationProvider.overrideWith((ref) async => inspiration),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('有推荐时按钮显示模板名并带 templateId 跳转拍摄页', (tester) async {
    final inspiration = HeroInspiration(
      dateText: '8月23日',
      title: '今日灵感',
      description: '捕捉光',
      weatherText: '',
      recommendedTemplateId: 'soft_portrait',
      recommendedTemplateName: '柔光人像',
    );
    await tester.pumpWidget(_wrap(inspiration: inspiration));
    await tester.pumpAndSettle();

    expect(find.textContaining('柔光人像'), findsOneWidget);
    expect(find.text('开始拍摄'), findsNothing);

    await tester.tap(find.textContaining('柔光人像'));
    await tester.pumpAndSettle();

    expect(find.text('CAPTURE:soft_portrait'), findsOneWidget);
  });

  testWidgets('无推荐时按钮仍是「开始拍摄」并走 onCapture', (tester) async {
    var captured = false;
    final inspiration = HeroInspiration(
      dateText: '8月23日',
      title: '今日灵感',
      description: '捕捉光',
      weatherText: '',
    );
    await tester.pumpWidget(_wrap(
      inspiration: inspiration,
      onCapture: () => captured = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('开始拍摄'), findsOneWidget);

    await tester.tap(find.text('开始拍摄'));
    // pump 一帧触发回调（不跳路由）
    await tester.pump();
    expect(captured, isTrue);
  });
}