import 'package:sqflite/sqflite.dart';

import 'academy_models.dart';

/// 学院相关表名与列名常量
class AcademyTables {
  AcademyTables._();

  // === academy_course_progress ===
  static const courseProgress = 'academy_course_progress';
  static const cpColCourseId = 'course_id';
  static const cpColStatus = 'status';
  static const cpColProgressPercent = 'progress_percent';
  static const cpColStartedAt = 'started_at';
  static const cpColCompletedAt = 'completed_at';
  static const cpColLastViewedAt = 'last_viewed_at';

  static const cpCreateSql = '''
    CREATE TABLE IF NOT EXISTS $courseProgress (
      $cpColCourseId TEXT PRIMARY KEY,
      $cpColStatus TEXT NOT NULL DEFAULT 'not_started',
      $cpColProgressPercent INTEGER NOT NULL DEFAULT 0,
      $cpColStartedAt INTEGER,
      $cpColCompletedAt INTEGER,
      $cpColLastViewedAt INTEGER
    )
  ''';

  // === academy_assignment_submission ===
  static const assignmentSubmission = 'academy_assignment_submission';
  static const asColId = 'id';
  static const asColAssignmentId = 'assignment_id';
  static const asColCourseId = 'course_id';
  static const asColPhotoPath = 'photo_path';
  static const asColPhotoUrl = 'photo_url';
  static const asColNote = 'note';
  static const asColStatus = 'status';
  static const asColScore = 'score';
  static const asColFeedback = 'feedback';
  static const asColSubmittedAt = 'submitted_at';

  static const asCreateSql = '''
    CREATE TABLE IF NOT EXISTS $assignmentSubmission (
      $asColId TEXT PRIMARY KEY,
      $asColAssignmentId TEXT UNIQUE,
      $asColCourseId TEXT NOT NULL,
      $asColPhotoPath TEXT,
      $asColPhotoUrl TEXT,
      $asColNote TEXT,
      $asColStatus TEXT NOT NULL DEFAULT 'not_submitted',
      $asColScore INTEGER,
      $asColFeedback TEXT,
      $asColSubmittedAt INTEGER NOT NULL
    )
  ''';

  // === academy_knowledge_favorite ===
  static const knowledgeFavorite = 'academy_knowledge_favorite';
  static const kfColCardId = 'card_id';
  static const kfColFavoritedAt = 'favorited_at';

  static const kfCreateSql = '''
    CREATE TABLE IF NOT EXISTS $knowledgeFavorite (
      $kfColCardId TEXT PRIMARY KEY,
      $kfColFavoritedAt INTEGER NOT NULL
    )
  ''';
}

/// 学院 DAO
class AcademyDao {
  final Database _db;
  AcademyDao(this._db);

  // === 课程进度 ===

