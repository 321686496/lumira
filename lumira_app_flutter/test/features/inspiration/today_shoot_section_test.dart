import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/today_shoot_section.dart';

void main() {
  const items = [
    TodayShootItem(
      id: 'cafe-window',
      name: '咖啡馆窗边',
      vibe: '午后斜阳',
      imageAsset: 'assets/images/scenes/scene_cafe.jpg',
      target: TodayShootTarget.scene,
      targetId: 'cafe-window',
    ),
    TodayShootItem(
      id: 'night-street',
      name: '霓虹街头',
      vibe: '城市的故事',
      imageAsset: 'assets/images/scenes/scene_street.jpg',
      target: TodayShootTarget.scene,
      targetId: 'night-street',
    ),
  ];

  testWidgets('renders item cards and triggers callbacks', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1600);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    final tapped = <String>[];
    var moreTapped = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        todayShootProvider.overrideWith((ref) async => items),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TodayShootSection(
            onItemTap: (item) => tapped.add(item.id),
            onMoreScenes: () => moreTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('今日可拍'), findsOneWidget);
    expect(find.text('咖啡馆窗边'), findsOneWidget);
    expect(find.text('霓虹街头'), findsOneWidget);
    expect(find.text('查看全部场景'), findsOneWidget);

    await tester.tap(find.text('咖啡馆窗边'));
    expect(tapped, ['cafe-window']);

    await tester.tap(find.text('查看全部场景'));
    expect(moreTapped, isTrue);
  });
}
