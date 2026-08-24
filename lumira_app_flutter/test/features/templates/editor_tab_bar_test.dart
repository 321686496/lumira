import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/widgets/editor_tab_bar.dart';

void main() {
  /// 空回调，用于渲染冒烟测试。
  void noop(int index) {}

  /// 用指定 theme + style 包裹，使 EditorTabBar 的 4 风格 × 主题自适应可被测试。
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

  final tabs = ['基本信息', '常用设置', '高级选项', '预览'];

  group('EditorTabBar 渲染', () {
    for (final style in UIStyle.values) {
      for (final theme in [ThemeKey.warmWhite, ThemeKey.ink]) {
        testWidgets('$theme · $style 渲染出所有 tab 且选中态高亮不抛异常',
            (tester) async {
          var selected = -1;
          await tester.pumpWidget(wrapWithTheme(
            EditorTabBar(
              tabs: tabs,
              index: 1,
              onSelect: (i) => selected = i,
            ),
            theme: theme,
            style: style,
          ));
          await tester.pump();

          // 所有 tab 文本均可找到
          for (final label in tabs) {
            expect(find.text(label), findsOneWidget);
          }

          // 选中 tab 的字体加粗（w600），区别于未选中
          final selectedText = tester.widget<Text>(find.text(tabs[1]));
          expect(selectedText.style?.fontWeight, FontWeight.w600);

          // 点击未选中 tab 触发 onSelect
          await tester.tap(find.text(tabs[0]));
          await tester.pump();
          expect(selected, 0);
        });
      }
    }
  });

  group('EditorTabBar 全部主题', () {
    testWidgets('全部 8 主题渲染无错误', (tester) async {
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrapWithTheme(
          EditorTabBar(
            tabs: const ['A', 'B', 'C'],
            index: 0,
            onSelect: noop,
          ),
          theme: theme,
        ));
        await tester.pump();
        expect(find.text('A'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        expect(find.text('C'), findsOneWidget);
      }
    });
  });
}