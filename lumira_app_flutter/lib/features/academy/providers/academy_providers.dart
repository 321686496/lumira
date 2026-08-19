import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/academy_repository.dart';
import '../data/academy_models.dart';
import '../data/academy_content.dart';
import '../data/academy_trajectory_models.dart';

// === DAO & Repository ===

final academyRepositoryProvider = FutureProvider<AcademyRepository>((ref) async {
  final dao = await ref.watch(academyDaoProvider.future);
  return LocalAcademyRepository(dao: dao);
});

// === 课程数据 ===

/// 按等级筛选课程（null = 全部）
final coursesProvider = Provider.family<List<AcademyCourse>, AcademyLevel?>((ref, level) {
  // 同步访问本地课程内容数据，无需 async
  return AcademyContent.courses
      .where((c) => level == null || c.level == level)
      .toList();
});

/// 课程详情
final courseDetailProvider = Provider.family<AcademyCourseDetail?, String>((ref, courseId) {
  return AcademyContent.getCourseDetail(courseId);
});

// === 学习进度 ===

/// 学习概览
final academyOverviewProvider = FutureProvider<AcademyOverview>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getOverview();
});

/// 单课进度
final courseProgressProvider = FutureProvider.family<CourseProgress?, String>((ref, courseId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getProgress(courseId);
});

/// 课程是否完全完成（status=completed 且作业有 photoPath）
final courseFullyCompletedProvider =
    FutureProvider.family<bool, String>((ref, courseId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.isCourseFullyCompleted(courseId);
});

/// 学习轨迹列表（按 sequence ASC）
final academyTrajectoryProvider =
    FutureProvider<List<AcademyTrajectoryRecord>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getAllTrajectory();
});

/// 排序后的课程列表
/// 规则：
/// 1. 先按完全完成状态分组：未完全完成的在前，已完全完成的沉底（跨 level）
/// 2. 未完成组内：按 level 升序，同 level 按 lastViewedAt DESC
/// 3. 已完成组内：按 level 升序，同 level 按 completedAt ASC
final sortedCoursesProvider = FutureProvider.family<List<AcademyCourse>, AcademyLevel?>(
    (ref, level) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  final allCourses = AcademyContent.courses
      .where((c) => level == null || c.level == level)
      .toList();

  // 获取每门课的进度和完全完成状态
  final courseData = <_CourseSortData>[];
  for (final course in allCourses) {
    final progress = await repo.getProgress(course.id);
    final isFullyCompleted = await repo.isCourseFullyCompleted(course.id);
    courseData.add(_CourseSortData(
      course: course,
      progress: progress,
      isFullyCompleted: isFullyCompleted,
    ));
  }

  // 排序：已完全完成的课程统一沉底
  courseData.sort((a, b) {
    // 1. 未完成在前，已完成沉底（跨 level）
    if (a.isFullyCompleted != b.isFullyCompleted) {
      return a.isFullyCompleted ? 1 : -1;
    }

    // 2. 同组内按 level 升序
    final levelCompare = a.course.level.index.compareTo(b.course.level.index);
    if (levelCompare != 0) return levelCompare;

    if (a.isFullyCompleted) {
      // 都已完成：按 completedAt ASC
      final aCompletedAt = a.progress?.completedAt ?? 0;
      final bCompletedAt = b.progress?.completedAt ?? 0;
      return aCompletedAt.compareTo(bCompletedAt);
    } else {
      // 都未完成：按 lastViewedAt DESC
      final aLastViewed = a.progress?.lastViewedAt ?? 0;
      final bLastViewed = b.progress?.lastViewedAt ?? 0;
      return bLastViewed.compareTo(aLastViewed);
    }
  });

  return courseData.map((d) => d.course).toList();
});

class _CourseSortData {
  final AcademyCourse course;
  final CourseProgress? progress;
  final bool isFullyCompleted;

  const _CourseSortData({
    required this.course,
    required this.progress,
    required this.isFullyCompleted,
  });
}

// === 作业 ===

/// 作业提交记录
final assignmentSubmissionProvider = FutureProvider.family<AssignmentSubmission?, String>((ref, assignmentId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getSubmission(assignmentId);
});

// === 知识卡片 ===

/// 知识卡片列表
final knowledgeCardsProvider = Provider<List<KnowledgeCard>>((ref) {
  return AcademyContent.knowledgeCards;
});

/// 收藏卡片 ID 集合
final favoriteCardIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getFavoriteCardIds();
});

/// 收藏课程 ID 集合
final favoriteCourseIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getFavoriteCourseIds();
});

// === 状态变更通知器 ===

/// 操作后刷新用的状态
class AcademyActionState {
  final int version;
  const AcademyActionState(this.version);
}

final academyActionsProvider = StateNotifierProvider<AcademyActionNotifier, AcademyActionState>((ref) {
  return AcademyActionNotifier(ref);
});

class AcademyActionNotifier extends StateNotifier<AcademyActionState> {
  final Ref _ref;
  AcademyActionNotifier(this._ref) : super(const AcademyActionState(0));

  Future<void> markStarted(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.markStarted(courseId);
    _refresh();
  }

  Future<void> markCompleted(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.markCompleted(courseId);
    _refresh();
  }

  Future<void> submitAssignment(AssignmentSubmission submission) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.submitAssignment(submission);
    _refresh();
  }

  Future<void> toggleFavorite(String cardId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.toggleFavorite(cardId);
    _refresh();
  }

  Future<void> toggleCourseFavorite(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.toggleCourseFavorite(courseId);
    _refresh();
  }

  void _refresh() {
    state = AcademyActionState(state.version + 1);
    // 失效所有依赖 DAO 数据的 provider，确保下次读取时重新计算。
    // 仅靠 state.version 自增只会触发 watch academyActionsProvider 的 widget 重建，
    // 但 FutureProvider 自身的缓存仍是旧值（如 sortedCoursesProvider /
    // courseFullyCompletedProvider / academyTrajectoryProvider），
    // 必须显式 invalidate 才能让 markCompleted / submitAssignment 后的
    // 「已学完徽章」「课程排序沉底」「学习轨迹列表」立即可见。
    _ref.invalidate(academyOverviewProvider);
    _ref.invalidate(courseProgressProvider);
    _ref.invalidate(courseFullyCompletedProvider);
    _ref.invalidate(academyTrajectoryProvider);
    _ref.invalidate(sortedCoursesProvider);
    _ref.invalidate(assignmentSubmissionProvider);
    _ref.invalidate(favoriteCardIdsProvider);
  }
}
