import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_providers.dart';
import 'package:lumira_app_flutter/features/home/data/inspiration_models.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_guide_bar.dart';

void main() {
  testWidgets('renders inspiration text from provider and triggers onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        homeInspirationProvider.overrideWith((ref) async => const HeroInspiration(
              dateText: '8月14日 星期五 · 光线极佳',
              title: '今日灵感',
              description: '适合拍人像',
              weatherText: '28°C 晴 · 黄金时刻 17:00',
            )),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InspirationGuideBar(
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('8月14日 星期五 · 光线极佳'), findsOneWidget);
    expect(find.textContaining('适合拍人像'), findsOneWidget);

    await tester.tap(find.byType(InspirationGuideBar));
    expect(tapped, isTrue);
  });
}
