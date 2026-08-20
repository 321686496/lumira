import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/pages/watermark_editor_page.dart';

/// 预置模板「简约日期」的真实 id（与 preset_watermarks.dart 一致）。
/// 该模板含 3 个文本元素、无画框（frame.type == none）。
const _presetMinimal = 'preset_minimal_date';

void main() {
  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: const MaterialApp(
        home: WatermarkEditorPage(templateId: _presetMinimal),
      ),
    );
  }

  Future<void> settle(WidgetTester tester, UIStyle style) async {
    await tester.pump();
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  WatermarkEditorPageState editorState(WidgetTester tester) {
    return tester.state<WatermarkEditorPageState>(
      find.byType(WatermarkEditorPage),
    );
  }

  group('WatermarkEditorPage 模板模式', () {
    testWidgets('渲染编辑页不崩溃，预览区存在，底部操作栏默认展开含 3 个 Tab',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      expect(find.byType(WatermarkEditorPage), findsOneWidget);
      // 预览区（照片 contain 区）
      expect(find.byKey(const ValueKey('wm-preview-area')), findsOneWidget);
      // 底部操作栏默认展开，三 Tab
      expect(find.text('元素'), findsOneWidget);
      expect(find.text('样式'), findsOneWidget);
      expect(find.text('边框'), findsOneWidget);
    });

    testWidgets('点击收起折叠为细条，可重新展开', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      // 收起
      await tester.tap(find.byKey(const ValueKey('wm-panel-collapse')));
      await settle(tester, UIStyle.neumorphic);
      expect(find.text('元素'), findsNothing);
      expect(find.byKey(const ValueKey('wm-panel-expand')), findsOneWidget);

      // 重新展开
      await tester.tap(find.byKey(const ValueKey('wm-panel-expand')));
      await settle(tester, UIStyle.neumorphic);
      expect(find.text('元素'), findsOneWidget);
      expect(find.text('样式'), findsOneWidget);
      expect(find.text('边框'), findsOneWidget);
    });

    testWidgets('元素 Tab：＋文本新增元素、可删除', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      final initialCount = editorState(tester).template.elements.length;
      expect(initialCount, greaterThan(0));

      // 新增文本元素
      await tester.tap(find.text('＋文本'));
      await settle(tester, UIStyle.neumorphic);
      expect(
        editorState(tester).template.elements.length,
        initialCount + 1,
      );
      final newId = editorState(tester).template.elements.last.id;

      // 新增后自动选中，出现删除按钮
      expect(editorState(tester).selectedElementId, newId);
      await tester.tap(find.text('删除'));
      await settle(tester, UIStyle.neumorphic);
      expect(
        editorState(tester).template.elements.length,
        initialCount,
      );
    });

    testWidgets('边框 Tab：切到「拍立得」后模板 frame.type 更新', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      // 初始无画框
      expect(
        editorState(tester).template.frame.type,
        WatermarkFrameType.none,
      );

      await tester.tap(find.byKey(const ValueKey('wm-tab-border')));
      await settle(tester, UIStyle.neumorphic);
      await tester.tap(find.text('拍立得'));
      await settle(tester, UIStyle.neumorphic);

      expect(
        editorState(tester).template.frame.type,
        WatermarkFrameType.polaroid,
      );
      // 拍立得专属控件出现
      expect(find.text('白板'), findsOneWidget);
    });

    testWidgets('样式 Tab：切换「白边」后选中元素 space 更新', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      // 1) 边框切到拍立得（否则白边选项禁用）
      await tester.tap(find.byKey(const ValueKey('wm-tab-border')));
      await settle(tester, UIStyle.neumorphic);
      await tester.tap(find.text('拍立得'));
      await settle(tester, UIStyle.neumorphic);

      // 2) 切到元素 Tab 并新增一个文本元素（自动选中）
      await tester.tap(find.byKey(const ValueKey('wm-tab-element')));
      await settle(tester, UIStyle.neumorphic);
      await tester.tap(find.text('＋文本'));
      await settle(tester, UIStyle.neumorphic);
      final newId = editorState(tester).template.elements.last.id;
      expect(editorState(tester).selectedElementId, newId);

      // 3) 样式 Tab，切到「白边」→ 元素 space 变 frame
      await tester.tap(find.byKey(const ValueKey('wm-tab-style')));
      await settle(tester, UIStyle.neumorphic);
      await tester.tap(find.text('白边'));
      await settle(tester, UIStyle.neumorphic);

      expect(
        editorState(tester)
            .template
            .elements
            .firstWhere((e) => e.id == newId)
            .space,
        WatermarkElementSpace.frame,
      );
    });
  });
}