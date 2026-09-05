import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/app_theme.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/buttons/lumira_button.dart';

void main() {
  Future<void> pumpPrimary(
    WidgetTester tester, {
    required UIStyle style,
    required ThemeKey theme,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => style),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: () {},
                child: const Text('去拍摄'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('golden: 主色按钮 neumorphic 常态', (tester) async {
    await pumpPrimary(tester, style: UIStyle.neumorphic, theme: ThemeKey.warmWhite);
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/btn_neu_normal.png'));
  });

  testWidgets('golden: 主色按钮 neumorphic 按压', (tester) async {
    await pumpPrimary(tester, style: UIStyle.neumorphic, theme: ThemeKey.warmWhite);
    final center = tester.getCenter(find.byType(LumiraButton));
    final g = await tester.startGesture(center);
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/btn_neu_pressed.png'));
    await g.up();
    await tester.pump();
  });

  testWidgets('golden: 次色按钮 neumorphic 常态(参照)', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: () {},
                child: const Text('导入照片'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/btn_neu_secondary.png'));
  });
}