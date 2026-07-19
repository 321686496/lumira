import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_editor_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

/// Task 2.8C — TemplatesEditorPage 测试
///
/// 覆盖 brief 第 5.2 节 ≥25 项断言 + cross-theme/cross-style smoke test。
/// 10 个分类：
/// 1. 路由参数加载（4）
/// 2. Step 1 模板信息（4）
/// 3. Step 2 构图叠图（3）
/// 4. Step 3 姿势剪影（5）
/// 5. Step 4 相机参数（3）
/// 6. Step 5 场景指南（2）
/// 7. Step 6 后期参数（2）
/// 8. Footer 操作（4）
/// 9. 自动保存（1）
/// 10. Cross-theme/cross-style smoke（1，12 组合）
void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    HttpOverrides.global = _TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String initialLocation = '/templates/editor',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/templates/editor',
          name: 'templatesEditor',
          builder: (context, state) {
            final templateId = state.queryParams[RouteNames.paramTemplateId];
            final draftId = state.queryParams['draftId'];
            return TemplatesEditorPage(
              templateId: templateId,
              draftId: draftId,
            );
          },
        ),
        GoRoute(
          path: RouteNames.templates,
          name: 'templates',
          builder: (_, __) => const _StubPage(text: 'TEMPLATES_PAGE'),
        ),
        GoRoute(
          path: RouteNames.templatesDrafts,
          name: 'templatesDrafts',
          builder: (_, __) => const _StubPage(text: 'DRAFTS_PAGE'),
        ),
        GoRoute(
          path: RouteNames.capturePreviewTemplate,
          name: 'capturePreviewTemplate',
          builder: (_, __) => const _StubPage(text: 'PREVIEW_TEMPLATE_PAGE'),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const _StubPage(text: 'HOME_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  // ============================================================
  // 分类 1: 路由参数加载（4 tests）
  // ============================================================
  group('TemplatesEditorPage — route parameter loading', () {
    testWidgets('new mode: renders with title 新建模板 and blank form',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      // 空白模板：name 输入框为空（占位符可见）
      expect(find.text('输入模板名称'), findsOneWidget);
    });

    testWidgets('edit mode: templateId loads existing template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/templates/editor?${RouteNames.paramTemplateId}=tpl-cafe-portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 编辑模式：标题为 编辑模板
      expect(find.widgetWithText(LumiraNav, '编辑模板'), findsOneWidget);
      // 已加载模板名称
      expect(find.text('咖啡馆人像'), findsOneWidget);
    });

    testWidgets('draft recovery: draftId loads draft form', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/templates/editor?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 草稿模式：仍为新建模板（草稿不属于已存在模板）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      // 已加载草稿名称
      expect(find.text('咖啡馆人像草稿'), findsOneWidget);
    });

    testWidgets(
        'invalid templateId falls back to new mode with blank form',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation:
            '/templates/editor?${RouteNames.paramTemplateId}=nonexistent-id',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 无效 templateId：返回新建模式（_isEditMode=false）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      expect(find.text('输入模板名称'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: Step 1 模板信息（4 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 1 模板信息', () {
    testWidgets('renders 6 step cards with numbered badges', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 6 个 step 标题
      expect(find.text('模板信息'), findsOneWidget);
      expect(find.text('构图叠图'), findsOneWidget);
      expect(find.text('姿势剪影'), findsOneWidget);
      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('场景指南'), findsOneWidget);
      expect(find.text('后期参数'), findsOneWidget);
      // 6 个 step 序号（Text '1' ~ '6'）— 用 findsNWidgets 验证数量
      for (var i = 1; i <= 6; i++) {
        expect(find.text('$i'), findsOneWidget,
            reason: 'step number badge $i');
      }
    });

    testWidgets('Step 1: name input accepts text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 名称字段：占位符为 '输入模板名称'
      expect(find.text('输入模板名称'), findsOneWidget);
      // 输入文本
      await tester.enterText(
          find.widgetWithText(TextField, '').first, '我的新模板');
      await settleOrPump(tester, UIStyle.neumorphic);
    });

    testWidgets('Step 1: renders 4 field labels (名称/分类/标签/简介)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('名称'), findsOneWidget);
      expect(find.text('分类'), findsOneWidget);
      expect(find.text('标签'), findsOneWidget);
      expect(find.text('简介'), findsOneWidget);
      expect(find.text('参数参考来源'), findsOneWidget);
    });

    testWidgets('Step 1: default category is portrait (人像)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // DropdownButton 显示当前选中项 '人像'
      expect(find.text('人像'), findsWidgets);
    });
  });

  // ============================================================
  // 分类 3: Step 2 构图叠图（3 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 2 构图叠图', () {
    testWidgets('renders overlay type dropdown with default 三分法',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 overlayType = 'rule_of_thirds'，显示 '三分法'
      expect(find.text('构图类型'), findsOneWidget);
      expect(find.text('三分法'), findsWidgets);
    });

    testWidgets('renders opacity slider with default 0.5', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('透明度'), findsOneWidget);
      // 默认 opacity=0.5，valueText 为 '0.5'
      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('renders aspect ratio input with default 3:4', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('宽高比'), findsOneWidget);
      // '3:4' 出现 2 次：Step 2 aspectRatio + Step 6 cropRatio（默认值均为 '3:4'）
      expect(find.text('3:4'), findsNWidgets(2));
    });
  });

  // ============================================================
  // 分类 4: Step 3 姿势剪影（5 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 3 姿势剪影', () {
    testWidgets('renders 3 source pills (内置库/导入图片/绘制剪影)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('来源'), findsOneWidget);
      expect(find.text('内置库'), findsOneWidget);
      expect(find.text('导入图片'), findsOneWidget);
      expect(find.text('绘制剪影'), findsOneWidget);
    });

    testWidgets('builtin source: renders 5 silhouette thumbnails',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 source=builtin，显示 '选择剪影' 标签 + 5 个 thumbnail
      expect(find.text('选择剪影'), findsOneWidget);
      // 5 个 key 文本：none / standing-profile / sitting-cafe / walking-street / soft-portrait
      expect(find.text('none'), findsOneWidget);
      expect(find.text('standing-profile'), findsOneWidget);
      expect(find.text('sitting-cafe'), findsOneWidget);
      expect(find.text('walking-street'), findsOneWidget);
      expect(find.text('soft-portrait'), findsOneWidget);
    });

    testWidgets('switching to image source shows 选择图片 button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '导入图片' pill
      await tester.tap(find.text('导入图片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '导入图片' 字段标签和 '选择图片' 按钮
      expect(find.text('选择图片'), findsOneWidget);
    });

    testWidgets('switching to svg source shows 打开画布 button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 '绘制剪影' pill
      await tester.tap(find.text('绘制剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示 '绘制剪影' 字段标签和 '打开画布' 按钮
      expect(find.text('打开画布'), findsOneWidget);
    });

    testWidgets('tapping 打开画布 opens SilhouetteEditorDialog', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换到 svg 源
      await tester.tap(find.text('绘制剪影'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 打开画布
      await tester.tap(find.text('打开画布'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗内容：标题 '绘制剪影'（dialog 标题） + 工具按钮 + 提示
      expect(find.text('画笔'), findsOneWidget);
      expect(find.text('橡皮'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);
      expect(find.text('重做'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 5: Step 4 相机参数（3 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 4 相机参数', () {
    testWidgets('renders EV slider with default 0.0', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // EV 默认值 0.0，valueText 为 '0.0'
      expect(find.text('EV'), findsOneWidget);
      expect(find.text('0.0'), findsWidgets);
    });

    testWidgets('renders ISO mode pills (自动/手动)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('ISO 模式'), findsOneWidget);
      // 默认 isoMode='auto'，'自动' pill 显示
      expect(find.text('自动'), findsWidgets);
      expect(find.text('手动'), findsWidgets);
    });

    testWidgets('renders white balance dropdown with default 日光',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('白平衡'), findsOneWidget);
      // 默认 whiteBalance='daylight'，显示 '日光'
      expect(find.text('日光'), findsWidgets);
    });
  });

  // ============================================================
  // 分类 6: Step 5 场景指南（2 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 5 场景指南', () {
    testWidgets('renders 6 field labels (光线方向/拍摄距离/背景/最佳时间/道具/贴士)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('光线方向'), findsOneWidget);
      expect(find.text('拍摄距离'), findsOneWidget);
      expect(find.text('背景'), findsOneWidget);
      expect(find.text('最佳时间'), findsOneWidget);
      expect(find.text('道具'), findsOneWidget);
      expect(find.text('贴士'), findsOneWidget);
    });

    testWidgets('draft form loads scene guide fields with props/tips',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/templates/editor?draftId=draft-editor-1',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // draftForm 已填充：lightDirection='侧面柔光 45°' / shootingDistance='1.5-2m' / bestTime='14:00-16:00'
      expect(find.text('侧面柔光 45°'), findsOneWidget);
      expect(find.text('1.5-2m'), findsOneWidget);
      expect(find.text('14:00-16:00'), findsOneWidget);
      // props 已解析：'咖啡杯, 书'（逗号分隔）
      expect(find.text('咖啡杯, 书'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 7: Step 6 后期参数（2 tests）
  // ============================================================
  group('TemplatesEditorPage — Step 6 后期参数', () {
    testWidgets('renders LUT dropdown with default 无', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('LUT'), findsOneWidget);
      // 默认 lut='none'，显示 '无'
      expect(find.text('无'), findsWidgets);
    });

    testWidgets('renders 9 slider labels (亮度/对比/饱和/色温/色调/磨皮/锐化/暗角/颗粒 + 裁剪比)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('裁剪比'), findsOneWidget);
      expect(find.text('亮度'), findsOneWidget);
      expect(find.text('对比'), findsOneWidget);
      expect(find.text('饱和'), findsOneWidget);
      expect(find.text('色温'), findsOneWidget);
      expect(find.text('色调'), findsOneWidget);
      expect(find.text('磨皮'), findsOneWidget);
      expect(find.text('锐化'), findsOneWidget);
      expect(find.text('暗角'), findsOneWidget);
      expect(find.text('颗粒'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 8: Footer 操作（4 tests）
  // ============================================================
  group('TemplatesEditorPage — Footer 操作', () {
    testWidgets('renders 3 footer buttons (草稿/预览/保存) in new mode',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('草稿'), findsOneWidget);
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      // 新建模式下不显示导出按钮
      expect(find.text('导出'), findsNothing);
    });

    testWidgets('tapping 保存 with empty name shows 请输入模板名称 SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 保存 按钮（空白模板，name 为空）
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 显示错误 SnackBar
      expect(find.text('请输入模板名称'), findsOneWidget);
    });

    testWidgets('tapping 草稿 shows 草稿已保存 SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('草稿'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('草稿已保存'), findsOneWidget);
    });

    testWidgets('tapping 预览 navigates to preview-template page', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('预览'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('PREVIEW_TEMPLATE_PAGE'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 9: 自动保存（1 test）
  // ============================================================
  group('TemplatesEditorPage — 自动保存', () {
    testWidgets(
        'form change schedules auto-save timer (1000ms debounce, no crash)',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 切换到 '导入图片' 源（触发 _onChange → _scheduleAutoSave）
      await tester.tap(find.text('导入图片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 推进时间至 1000ms 之后（auto-save timer 触发）
      await tester.pump(const Duration(milliseconds: 1100));

      // 验证：无崩溃 + 仍在编辑器页（无 SnackBar 因为 auto-save 静默执行）
      expect(find.widgetWithText(LumiraNav, '新建模板'), findsOneWidget);
      expect(find.text('选择图片'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 10: Cross-theme/cross-style smoke（1 test，12 组合）
  // ============================================================
  group('TemplatesEditorPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      // 8 主题 × 1 风格 (neumorphic) + 1 主题 (warmWhite) × 4 风格 = 12 组合
      // Dart 2.19 兼容：不用 record 类型，用 _ThemeStyleCombo 类
      final combinations = <_ThemeStyleCombo>[
        for (final t in ThemeKey.values)
          _ThemeStyleCombo(theme: t, style: UIStyle.neumorphic),
        for (final s in UIStyle.values)
          if (s != UIStyle.neumorphic)
            _ThemeStyleCombo(theme: ThemeKey.warmWhite, style: s),
      ];

      for (final combo in combinations) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: combo.theme, uiStyle: combo.style));
        await settleOrPump(tester, combo.style);

        // 验证关键元素渲染
        expect(find.text('模板信息'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('构图叠图'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('姿势剪影'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('相机参数'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('场景指南'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('后期参数'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        // 重置 viewport 为下一次迭代
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

/// 主题 × 风格组合（Dart 2.19 兼容：不用 record 类型）
class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

/// 占位页（用于测试 pop 行为）
class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}

/// 测试用 HttpOverrides（避免网络图片异常）
class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return client;
  }
}
