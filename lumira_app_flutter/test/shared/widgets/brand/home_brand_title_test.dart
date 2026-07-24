import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/preferences/home_wordmark_style.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/home_brand_title.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrap(Widget child, {HomeWordmarkStyle? style}) => ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        if (style != null)
          homeWordmarkStyleProvider.overrideWith((ref) => style),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('HomeBrandTitle', () {
    testWidgets('default style is logoEnglish', (tester) async {
      await tester.pumpWidget(_wrap(const HomeBrandTitle()));
      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsNothing);
    });

    testWidgets('logoEnglishChinese renders logo + Lumira + 如画', (tester) async {
      await tester.pumpWidget(_wrap(
        const HomeBrandTitle(),
        style: HomeWordmarkStyle.logoEnglishChinese,
      ));
      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });

    testWidgets('englishChinese renders Lumira + 如画 without logo', (tester) async {
      await tester.pumpWidget(_wrap(
        const HomeBrandTitle(),
        style: HomeWordmarkStyle.englishChinese,
      ));
      expect(find.byType(LumiraLogo), findsNothing);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });
  });
}
