// lib/features/capture/domain/scene_preset.dart
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
          exampleImages == other.exampleImages &&
          tips == other.tips &&
          whereToShoot == other.whereToShoot &&
          bestTime == other.bestTime &&
          sceneGuide == other.sceneGuide &&
          relatedCategory == other.relatedCategory &&
          recommendedTagIds == other.recommendedTagIds;

  @override
  int get hashCode => Object.hash(
    id, name, icon, category, style, filter, vibe, description,
    Object.hashAll(exampleImages), Object.hashAll(tips),
    whereToShoot, bestTime, sceneGuide, relatedCategory,
    Object.hashAll(recommendedTagIds),
  );
}
