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
    // 使用 mock 数据中真实存在的场景 ID（'cafe' → '咖啡馆'）
    // 之前的 'scene_portrait' 在 CapturePreviewMockData.sceneOptions 中不存在，
    // 无法验证 _selectedSceneId 是否真正驱动了 UI。
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      CaptureState.activeScenePresetIdProvider
          .overrideWith((ref) => 'cafe'),
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
    // pumpAndSettle 确保 addPostFrameCallback 执行，_selectedSceneId 被赋值并触发重建
    await tester.pumpAndSettle();

    // 观察点 1：override 仍然生效
    expect(container.read(CaptureState.activeScenePresetIdProvider), 'cafe');

    // 观察点 2：UI 层 — '咖啡馆' pill 应处于 active 状态
    // _Pill active 时 Text 颜色为白色 (Colors.white)，inactive 时为 0xFF666666
    final cafeTextFinder = find.text('咖啡馆');
    expect(cafeTextFinder, findsOneWidget);

    final Text cafeText = tester.widget(cafeTextFinder) as Text;
    expect(cafeText.style?.color, isNotNull);
    // active pill 文字为白色
    expect(cafeText.style!.color, equals(Colors.white),
        reason: 'active 场景 pill 文字应为白色，实际为 ${cafeText.style!.color}');

    // 观察点 3：其他场景 pill（如 '街头'）应处于 inactive 状态
    final streetTextFinder = find.text('街头');
    expect(streetTextFinder, findsOneWidget);
    final Text streetText = tester.widget(streetTextFinder) as Text;
    expect(streetText.style?.color, isNotNull);
    expect(streetText.style!.color, equals(const Color(0xFF666666)),
        reason: 'inactive 场景 pill 文字应为灰色 #666666，实际为 ${streetText.style!.color}');
  });

  testWidgets(
      'preview page defaults to "不标记" when no active scene is set',
      (tester) async {
    // 无 override 时 activeScenePresetIdProvider 应为 null，
    // _selectedSceneId 保持 null → '不标记' pill 为 active
    final container = ProviderContainer(overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
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

    expect(container.read(CaptureState.activeScenePresetIdProvider), isNull);

    // '不标记' pill 应为 active（白色文字）
    final noneTextFinder = find.text('不标记');
    expect(noneTextFinder, findsOneWidget);
    final Text noneText = tester.widget(noneTextFinder) as Text;
    expect(noneText.style?.color, equals(Colors.white),
        reason: '无 active scene 时 "不标记" 应为白色（active），实际为 ${noneText.style?.color}');

    // 第一个场景 '咖啡馆' 应为 inactive（灰色）
    final cafeTextFinder = find.text('咖啡馆');
    expect(cafeTextFinder, findsOneWidget);
    final Text cafeText = tester.widget(cafeTextFinder) as Text;
    expect(cafeText.style?.color, equals(const Color(0xFF666666)));
  });
}
