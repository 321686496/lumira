import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_repository.dart';

void main() {
  late Database db;
  late AcademyDao dao;
  late LocalAcademyRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = AcademyDao(db);
    repo = LocalAcademyRepository(
      dao: dao,
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('markCompleted trajectory maintenance', () {
    test('does not create trajectory when not fully completed (no submission)',
        () async {
      await repo.markCompleted('c1');
      expect(await dao.getTrajectory('c1'), isNull);
    });

    test('creates trajectory when fully completed', () async {
      // 先提交带照片的作业
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      // 标记完成
      await repo.markCompleted('c1');

      final traj = await dao.getTrajectory('c1');
      expect(traj, isNotNull);
      expect(traj!.courseId, 'c1');
      expect(traj.sequence, 1);
      expect(traj.completedAt, 5000);
    });

    test('does not duplicate trajectory on repeated markCompleted', () async {
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      await repo.markCompleted('c1');
      await repo.markCompleted('c1');

      final all = await dao.getAllTrajectory();
      expect(all.length, 1);
      expect(all.first.sequence, 1);
      // completedAt 应保持首次值
      expect(all.first.completedAt, 5000);
    });

    test('assigns incrementing sequence across courses', () async {
      // 课程 c1
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo1.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));
      await repo.markCompleted('c1');

      // 课程 c2
      await dao.upsertSubmission(AssignmentSubmission(
        id: 's2',
        assignmentId: 'a2',
        courseId: 'c2',
        photoPath: '/photo2.jpg',
        status: AssignmentStatus.submitted,
        submittedAt: 2000,
      ));
      await repo.markCompleted('c2');

      final all = await dao.getAllTrajectory();
      expect(all.length, 2);
      expect(all[0].courseId, 'c1');
      expect(all[0].sequence, 1);
      expect(all[1].courseId, 'c2');
      expect(all[1].sequence, 2);
    });
  });

  group('submitAssignment triggers markCompleted', () {
    test('submitAssignment with photoPath creates trajectory', () async {
      await repo.submitAssignment(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: '/photo.jpg',
        status: AssignmentStatus.reviewed,
        submittedAt: 1000,
      ));

      final traj = await dao.getTrajectory('c1');
      expect(traj, isNotNull);
      expect(traj!.sequence, 1);

      // 验证课程进度也被标记为 completed
      final progress = await dao.getProgress('c1');
      expect(progress?.status, CourseStatus.completed);
    });

    test('submitAssignment without photoPath does not create trajectory',
        () async {
      await repo.submitAssignment(AssignmentSubmission(
        id: 's1',
        assignmentId: 'a1',
        courseId: 'c1',
        photoPath: null,
        status: AssignmentStatus.submitted,
        submittedAt: 1000,
      ));

      expect(await dao.getTrajectory('c1'), isNull);
    });
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);
}
