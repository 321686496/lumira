/// 成长中心数据模型（来自 DAO 的只读计算结果）

/// 单一门槛等级定义（Lv.1–20）
class LevelThreshold {
  const LevelThreshold(this.level, this.xp, this.name);
  final int level;
  final int xp; // 达到该级所需最小总XP
  final String name;
}

/// 阶梯阈值表（升序，Lv.1 阈值 0）
// ignore: constant_identifier_names
const List<LevelThreshold> LEVEL_THRESHOLDS = [
  LevelThreshold(1, 0, '初学者'),
  LevelThreshold(2, 100, '入门学徒'),
  LevelThreshold(3, 300, '进阶学徒'),
  LevelThreshold(4, 600, '熟练学徒'),
  LevelThreshold(5, 1000, '摄影新手'),
  LevelThreshold(6, 1500, '摄影爱好者'),
  LevelThreshold(7, 2200, '摄影达人'),
  LevelThreshold(8, 3000, '构图能手'),
  LevelThreshold(9, 4000, '光影大师'),
  LevelThreshold(10, 5500, '摄影专家'),
  LevelThreshold(11, 7500, '摄影艺术家'),
  LevelThreshold(12, 10000, '视觉创作者'),
  LevelThreshold(13, 13500, '光影探索者'),
  LevelThreshold(14, 17500, '视觉叙事师'),
  LevelThreshold(15, 22000, '影像匠人'),
  LevelThreshold(16, 27000, '光影诗人'),
  LevelThreshold(17, 33000, '视觉艺术家'),
  LevelThreshold(18, 40000, '影像大家'),
  LevelThreshold(19, 48000, '光影宗师'),
  LevelThreshold(20, 57000, '摄影大师'),
];

/// 升级积分奖励（key=等级；缺省该 key 表示该级无奖励；本表与后端 LEVEL_REWARD_MAP 必须一致）
// ignore: constant_identifier_names
const Map<int, int> LEVEL_REWARD_MAP = {
  2: 25, 3: 25, 4: 50, 5: 100, 6: 50, 7: 50, 8: 50, 9: 50, 10: 250,
  11: 50, 12: 50, 13: 50, 14: 50, 15: 150, 16: 50, 17: 50, 18: 50, 19: 50, 20: 500,
};

/// 根据总 XP 计算当前等级（Lv.1–20）。总 XP 超过 Lv.20 阈值也封顶返回 20。
int levelForXp(int xp) {
  var level = 1;
  for (final t in LEVEL_THRESHOLDS) {
    if (xp >= t.xp) {
      level = t.level;
    } else {
      break;
    }
  }
  return level;
}

/// 该级是否有（及多少）升级积分奖励；无奖励返回 null。
int? levelReward(int level) => LEVEL_REWARD_MAP[level];

/// 该级称号；未知等级返回 null（调用方兜底）。
String? levelNameFor(int level) {
  for (final t in LEVEL_THRESHOLDS) {
    if (t.level == level) return t.name;
  }
  return null;
}

/// UTC+8 自然日字符串（YYYY-MM-DD），与后端 getUtc8DateStr 口径一致。
String utc8DateStr([DateTime? now]) {
  final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

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
    xpToNextLevel: 100, // 默认到 Lv.2 阈值 100
    levelName: '初学者',
  );
}

/// 经验来源明细（成长中心"来源明细卡"数据）
class XpBreakdownEntry {
  const XpBreakdownEntry({
    required this.source,
    required this.amount,
    required this.label,
    required this.ratio, // 0.0–1.0，占比
  });
  final String source;   // 'shoot_daily' | 'challenge' | 'course' | 'share'
  final int amount;
  final String label;    // 用户可见文案
  final double ratio;
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

/// 热力图格子点击后的单日详情（底部弹层数据）
class DayActivityDetail {
  const DayActivityDetail({
    required this.date,
    required this.photoCount,
    required this.challengeCount,
    required this.photos,
    required this.challenges,
  });

  /// YYYY-MM-DD
  final String date;
  final int photoCount;
  final int challengeCount;
  final List<DayPhoto> photos;
  final List<String> challenges; // 当日完成挑战标题

  /// 当日总活动量（与热力图格子的数值口径一致）
  int get totalCount => photoCount + challengeCount;
}

/// 单日照片（缩略图展示用）
class DayPhoto {
  const DayPhoto({
    required this.id,
    required this.thumb,
    required this.createdAt,
  });

  final String id;
  final String thumb; // dataUrl（base64）或 filePath
  final int createdAt;
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
