import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 用户档案信息（profile_page hero card）
class UserProfile {
  const UserProfile({
    required this.name,
    required this.avatarSeed,
    required this.level,
    required this.levelName,
    required this.currentXp,
    required this.maxXp,
    required this.photosCount,
    required this.templatesCount,
    required this.collectionsCount,
  });
  final String name;
  final String avatarSeed; // picsum seed
  final int level;
  final String levelName;
  final int currentXp;
  final int maxXp;
  final int photosCount;
  final int templatesCount;
  final int collectionsCount;

  int get xpPercent => ((currentXp / maxXp) * 100).round();
  int get xpRemaining => maxXp - currentXp;
}

/// 碎片收集项（profile_page fragment-card）
class FragmentItem {
  const FragmentItem({
    required this.name,
    required this.icon,
    required this.current,
    required this.max,
  });
  final String name;
  final IconData icon;
  final int current;
  final int max;
  int get percent => ((current / max) * 100).round();
}

/// 成就项（growth_page achievement-card）
class Achievement {
  const Achievement({
    required this.icon,
    required this.name,
    required this.locked,
  });
  final IconData icon;
  final String name;
  final bool locked;
}

/// 成长轨迹项（growth_page trajectory-card）
class TrajectoryEntry {
  const TrajectoryEntry({required this.title, required this.date});
  final String title;
  final String date; // 'YYYY-MM-DD'
}

/// 奖励阶梯项（invite_page reward-card）
class RewardEntry {
  const RewardEntry({
    required this.icon,
    required this.countLabel,
    required this.name,
    required this.done,
    required this.locked,
    required this.status,
  });
  final IconData icon;
  final String countLabel; // '1 分享'
  final String name;
  final bool done;
  final bool locked;
  final String status; // '已达成' / '进行中' / ''
}

/// 邀请记录项（invite_page record-card）
class InviteRecord {
  const InviteRecord({
    required this.icon,
    required this.name,
    required this.date,
    required this.status,
    required this.pending,
  });
  final IconData icon;
  final String name;
  final String date;
  final String status;
  final bool pending;
}

/// 主题预览信息（profile_theme_page）
class ThemePreview {
  const ThemePreview({
    required this.key,
    required this.label,
    required this.description,
    required this.canvasColor,
    required this.brandColor,
    required this.previewColors,
  });
  final ThemeKey key;
  final String label;
  final String description;
  final Color canvasColor;
  final Color brandColor;
  final List<Color> previewColors; // 4 dots
}

/// UI 风格预览信息（profile_theme_page）
class StylePreview {
  const StylePreview({
    required this.style,
    required this.label,
    required this.description,
  });
  final UIStyle style;
  final String label;
  final String description;
}

class ProfileMockData {
  ProfileMockData._();

  /// 当前用户档案（mock）
  static const UserProfile userProfile = UserProfile(
    name: '小美',
    avatarSeed: '733872',
    level: 12,
    levelName: '入门学徒',
    currentXp: 1280,
    maxXp: 2000,
    photosCount: 128,
    templatesCount: 36,
    collectionsCount: 12,
  );

  /// 下一级信息（mock）
  static const String nextLevelName = '进阶学徒';

  /// 碎片收集（4 项，对应 uni-app fragments ref）
  static const List<FragmentItem> fragments = [
    FragmentItem(name: '人像', icon: Icons.person_outline, current: 3, max: 5),
    FragmentItem(name: '风光', icon: Icons.landscape_outlined, current: 2, max: 5),
    FragmentItem(name: '美食', icon: Icons.restaurant_outlined, current: 4, max: 5),
    FragmentItem(name: '街拍', icon: Icons.camera_alt_outlined, current: 1, max: 5),
  ];

