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
  group('LumiraNav centerTitle', () {
    testWidgets('centerTitle=true (default) renders title centered', (tester) async {
      await tester.pumpWidget(_wrap(const LumiraNav(title: '发现')));
      expect(find.text('发现'), findsOneWidget);
    });

    testWidgets('centerTitle=false renders title without Center widget',
        (tester) async {
      await tester.pumpWidget(_wrap(const LumiraNav(
        title: '发现',
        centerTitle: false,
        showBackButton: false,
      )));
      expect(find.text('发现'), findsOneWidget);
      // 验证不再有 Center 强制居中
      expect(find.byType(Center), findsNothing);
    });
  });
}
