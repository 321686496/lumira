import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  Widget wrap({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/preview',
          routes: [
            GoRoute(
              path: '/preview',
              builder: (_, __) => const CapturePreviewPage(
                photoUrl: '',
                photoId: 'p1',
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration pillDecorationOf(WidgetTester tester, String name) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(name), matching: find.byType(Container))
          .first,
    );
    return container.decoration as BoxDecoration;
  }

  testWidgets('preview page pre-selects active scene from capture state',
      (tester) async {
    setLargeViewport(tester);
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      CaptureState.activeScenePresetIdProvider.overrideWith((ref) => 'cafe'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container: container));
    await tester.pumpAndSettle();

    expect(container.read(CaptureState.activeScenePresetIdProvider), 'cafe');
    // pill 行直接可见（无需展开抽屉）
    expect(find.text('咖啡馆'), findsOneWidget);
    expect(pillDecorationOf(tester, '咖啡馆').gradient, isA<LinearGradient>(),
        reason: 'active 场景 pill 应为渐变 active 态');
    expect(pillDecorationOf(tester, '街头').gradient, isNull,
        reason: 'inactive 场景 pill 应为非渐变');
  });

  testWidgets(
    'preview page defaults to 不标记 when no active scene is set',
    (tester) async {
      setLargeViewport(tester);
      final container = ProviderContainer(overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(wrap(container: container));
      await tester.pumpAndSettle();

      expect(find.text('不标记'), findsOneWidget);
      expect(pillDecorationOf(tester, '不标记').gradient, isA<LinearGradient>());
      expect(pillDecorationOf(tester, '咖啡馆').gradient, isNull);
    },
  );
}
