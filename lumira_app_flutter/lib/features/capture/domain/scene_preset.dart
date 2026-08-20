// lib/features/capture/domain/scene_preset.dart
import 'package:flutter/foundation.dart';
import 'photo_template.dart';

/// 对应 TS SceneCategory: 'light' | 'outdoor' | 'indoor' | 'mood'
class SceneCategory {
  static const light = 'light';
  static const outdoor = 'outdoor';
  static const indoor = 'indoor';
  static const mood = 'mood';
}

class SceneFilter {
  final String lut;           // LutPreset，如 'none', 'cinematic', ...
  final String? systemFilter; // SystemFilter，如 'none', 'vivid', ...
  final String reason;

  const SceneFilter({required this.lut, this.systemFilter, this.reason = ''});

  SceneFilter copyWith({String? lut, String? systemFilter, String? reason}) => SceneFilter(
    lut: lut ?? this.lut,
    systemFilter: systemFilter ?? this.systemFilter,
    reason: reason ?? this.reason,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneFilter &&
          lut == other.lut &&
          systemFilter == other.systemFilter &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(lut, systemFilter, reason);
}

class ScenePreset {
  final String id;       // ScenePresetId
  final String name;
  final String icon;
  final String category; // SceneCategory
  final String style;
  final SceneFilter filter;
  final String vibe;
  final String description;
  final List<String> exampleImages;
  final List<String> tips;
  final String whereToShoot;
  final String bestTime;
  final SceneGuide sceneGuide;
  final String relatedCategory;
  final List<String> recommendedTagIds;

  const ScenePreset({
    required this.id,
    required this.name,
    this.icon = '',
    this.category = SceneCategory.light,
    this.style = '',
    required this.filter,
    this.vibe = '',
    this.description = '',
    this.exampleImages = const [],
    this.tips = const [],
    this.whereToShoot = '',
    this.bestTime = '',
    required this.sceneGuide,
    this.relatedCategory = 'portrait',
    this.recommendedTagIds = const [],
  });

  ScenePreset copyWith({
    String? id,
    String? name,
    String? icon,
    String? category,
    String? style,
    SceneFilter? filter,
    String? vibe,
    String? description,
    List<String>? exampleImages,
    List<String>? tips,
    String? whereToShoot,
    String? bestTime,
    SceneGuide? sceneGuide,
    String? relatedCategory,
    List<String>? recommendedTagIds,
  }) => ScenePreset(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    category: category ?? this.category,
    style: style ?? this.style,
    filter: filter ?? this.filter,
    vibe: vibe ?? this.vibe,
    description: description ?? this.description,
    exampleImages: exampleImages ?? this.exampleImages,
    tips: tips ?? this.tips,
    whereToShoot: whereToShoot ?? this.whereToShoot,
    bestTime: bestTime ?? this.bestTime,
    sceneGuide: sceneGuide ?? this.sceneGuide,
    relatedCategory: relatedCategory ?? this.relatedCategory,
    recommendedTagIds: recommendedTagIds ?? this.recommendedTagIds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScenePreset &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          category == other.category &&
          style == other.style &&
          filter == other.filter &&
          vibe == other.vibe &&
          description == other.description &&
          listEquals(exampleImages, other.exampleImages) &&
          listEquals(tips, other.tips) &&
          whereToShoot == other.whereToShoot &&
          bestTime == other.bestTime &&
          sceneGuide == other.sceneGuide &&
          relatedCategory == other.relatedCategory &&
          listEquals(recommendedTagIds, other.recommendedTagIds);

  @override
  int get hashCode => Object.hash(
    id, name, icon, category, style, filter, vibe, description,
    Object.hashAll(exampleImages), Object.hashAll(tips),
    whereToShoot, bestTime, sceneGuide, relatedCategory,
    Object.hashAll(recommendedTagIds),
  );

  /// 是否为自定义场景（id 以 'custom_' 开头）
  bool get isCustom => id.startsWith('custom_');
}

/// 拍摄目标（对应 TS Target: 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life'）
class Target {
  static const portrait = 'portrait';
  static const landscape = 'landscape';
  static const food = 'food';
  static const street = 'street';
  static const night = 'night';
  static const macro = 'macro';
  static const stillLife = 'still-life';

  static const all = <String>[portrait, landscape, food, street, night, macro, stillLife];

  static String label(String value) {
    const map = {
      'portrait': '人像',
      'landscape': '风光',
      'food': '美食',
      'street': '街拍',
      'night': '夜景',
      'macro': '微距',
      'still-life': '静物',
    };
    return map[value] ?? value;
  }
}

/// 场景风格（对应 TS SceneStyle）
class SceneStyle {
  const SceneStyle({required this.id, required this.name, required this.category});
  final String id;
  final String name;
  final String category; // SceneCategory 字符串
}

/// 场景大类聚合（对应 TS SceneCategoryGroup）
class SceneCategoryGroup {
  const SceneCategoryGroup({
    required this.category,
    required this.name,
    required this.icon,
    required this.styles,
  });
  final String category; // SceneCategory 字符串
  final String name;
  final String icon; // phosphor 图标名字符串
  final List<SceneStyle> styles;
}

/// 自定义场景预设（对应 TS CustomScenePreset）
class CustomScenePreset extends ScenePreset {
  const CustomScenePreset({
    required super.id,
    required super.name,
    super.icon = '',
    super.category = SceneCategory.light,
    super.style = '',
    required super.filter,
    super.vibe = '',
    super.description = '',
    super.exampleImages = const [],
    super.tips = const [],
    super.whereToShoot = '',
    super.bestTime = '',
    required super.sceneGuide,
    super.relatedCategory = Target.portrait,
    super.recommendedTagIds = const [],
    required this.tagIds,
    required this.createdAt,
    required this.updatedAt,
    this.cover = '',
  });

  final List<String> tagIds;
  final int createdAt;
  final int updatedAt;
  /// 自定义场景封面图（base64 data URL 或远程/路径 URL），空串表示未设置
  final String cover;
}

/// 场景成就（对应 TS SceneAchievement）
class SceneAchievement {
  const SceneAchievement({
    required this.sceneId,
    required this.level,
    required this.levelName,
    required this.photoCount,
    required this.nextLevelCount,
  });
  final String sceneId;
  final int level;
  final String levelName;
  final int photoCount;
  final int nextLevelCount;

  SceneAchievement copyWith({int? level, String? levelName, int? photoCount, int? nextLevelCount}) =>
      SceneAchievement(
        sceneId: sceneId,
        level: level ?? this.level,
        levelName: levelName ?? this.levelName,
        photoCount: photoCount ?? this.photoCount,
        nextLevelCount: nextLevelCount ?? this.nextLevelCount,
      );
}

/// 周排行条目
class SceneRankingEntry {
  const SceneRankingEntry({required this.scene, required this.photoCount, required this.rank});
  final ScenePreset scene;
  final int photoCount;
  final int rank;
}

/// 标签
class SceneTag {
  const SceneTag({required this.id, required this.name});
  final String id;
  final String name;
}

/// 拍摄套件（简化）
class ShootKit {
  const ShootKit({
    required this.id,
    required this.sceneId,
    required this.templateId,
    required this.name,
  });
  final String id;
  final String sceneId;
  final String templateId;
  final String name;
}

/// LUT 选项
class LutOption {
  const LutOption({required this.value, required this.label});
  final String value;
  final String label;
}

/// 系统滤镜选项
class SystemFilterOption {
  const SystemFilterOption({required this.value, required this.label});
  final String value;
  final String label;
}
