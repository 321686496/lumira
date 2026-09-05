import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/app_theme.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/buttons/lumira_button.dart';
import 'package:lumira_app_flutter/shared/widgets/effects/bevel_surface.dart';
import 'package:lumira_app_flutter/shared/widgets/effects/pressable_recess.dart';
import 'package:lumira_app_flutter/shared/widgets/effects/recessed_surface.dart';

/// 诊断：主色背景按钮的文字颜色实际渲染值
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required UIStyle style,
    required ThemeKey theme,
  }) async {
    // 先清空上一轮组件树：Riverpod 不允许同一 element 更换 ProviderScope.parent
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
          home: Scaffold(
            body: Column(
              children: [
                LumiraButton(
                  variant: ButtonVariant.primary,
                  onPressed: () {},
                  child: const Text('LumiraButton主色'),
                ),
                LumiraButton(
                  variant: ButtonVariant.primary,
                  keepBrandOnPress: true,
                  onPressed: () {},
                  child: const Text('keepBrand主色'),
                ),
                Builder(
                  builder: (context) {
                    final tokens = ThemeTokens.of(theme);
                    return PressableRecess(
                      onTap: () {},
                      borderRadius: 9999,
                      raisedFill: tokens.brand,
                      bevelLight: ThemeTokens.brandBevelLight(tokens),
                      bevelDark: ThemeTokens.brandBevelDark(tokens),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          'PressableRecess新建',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.textInverse,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> checkTextColor(
    WidgetTester tester,
    String text, {
    required Color expectedBg,
    required String label,
  }) async {
    final finder = find.text(text);
    expect(finder, findsOneWidget, reason: '$label 应渲染出文字');
    final textWidget = tester.widget<Text>(finder);
    final ctx = tester.element(finder);
    final effective = DefaultTextStyle.of(ctx).style;
    final color = textWidget.style?.color ?? effective.color;
    debugPrint(
        '[diag] $label: textColor=$color expectedBg=$expectedBg same=${color == expectedBg}');
  }

  testWidgets('主色按钮文字颜色诊断（全部主题×风格）', (tester) async {
    for (final theme in ThemeKey.values) {
      for (final style in UIStyle.values) {
        await pumpButton(tester, style: style, theme: theme);
        final tokens = ThemeTokens.of(theme);
        await checkTextColor(tester, 'LumiraButton主色',
            expectedBg: tokens.brand, label: 'LumiraButton $theme/$style');
        await checkTextColor(tester, 'keepBrand主色',
            expectedBg: tokens.brand, label: 'keepBrand $theme/$style');
        await checkTextColor(tester, 'PressableRecess新建',
            expectedBg: tokens.brand, label: 'PressableRecess $theme/$style');
      }
    }
  });

  testWidgets('主色按钮按压态保持主色（新拟态）', (tester) async {
    await pumpButton(tester,
        style: UIStyle.neumorphic, theme: ThemeKey.warmWhite);

    final finder = find.byType(LumiraButton).first;
    final center = tester.getCenter(finder);
    final gesture = await tester.startGesture(center);
    await tester.pump();

    // primary 按压：不切换凹陷表面，保持品牌色 + 反转内斜边
    expect(find.byType(RecessedSurface), findsNothing,
        reason: '主色按钮按压不应切换为凹陷表面');
    expect(find.byType(BevelRoundedSurface), findsOneWidget,
        reason: '主色按钮按压应使用反转内斜边');
    expect(find.text('LumiraButton主色'), findsOneWidget,
        reason: '按压时文字仍应显示');

    await gesture.up();
    await tester.pump();
    expect(find.byType(RecessedSurface), findsNothing);
  });
}
