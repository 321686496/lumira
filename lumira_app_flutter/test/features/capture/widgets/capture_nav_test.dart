import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_nav.dart';

void main() {
  group('CaptureNav', () {
    testWidgets('title shows "自由调参" when no template is selected',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // currentTemplateIdProvider defaults to null

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CaptureNav(onBack: _noop)),
          ),
        ),
      );

      expect(find.text('自由调参'), findsOneWidget);
      expect(find.text('模板拍摄'), findsNothing);
    });

    testWidgets('title shows "模板拍摄" when a template is selected',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CaptureNav(onBack: _noop)),
          ),
        ),
      );

      expect(find.text('模板拍摄'), findsOneWidget);
      expect(find.text('自由调参'), findsNothing);
    });

    testWidgets('subtitle "点击调整参数" appears only when template is selected',
        (tester) async {
      // Case 1: No template → no subtitle
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container1,
          child: const MaterialApp(
            home: Scaffold(body: CaptureNav(onBack: _noop)),
          ),
        ),
      );
      expect(find.text('点击调整参数'), findsNothing);

      // Case 2: Template selected → subtitle appears
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'soft_portrait';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
          child: const MaterialApp(
            home: Scaffold(body: CaptureNav(onBack: _noop)),
          ),
        ),
      );
      expect(find.text('点击调整参数'), findsOneWidget);
    });

    testWidgets('tapping the title opens the parameter panel',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CaptureNav(onBack: _noop)),
          ),
        ),
      );

      // panelExpandedProvider defaults to false
      expect(container.read(CaptureState.panelExpandedProvider), false);

      // Tap the title text — find by the '自由调参' text (default state, no template)
      await tester.tap(find.text('自由调参'));
      await tester.pump();

      expect(container.read(CaptureState.panelExpandedProvider), true);
    });
  });
}

void _noop() {}
