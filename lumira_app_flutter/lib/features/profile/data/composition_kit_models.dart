import 'dart:convert';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';

/// 组合封面来源（兼容 `TemplateCoverImage` 的 cover / coverData 双字段）。
class KitCoverSource {
  const KitCoverSource({this.cover = '', this.coverData});

  /// http / assets / `data:` URL
  final String cover;

  /// base64 data URL
  final String? coverData;

  bool get hasImage => cover.isNotEmpty || (coverData != null && coverData!.isNotEmpty);
}

/// 派生组合封面：优先套件自带封面 → 场景封面（coverUrl / 示例图）→ 模板封面（coverData / cover）。
KitCoverSource resolveKitCover(
  CompositionKit kit, {
  SceneRecord? scene,
  TemplateRecord? template,
}) {
  final own = kit.coverUrl;
  if (own != null && own.isNotEmpty) return KitCoverSource(cover: own);

  if (scene != null) {
    if (scene.coverUrl.isNotEmpty) return KitCoverSource(cover: scene.coverUrl);
    if (scene.exampleImages.isNotEmpty) {
      return KitCoverSource(cover: scene.exampleImages.first);
    }
  }

  if (template != null) {
    if (template.coverData != null && template.coverData!.isNotEmpty) {
      return KitCoverSource(coverData: template.coverData);
    }
    if (template.cover.isNotEmpty) return KitCoverSource(cover: template.cover);
  }

  return const KitCoverSource();
}

/// 组合套件实体（对应 `composition_kits` 表）
///
/// 一个套件绑定一个场景 + 可选模板 + 可选相机参数覆盖，
/// 用户可在场景详情页"加入组合"创建，套用拍照时三参数同时应用。
class CompositionKit {
  CompositionKit({
    required this.id,
    required this.name,
    required this.sceneId,
    this.templateId,
    this.cameraOverrides = const {},
    this.note = '',
    this.coverUrl,
    required this.createdAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  /// 唯一 ID（推荐前缀 'kit_'）
  final String id;

  /// 套件名（如"咖啡馆+柔光人像"）
  final String name;

  /// 关联场景 ID
  final String sceneId;

  /// 关联模板 ID（可空，表示纯场景套件）
  final String? templateId;

  /// 相机参数覆盖（如 {'exposureCompensation': 0.3, 'iso': 400}）
  /// 序列化为 JSON 字符串存 `camera_overrides_json` 列
  final Map<String, dynamic> cameraOverrides;

  /// 备注
  final String note;

  /// 封面图 URL（一般为场景示例图）
  final String? coverUrl;

  /// 创建时间（毫秒）
  final int createdAt;

  /// 最近使用时间（毫秒，可空）
  final int? lastUsedAt;

  /// 使用次数（每次套用拍照 +1）
  final int usageCount;

  /// 序列化为 DB 行
  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'scene_id': sceneId,
      'template_id': templateId,
      'camera_overrides_json': cameraOverrides.isEmpty ? null : jsonEncode(cameraOverrides),
      'note': note,
      'cover_url': coverUrl,
      'created_at': createdAt,
      'last_used_at': lastUsedAt,
      'usage_count': usageCount,
    };
  }

  /// 从 DB 行反序列化
  static CompositionKit fromRow(Map<String, Object?> row) {
    return CompositionKit(
      id: row['id'] as String,
      name: row['name'] as String,
      sceneId: row['scene_id'] as String,
      templateId: row['template_id'] as String?,
      cameraOverrides: _decodeJsonMap(row['camera_overrides_json']),
      note: (row['note'] as String?) ?? '',
      coverUrl: row['cover_url'] as String?,
      createdAt: (row['created_at'] as num).toInt(),
      lastUsedAt: row['last_used_at'] == null ? null : (row['last_used_at'] as num).toInt(),
      usageCount: (row['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// 副本（用于编辑时构造新实例）
  CompositionKit copyWith({
    String? id,
    String? name,
    String? sceneId,
    String? templateId,
    Map<String, dynamic>? cameraOverrides,
    String? note,
    String? coverUrl,
    int? createdAt,
    int? lastUsedAt,
    int? usageCount,
  }) {
    return CompositionKit(
      id: id ?? this.id,
      name: name ?? this.name,
      sceneId: sceneId ?? this.sceneId,
      templateId: templateId ?? this.templateId,
      cameraOverrides: cameraOverrides ?? this.cameraOverrides,
      note: note ?? this.note,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  static Map<String, dynamic> _decodeJsonMap(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }
}
