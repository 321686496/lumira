// lib/features/templates/data/remote_template_dto.dart
//
// 后端动态模板 DTO（Data Transfer Object）。
// 对应 spec 2026-08-05-remote-templates-design.md §2.4 的 TypeScript 接口。
// 仅负责 JSON ↔ Dart 对象转换，不含业务逻辑。

import 'package:flutter/foundation.dart';

/// 后端动态模板 meta（列表用，轻量）。
///
/// 对应 spec `RemoteTemplateMeta`：仅含标量字段 + tags/tagIds 数组 + classification 对象，
/// 不含 5 段完整内容 JSON（composition/pose/camera/sceneGuide/postProcess）。
/// 用于列表展示与 sqflite 缓存：拉取后 upsert 到本地，详情按需再拉取。
@immutable
class RemoteTemplateMetaDto {
  final String id;
  final String name;
  final String author;
  final String version;
  final String category;
  final int price;
  final String coverUrl;
  final String description;
  final String shortDesc;
  final String referenceSource;
  final List<String> tags;
  final List<String> tagIds;
  final RemoteTemplateClassificationDto classification;
  final RemoteTemplateAmbienceDto ambience;
  final int sortOrder;
  final int updatedAt;

  const RemoteTemplateMetaDto({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.category,
    required this.price,
    required this.coverUrl,
    required this.description,
    this.shortDesc = '',
    required this.referenceSource,
    required this.tags,
    required this.tagIds,
    required this.classification,
    this.ambience = const RemoteTemplateAmbienceDto(),
    required this.sortOrder,
    required this.updatedAt,
  });

