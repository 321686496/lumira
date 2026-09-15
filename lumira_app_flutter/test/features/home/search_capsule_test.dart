import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/widgets/search_capsule.dart';

void main() {
  testWidgets('SearchCapsule 显示占位文案，点击跳转 /search', (tester) async {
    final router = GoRouter(
      initialLocation: RouteNames.home,
      routes: [
        GoRoute(
          path: RouteNames.home,
          name: 'home',
          builder: (context, state) => const Scaffold(body: SearchCapsule()),
        ),
        GoRoute(
          path: RouteNames.search,
          name: 'search',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('SEARCH_PAGE'))),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('搜索模板 / 场景 / 拍摄教程'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.text('搜索模板 / 场景 / 拍摄教程'));
    await tester.pumpAndSettle();

    expect(find.text('SEARCH_PAGE'), findsOneWidget);
  });
}
