import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/watermark_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/watermark/data/watermark_providers.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/pages/watermark_editor_page.dart';

/// 预置模板「简约日期」的真实 id（与 preset_watermarks.dart 一致）。
/// 该模板含 3 个文本元素、无画框（frame.type == none）。
const _presetMinimal = 'preset_minimal_date';

/// 测试用自定义水印 DAO（内存实现，无需真实 Database）。
class _FakeWatermarkDao implements WatermarkDao {
  _FakeWatermarkDao(this.templates);

  final List<WatermarkTemplate> templates;

  @override
  Future<List<WatermarkTemplate>> getAll() async => List.of(templates);

  @override
  Future<WatermarkTemplate?> getById(String id) async {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<void> insert(WatermarkTemplate template) async {
    lastInserted = template;
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      templates[index] = template; // 同 id 覆盖（对齐 ConflictAlgorithm.replace）
    } else {
      templates.insert(0, template);
    }
  }

  @override
  Future<int> update(WatermarkTemplate template) async {
    lastUpdated = template;
    return 1;
  }

  @override
  Future<int> delete(String id) async {
    lastDeletedId = id;
    return 1;
  }

  WatermarkTemplate? lastInserted;
  WatermarkTemplate? lastUpdated;
  String? lastDeletedId;
}

WatermarkTemplate _custom(String id, String name) {
  return WatermarkTemplate(
    id: id,
    name: name,
    type: WatermarkTemplateType.custom,
    createdAt: DateTime(2026, 8, 20),
    elements: [
      WatermarkElement(
        id: '${id}_t',
        type: WatermarkElementType.text,
        text: 'CUSTOM',
        x: 0.5,
        y: 0.5,
        fontSize: 0.05,
      ),
    ],
  );
}

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
      // 编辑已有模板 → 标题「编辑水印」
      expect(find.text('编辑水印'), findsOneWidget);
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

      // 新增文本元素（自动切入「样式」tab 并聚焦输入框）
      await tester.tap(find.text('＋文本'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // 停用光标闪烁，避免后续 pumpAndSettle 被持续排帧卡住
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        editorState(tester).template.elements.length,
        initialCount + 1,
      );
      final newId = editorState(tester).template.elements.last.id;

      // 新增后自动选中；删除按钮位于元素 tab，需先切回
      expect(editorState(tester).selectedElementId, newId);
      await tester.tap(find.byKey(const ValueKey('wm-tab-element')));
      await settle(tester, UIStyle.neumorphic);
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

      // 2) 切到元素 Tab 并新增一个文本元素（自动选中并聚焦输入）
      await tester.tap(find.byKey(const ValueKey('wm-tab-element')));
      await settle(tester, UIStyle.neumorphic);
      await tester.tap(find.text('＋文本'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      tester.binding.focusManager.primaryFocus?.unfocus(); // 停用光标闪烁
      await tester.pump();
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

    testWidgets('新建模式：标题显示「自定义水印」，模板为空白自定义',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
            uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          ],
          child: const MaterialApp(
            home: WatermarkEditorPage(), // 无 templateId → 新建空白模板
          ),
        ),
      );
      await settle(tester, UIStyle.neumorphic);

      expect(find.text('自定义水印'), findsOneWidget);
      expect(editorState(tester).template.type, WatermarkTemplateType.custom);
    });

    testWidgets('编辑自定义水印：保留原 id / 名称，保存后原地更新',
        (tester) async {
      setLargeViewport(tester);
      final custom = _custom('custom_1', '我的水印');
      final dao = _FakeWatermarkDao([custom]);
      final container = ProviderContainer(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          customWatermarksProvider.overrideWith((ref) => [custom]),
          watermarkDaoProvider.overrideWith((ref) async => dao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WatermarkEditorPage(templateId: 'custom_1'),
          ),
        ),
      );
      await settle(tester, UIStyle.neumorphic);

      // 原地编辑：id / 名称保留，不加「（副本）」后缀
      expect(editorState(tester).template.id, 'custom_1');
      expect(editorState(tester).template.name, '我的水印');
      expect(
        editorState(tester).template.type,
        WatermarkTemplateType.custom,
      );

      // 保存 → 按原 id 覆盖，自定义列表不新增重复项
      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700)); // 等持久化 timer
      await tester.pumpAndSettle();

      expect(dao.lastInserted, isNotNull);
      expect(dao.lastInserted!.id, 'custom_1');
      expect(container.read(customWatermarksProvider), hasLength(1));
      expect(container.read(customWatermarksProvider).first.id, 'custom_1');
    });

    testWidgets('编辑预置水印：另存为新的自定义模板（id 变化、名称保持）',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settle(tester, UIStyle.neumorphic);

      final state = editorState(tester);
      // 新 id 以 custom_ 开头，不覆盖预置
      expect(state.template.id, startsWith('custom_'));
      expect(state.template.id, isNot(_presetMinimal));
      expect(state.template.name, isNotEmpty);
      expect(state.template.type, WatermarkTemplateType.custom);
    });
  });
}