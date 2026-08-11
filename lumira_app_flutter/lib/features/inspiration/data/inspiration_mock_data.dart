import 'package:flutter/material.dart';

import '../../home/data/home_mock_data.dart';

/// 心情标签配色方案
class MoodColorScheme {
  const MoodColorScheme({
    required this.background,
    required this.border,
    required this.foreground,
  });
  final Color background;
  final Color border;
  final Color foreground;
}

/// 心情条目
class MoodEntry {
  const MoodEntry({
    required this.label,
    required this.icon,
    required this.count,
    required this.colorScheme,
  });
  final String label;
  final IconData icon;
  final int count;
  final MoodColorScheme colorScheme;
}

/// 穿搭日记照片
class OutfitPhoto {
  const OutfitPhoto({required this.imageSeed, required this.date});
  final String imageSeed;
  final String date;
}

/// 穿搭日记卡片真实数据（替代 mock）
class OutfitDiaryCardData {
  const OutfitDiaryCardData({required this.streak, required this.photos});
  final int streak;
  final List<OutfitPhoto> photos;
}

/// 场景标签信息（对应 uni-app getSceneTagInfo）
class SceneTagInfo {
  const SceneTagInfo({required this.tag, required this.tagCls});
  final String tag;
  final SceneTagType tagCls;
}

enum SceneTagType { gold, red, green }

/// 推荐场景条目（复用 SceneReco + 标签信息）
class InspirationScene {
  const InspirationScene({required this.scene, required this.tagInfo});
  final SceneReco scene;
  final SceneTagInfo tagInfo;
}

class InspirationMockData {
  InspirationMockData._();

  /// 今日心情（7 条，对应 uni-app moods ref）
  static const List<MoodEntry> moods = [
    MoodEntry(
      label: '开心', icon: Icons.sentiment_satisfied_outlined, count: 12,
      colorScheme: MoodColorScheme(background: Color(0xFFFFF5E6), border: Color(0xFFFFE4B8), foreground: Color(0xFFB8860B)),
    ),
    MoodEntry(
      label: '甜酷', icon: Icons.favorite_outline, count: 8,
      colorScheme: MoodColorScheme(background: Color(0xFFF0E6FF), border: Color(0xFFD4B8FF), foreground: Color(0xFF7B5EA7)),
    ),
    MoodEntry(
      label: '温柔', icon: Icons.local_florist_outlined, count: 15,
      colorScheme: MoodColorScheme(background: Color(0xFFFFF0F0), border: Color(0xFFFFD0D0), foreground: Color(0xFFC47C7C)),
    ),
    MoodEntry(
      label: '复古', icon: Icons.movie_outlined, count: 6,
      colorScheme: MoodColorScheme(background: Color(0xFFF5E6D0), border: Color(0xFFD4B896), foreground: Color(0xFF8B6B3D)),
    ),
    MoodEntry(
      label: '清新', icon: Icons.eco_outlined, count: 9,
      colorScheme: MoodColorScheme(background: Color(0xFFE8F5E4), border: Color(0xFFB8D4A8), foreground: Color(0xFF5A7A48)),
    ),
    MoodEntry(
      label: '文艺', icon: Icons.menu_book_outlined, count: 4,
      colorScheme: MoodColorScheme(background: Color(0xFFEDE8E0), border: Color(0xFFC8BFB0), foreground: Color(0xFF6B5E4E)),
    ),
    MoodEntry(
      label: '治愈', icon: Icons.toys_outlined, count: 7,
      colorScheme: MoodColorScheme(background: Color(0xFFFFF0E0), border: Color(0xFFFFD8B0), foreground: Color(0xFFC4783C)),
    ),
  ];

  /// 穿搭日记照片（2 张，对应 uni-app outfitPhotos ref）
  static const List<OutfitPhoto> outfitPhotos = [
    OutfitPhoto(imageSeed: 'outfit-0708', date: '7月8日'),
    OutfitPhoto(imageSeed: 'outfit-0707', date: '7月7日'),
  ];

  /// 穿搭日记连续打卡天数
  static const int outfitStreakDays = 7;

  /// 推荐场景（4 条，对应 uni-app scenes computed：customScenes.slice(0,4) + SCENE_PRESETS.slice(0,4)，取前 4）
  /// uni-app 无自定义场景时取前 4 个预设：cafe-window / library-quiet / home-cozy / sunset-silhouette
  static const List<InspirationScene> scenes = [
    InspirationScene(
      scene: SceneReco(
        id: 'cafe-window', name: '咖啡馆', vibe: '慵懒午后，把光调成蜜糖色',
        imageSeed: 'scene-inspiration-cafe-window', badgeText: '咖啡馆', badgeBrand: false, photoCount: 12,
      ),
      tagInfo: SceneTagInfo(tag: '你最常去', tagCls: SceneTagType.gold), // presetIndex === 0
    ),
    InspirationScene(
      scene: SceneReco(
        id: 'library-quiet', name: '图书馆', vibe: '静谧书海，让时间在指尖慢下来',
        imageSeed: 'scene-inspiration-library-quiet', badgeText: '图书馆', badgeBrand: false, photoCount: 8,
      ),
      tagInfo: SceneTagInfo(tag: '图书馆拍摄', tagCls: SceneTagType.green), // presetIndex === 1
    ),
    InspirationScene(
      scene: SceneReco(
        id: 'home-cozy', name: '居家温馨', vibe: '慵懒清晨，把日子过成一首慢歌',
        imageSeed: 'scene-inspiration-home-cozy', badgeText: '居家温馨', badgeBrand: false, photoCount: 15,
      ),
      tagInfo: SceneTagInfo(tag: '新场景推荐', tagCls: SceneTagType.red), // presetIndex === 2
    ),
    InspirationScene(
      scene: SceneReco(
        id: 'sunset-silhouette', name: '黄昏剪影', vibe: '把人放进夕阳里，剪成一帧诗',
        imageSeed: 'scene-inspiration-sunset-silhouette', badgeText: '黄昏剪影', badgeBrand: false, photoCount: 6,
      ),
      tagInfo: SceneTagInfo(tag: '黄昏剪影拍摄', tagCls: SceneTagType.green), // presetIndex === 3
    ),
  ];

  /// 推荐副标题
  static const String recommendSubtitle = '基于你最近 30 天的拍摄记录';
}
