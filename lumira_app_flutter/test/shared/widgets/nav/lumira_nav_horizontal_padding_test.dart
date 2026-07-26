import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(home: Scaffold(appBar: child as PreferredSizeWidget, body: const SizedBox())),
    );

void main() {
  testWidgets('LumiraNav default horizontalPadding is 24.0', (tester) async {
    await tester.pumpWidget(_wrap(LumiraNav(title: 'T')));
    await tester.pumpAndSettle();
    final nav = tester.widget<LumiraNav>(find.byType(LumiraNav));
    expect(nav.horizontalPadding, 24.0);
  });

  testWidgets('LumiraNav horizontalPadding=12 applies to leading Positioned', (tester) async {
    await tester.pumpWidget(_wrap(LumiraNav(
      title: 'T',
      horizontalPadding: 12.0,
      leading: const Text('L'),
    )));
    await tester.pumpAndSettle();
    // centerTitle=true default → leading uses Positioned(left: horizontalPadding)
    final positioned = find.byWidgetPredicate((w) =>
        w is Positioned && w.left == 12.0);
    expect(positioned, findsWidgets);
  });

  testWidgets('LumiraNav horizontalPadding=16 applies to non-centerTitle Padding', (tester) async {
    await tester.pumpWidget(_wrap(LumiraNav(
      title: 'T',
      centerTitle: false,
      horizontalPadding: 16.0,
      leading: const Text('L'),
    )));
    await tester.pumpAndSettle();
    // non-centerTitle branch uses Padding(EdgeInsets.symmetric(horizontal: horizontalPadding))
    final padding = find.byWidgetPredicate((w) =>
        w is Padding &&
        w.padding is EdgeInsets &&
        (w.padding as EdgeInsets).horizontal == 32.0); // 16 left + 16 right
    expect(padding, findsWidgets);
  });
}
