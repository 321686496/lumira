import 'package:flutter/material.dart';

// === 枚举 ===

enum AcademyLevel { beginner, intermediate, advanced }

enum AcademyTopic { portrait, landscape, stillLife, street }

enum CourseStatus { notStarted, inProgress, completed }

enum AssignmentStatus { notSubmitted, submitted, reviewed }

// === 扩展方法：枚举转字符串与标签 ===

extension AcademyLevelExt on AcademyLevel {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case AcademyLevel.beginner: return '入门基础';
      case AcademyLevel.intermediate: return '进阶技巧';
      case AcademyLevel.advanced: return '高级创作';
    }
  }
}

extension AcademyTopicExt on AcademyTopic {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case AcademyTopic.portrait: return '人像';
      case AcademyTopic.landscape: return '风光';
      case AcademyTopic.stillLife: return '静物';
      case AcademyTopic.street: return '街头';
    }
  }
}

extension CourseStatusExt on CourseStatus {
  String get name => toString().split('.').last;
  static CourseStatus fromName(String? s) {
    switch (s) {
      case 'in_progress': return CourseStatus.inProgress;
      case 'completed': return CourseStatus.completed;
      default: return CourseStatus.notStarted;
    }
  }
}

extension AssignmentStatusExt on AssignmentStatus {
  String get name => toString().split('.').last;
  static AssignmentStatus fromName(String? s) {
    switch (s) {
      case 'submitted': return AssignmentStatus.submitted;
      case 'reviewed': return AssignmentStatus.reviewed;
      default: return AssignmentStatus.notSubmitted;
    }
  }
}

// === 从 profile_content_mock_data.dart 迁移的模型 ===

/// 摄影学院课程章节
class LessonSection {
  final String title;
  final List<String> paragraphs;
  const LessonSection({required this.title, required this.paragraphs});
}

/// 对比卡片（academy-detail 用）
class CompareCell {
  final String iconName;
  final String name;
  final String desc;
  final String tagText;
  final String tagColor;
  const CompareCell({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.tagText,
    required this.tagColor,
  });
}

/// 实战练习标签
class PracticeTag {
  final String iconName;
  final String label;
  final String color;
  const PracticeTag({
    required this.iconName,
    required this.label,
    required this.color,
  });
}

/// 推荐模板
class RecommendTemplate {
  final String imageUrl;
  final String name;
  final String desc;
  final String badge;
  const RecommendTemplate({
    required this.imageUrl,
    required this.name,
    required this.desc,
    required this.badge,
  });
}

// === 核心数据类 ===

/// 课程元数据（列表展示）
class AcademyCourse {
  final String id;
  final int lessonNumber;
  final String title;
  final AcademyLevel level;
  final AcademyTopic topic;
  final String coverImage;
  final String meta; // 如 "8分钟 · 进阶入门"
  final List<String> tags;
  final int rewardXP;

  const AcademyCourse({
    required this.id,
    required this.lessonNumber,
    required this.title,
    required this.level,
    required this.topic,
    required this.coverImage,
    required this.meta,
    this.tags = const [],
    this.rewardXP = 50,
  });
}

/// 课程详情（完整内容）
class AcademyCourseDetail {
  final AcademyCourse course;
  final String heroImage;
  final List<LessonSection> sections;
  final String tipCardTitle;
  final String tipCardParagraph;
  final String tipCardImage;
  final List<CompareCell> compareCells;
  final String practiceTitle;
  final String practiceParagraph;
  final List<PracticeTag> practiceTags;
  final List<String> tips;
  final RecommendTemplate? recommendTemplate;
  final List<String> knowledgeCardIds; // 关联知识卡片 ID
  final AcademyAssignment? assignment;

  const AcademyCourseDetail({
    required this.course,
    required this.heroImage,
    required this.sections,
    required this.tipCardTitle,
    required this.tipCardParagraph,
    required this.tipCardImage,
    required this.compareCells,
    required this.practiceTitle,
    required this.practiceParagraph,
    required this.practiceTags,
    required this.tips,
    this.recommendTemplate,
    this.knowledgeCardIds = const [],
    this.assignment,
  });
}

/// 美学知识卡片
class KnowledgeCard {
  final String id;
  final AcademyTopic topic;
  final String title;
  final String subtitle;
  final String coverImage;
  final String body; // 卡片正文
  final List<String> keyPoints; // 关键要点

  const KnowledgeCard({
    required this.id,
    required this.topic,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.body,
    this.keyPoints = const [],
  });
}

/// 作业定义
class AcademyAssignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final List<String> requirements; // 作业要求
  final int rewardXP;

  const AcademyAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    this.requirements = const [],
    this.rewardXP = 100,
  });
}

/// 作业提交记录
class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String courseId;
  final String? photoPath; // 本地照片路径
  final String? photoUrl; // 网络照片 URL
  final String? note; // 用户备注
  final AssignmentStatus status;
  final int? score; // 评分 0-100
  final String? feedback; // 反馈
  final int submittedAt;

  const AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.courseId,
    this.photoPath,
    this.photoUrl,
    this.note,
    required this.status,
    this.score,
    this.feedback,
    required this.submittedAt,
  });
}

/// 学习概览
class AcademyOverview {
  final int streakDays; // 连续学习天数
  final int completedCourses; // 已完成课程数
  final int totalCourses; // 总课程数
  final int totalXP; // 累计 XP
  final String? nextCourseId; // 推荐下一课 ID
  final String? nextCourseTitle; // 推荐下一课标题

  const AcademyOverview({
    required this.streakDays,
    required this.completedCourses,
    required this.totalCourses,
    required this.totalXP,
    this.nextCourseId,
    this.nextCourseTitle,
  });

  double get completionRate =>
      totalCourses > 0 ? completedCourses / totalCourses : 0;
}

/// 课程进度记录（持久化）
class CourseProgress {
  final String courseId;
  final CourseStatus status;
  final int progressPercent;
  final int? startedAt;
  final int? completedAt;
  final int? lastViewedAt;

  const CourseProgress({
    required this.courseId,
    required this.status,
    required this.progressPercent,
    this.startedAt,
    this.completedAt,
    this.lastViewedAt,
  });
}
