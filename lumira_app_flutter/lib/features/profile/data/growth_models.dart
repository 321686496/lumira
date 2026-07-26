/// 成长中心数据模型（来自 DAO 的只读计算结果）

class GrowthSummary {
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final String levelName;

  const GrowthSummary({
    required this.level,
    required this.currentXp,
    required this.xpToNextLevel,
    required this.levelName,
  });

  static const GrowthSummary empty = GrowthSummary(
    level: 1,
    currentXp: 0,
    xpToNextLevel: 500,
    levelName: '新手',
  );
}

class AchievementRecord {
  final String id;
  final String name;
  final String description;
  final String iconKey; // 内置图标 key，UI 层映射为 IconData
  final bool unlocked;
  final int? unlockedAt;

  const AchievementRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.unlocked,
    this.unlockedAt,
  });
}

class GrowthTrajectoryRecord {
  final String eventId;
  final String type; // 'challenge' | 'course' | 'milestone'
  final String title;
  final int timestamp;

  const GrowthTrajectoryRecord({
    required this.eventId,
    required this.type,
    required this.title,
    required this.timestamp,
  });
}

class HeatmapCell {
  final String date; // YYYY-MM-DD
  final int count;

  const HeatmapCell({required this.date, required this.count});
}

/// 6 项成就墙的占位定义（无 DB 记录时返回）
const List<AchievementRecord> kPlaceholderAchievements = [
  AchievementRecord(id: 'ach_first_photo', name: '初次拍摄', description: '完成第一次拍摄', iconKey: 'camera', unlocked: false),
  AchievementRecord(id: 'ach_streak_7', name: '连续7天', description: '连续打卡 7 天', iconKey: 'flame', unlocked: false),
  AchievementRecord(id: 'ach_streak_30', name: '坚持30天', description: '连续打卡 30 天', iconKey: 'flame', unlocked: false),
  AchievementRecord(id: 'ach_templates_5', name: '模板收藏家', description: '创建 5 个自定义模板', iconKey: 'layers', unlocked: false),
  AchievementRecord(id: 'ach_challenge_10', name: '挑战达人', description: '完成 10 次挑战', iconKey: 'trophy', unlocked: false),
  AchievementRecord(id: 'ach_level_5', name: '进阶玩家', description: '达到 5 级', iconKey: 'star', unlocked: false),
];
