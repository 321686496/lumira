import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/splash/pages/splash_page.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrapWithRouter(Widget child, {ThemeKey theme = ThemeKey.warmWhite}) {
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOME'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('SplashPage renders logo + title + caption + brand halo', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('如画 Lumira'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
    expect(find.byType(LumiraLogo), findsOneWidget);
    // 主题色光晕：用 Stack + Container(circle + RadialGradient)
    expect(find.byType(Stack), findsWidgets);
  });

  testWidgets('SplashPage uses tokens.canvas as background', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    expect(scaffold.backgroundColor, tokens.canvas);
  });

  testWidgets('SplashPage renders across 8 themes without error',
      (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(_wrapWithRouter(const SplashPage(), theme: theme));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('如画 Lumira'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }
  });
}
