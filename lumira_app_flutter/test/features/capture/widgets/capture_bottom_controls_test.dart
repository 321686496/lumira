import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_bottom_controls.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';

void main() {
  Future<void> host(
    WidgetTester tester,
    ProviderContainer container, {
    required void Function(Size size) onHeightChanged,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: CaptureBottomBar(
              isFullscreen: false,
              isTrialMode: false,
              onZoomChanged: (_) {},
              onCapture: () {},
              onSwitchCamera: () {},
              onThumbnailTap: () {},
              onHeightChanged: onHeightChanged,
            ),
          ),
        ),
      ),
    );
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('params renders inside tool drawer and sits below toolbar',
      (tester) async {
    final container = makeContainer();
    container.read(CaptureState.activeToolProvider.notifier).state = 'params';
    container.read(CaptureState.panelExpandedProvider.notifier).state = true;

    await host(tester, container, onHeightChanged: (_) {});
    await tester.pumpAndSettle();

    expect(find.byType(ParamPanel), findsOneWidget);
    final toolbarTop = tester.getTopLeft(find.byType(CaptureToolbar)).dy;
    final panelTop = tester.getTopLeft(find.byType(ParamPanel)).dy;
    expect(panelTop, greaterThan(toolbarTop));
  });

  testWidgets('bottom bar reports animated height changes', (tester) async {
    final container = makeContainer();
    var height = 0.0;

    await host(
      tester,
      container,
      onHeightChanged: (size) => height = size.height,
    );
    await tester.pumpAndSettle();
    final collapsedHeight = height;

    container.read(CaptureState.activeToolProvider.notifier).state = 'params';
    container.read(CaptureState.panelExpandedProvider.notifier).state = true;
    await tester.pumpAndSettle();
    final expandedHeight = height;

    expect(collapsedHeight, greaterThan(0));
    expect(expandedHeight, greaterThan(collapsedHeight + 50));
  });

  testWidgets('switching away from params closes parameter expansion',
      (tester) async {
    final container = makeContainer();
    container.read(CaptureState.activeToolProvider.notifier).state = 'params';
    container.read(CaptureState.panelExpandedProvider.notifier).state = true;

    await host(tester, container, onHeightChanged: (_) {});
    await tester.pumpAndSettle();

    await tester.tap(find.text('模板').last);
    await tester.pumpAndSettle();

    expect(container.read(CaptureState.activeToolProvider), 'templates');
    expect(container.read(CaptureState.panelExpandedProvider), false);
  });
}
