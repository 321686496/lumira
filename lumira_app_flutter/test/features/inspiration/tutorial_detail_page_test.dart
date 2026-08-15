import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/pages/tutorial_detail_page.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('渲染标题/步骤/贴士/CTA/导流条', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(
        home: TutorialDetailPage(tutorialId: 'tut_general_premium'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('如何拍出高级感'), findsOneWidget);
    expect(find.text('减少画面元素'), findsOneWidget);
    expect(find.text('低饱和 + 低对比，质感更高级'), findsOneWidget);
    expect(find.text('去试试'), findsOneWidget);
    expect(find.text('想系统学？进入美学院'), findsOneWidget);
  });

  testWidgets('tutorialId 不存在时显示空态', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(home: TutorialDetailPage(tutorialId: 'not-exist')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('教程不存在'), findsOneWidget);
  });
}