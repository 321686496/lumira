import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/delay_timer_button.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    int delay = 0,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.delayTimerProvider.notifier).state = delay;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DelayTimerButton())),
      ),
    );
    return container;
  }

  testWidgets('shows menu with 关闭/3秒/5秒/10秒 when tapped', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(DelayTimerButton));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('3秒'), findsOneWidget);
    expect(find.text('5秒'), findsOneWidget);
    expect(find.text('10秒'), findsOneWidget);
  });

  testWidgets('selecting an option updates delayTimerProvider', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byType(DelayTimerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5秒'));
    await tester.pumpAndSettle();
    expect(container.read(CaptureState.delayTimerProvider), 5);
  });

  testWidgets('active state shows selected seconds badge', (tester) async {
    await pump(tester, delay: 3);
    expect(find.text('3s'), findsOneWidget);
  });
}