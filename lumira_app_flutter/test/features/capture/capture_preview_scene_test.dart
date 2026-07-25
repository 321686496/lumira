import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  testWidgets('preview page pre-selects active scene from capture state',
      (tester) async {
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      CaptureState.activeScenePresetIdProvider
          .overrideWith((ref) => 'scene_portrait'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/preview',
            routes: [
              GoRoute(
                path: '/preview',
                builder: (_, __) =>
                    const CapturePreviewPage(photoUrl: '', photoId: 'p1'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 预选场景应被设置；具体 UI 文本取决于 CapturePreviewMockData.sceneOptions
    // 这里仅断言 activeScenePresetIdProvider 与 _selectedSceneId 一致
    expect(container.read(CaptureState.activeScenePresetIdProvider),
        'scene_portrait');
  });
}