  factory RemoteTemplateMetaDto.fromJson(Map<String, dynamic> j) {
    return RemoteTemplateMetaDto(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      author: j['author'] as String? ?? 'Lumira',
      version: j['version'] as String? ?? '1.0.0',
      category: j['category'] as String? ?? '',
      price: (j['price'] as num?)?.toInt() ?? 0,
      coverUrl: j['coverUrl'] as String? ?? '',
      description: j['description'] as String? ?? '',
      shortDesc: j['shortDesc'] as String? ?? '',
      referenceSource: j['referenceSource'] as String? ?? '',
      tags: (j['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      tagIds: (j['tagIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      classification: RemoteTemplateClassificationDto.fromJson(
        (j['classification'] as Map<String, dynamic>?) ?? const {},
      ),
      ambience: RemoteTemplateAmbienceDto.fromJson(
        (j['ambience'] as Map<String, dynamic>?) ?? const {},
      ),
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 模板季节/天气/时段元数据（对应后端 TemplateAmbience，仅展示用）。
@immutable
class RemoteTemplateAmbienceDto {
  const RemoteTemplateAmbienceDto({
    this.seasons = const [],
    this.weathers = const [],
    this.timeTones = const [],
  });

  final List<String> seasons;
  final List<String> weathers;
  final List<String> timeTones;

  bool get isEmpty =>
      seasons.isEmpty && weathers.isEmpty && timeTones.isEmpty;

  factory RemoteTemplateAmbienceDto.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RemoteTemplateAmbienceDto();
    return RemoteTemplateAmbienceDto(
      seasons: (j['seasons'] as List<dynamic>?)?.cast<String>() ?? const [],
      weathers: (j['weathers'] as List<dynamic>?)?.cast<String>() ?? const [],
      timeTones: (j['timeTones'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'seasons': seasons,
        'weathers': weathers,
        'timeTones': timeTones,
      };
}

/// 模板分类信息（meta 内嵌）。
///
/// 对应 spec `RemoteTemplateMeta.classification`（四级分类）：
/// `{ type; majorStyle; subStyle; method }`。`style` 为 v17 之前旧后端的兼容字段，
/// 迁移 009 后旧 `style` 已平移为 `subStyle`，新模板使用 `majorStyle`/`subStyle`。
@immutable
class RemoteTemplateClassificationDto {
  final String type;
  /// 兼容保留：旧后端/旧数据可能返回 `style`，新后端已不使用（空字符串）。
  final String style;
  final String method;
  /// 四级分类扩展：大风格（L2，如 emotional）
  final String majorStyle;
  /// 四级分类扩展：子风格（L3，迁移前老字段为 style）
  final String subStyle;

  const RemoteTemplateClassificationDto({
    required this.type,
    this.style = '',
    this.method = '',
    this.majorStyle = '',
    this.subStyle = '',
  });

  factory RemoteTemplateClassificationDto.fromJson(Map<String, dynamic> j) {
    return RemoteTemplateClassificationDto(
      type: j['type'] as String? ?? '',
      style: j['style'] as String? ?? '',
      method: j['method'] as String? ?? '',
      majorStyle: j['majorStyle'] as String? ?? '',
      subStyle: j['subStyle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'style': style,
        'method': method,
        'majorStyle': majorStyle,
        'subStyle': subStyle,
      };
}

/// `GET /templates/list` 响应体。
///
/// 对应 spec `RemoteTemplateListResponse`：
/// `{ templates: RemoteTemplateMeta[]; serverUpdatedAt: number }`
@immutable
class RemoteTemplateListResponseDto {
  final List<RemoteTemplateMetaDto> templates;
  final int serverUpdatedAt;

  const RemoteTemplateListResponseDto({
    required this.templates,
    required this.serverUpdatedAt,
  });

  factory RemoteTemplateListResponseDto.fromJson(Map<String, dynamic> j) {
    final list = j['templates'] as List<dynamic>? ?? const [];
    return RemoteTemplateListResponseDto(
      templates: list
          .map((e) =>
              RemoteTemplateMetaDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverUpdatedAt: (j['serverUpdatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 排序方式（对应后端 `TemplateSearchSort`）。
enum TemplateSearchSort { comprehensive, hot, latest, photos, name }

/// `GET /templates/search` 的单个结果项。
///
/// 对应后端 `TemplateSearchItem extends RemoteTemplateMeta`：
/// 在 meta 基础上附加全站热度/拍摄/查看计数。
@immutable
class RemoteTemplateSearchItemDto {
  final RemoteTemplateMetaDto meta;
  /// 全站热度 = 2×拍摄数 + 1×查看数（后端已计算）。
  final int hotScore;
  /// 全站拍摄数（use_shoot）。
  final int shootCount;
  /// 全站查看数（open_detail）。
  final int openCount;

  const RemoteTemplateSearchItemDto({
    required this.meta,
    required this.hotScore,
    required this.shootCount,
    required this.openCount,
  });

  factory RemoteTemplateSearchItemDto.fromJson(Map<String, dynamic> j) {
    return RemoteTemplateSearchItemDto(
      meta: RemoteTemplateMetaDto.fromJson(j),
      hotScore: (j['hotScore'] as num?)?.toInt() ?? 0,
      shootCount: (j['shootCount'] as num?)?.toInt() ?? 0,
      openCount: (j['openCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `GET /templates/search` 响应体。
///
/// 对应后端 `TemplateSearchResponse`：`{ items; total; page; pageSize }`
@immutable
class RemoteTemplateSearchResponseDto {
  final List<RemoteTemplateSearchItemDto> items;
  final int total;
  final int page;
  final int pageSize;

  const RemoteTemplateSearchResponseDto({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory RemoteTemplateSearchResponseDto.fromJson(Map<String, dynamic> j) {
    final list = j['items'] as List<dynamic>? ?? const [];
    return RemoteTemplateSearchResponseDto(
      items: list
          .map((e) =>
              RemoteTemplateSearchItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      page: (j['page'] as num?)?.toInt() ?? 1,
      pageSize: (j['pageSize'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 后端动态模板完整内容（详情用）。
///
/// 对应 spec `RemoteTemplateDetail extends RemoteTemplateMeta`：
/// 在 meta 基础上扩展 5 段内容 JSON（composition/pose/camera/sceneGuide/postProcess）。
/// 5 段内容均为原始 JSON Map，由 TemplateMapper 转换为领域对象。
@immutable
class RemoteTemplateDetailDto {
  // === meta 标量字段 ===
  final String id;
  final String name;
  final String author;
  final String version;
  final String category;
  final int price;
  final String coverUrl;
  final String description;
  final String shortDesc;
  final String referenceSource;
  final List<String> tags;
  final List<String> tagIds;
  final RemoteTemplateClassificationDto classification;
  final RemoteTemplateAmbienceDto ambience;
  final int sortOrder;
  final int updatedAt;

  // === 5 段完整内容 JSON ===
  final Map<String, dynamic> composition;
  final Map<String, dynamic> pose;
  final Map<String, dynamic> camera;
  final Map<String, dynamic> sceneGuide;
  final Map<String, dynamic> postProcess;

  const RemoteTemplateDetailDto({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.category,
    required this.price,
    required this.coverUrl,
    required this.description,
    this.shortDesc = '',
    required this.referenceSource,
    required this.tags,
    required this.tagIds,
    required this.classification,
    this.ambience = const RemoteTemplateAmbienceDto(),
    required this.sortOrder,
    required this.updatedAt,
    required this.composition,
    required this.pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
  });

  /// 从 meta + 5 段 JSON 构造（便于复用 [RemoteTemplateMetaDto] 解析逻辑）。
  factory RemoteTemplateDetailDto.fromMetaAndSegments(
    RemoteTemplateMetaDto meta,
    Map<String, dynamic> composition,
    Map<String, dynamic> pose,
    Map<String, dynamic> camera,
    Map<String, dynamic> sceneGuide,
    Map<String, dynamic> postProcess,
  ) {
    return RemoteTemplateDetailDto(
      id: meta.id,
      name: meta.name,
      author: meta.author,
      version: meta.version,
      category: meta.category,
      price: meta.price,
      coverUrl: meta.coverUrl,
      description: meta.description,
      shortDesc: meta.shortDesc,
      referenceSource: meta.referenceSource,
      tags: meta.tags,
      tagIds: meta.tagIds,
      classification: meta.classification,
      ambience: meta.ambience,
      sortOrder: meta.sortOrder,
      updatedAt: meta.updatedAt,
      composition: composition,
      pose: pose,
      camera: camera,
      sceneGuide: sceneGuide,
      postProcess: postProcess,
    );
  }

  factory RemoteTemplateDetailDto.fromJson(Map<String, dynamic> j) {
    // 复用 meta 解析逻辑提取标量字段
    final meta = RemoteTemplateMetaDto.fromJson(j);
    return RemoteTemplateDetailDto.fromMetaAndSegments(
      meta,
      (j['composition'] as Map<String, dynamic>?) ?? const {},
      (j['pose'] as Map<String, dynamic>?) ?? const {},
      (j['camera'] as Map<String, dynamic>?) ?? const {},
      (j['sceneGuide'] as Map<String, dynamic>?) ?? const {},
      (j['postProcess'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// 后端动态分类 DTO。
///
/// 对应 spec `TemplateCategory`：
/// `{ key; name; iconUrl; sortOrder; isSystem; isActive; updatedAt }`
///
/// v17 扩展：新增 `parentKey` 和 `level` 字段以支持三级树形分类。
@immutable
class TemplateCategoryDto {
  final String key;
  final String name;
  /// 父分类 key（v17 新增）。一级分类为 null，二级为一级 key，三级为二级 key。
  final String? parentKey;
  /// 层级（v17 新增）：1=type / 2=style / 3=method。默认 1 兼容旧后端。
  final int level;
  final String iconUrl;
  /// 简短描述（可为空，仅一/二级分类展示）
  final String description;
  final int sortOrder;
  final bool isSystem;
  final bool isActive;
  final int updatedAt;

  const TemplateCategoryDto({
    required this.key,
    required this.name,
    this.parentKey,
    this.level = 1,
    required this.iconUrl,
    this.description = '',
    required this.sortOrder,
    required this.isSystem,
    required this.isActive,
    required this.updatedAt,
  });

  factory TemplateCategoryDto.fromJson(Map<String, dynamic> j) {
    return TemplateCategoryDto(
      key: j['key'] as String? ?? '',
      name: j['name'] as String? ?? '',
      parentKey: j['parentKey'] as String?,
      level: (j['level'] as num?)?.toInt() ?? 1,
      iconUrl: j['iconUrl'] as String? ?? '',
      description: j['description'] as String? ?? '',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isSystem: j['isSystem'] as bool? ?? false,
      isActive: j['isActive'] as bool? ?? true,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `GET /templates/categories` 响应体。
///
/// 对应 spec `TemplateCategoryListResponse`：`{ categories: TemplateCategory[] }`
@immutable
class TemplateCategoryListResponseDto {
  final List<TemplateCategoryDto> categories;

  const TemplateCategoryListResponseDto({required this.categories});

  factory TemplateCategoryListResponseDto.fromJson(Map<String, dynamic> j) {
    final list = j['categories'] as List<dynamic>? ?? const [];
    return TemplateCategoryListResponseDto(
      categories: list
          .map((e) => TemplateCategoryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
