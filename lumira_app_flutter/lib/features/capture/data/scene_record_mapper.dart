// lib/features/capture/data/scene_record_mapper.dart
//
// scenes 表 DB 记录（SceneRecord）与领域模型（ScenePreset / CustomScenePreset）互转。
// 场景管理页从 DB 读取真实数据，这里集中处理 filter / sceneGuide 的 JSON 与结构体映射，
// 避免在 UI 层散布转换逻辑。

import '../../../core/db/dao/scenes_dao.dart';
import '../domain/photo_template.dart' show SceneGuide;
import '../domain/scene_preset.dart';

/// 解析 filter JSON 为 [SceneFilter]（字段缺失时使用默认值）。
SceneFilter sceneFilterFromJson(Map<String, dynamic> json) {
  return SceneFilter(
    lut: (json['lut'] as String?) ?? 'none',
    systemFilter: json['systemFilter'] as String?,
    reason: (json['reason'] as String?) ?? '',
  );
}

/// 将 [SceneFilter] 序列化为 filter JSON。
Map<String, dynamic> sceneFilterToJson(SceneFilter filter) {
  return {
    'lut': filter.lut,
    'systemFilter': filter.systemFilter,
    'reason': filter.reason,
  };
}

/// 解析 sceneGuide JSON 为 [SceneGuide]。
SceneGuide sceneGuideFromJson(Map<String, dynamic> json) {
  return SceneGuide(
    lightDirection: (json['lightDirection'] as String?) ?? '',
    shootingDistance: (json['shootingDistance'] as String?) ?? '',
    background: (json['background'] as String?) ?? '',
    props: _strList(json['props']),
    bestTime: (json['bestTime'] as String?) ?? '',
    tips: _strList(json['tips']),
  );
}

/// 将 [SceneGuide] 序列化为 sceneGuide JSON。
Map<String, dynamic> sceneGuideToJson(SceneGuide guide) {
  return {
    'lightDirection': guide.lightDirection,
    'shootingDistance': guide.shootingDistance,
    'background': guide.background,
    'props': guide.props,
    'bestTime': guide.bestTime,
    'tips': guide.tips,
  };
}

/// DB 记录 → 自定义场景领域模型。
CustomScenePreset sceneRecordToCustom(SceneRecord r) {
  return CustomScenePreset(
    id: r.id,
    name: r.name,
    icon: r.icon,
    category: r.category,
    style: r.style,
    filter: sceneFilterFromJson(r.filter),
    vibe: r.vibe,
    description: r.description,
    exampleImages: r.exampleImages,
    tips: r.tips,
    whereToShoot: r.whereToShoot,
    bestTime: r.bestTime,
    sceneGuide: sceneGuideFromJson(r.sceneGuide),
    relatedCategory: r.relatedCategory,
    recommendedTagIds: r.recommendedTagIds,
    tagIds: r.tagIds,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    cover: r.coverUrl,
  );
}

/// DB 记录 → 内置/系统场景领域模型（作为收藏展示兜底）。
ScenePreset sceneRecordToPreset(SceneRecord r) {
  return ScenePreset(
    id: r.id,
    name: r.name,
    icon: r.icon,
    category: r.category,
    style: r.style,
    filter: sceneFilterFromJson(r.filter),
    vibe: r.vibe,
    description: r.description,
    exampleImages: r.exampleImages,
    tips: r.tips,
    whereToShoot: r.whereToShoot,
    bestTime: r.bestTime,
    sceneGuide: sceneGuideFromJson(r.sceneGuide),
    relatedCategory: r.relatedCategory,
    recommendedTagIds: r.recommendedTagIds,
  );
}

/// 自定义场景领域模型 → DB 记录（creator='user'）。
SceneRecord customToRecord(CustomScenePreset s, {required bool isFavorite}) {
  return SceneRecord(
    id: s.id,
    name: s.name,
    icon: s.icon,
    category: s.category,
    style: s.style,
    filter: sceneFilterToJson(s.filter),
    vibe: s.vibe,
    description: s.description,
    exampleImages: s.exampleImages,
    tips: s.tips,
    whereToShoot: s.whereToShoot,
    bestTime: s.bestTime,
    sceneGuide: sceneGuideToJson(s.sceneGuide),
    relatedCategory: s.relatedCategory,
    recommendedTagIds: s.recommendedTagIds,
    tagIds: s.tagIds,
    creator: 'user',
    isFavorite: isFavorite,
    coverUrl: s.cover,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  );
}

List<String> _strList(Object? v) {
  if (v is! List) return <String>[];
  return v.whereType<String>().toList();
}