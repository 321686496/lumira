// 集成测试：submitAssignment → courseFullyCompletedProvider 返回 true → 已学完徽章出现
//
// 验证 AcademyActionNotifier._refresh() 中的 ref.invalidate() 调用确实让
// courseFullyCompletedProvider 在作业提交后重新计算并返回新值（badge 流转）。
// 这是 Plan C 最终评审中标记为 Important 的待补集成测试。
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/providers/academy_providers.dart';

void main() {
  late Database db;
  late AcademyDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = AcademyDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'submitAssignment with photo invalidates courseFullyCompletedProvider so '
      'badge appears (true) after being false before submission', () async {
    final container = ProviderContainer(
      overrides: [
        academyDaoProvider.overrideWith((ref) async => dao),
      ],
    );
    addTearDown(container.dispose);

    // 1. 提交前：courseFullyCompletedProvider('c1') 应为 false
    //    （无 progress 记录，无作业提交）
    final before = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(before, isFalse,
        reason: '未提交作业时课程不应标记为完全完成');

    // 2. 通过 AcademyActionNotifier 提交带照片的作业
    //    submitAssignment 内部会调用 markCompleted → 写入 progress +
    //    校验 isCourseFullyCompleted → upsertTrajectory
    //    然后调用 _refresh() 触发 ref.invalidate(courseFullyCompletedProvider)
    await container.read(academyActionsProvider.notifier).submitAssignment(
          AssignmentSubmission(
            id: 's1',
            assignmentId: 'a1',
            courseId: 'c1',
            photoPath: '/path/to/photo.jpg',
            status: AssignmentStatus.submitted,
            submittedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // 3. 提交后：courseFullyCompletedProvider('c1') 应重新计算并返回 true
    //    若 _refresh() 中缺少 ref.invalidate，此处会读到缓存的旧值 false
    final after = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(after, isTrue,
        reason: '提交带照片的作业后，徽章状态应通过 invalidate 立即刷新为 true');

    // 4. 轨迹也应通过 academyTrajectoryProvider 立即可见（同上 invalidate 机制）
    final trajectory = await container.read(academyTrajectoryProvider.future);
    expect(trajectory, hasLength(1),
        reason: '提交带照片的作业后，学习轨迹应通过 invalidate 立即包含一条记录');
    expect(trajectory.first.courseId, 'c1');
  });

  test('submitAssignment without photo does NOT trigger badge (stays false)',
      () async {
    final container = ProviderContainer(
      overrides: [
        academyDaoProvider.overrideWith((ref) async => dao),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(before, isFalse);

    // 提交不含照片的作业 —— markCompleted 不应写入轨迹
    await container.read(academyActionsProvider.notifier).submitAssignment(
          AssignmentSubmission(
            id: 's2',
            assignmentId: 'a2',
            courseId: 'c1',
            photoPath: null,
            status: AssignmentStatus.submitted,
            submittedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    final after = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(after, isFalse,
        reason: '未含照片的作业不应让课程标记为完全完成');

    final trajectory = await container.read(academyTrajectoryProvider.future);
    expect(trajectory, isEmpty,
        reason: '未含照片的作业不应生成学习轨迹');
  });

  test('markCompleted alone (without submission) does NOT trigger badge',
      () async {
    final container = ProviderContainer(
      overrides: [
        academyDaoProvider.overrideWith((ref) async => dao),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(before, isFalse);

    // 仅标记完成（无作业提交）—— isCourseFullyCompleted 应返回 false
    await container
        .read(academyActionsProvider.notifier)
        .markCompleted('c1');

    final after = await container.read(
      courseFullyCompletedProvider('c1').future,
    );
    expect(after, isFalse,
        reason: '仅有 markCompleted 而无作业提交不应让课程标记为完全完成');

    final trajectory = await container.read(academyTrajectoryProvider.future);
    expect(trajectory, isEmpty,
        reason: '仅有 markCompleted 而无作业提交不应生成学习轨迹');
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);
}
