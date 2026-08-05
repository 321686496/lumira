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
  final String referenceSource;
  final List<String> tags;
  final List<String> tagIds;
  final RemoteTemplateClassificationDto classification;
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
    required this.referenceSource,
    required this.tags,
    required this.tagIds,
    required this.classification,
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
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 模板分类信息（meta 内嵌）。
///
/// 对应 spec `RemoteTemplateMeta.classification`：
/// `{ type: string; style: string; method: string }`
@immutable
class RemoteTemplateClassificationDto {
  final String type;
  final String style;
  final String method;

  const RemoteTemplateClassificationDto({
    required this.type,
    this.style = '',
    this.method = '',
  });

  factory RemoteTemplateClassificationDto.fromJson(Map<String, dynamic> j) {
    return RemoteTemplateClassificationDto(
      type: j['type'] as String? ?? '',
      style: j['style'] as String? ?? '',
      method: j['method'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'style': style,
        'method': method,
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
  final String referenceSource;
  final List<String> tags;
  final List<String> tagIds;
  final RemoteTemplateClassificationDto classification;
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
    required this.referenceSource,
    required this.tags,
    required this.tagIds,
    required this.classification,
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
      referenceSource: meta.referenceSource,
      tags: meta.tags,
      tagIds: meta.tagIds,
      classification: meta.classification,
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
@immutable
class TemplateCategoryDto {
  final String key;
  final String name;
  final String iconUrl;
  final int sortOrder;
  final bool isSystem;
  final bool isActive;
  final int updatedAt;

  const TemplateCategoryDto({
    required this.key,
    required this.name,
    required this.iconUrl,
    required this.sortOrder,
    required this.isSystem,
    required this.isActive,
    required this.updatedAt,
  });

  factory TemplateCategoryDto.fromJson(Map<String, dynamic> j) {
    return TemplateCategoryDto(
      key: j['key'] as String? ?? '',
      name: j['name'] as String? ?? '',
      iconUrl: j['iconUrl'] as String? ?? '',
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