  /// 成就墙（6 项，对应 uni-app achievements ref）
  static const List<Achievement> achievements = [
    Achievement(icon: Icons.wb_sunny_outlined, name: '初露锋芒', locked: false),
    Achievement(icon: Icons.camera_alt_outlined, name: '快门达人', locked: false),
    Achievement(icon: Icons.emoji_events_outlined, name: '模板收藏家', locked: false),
    Achievement(icon: Icons.brush_outlined, name: '构图大师', locked: true),
    Achievement(icon: Icons.auto_fix_high_outlined, name: '后期魔法师', locked: true),
    Achievement(icon: Icons.nights_stay_outlined, name: '百变达人', locked: false),
  ];

  /// 成长轨迹（4 项，对应 uni-app trajectory ref）
  static const List<TrajectoryEntry> trajectory = [
    TrajectoryEntry(title: '首张照片', date: '2026-05-01'),
    TrajectoryEntry(title: '10张照片', date: '2026-05-20'),
    TrajectoryEntry(title: '升至 Lv.5', date: '2026-06-01'),
    TrajectoryEntry(title: '100张照片', date: '2026-06-15'),
  ];

  /// 拍摄日历热力图（112 格，对应 uni-app heatmap ref，10 列 × 12 行）
  static const List<int> heatmap = [
    0,1,0,2,3,0,1,0,4,2,
    0,1,2,0,3,1,0,2,4,0,
    1,0,3,2,1,0,4,0,2,3,
    0,1,1,0,2,4,1,0,3,0,
    2,1,0,1,0,3,0,4,2,0,
    0,1,2,0,3,1,0,2,0,4,
    1,0,2,0,1,0,3,2,0,1,
    0,4,0,2,1,0,0,3,0,2,
    1,0,4,0,2,0,1,0,0,3,
    1,0,2,0,1,0,4,2,0,1,
    0,4,0,1,2,0,0,4,0,1,
    2,0,0,4,
  ];

  /// 本月拍摄数
  static const int monthlyPhotos = 42;

  /// 邀请奖励阶梯（6 项，对应 uni-app rewards ref）
  static const List<RewardEntry> rewards = [
    RewardEntry(icon: Icons.movie_outlined, countLabel: '1 分享', name: '日系胶片模板', done: true, locked: false, status: '已达成'),
    RewardEntry(icon: Icons.flag_outlined, countLabel: '3 分享', name: '法式复古包', done: true, locked: false, status: '已达成'),
    RewardEntry(icon: Icons.star_outline, countLabel: '5 分享', name: '氛围感包', done: false, locked: false, status: '进行中'),
    RewardEntry(icon: Icons.emoji_events_outlined, countLabel: '10 分享', name: '分享达人成就', done: false, locked: true, status: ''),
    RewardEntry(icon: Icons.workspace_premium_outlined, countLabel: '15 分享', name: '全部精选模板', done: false, locked: true, status: ''),
    RewardEntry(icon: Icons.bolt_outlined, countLabel: '20 分享', name: '裂变之神', done: false, locked: true, status: ''),
  ];

  /// 邀请进度（mock）
  static const int invitedCount = 3;
  static const int totalInvitedForNext = 5; // 再邀请 2 人解锁氛围感包
  static const String nextRewardName = '氛围感包';
  static const int inviteProgressPercent = 60; // 3/5 = 60%

  /// 邀请记录（3 项，对应 uni-app records ref）
  static const List<InviteRecord> inviteRecords = [
    InviteRecord(icon: Icons.account_circle, name: '小雅', date: '2026-07-05', status: '已确认', pending: false),
    InviteRecord(icon: Icons.account_circle_outlined, name: '小琳', date: '2026-07-07', status: '已确认', pending: false),
    InviteRecord(icon: Icons.person_outline, name: '小悦', date: '2026-07-08', status: '待确认', pending: true),
  ];

