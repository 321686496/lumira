import 'package:flutter/material.dart';

/// 挑战状态
enum ChallengeStatus {
  /// 已完成
  done,
  /// 未完成 / 可完成
  pending,
  /// 锁定（明日预览等）
  locked,
}

/// 附加挑战标签色
enum ChallengeTagColor {
  gold,
  green,
  red,
}

/// 主挑战卡数据
class MainChallenge {
  const MainChallenge({
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.status,
    this.coverImage,
    this.tags = const [],
  });

  final String title;
  final String description;
  final int rewardXP;
  final ChallengeStatus status;
  final String? coverImage;
  final List<ChallengeTag> tags;
}

/// 支线挑战数据
class SubChallenge {
  const SubChallenge({
    required this.id,
    required this.title,
    required this.icon,
    required this.status,
    required this.progressCurrent,
    required this.progressTotal,
    required this.rewardXP,
    this.tags = const [],
  });

  final String id;
  final String title;
  final IconData icon;
  final ChallengeStatus status;
  final int progressCurrent;
  final int progressTotal;
  final int rewardXP;
  final List<ChallengeTag> tags;
}

/// 挑战标签
class ChallengeTag {
  const ChallengeTag({
    required this.label,
    required this.color,
    this.showCheckIcon = false,
  });

  final String label;
  final ChallengeTagColor color;
  final bool showCheckIcon;
}

/// 明日预览数据
class TomorrowPreview {
  const TomorrowPreview({
    required this.mainTitle,
    required this.subTitles,
    this.locked = true,
  });

  final String mainTitle;
  final List<String> subTitles;
  final bool locked;
}

/// 连续打卡数据
class StreakInfo {
  const StreakInfo({
    required this.currentStreak,
    required this.totalDays,
    required this.nextRewardXP,
    required this.tipMessage,
  });

  final int currentStreak;
  final int totalDays;
  final int nextRewardXP;
  final String tipMessage;
}

/// 挑战详情数据
class ChallengeDetail {
  const ChallengeDetail({
    required this.id,
    required this.badge,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.progressCurrent,
    required this.progressTotal,
    required this.requirements,
    required this.tips,
    this.completedWork,
    this.status = ChallengeStatus.done,
  });

  final String id;
  final String badge;
  final String title;
  final String description;
  final int rewardXP;
  final int progressCurrent;
  final int progressTotal;
  final List<Requirement> requirements;
  final List<Tip> tips;
  final Work? completedWork;
  final ChallengeStatus status;
}

/// 挑战要求项
class Requirement {
  const Requirement({
    required this.index,
    required this.title,
    required this.description,
    required this.done,
  });

  final int index;
  final String title;
  final String description;
  final bool done;
}

/// 拍摄建议项
class Tip {
  const Tip({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final ChallengeTagColor iconColor;
  final String title;
  final String description;
}

/// 完成的作品
class Work {
  const Work({
    required this.imageUrl,
    required this.date,
    required this.title,
    required this.tags,
  });

  final String imageUrl;
  final String date;
  final String title;
  final List<ChallengeTag> tags;
}
