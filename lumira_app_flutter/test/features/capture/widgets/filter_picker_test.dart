import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/filter_picker.dart';

void main() {
  group('FilterPicker', () {
    testWidgets('renders nothing when activeTool is not filter',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      // No content should be present when activeTool is null.
      expect(find.text('系统滤镜'), findsNothing);
      expect(find.text('LUT 预设'), findsNothing);
    });

    testWidgets('shows system filters and LUTs when activeTool is filter',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Set a template so editableTemplate is non-null.
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = 'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      // Activate the filter tool.
      container.read(CaptureState.activeToolProvider.notifier).state = 'filter';
      await tester.pump();
      await tester.pumpAndSettle();

      // Content should be visible.
      expect(find.text('系统滤镜'), findsOneWidget);
      // A known system filter label from systemFilterLabel() in filter_recipe.dart.
      expect(find.text('鲜明'), findsOneWidget);
      expect(find.text('LUT 预设'), findsOneWidget);
      // A known LUT label from lutLabel() in filter_recipe.dart.
      expect(find.text('电影感'), findsOneWidget);
    });

    testWidgets('tapping a LUT chip updates editableTemplate.postProcess.lut',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = 'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      container.read(CaptureState.activeToolProvider.notifier).state = 'filter';
      await tester.pump();
      await tester.pumpAndSettle();

      final initialLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      // Tap the "电影感" chip (LUT 'cinematic').
      await tester.tap(find.text('电影感'));
      await tester.pumpAndSettle();

      final newLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      expect(newLut, 'cinematic');
      expect(newLut, isNot(equals(initialLut)));
    });

    testWidgets('tapping a system filter chip updates editableTemplate.postProcess.systemFilter',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = 'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      container.read(CaptureState.activeToolProvider.notifier).state = 'filter';
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap the "鲜明" chip (system filter 'vivid').
      await tester.tap(find.text('鲜明'));
      await tester.pumpAndSettle();

      final newFilter = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .systemFilter;

      expect(newFilter, 'vivid');
    });

    testWidgets('tapping 原图 after selecting a filter clears systemFilter',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = 'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      container.read(CaptureState.activeToolProvider.notifier).state = 'filter';
      await tester.pump();
      await tester.pumpAndSettle();

      // First select 'vivid'
      await tester.tap(find.text('鲜明'));
      await tester.pumpAndSettle();
      expect(
        container.read(CaptureState.editableTemplateProvider)!.postProcess.systemFilter,
        'vivid',
      );

      // Now tap '原图' (none) — should clear systemFilter to null
      await tester.tap(find.text('原图').first);
      await tester.pumpAndSettle();
      expect(
        container.read(CaptureState.editableTemplateProvider)!.postProcess.systemFilter,
        isNull,
        reason: '原图 should clear systemFilter to null',
      );
    });

    testWidgets('raw mode shows RAW warning', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = 'soft_portrait';
      container.read(CaptureState.rawModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: FilterPicker()),
          ),
        ),
      );

      // 记录进入 RAW 模式前的 LUT（soft_portrait 模板默认 'pastel'）
      final initialLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      container.read(CaptureState.activeToolProvider.notifier).state = 'filter';
      await tester.pump();
      await tester.pumpAndSettle();

      // RAW warning text should appear.
      expect(find.text('RAW 模式已启用'), findsOneWidget);

      // In RAW mode, the filter content is replaced by _RawModePlaceholder,
      // so '电影感' is NOT present at all.
      expect(find.text('电影感'), findsNothing);

      final newLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      // LUT should be unchanged (RAW 模式不修改后期参数).
      expect(newLut, initialLut);
    });
  });
}
