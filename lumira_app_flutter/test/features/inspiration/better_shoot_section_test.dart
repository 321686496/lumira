import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/better_shoot_section.dart';

void main() {
  testWidgets('renders course cards and triggers callbacks', (tester) async {
    final courses = [
      AcademyContent.getCourse('course_01')!,
      AcademyContent.getCourse('course_02')!,
      AcademyContent.getCourse('course_04')!,
    ];
    final tapped = <String>[];
    var moreTapped = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        coursePicksProvider.overrideWith((ref) async => courses),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BetterShootSection(
            onCourseTap: (course) => tapped.add(course.id),
            onMoreCourses: () => moreTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('拍得更好'), findsOneWidget);
    expect(find.text('找到你的最佳角度'), findsOneWidget);
    expect(find.text('全部课程'), findsOneWidget);

    await tester.tap(find.text('找到你的最佳角度'));
    expect(tapped, ['course_01']);

    await tester.tap(find.text('全部课程'));
    expect(moreTapped, isTrue);
  });
}
