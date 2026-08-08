import 'package:flutter/material.dart';

/// 挑战状态
enum ChallengeStatus {
  /// 已完成
  done,
  /// 未完成 / 可完成
  pending,
  /// 锁定（明日预览等）
  locked,
  /// 已跳过
  skipped,
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
    this.photoId,
    this.tags = const [],
  });

  final String title;
  final String description;
  final int rewardXP;
  final ChallengeStatus status;
  final String? coverImage;
  /// 已完成态关联的作品照片 ID（来自 gallery_items），存在时优先显示真实照片
  final String? photoId;
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

// === 每日挑战增强模型 ===

/// 挑战分类常量（与模板 category 对齐）
class ChallengeCategory {
  static const portrait = 'portrait';
  static const landscape = 'landscape';
  static const food = 'food';
  static const street = 'street';
  static const night = 'night';
  static const macro = 'macro';
  static const stillLife = 'still-life';

  static const all = [portrait, landscape, food, street, night, macro, stillLife];

  static String label(String category) {
    switch (category) {
      case portrait:
        return '人像';
      case landscape:
        return '风光';
      case food:
        return '美食';
      case street:
        return '街拍';
      case night:
        return '夜景';
      case macro:
        return '微距';
      case stillLife:
        return '静物';
      default:
        return '未知';
    }
  }
}

/// 题库条目
class ChallengePoolItem {
  final String id;
  final String category;
  final String title;
  final String description;
  final int rewardXP;
  final String tip;
  final List<String> tags;

  const ChallengePoolItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.tip,
    this.tags = const [],
  });
}

/// 历史记录
class ChallengeHistoryRecord {
  final String id;
  final String date;
  final String challengeId;
  final String category;
  final String title;
  final int rewardXP;
  final ChallengeStatus status;
  final int selectedAt;
  final int? completedAt;
  final int? skippedAt;
  final bool isDaily;
  /// 关联的照片 ID 列表（用于挑战墙溯源展示）
  final List<String> photoIds;

  const ChallengeHistoryRecord({
    required this.id,
    required this.date,
    required this.challengeId,
    required this.category,
    required this.title,
    required this.rewardXP,
    required this.status,
    required this.selectedAt,
    this.completedAt,
    this.skippedAt,
    this.isDaily = false,
    this.photoIds = const [],
  });
}

/// 成就
class ChallengeAchievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final double progress;

  const ChallengeAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    this.progress = 0,
  });
}

/// 本周日历
class WeeklyCalendar {
  final DateTime weekStart;
  final List<DailyStatus> days;
  const WeeklyCalendar({required this.weekStart, required this.days});
}

class DailyStatus {
  final DateTime date;
  final bool isToday;
  final ChallengeStatus status;
  const DailyStatus({required this.date, required this.isToday, required this.status});
}

/// 拍摄技巧
class ChallengeTip {
  final String title;
  final String description;
  final IconData icon;
  final String category;
  const ChallengeTip({required this.title, required this.description, required this.icon, required this.category});
}

/// 当日挑战状态
class DailyChallengeState {
  final bool needsFlip;
  final List<ChallengePoolItem>? candidates;
  final ChallengePoolItem? selected;

  const DailyChallengeState({required this.needsFlip, this.candidates, this.selected});

  factory DailyChallengeState.needsFlipState(List<ChallengePoolItem> candidates) =>
      DailyChallengeState(needsFlip: true, candidates: candidates);
  factory DailyChallengeState.revealedState(ChallengePoolItem selected) =>
      DailyChallengeState(needsFlip: false, selected: selected);
}

/// 用户拍摄画像
class UserShootingProfile {
  final int totalPhotos;
  final Map<String, int> categoryCounts;
  final Set<String> triedCategories;
  final Set<String> untriedCategories;
  final String? topCategory;

  const UserShootingProfile({
    required this.totalPhotos,
    required this.categoryCounts,
    required this.triedCategories,
    required this.untriedCategories,
    this.topCategory,
  });
}
