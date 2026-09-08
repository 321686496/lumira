import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/common/lumira_surface.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    ThemeKey theme = ThemeKey.warmWhite,
    UIStyle style = UIStyle.neumorphic,
  }) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => theme),
        uiStyleProvider.overrideWith((ref) => style),
      ],
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: child),
        ),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(find.ancestor(
      of: find.text('hello'),
      matching: find.byType(Container),
    ).first);
    return container.decoration as BoxDecoration;
  }

  group('LumiraSurface.darkContext 新拟态暗色语境', () {
    testWidgets('darkContext=true 渲染近黑卡面 + 双向浮雕明暗梯度', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(darkContext: true, child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      final expectedBg = Color.lerp(Colors.black, tokens.canvas, 0.10)!;

      expect(deco.color, expectedBg);
      expect(deco.boxShadow, isNotNull);
      expect(deco.boxShadow!.length, 2);

      // 梯度：高光 > 卡面 > 暗影（黑底上的真浮雕方向感）
      final dark = deco.boxShadow![0];
      final light = deco.boxShadow![1];
      expect(light.color.computeLuminance(),
          greaterThan(dark.color.computeLuminance()));
      expect(light.color.computeLuminance(),
          greaterThan(expectedBg.computeLuminance()));
      expect(expectedBg.computeLuminance(),
          greaterThan(dark.color.computeLuminance()));
      // 暗影右下、高光左上（轻量档 offset）
      expect(dark.offset, const Offset(4, 4));
      expect(light.offset, const Offset(-4, -4));
    });

    testWidgets('darkContext=true + emphasize 用强浮雕偏移', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(
            darkContext: true, emphasize: true, child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      expect(deco.boxShadow![0].offset, const Offset(6, 6));
      expect(deco.boxShadow![1].offset, const Offset(-6, -6));
    });

    testWidgets('darkContext=false 保持原有浅色卡表现', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      expect(deco.color, tokens.surface);
      expect(deco.boxShadow, tokens.shadowConvexSubtle);
    });

    testWidgets('ink 主题下 darkContext 同样成立明暗梯度', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(darkContext: true, child: Text('hello')),
        theme: ThemeKey.ink,
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.ink);
      expect(deco.color, Color.lerp(Colors.black, tokens.canvas, 0.10)!);
      expect(deco.boxShadow![1].color.computeLuminance(),
          greaterThan(deco.boxShadow![0].color.computeLuminance()));
    });

    testWidgets('flat/glass/female 风格不受 darkContext 影响', (tester) async {
      for (final style in [UIStyle.flat, UIStyle.glass, UIStyle.female]) {
        await tester.pumpWidget(wrapWithTheme(
          const LumiraSurface(darkContext: true, child: Text('hello')),
          style: style,
        ));
        await tester.pumpAndSettle();

        final deco = decorationOf(tester);
        expect(deco.color, isNotNull);
        if (style == UIStyle.flat) {
          final tokens = ThemeTokens.of(ThemeKey.warmWhite);
          expect(deco.color, tokens.surfaceAlt);
        }
      }
    });
  });
}
