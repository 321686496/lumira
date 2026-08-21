import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/tags/tag_chip.dart';

void main() {
  /// 用指定 theme + style 包裹，使 TagChip 的 4 风格 × 主题自适应可被测试。
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

  /// female 风格带 repeat 动画阴影，pumpAndSettle 会超时，改用 pump。
  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
  }

  // 定位 TagChip 的 BoxDecoration（chip 内容外包一层 Container）
  BoxDecoration? decoOf(WidgetTester tester, String label) {
    final container = tester.widget<Container>(find.ancestor(
      of: find.text(label),
      matching: find.byType(Container),
    ).first);
    return container.decoration as BoxDecoration?;
  }

  group('TagChip 4 风格渲染', () {
    for (final style in UIStyle.values) {
      testWidgets('plain 标签在 $style 风格下渲染标签文本', (tester) async {
        await tester.pumpWidget(wrapWithTheme(
          const TagChip(label: '自定义'),
          style: style,
        ));
        expect(find.text('自定义'), findsOneWidget);
        await settleOrPump(tester, style);
      });

      testWidgets('system 标签在 $style 风格下渲染（带星形图标，无“系统”文本）', (tester) async {
        await tester.pumpWidget(wrapWithTheme(
          const TagChip(label: '日系', kind: TagChipKind.system),
          style: style,
        ));
        expect(find.text('日系'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget); // 特殊视觉标识
        expect(find.textContaining('系统'), findsNothing); // 不含“系统”二字
        await settleOrPump(tester, style);
      });

      testWidgets('golden 标签在 $style 风格下渲染', (tester) async {
        await tester.pumpWidget(wrapWithTheme(
          const TagChip(label: '推荐', kind: TagChipKind.golden),
          style: style,
        ));
        expect(find.text('推荐'), findsOneWidget);
        await settleOrPump(tester, style);
      });
    }
  });

  group('TagChip 交互', () {
    testWidgets('点击触发 onTap（呼吸反馈）', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(wrapWithTheme(
        TagChip(label: '人像', onTap: () => tapped++),
      ));
      await tester.tap(find.text('人像'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('提供 onDeleted 时显示关闭按钮并触发', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(wrapWithTheme(
        TagChip(label: '胶片', onDeleted: () => deleted++),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(deleted, 1);
    });

    testWidgets('选中态使用品牌实底', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const TagChip(label: '已选', selected: true),
      ));
      final deco = decoOf(tester, '已选');
      expect(deco, isNotNull);
      expect(deco!.color, isNotNull);
      // 选中态品牌色：与文本色反色（textInverse → 白）
      final text = tester.widget<Text>(find.text('已选'));
      expect(text.style?.color, isNotNull);
    });
  });

  group('TagChip 8 主题', () {
    testWidgets('全部主题渲染无错误', (tester) async {
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrapWithTheme(
          const TagChip(label: '主题', kind: TagChipKind.system),
          theme: theme,
        ));
        expect(find.text('主题'), findsOneWidget);
        await tester.pumpAndSettle();
      }
    });
  });
}