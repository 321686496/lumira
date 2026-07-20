import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/filter_picker.dart';

void main() {
  group('FilterPicker', () {
    testWidgets('renders nothing when filterPickerVisibleProvider is false',
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

      // No modal sheet content should be present.
      expect(find.text('系统滤镜'), findsNothing);
      expect(find.text('LUT 预设'), findsNothing);
    });

    testWidgets('shows modal sheet with system filters and LUTs when visible becomes true',
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

      // Trigger the sheet.
      container.read(CaptureState.filterPickerVisibleProvider.notifier).state = true;
      await tester.pump(); // run build + schedule post-frame callback
      await tester.pumpAndSettle(); // run post-frame callback + show sheet + animate

      // Sheet content should be visible.
      expect(find.text('系统滤镜'), findsOneWidget);
      expect(find.text('LUT 预设'), findsOneWidget);
      // A known system filter label from systemFilterLabel() in filter_recipe.dart.
      expect(find.text('鲜明'), findsOneWidget);
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

      container.read(CaptureState.filterPickerVisibleProvider.notifier).state = true;
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

      container.read(CaptureState.filterPickerVisibleProvider.notifier).state = true;
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

    testWidgets('raw mode disables chips and shows RAW warning', (tester) async {
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

      container.read(CaptureState.filterPickerVisibleProvider.notifier).state = true;
      await tester.pump();
      await tester.pumpAndSettle();

      // RAW warning text should appear.
      expect(find.text('RAW 模式下不可用'), findsOneWidget);

      // Tapping a chip should NOT update the template (chips are disabled).
      final initialLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      // ChoiceChip with onSelected: null is disabled; tap should be a no-op.
      await tester.tap(find.text('电影感'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final newLut = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .lut;

      expect(newLut, equals(initialLut));
    });
  });
}
