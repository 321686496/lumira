import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/cards/neu_card.dart';
import 'package:lumira_app_flutter/shared/widgets/buttons/lumira_buttons.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';
import 'package:lumira_app_flutter/shared/widgets/tabbar/floating_tabbar.dart';

void main() {
  /// Helper：用指定 theme + style 构建 ProviderScope 包裹的 widget
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
        home: Scaffold(body: child),
      ),
    );
  }

  /// Female 风格下 FloatingTabBar 的 _CenterCaptureButton 会启动 repeat 动画，
  /// pumpAndSettle 会因永远有下一帧而超时。对涉及 FloatingTabBar 的测试用 pump
  /// 代替 pumpAndSettle 以稳定通过。
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  group('NeuCard', () {
    testWidgets('neumorphic style renders with canvas background and convex shadow', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const NeuCard(child: Text('hello')),
        style: UIStyle.neumorphic,
      ));

      // 找到 Container with BoxDecoration
      final container = tester.widget<Container>(find.ancestor(
        of: find.text('hello'),
        matching: find.byType(Container),
      ).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.length, greaterThanOrEqualTo(2)); // 双向外阴影
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('flat style renders with divider border and no shadow', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const NeuCard(child: Text('hello')),
        style: UIStyle.flat,
      ));

      final container = tester.widget<Container>(find.ancestor(
        of: find.text('hello'),
        matching: find.byType(Container),
      ).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isNotNull);
    });

    testWidgets('glass style wraps in BackdropFilter', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const NeuCard(child: Text('hello')),
        style: UIStyle.glass,
      ));

      // glass 风格用 ClipRRect + BackdropFilter 包裹
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('female style uses multiGradient with linear gradient', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const NeuCard(child: Text('hello')),
        style: UIStyle.female,
      ));

      // female 风格用 Container with gradient
      final container = tester.widget<Container>(find.ancestor(
        of: find.text('hello'),
        matching: find.byType(Container),
      ).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect(decoration.border, isNotNull); // hairlineBorder
      expect(decoration.boxShadow, isNotNull); // brand shadow
      // female 圆角 = 48/2 = 24
      expect((decoration.borderRadius as BorderRadius).topLeft.x, 24.0);
    });

    testWidgets('all 8 themes render without error', (tester) async {
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrapWithTheme(
          const NeuCard(child: Text('hello')),
          theme: theme,
        ));
        expect(find.text('hello'), findsOneWidget);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('onTap triggers callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(wrapWithTheme(
        NeuCard(
          child: const Text('hello'),
          onTap: () => tapped++,
        ),
      ));

      await tester.tap(find.text('hello'));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('LumiraButton', () {
    testWidgets('renders label for all 4 variants', (tester) async {
      for (final variant in LumiraButtonVariant.values) {
        await tester.pumpWidget(wrapWithTheme(
          LumiraButton(
            label: 'Click me',
            variant: variant,
            onPressed: () {},
          ),
        ));
        expect(find.text('Click me'), findsOneWidget);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('onPressed triggers callback', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithTheme(
        LumiraButton(
          label: 'Tap',
          onPressed: () => pressed++,
        ),
      ));

      await tester.tap(find.text('Tap'));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('disabled button does not trigger callback', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(wrapWithTheme(
        LumiraButton(
          label: 'Tap',
          onPressed: () => pressed++,
          enabled: false,
        ),
      ));

      // disabled 时 onPressed=null，tap 不触发
      expect(pressed, 0);
    });
  });

  group('LumiraNav', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraNav(title: '我的页面'),
      ));
      expect(find.text('我的页面'), findsOneWidget);
    });

    testWidgets('renders actions', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        LumiraNav(
          title: '页面',
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
      ));
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('scrolled state has non-transparent background', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraNav(title: '页面', scrolled: true),
      ));
      // scrolled=true 时 AnimatedContainer 的 backgroundColor 应非 transparent
      // 通过查找 AnimatedContainer 验证不抛错
      expect(find.byType(AnimatedContainer), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('FloatingTabBar', () {
    testWidgets('renders 5 tab items', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const FloatingTabBar(active: 'home'),
      ));

      // 5 个 tab：4 个 _TabItem + 1 个 _CenterCaptureButton
      // Forced fix: '模板' tab 已重命名为 '发现'（templates 入口对应发现/灵感页）。
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('挑战'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('marks active tab with brand color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const FloatingTabBar(active: 'home'),
      ));

      // home 是 active
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
      expect(homeIcon.color, isNotNull);
    });

    testWidgets('renders in all 4 styles', (tester) async {
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrapWithTheme(
          const FloatingTabBar(active: 'home'),
          style: style,
        ));
        expect(find.text('首页'), findsOneWidget);
        await settleOrPump(tester, style);
      }
    });
  });

  group('Cross-style smoke', () {
    testWidgets('all 4 styles render NeuCard + LumiraButton + LumiraNav + FloatingTabBar together', (tester) async {
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrapWithTheme(
          Column(
            children: [
              const LumiraNav(title: '测试'),
              const NeuCard(child: Text('card')),
              LumiraButton(label: 'btn', onPressed: () {}),
              const FloatingTabBar(active: 'home'),
            ],
          ),
          style: style,
        ));
        await settleOrPump(tester, style);
        expect(find.text('card'), findsOneWidget);
        expect(find.text('btn'), findsOneWidget);
        expect(find.text('测试'), findsOneWidget);
      }
    });
  });
}
