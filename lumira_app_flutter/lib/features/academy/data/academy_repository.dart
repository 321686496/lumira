import 'academy_dao.dart';
import 'academy_mock_data.dart';
import 'academy_models.dart';

abstract class AcademyRepository {
  // 课程数据
  List<AcademyCourse> getCourses({AcademyLevel? level, AcademyTopic? topic});
  AcademyCourse? getCourse(String courseId);
  AcademyCourseDetail? getCourseDetail(String courseId);
  AcademyAssignment? getAssignment(String courseId);

  // 学习进度
  Future<AcademyOverview> getOverview();
  Future<CourseProgress?> getProgress(String courseId);
  Future<void> markStarted(String courseId);
  Future<void> updateProgress(String courseId, int percent);
  Future<void> markCompleted(String courseId);
  Future<int> getStreakDays();

  // 作业
  Future<AssignmentSubmission?> getSubmission(String assignmentId);
  Future<void> submitAssignment(AssignmentSubmission submission);
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId);

  // 知识卡片
  List<KnowledgeCard> getKnowledgeCards({AcademyTopic? topic});
  KnowledgeCard? getKnowledgeCard(String cardId);
  Future<bool> isCardFavorited(String cardId);
  Future<void> toggleFavorite(String cardId);
  Future<Set<String>> getFavoriteCardIds();
}

class LocalAcademyRepository implements AcademyRepository {
  final AcademyDao _dao;
  final DateTime Function() _now;

  LocalAcademyRepository({
    required AcademyDao dao,
    DateTime Function()? now,
  })  : _dao = dao,
        _now = now ?? DateTime.now;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  List<AcademyCourse> getCourses({AcademyLevel? level, AcademyTopic? topic}) {
    var result = AcademyMockData.courses;
    if (level != null) {
      result = result.where((c) => c.level == level).toList();
    }
    if (topic != null) {
      result = result.where((c) => c.topic == topic).toList();
    }
    return result;
  }

  @override
  AcademyCourse? getCourse(String courseId) =>
      AcademyMockData.getCourse(courseId);

  @override
  AcademyCourseDetail? getCourseDetail(String courseId) =>
      AcademyMockData.getCourseDetail(courseId);

  @override
  AcademyAssignment? getAssignment(String courseId) =>
      AcademyMockData.getAssignment(courseId);

  @override
  Future<AcademyOverview> getOverview() async {
    final completedCount = await _dao.countCompleted();
    final allProgress = await _dao.getAllProgress();
    final streakDays = await getStreakDays();

    // 计算 XP：已完成课程的 rewardXP 之和
    int totalXP = 0;
    final completedIds = allProgress
        .where((p) => p.status == CourseStatus.completed)
        .map((p) => p.courseId)
        .toList();
    for (final id in completedIds) {
      final course = AcademyMockData.getCourse(id);
      if (course != null) totalXP += course.rewardXP;
    }

    // 推荐下一课：第一个未完成的课程
    String? nextId;
    String? nextTitle;
    for (final course in AcademyMockData.courses) {
      final progress = allProgress.firstWhere(
        (p) => p.courseId == course.id,
        orElse: () => const CourseProgress(
          courseId: '',
          status: CourseStatus.notStarted,
          progressPercent: 0,
        ),
      );
      if (progress.status != CourseStatus.completed) {
        nextId = course.id;
        nextTitle = course.title;
        break;
      }
    }

    return AcademyOverview(
      streakDays: streakDays,
      completedCourses: completedCount,
      totalCourses: AcademyMockData.courses.length,
      totalXP: totalXP,
      nextCourseId: nextId,
      nextCourseTitle: nextTitle,
    );
  }

  @override
  Future<CourseProgress?> getProgress(String courseId) =>
      _dao.getProgress(courseId);

  @override
  Future<void> markStarted(String courseId) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.inProgress,
      existing?.progressPercent ?? 0,
      startedAt: existing?.startedAt ?? now,
      lastViewedAt: now,
    );
  }

  @override
  Future<void> updateProgress(String courseId, int percent) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.inProgress,
      percent,
      startedAt: existing?.startedAt ?? now,
      lastViewedAt: now,
    );
  }

  @override
  Future<void> markCompleted(String courseId) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.completed,
      100,
      startedAt: existing?.startedAt ?? now,
      completedAt: now,
      lastViewedAt: now,
    );
  }

  @override
  Future<int> getStreakDays() async {
    // 简化实现：基于最后查看课程的日期计算连续天数
    final allProgress = await _dao.getAllProgress();
    if (allProgress.isEmpty) return 0;

    // 按日期排序去重
    final dates = <String>{};
    for (final p in allProgress) {
      if (p.lastViewedAt != null) {
        dates.add(_formatDate(DateTime.fromMillisecondsSinceEpoch(p.lastViewedAt!)));
      }
    }
    if (dates.isEmpty) return 0;

    // 从今天往回数连续天数
    int streak = 0;
    var checkDate = _now();
    while (dates.contains(_formatDate(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // === 作业 ===

  @override
  Future<AssignmentSubmission?> getSubmission(String assignmentId) =>
      _dao.getSubmission(assignmentId);

  @override
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    await _dao.upsertSubmission(submission);
  }

  @override
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) =>
      _dao.getCourseSubmissions(courseId);

  // === 知识卡片 ===

  @override
  List<KnowledgeCard> getKnowledgeCards({AcademyTopic? topic}) =>
      AcademyMockData.getKnowledgeCardsByTopic(topic);

  @override
  KnowledgeCard? getKnowledgeCard(String cardId) =>
      AcademyMockData.getKnowledgeCard(cardId);

  @override
  Future<bool> isCardFavorited(String cardId) =>
      _dao.isCardFavorited(cardId);

  @override
  Future<void> toggleFavorite(String cardId) async {
    final isFav = await _dao.isCardFavorited(cardId);
    if (isFav) {
      await _dao.removeFavorite(cardId);
    } else {
      await _dao.addFavorite(cardId, _now().millisecondsSinceEpoch);
    }
  }

  @override
  Future<Set<String>> getFavoriteCardIds() => _dao.getFavoriteCardIds();
}
