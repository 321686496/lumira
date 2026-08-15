import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/tutorial_section.dart';

void main() {
  const tutorials = [
    ShootingTutorial(
      id: 't1', title: '如何拍出高级感', subtitle: '留白与克制',
      coverImage: '', category: 'general', readMinutes: '3分钟',
      tags: [], intro: 'i',
      steps: [TutorialStep(title: 's', body: 'b')],
      tips: ['tip'], cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
    ),
  ];

  testWidgets('渲染标题/卡片/右侧美学院入口并回调', (tester) async {
    final tapped = <String>[];
    var academyTapped = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        tutorialPicksProvider.overrideWith((ref) async => tutorials),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TutorialSection(
            onTutorialTap: (t) => tapped.add(t.id),
            onAcademyTap: () => academyTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('拍摄小课堂'), findsOneWidget);
    expect(find.text('系统性学习 → 美学院'), findsOneWidget);
    expect(find.text('如何拍出高级感'), findsOneWidget);

    await tester.tap(find.text('如何拍出高级感'));
    expect(tapped, ['t1']);

    await tester.tap(find.text('系统性学习 → 美学院'));
    expect(academyTapped, isTrue);
  });
}