import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/watermark/pages/watermark_editor_page.dart';

const _presetMinimal = 'preset_minimal_date';

void main() {
  Future<void> pumpFor(
    WidgetTester tester,
    UIStyle uiStyle,
  ) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => uiStyle),
        ],
        child: const MaterialApp(
          home: WatermarkEditorPage(templateId: _presetMinimal),
        ),
      ),
    );
    await tester.pump();
    if (uiStyle == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final style in UIStyle.values) {
    testWidgets('编辑页在 ${style.name} 风格下渲染不抛异常且关键 key 存在',
        (tester) async {
      await pumpFor(tester, style);

      // 不抛异常 = 通过（pump 过程中异常会使测试 fail）
      expect(find.byKey(const ValueKey('wm-preview-area')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-element')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-style')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-border')), findsOneWidget);
    });

    testWidgets('编辑页 ${style.name} 下可切到样式 Tab 并渲染滑块文本输入',
        (tester) async {
      await pumpFor(tester, style);
      // 先新增一个文本元素（自动选中），保证样式 Tab 能渲染字号/透明度滑块
      await tester.tap(find.text('＋文本'));
      await tester.pump(const Duration(milliseconds: 400)); // waiting breathing tap rebound
      await tester.tap(find.byKey(const ValueKey('wm-tab-style')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // 样式 Tab 选中一个元素后应出现字号/透明度标签（Text 来自 _sliderRow）
      expect(find.text('字号'), findsWidgets);
      expect(find.text('透明度'), findsWidgets);
    });
  }
}