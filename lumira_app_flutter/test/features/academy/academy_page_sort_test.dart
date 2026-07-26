import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/widgets/academy_course_card.dart';

void main() {
  testWidgets(
      'AcademyCourseCard shows 已学完 badge when isFullyCompleted is true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AcademyCourseCard(
                  course: const AcademyCourse(
                    id: 'c1',
                    lessonNumber: 1,
                    title: '测试课程',
                    level: AcademyLevel.beginner,
                    topic: AcademyTopic.portrait,
                    coverImage: '',
                    meta: '5分钟',
                  ),
                  status: CourseStatus.completed,
                  isFullyCompleted: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('已学完'), findsOneWidget);
  });

  testWidgets(
      'AcademyCourseCard does not show 已学完 when isFullyCompleted is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AcademyCourseCard(
                  course: const AcademyCourse(
                    id: 'c1',
                    lessonNumber: 1,
                    title: '测试课程',
                    level: AcademyLevel.beginner,
                    topic: AcademyTopic.portrait,
                    coverImage: '',
                    meta: '5分钟',
                  ),
                  status: CourseStatus.inProgress,
                  isFullyCompleted: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('已学完'), findsNothing);
  });
}
