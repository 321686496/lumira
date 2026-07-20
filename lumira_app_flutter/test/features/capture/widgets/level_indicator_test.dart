import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/level_indicator.dart';

void main() {
  group('LevelIndicator', () {
    testWidgets('renders CustomPaint when enabled', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.levelEnabledProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: const [LevelIndicator()]),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(LevelIndicator),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when disabled', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.levelEnabledProvider.notifier).state = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: const [LevelIndicator()]),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(LevelIndicator),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
