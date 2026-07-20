import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_strip.dart';

void main() {
  group('TemplateStrip', () {
    testWidgets('compact mode renders 6 template cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(6));
    });

    testWidgets('expanded mode renders 12 template cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Expand the test viewport so the lazy ListView.builder builds all 12 cards
      // (default 800×600 only fits ~10 of the 72px-wide items).
      tester.binding.window.physicalSizeTestValue = const Size(2000, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: false)),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(12));
    });

    testWidgets('tapping a template card updates currentTemplateIdProvider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );

      expect(container.read(CaptureState.currentTemplateIdProvider), isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(container.read(CaptureState.currentTemplateIdProvider), isNotNull);
    });

    testWidgets('active template card has amber border', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );

      // Tap first card to make it active.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // The first Container should now have a non-null border.
      final containers = find.byType(Container);
      final firstContainerWidget = tester.widget<Container>(containers.first);
      final decoration = firstContainerWidget.decoration;
      expect(decoration, isA<BoxDecoration>());
      final boxDecoration = decoration as BoxDecoration;
      expect(boxDecoration.border, isNotNull);
    });
  });
}
