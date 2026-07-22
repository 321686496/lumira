import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';

void main() {
  group('ParamPanel', () {
    testWidgets('renders camera tab with EV slider when panel is expanded and template is set',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';

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

      // Panel starts collapsed. Expand it.
      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // The "相机" tab label and "EV" label should be visible.
      expect(find.text('相机'), findsOneWidget);
      expect(find.text('EV'), findsOneWidget);

      // The "完成" button should be present (always shown when panel is open).
      expect(find.text('完成'), findsOneWidget);
    });

    testWidgets('does not render reset button when no template is selected', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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

      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // No template → no reset button (only "完成" is shown).
      expect(find.text('重置'), findsNothing);
    });

    testWidgets('EV slider drag updates editableTemplate.camera.exposureCompensation',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';

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

      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      final initialEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;

      // Find the EV slider (first Slider in the camera tab).
      final sliderFinder = find.byType(Slider).first;
      expect(sliderFinder, findsOneWidget);

      // Drag the slider to the right by a large offset to ensure value change.
      await tester.drag(sliderFinder, const Offset(200, 0));
      await tester.pumpAndSettle();

      final newEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;

      // EV should have increased (or at least changed) from the drag.
      expect(newEv, isNot(equals(initialEv)));
    });

    testWidgets('reset button resets editableTemplate to original copy', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';

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

      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // First, modify EV via slider to make editable differ from original.
      final sliderFinder = find.byType(Slider).first;
      await tester.drag(sliderFinder, const Offset(200, 0));
      await tester.pumpAndSettle();

      // Confirm they differ.
      expect(container.read(CaptureState.appliedProvider), false);

      // Tap the "重置" button (only visible when modified).
      final resetBtn = find.text('重置');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // After tap, editable should equal original (applied == true).
      expect(container.read(CaptureState.appliedProvider), true);
    });

    testWidgets('close button collapses the panel', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';

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

      // Expand panel.
      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), true);

      // Tap the close icon (Icons.close in the header).
      final closeBtn = find.byIcon(Icons.close).first;
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Panel should be collapsed.
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });

    testWidgets('自由模式下也能调整 EV 参数', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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

      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // 自由模式下应该显示"自由"标识
      expect(find.text('自由'), findsOneWidget);

      // 应该能调整 EV
      final initialEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;

      final sliderFinder = find.byType(Slider).first;
      await tester.drag(sliderFinder, const Offset(200, 0));
      await tester.pumpAndSettle();

      final newEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;
      expect(newEv, isNot(equals(initialEv)));
    });
  });
}
