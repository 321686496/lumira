import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_about_page.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/about',
    routes: [
      GoRoute(
        path: '/about',
        builder: (context, state) => const ProfileAboutPage(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('ProfileAboutPage renders brand logo with halo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(LumiraLogo), findsOneWidget);
    expect(find.text('如画 Lumira'), findsOneWidget);
  });
}
