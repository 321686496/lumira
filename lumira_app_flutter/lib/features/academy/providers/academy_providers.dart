import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/academy_repository.dart';
import '../data/academy_models.dart';
import '../data/academy_mock_data.dart';

// === DAO & Repository ===

final academyRepositoryProvider = FutureProvider<AcademyRepository>((ref) async {
  final dao = await ref.watch(academyDaoProvider.future);
  return LocalAcademyRepository(dao: dao);
});

// === 课程数据 ===

/// 按等级筛选课程（null = 全部）
final coursesProvider = Provider.family<List<AcademyCourse>, AcademyLevel?>((ref, level) {
  // 同步访问 mock 数据，无需 async
  return AcademyMockData.courses
      .where((c) => level == null || c.level == level)
      .toList();
});

/// 课程详情
final courseDetailProvider = Provider.family<AcademyCourseDetail?, String>((ref, courseId) {
  return AcademyMockData.getCourseDetail(courseId);
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

// === 作业 ===

/// 作业提交记录
final assignmentSubmissionProvider = FutureProvider.family<AssignmentSubmission?, String>((ref, assignmentId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getSubmission(assignmentId);
});

// === 知识卡片 ===

/// 知识卡片列表
final knowledgeCardsProvider = Provider<List<KnowledgeCard>>((ref) {
  return AcademyMockData.knowledgeCards;
});

/// 收藏卡片 ID 集合
final favoriteCardIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getFavoriteCardIds();
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

  void _refresh() {
    state = AcademyActionState(state.version + 1);
  }
}
