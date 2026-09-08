import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_adjust_panel.dart';

void main() {
  /// 构建带主题 override 的测试宿主（ParamPanel 依赖 appThemeProvider）
  Future<void> host(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(children: const [ParamPanel()]),
          ),
        ),
      ),
    );
  }

  ProviderContainer makeContainer({String? templateId}) {
    final container = ProviderContainer(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
    );
    addTearDown(container.dispose);
    if (templateId != null) {
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = templateId;
    }
    return container;
  }

  void expand(ProviderContainer container) {
    container.read(CaptureState.panelExpandedProvider.notifier).state = true;
  }

  group('ParamPanel 工具条结构', () {
    testWidgets('展开后显示 7 个工具 + 徽标 + 重置，无旧版“完成”按钮', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      expect(find.text('模板'), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);
      for (final label in ['曝光', '白平衡', '闪光', '色彩', '细节', '构图', '场景']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('完成'), findsNothing);
      expect(find.text('相机'), findsNothing); // 旧文字 Tab 不再存在
    });

    testWidgets('自由模式显示“自由”徽标', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();
      expect(find.text('自由'), findsOneWidget);
    });
  });

  group('ParamPanel 工具交互', () {
    testWidgets('点“曝光”滑出 EV 滑块，拖动更新曝光值', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();

      final slider = find.byType(AdjustSlider);
      expect(slider, findsOneWidget);
      expect(find.text('EV'), findsOneWidget);

      final initialEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();
      final newEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;
      expect(newEv, isNot(equals(initialEv)));
    });

    testWidgets('再点同一工具收起控件区', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      expect(find.byType(AdjustSlider), findsOneWidget);

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      expect(find.byType(AdjustSlider), findsNothing);
    });

    testWidgets('自由模式 EV 拖动写入 freeModeCamera（防抖持久化推进）', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();

      final initialEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      final newEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;
      expect(newEv, isNot(equals(initialEv)));

      // 推进 500ms 防抖持久化 Timer，避免测试结束时 Timer pending
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });

    testWidgets('点“色彩”展开 AdjustPanel 并可调亮度', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('色彩'));
      await tester.pumpAndSettle();

      // AdjustPanel 默认选中第 0 项「亮度」
      //（横向调节条 chip 与当前滑块 label 同名，文本出现 2 处）
      expect(find.text('亮度'), findsWidgets);

      final initial = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .color
          .brightness;
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      final updated = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .color
          .brightness;
      expect(updated, isNot(equals(initial)));
    });

    testWidgets('点“闪光”展开选项 pill 并切换闪光模式', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('闪光'));
      await tester.pumpAndSettle();

      expect(find.text('常亮'), findsOneWidget);
      await tester.tap(find.text('常亮'));
      await tester.pumpAndSettle();

      expect(
        container.read(CaptureState.effectiveCameraProvider).flashMode,
        'on',
      );
    });

    testWidgets('点“构图”展开辅助线类型 pill 与透明度滑块', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('构图'));
      await tester.pumpAndSettle();

      expect(find.text('三分法'), findsOneWidget);
      expect(find.text('透明度'), findsOneWidget);
    });

    testWidgets('点“场景”展开场景指南（模板模式）', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();

      expect(find.text('光线方向'), findsOneWidget);
    });

    testWidgets('自由模式场景空态文案', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();

      expect(find.text('当前为自由模式，无场景指南'), findsOneWidget);
    });
  });

  group('ParamPanel 面板级交互', () {
    testWidgets('重置按钮恢复模板原始值', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      // 修改 EV 使 editable 偏离 original
      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.appliedProvider), false);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.appliedProvider), true);
    });

    testWidgets('把手行收起图标关闭面板', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), true);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });

    testWidgets('点面板外区域（取景器）关闭整栏', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      // 面板贴底；点击屏幕上半部（面板外）
      await tester.tapAt(const Offset(400, 100));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });
  });
}