  Future<CourseProgress?> getProgress(String courseId) async {
    final rows = await _db.query(
      AcademyTables.courseProgress,
      where: '${AcademyTables.cpColCourseId} = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToProgress(rows.first);
  }

  Future<List<CourseProgress>> getAllProgress() async {
    final rows = await _db.query(AcademyTables.courseProgress);
    return rows.map(_rowToProgress).toList();
  }

  Future<void> upsertProgress(String courseId, CourseStatus status, int percent, {int? startedAt, int? completedAt, int? lastViewedAt}) async {
    await _db.insert(
      AcademyTables.courseProgress,
      {
        AcademyTables.cpColCourseId: courseId,
        AcademyTables.cpColStatus: _courseStatusToString(status),
        AcademyTables.cpColProgressPercent: percent,
        AcademyTables.cpColStartedAt: startedAt,
        AcademyTables.cpColCompletedAt: completedAt,
        AcademyTables.cpColLastViewedAt: lastViewedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countCompleted() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AcademyTables.courseProgress} WHERE ${AcademyTables.cpColStatus} = ?',
      ['completed'],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> sumRewardXP(List<String> completedCourseIds) async {
    if (completedCourseIds.isEmpty) return 0;
    final placeholders = List.filled(completedCourseIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AcademyTables.courseProgress} WHERE ${AcademyTables.cpColCourseId} IN ($placeholders) AND ${AcademyTables.cpColStatus} = ?',
      [...completedCourseIds, 'completed'],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  CourseProgress _rowToProgress(Map<String, Object?> row) {
    return CourseProgress(
      courseId: row[AcademyTables.cpColCourseId] as String,
      status: CourseStatusExt.fromName(row[AcademyTables.cpColStatus] as String?),
      progressPercent: row[AcademyTables.cpColProgressPercent] as int? ?? 0,
      startedAt: row[AcademyTables.cpColStartedAt] as int?,
      completedAt: row[AcademyTables.cpColCompletedAt] as int?,
      lastViewedAt: row[AcademyTables.cpColLastViewedAt] as int?,
    );
  }

  // === 作业提交 ===

  Future<AssignmentSubmission?> getSubmission(String assignmentId) async {
    final rows = await _db.query(
      AcademyTables.assignmentSubmission,
      where: '${AcademyTables.asColAssignmentId} = ?',
      whereArgs: [assignmentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToSubmission(rows.first);
  }

  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) async {
    final rows = await _db.query(
      AcademyTables.assignmentSubmission,
      where: '${AcademyTables.asColCourseId} = ?',
      whereArgs: [courseId],
      orderBy: '${AcademyTables.asColSubmittedAt} DESC',
    );
    return rows.map(_rowToSubmission).toList();
  }

  Future<void> upsertSubmission(AssignmentSubmission submission) async {
    await _db.insert(
      AcademyTables.assignmentSubmission,
      {
        AcademyTables.asColId: submission.id,
        AcademyTables.asColAssignmentId: submission.assignmentId,
        AcademyTables.asColCourseId: submission.courseId,
        AcademyTables.asColPhotoPath: submission.photoPath,
        AcademyTables.asColPhotoUrl: submission.photoUrl,
        AcademyTables.asColNote: submission.note,
        AcademyTables.asColStatus: _assignmentStatusToString(submission.status),
        AcademyTables.asColScore: submission.score,
        AcademyTables.asColFeedback: submission.feedback,
        AcademyTables.asColSubmittedAt: submission.submittedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  AssignmentSubmission _rowToSubmission(Map<String, Object?> row) {
    return AssignmentSubmission(
      id: row[AcademyTables.asColId] as String,
      assignmentId: row[AcademyTables.asColAssignmentId] as String,
      courseId: row[AcademyTables.asColCourseId] as String,
      photoPath: row[AcademyTables.asColPhotoPath] as String?,
      photoUrl: row[AcademyTables.asColPhotoUrl] as String?,
      note: row[AcademyTables.asColNote] as String?,
      status: AssignmentStatusExt.fromName(row[AcademyTables.asColStatus] as String?),
      score: row[AcademyTables.asColScore] as int?,
      feedback: row[AcademyTables.asColFeedback] as String?,
      submittedAt: row[AcademyTables.asColSubmittedAt] as int,
    );
  }

  // === 知识卡片收藏 ===

  Future<bool> isCardFavorited(String cardId) async {
    final rows = await _db.query(
      AcademyTables.knowledgeFavorite,
      where: '${AcademyTables.kfColCardId} = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getFavoriteCardIds() async {
    final rows = await _db.query(AcademyTables.knowledgeFavorite);
    return rows.map((r) => r[AcademyTables.kfColCardId] as String).toSet();
  }

  Future<void> addFavorite(String cardId, int timestamp) async {
    await _db.insert(
      AcademyTables.knowledgeFavorite,
      {AcademyTables.kfColCardId: cardId, AcademyTables.kfColFavoritedAt: timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String cardId) async {
    await _db.delete(
      AcademyTables.knowledgeFavorite,
      where: '${AcademyTables.kfColCardId} = ?',
      whereArgs: [cardId],
    );
  }

  // === 枚举序列化辅助 ===
  // 注意：Dart 2.15+ 的 Enum.name 会遮蔽扩展中定义的 String get name，
  // 且扩展的 name getter 返回 camelCase（如 'inProgress'），
  // 而 fromName 期望 snake_case（如 'in_progress'）。
  // 因此必须显式转换为 snake_case，避免数据读写不一致。
  static String _courseStatusToString(CourseStatus status) {
    switch (status) {
      case CourseStatus.notStarted: return 'not_started';
      case CourseStatus.inProgress: return 'in_progress';
      case CourseStatus.completed: return 'completed';
    }
  }

  static String _assignmentStatusToString(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.notSubmitted: return 'not_submitted';
      case AssignmentStatus.submitted: return 'submitted';
      case AssignmentStatus.reviewed: return 'reviewed';
    }
  }
}
