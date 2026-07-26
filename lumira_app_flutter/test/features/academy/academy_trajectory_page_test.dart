import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_trajectory_models.dart';
import 'package:lumira_app_flutter/features/academy/pages/academy_trajectory_page.dart';
import 'package:lumira_app_flutter/features/academy/providers/academy_providers.dart';

void main() {
  testWidgets('AcademyTrajectoryPage shows empty state when no trajectory',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academyTrajectoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: AcademyTrajectoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('开始你的第一节课程吧'), findsOneWidget);
  });

  testWidgets('AcademyTrajectoryPage shows timeline with trajectory records',
      (tester) async {
    final trajectories = <AcademyTrajectoryRecord>[
      const AcademyTrajectoryRecord(
        courseId: 'academy_01',
        completedAt: 1700000000000,
        sequence: 1,
      ),
      const AcademyTrajectoryRecord(
        courseId: 'academy_02',
        completedAt: 1700100000000,
        sequence: 2,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          academyTrajectoryProvider.overrideWith((ref) async => trajectories),
        ],
        child: const MaterialApp(home: AcademyTrajectoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 验证顶部统计卡显示（AcademyMockData.courses.length = 16）
    expect(find.text('已完成 2 / 16 课'), findsOneWidget);
    // 验证总学习时长显示（按 sections.paragraphs.length * 30秒 估算）
    expect(find.textContaining('总学习时长约'), findsOneWidget);
    // 验证时间线节点标签
    expect(find.text('第 1 个完成'), findsOneWidget);
    expect(find.text('第 2 个完成'), findsOneWidget);
  });
}
