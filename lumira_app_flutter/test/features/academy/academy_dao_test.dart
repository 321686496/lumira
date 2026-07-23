import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';

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

  group('CourseProgress', () {
    test('getProgress returns null for non-existent course', () async {
      final progress = await dao.getProgress('non_existent');
      expect(progress, isNull);
    });

    test('upsertProgress creates inProgress record', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress, isNotNull);
      expect(progress!.status, CourseStatus.inProgress);
      expect(progress.progressPercent, 0);
      expect(progress.startedAt, now);
      expect(progress.completedAt, isNull);
    });

    test('upsertProgress updates percent', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 50, startedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress!.progressPercent, 50);
      expect(progress.status, CourseStatus.inProgress);
    });

    test('upsertProgress sets completed status and completedAt', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('course_1', CourseStatus.completed, 100, startedAt: now, completedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress!.status, CourseStatus.completed);
      expect(progress.progressPercent, 100);
      expect(progress.completedAt, isNotNull);
    });

    test('getAllProgress returns all records', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c2', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c3', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      final all = await dao.getAllProgress();
      expect(all.length, 3);
    });

    test('countCompleted returns only completed courses', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c2', CourseStatus.completed, 100, startedAt: now, completedAt: now, lastViewedAt: now);
      expect(await dao.countCompleted(), 1);
    });
  });

  group('AssignmentSubmission', () {
    test('getSubmission returns null for non-existent assignment', () async {
      final sub = await dao.getSubmission('non_existent');
      expect(sub, isNull);
    });

    test('upsertSubmission inserts submission', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final submission = AssignmentSubmission(
        id: 'sub_1',
        assignmentId: 'assign_1',
        courseId: 'course_1',
        photoPath: '/path/to/photo.jpg',
        note: '我的作业',
        status: AssignmentStatus.submitted,
        submittedAt: now,
      );
      await dao.upsertSubmission(submission);
      final sub = await dao.getSubmission('assign_1');
      expect(sub, isNotNull);
      expect(sub!.assignmentId, 'assign_1');
      expect(sub.courseId, 'course_1');
      expect(sub.photoPath, '/path/to/photo.jpg');
      expect(sub.note, '我的作业');
      expect(sub.status, AssignmentStatus.submitted);
      expect(sub.submittedAt, now);
    });

    test('upsertSubmission replaces existing (upsert by assignmentId)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertSubmission(AssignmentSubmission(
        id: 'sub_1', assignmentId: 'assign_1', courseId: 'c1',
        photoPath: '/photo1.jpg', note: '第一版',
        status: AssignmentStatus.submitted, submittedAt: now,
      ));
      await dao.upsertSubmission(AssignmentSubmission(
        id: 'sub_2', assignmentId: 'assign_1', courseId: 'c1',
        photoPath: '/photo2.jpg', note: '第二版',
        status: AssignmentStatus.submitted, submittedAt: now,
      ));
      final sub = await dao.getSubmission('assign_1');
      expect(sub!.photoPath, '/photo2.jpg');
      expect(sub.note, '第二版');
    });

    test('getCourseSubmissions filters by courseId', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertSubmission(AssignmentSubmission(id: 's1', assignmentId: 'a1', courseId: 'c1', photoPath: 'p1', status: AssignmentStatus.submitted, submittedAt: now));
      await dao.upsertSubmission(AssignmentSubmission(id: 's2', assignmentId: 'a2', courseId: 'c1', photoPath: 'p2', status: AssignmentStatus.submitted, submittedAt: now));
      await dao.upsertSubmission(AssignmentSubmission(id: 's3', assignmentId: 'a3', courseId: 'c2', photoPath: 'p3', status: AssignmentStatus.submitted, submittedAt: now));
      final c1Subs = await dao.getCourseSubmissions('c1');
      expect(c1Subs.length, 2);
    });
  });

  group('KnowledgeFavorite', () {
    test('isCardFavorited returns false for non-favorited card', () async {
      expect(await dao.isCardFavorited('card_1'), isFalse);
    });

    test('addFavorite inserts favorite', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      expect(await dao.isCardFavorited('card_1'), isTrue);
    });

    test('removeFavorite deletes existing favorite', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      expect(await dao.isCardFavorited('card_1'), isTrue);
      await dao.removeFavorite('card_1');
      expect(await dao.isCardFavorited('card_1'), isFalse);
    });

    test('getFavoriteCardIds returns all favorited ids', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      await dao.addFavorite('card_3', now);
      final ids = await dao.getFavoriteCardIds();
      expect(ids.length, 2);
      expect(ids.contains('card_1'), isTrue);
      expect(ids.contains('card_3'), isTrue);
    });
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
}
