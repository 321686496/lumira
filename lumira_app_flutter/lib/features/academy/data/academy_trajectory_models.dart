/// 学院学习轨迹记录（持久化）
///
/// 记录用户完成的课程及其完成顺序。
/// 当 [AcademyRepository.markCompleted] 检测到课程完全完成
/// （status=completed 且作业有 photoPath）时自动 upsert。
class AcademyTrajectoryRecord {
  final String courseId;
  final int completedAt;
  final int sequence;

  const AcademyTrajectoryRecord({
    required this.courseId,
    required this.completedAt,
    required this.sequence,
  });
}