  /// 8 套主题预览（对应 uni-app THEME_METAS）
  /// 注意：颜色硬编码来自 uni-app theme-configs.ts，与 Flutter ThemeTokens 一致
  static const List<ThemePreview> themes = [
    ThemePreview(
      key: ThemeKey.warmWhite, label: '暖米白', description: '温润如玉，东方留白的经典底色',
      canvasColor: Color(0xFFFAF7F2), brandColor: Color(0xFFC9A96E),
      previewColors: [Color(0xFFFAF7F2), Color(0xFFC9A96E), Color(0xFF1A1A1A), Color(0xFF5C5852)],
    ),
    ThemePreview(
      key: ThemeKey.ink, label: '浓墨', description: '深邃墨色，暗夜中的专注拍摄',
      canvasColor: Color(0xFF1C1A17), brandColor: Color(0xFFD4B57A),
      previewColors: [Color(0xFF1C1A17), Color(0xFFD4B57A), Color(0xFFF2EEE6), Color(0xFFA39D94)],
    ),
    ThemePreview(
      key: ThemeKey.retro, label: '胶片复古', description: '温暖胶片质感，怀旧色彩调色',
      canvasColor: Color(0xFFF5E6D3), brandColor: Color(0xFFC4956A),
      previewColors: [Color(0xFFF5E6D3), Color(0xFFC4956A), Color(0xFF3D2817), Color(0xFF6B4C2F)],
    ),
    ThemePreview(
      key: ThemeKey.fresh, label: '日系清新', description: '清新自然，柔和明亮的日常感',
      canvasColor: Color(0xFFF8FAF6), brandColor: Color(0xFF8BAD72),
      previewColors: [Color(0xFFF8FAF6), Color(0xFF8BAD72), Color(0xFF4A3F35), Color(0xFF8C7F70)],
    ),
    ThemePreview(
      key: ThemeKey.cozy, label: '温馨粉', description: '柔粉温暖，温馨治愈的日常',
      canvasColor: Color(0xFFFFF5F5), brandColor: Color(0xFFE8A0A0),
      previewColors: [Color(0xFFFFF5F5), Color(0xFFE8A0A0), Color(0xFF4A3A3A), Color(0xFF8C7070)],
    ),
    ThemePreview(
      key: ThemeKey.macaron, label: '马卡龙', description: '薄荷糖果，甜美活泼',
      canvasColor: Color(0xFFFFF8F0), brandColor: Color(0xFFA8D8C8),
      previewColors: [Color(0xFFFFF8F0), Color(0xFFA8D8C8), Color(0xFF5A4A4A), Color(0xFF8C7A7A)],
    ),
    ThemePreview(
      key: ThemeKey.morandi, label: '莫兰迪', description: '灰调优雅，安静内敛',
      canvasColor: Color(0xFFE8E4E0), brandColor: Color(0xFF8B9DAF),
      previewColors: [Color(0xFFE8E4E0), Color(0xFF8B9DAF), Color(0xFF4A4540), Color(0xFF7A7570)],
    ),
    ThemePreview(
      key: ThemeKey.rosegold, label: '玫瑰金', description: '轻奢优雅，玫瑰金质感',
      canvasColor: Color(0xFFFAF6F2), brandColor: Color(0xFFC9A0A0),
      previewColors: [Color(0xFFFAF6F2), Color(0xFFC9A0A0), Color(0xFF3D2E2A), Color(0xFF6B5450)],
    ),
  ];

  /// 4 种 UI 风格预览（对应 uni-app STYLE_METAS）
  static const List<StylePreview> styles = [
    StylePreview(style: UIStyle.neumorphic, label: '新拟态', description: '双向阴影，柔和立体'),
    StylePreview(style: UIStyle.flat, label: '扁平化', description: '干净利落，无多余修饰'),
    StylePreview(style: UIStyle.glass, label: '玻璃拟态', description: '半透明毛玻璃，通透感'),
    StylePreview(style: UIStyle.female, label: '女性美学', description: '暖粉弥散，大圆角，呼吸感'),
  ];

  /// 设置页默认开关值（mock）
  static const bool defaultGridOn = false;
  static const bool defaultLevelOn = true;
  static const bool defaultShutterOn = true;
  static const bool defaultWatermarkOn = true;

  /// 设置页版本号
  static const String appVersion = 'v2.0.0';
  static const String appVersionSub = '如画 Lumira v2.0.0';
  static const String appVersionDesc = '东方新拟态 · 用镜头书写日常的诗';
}
