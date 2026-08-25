import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/domain/photo_template.dart';

/// 简化的模板实体（仅常用字段；完整 PhotoTemplate 在 lib/features/templates/ 中定义）
/// 本任务范围：DB 层只负责存取原始 JSON 数据
class TemplateRecord {
  final String id;
  final String name;
  final String author;
  final String version;
  final String category;
  final Map<String, dynamic> classification;
  final List<String> tags;
  final List<String> tagIds;
  final int price;
  final String cover;
  final String? coverData;
  /// 效果图列表（images_json 列）。null 表示未存储（旧模板无该列数据）。
  /// [0] 为封面；仅 Phase 1 存量模板由 cover/coverData 派生，Phase 2 起直接读数组。
  final List<TemplateImage>? images;
  final String description;
  final String referenceSource;
  final String shortDesc;
  final String ambienceJson;
  final Map<String, dynamic> composition;
  /// pose 载体（Phase 1 兼容两种形态）：
  /// - 旧数据：单个 Map（单姿势）
  /// - 新数据：JSON 数组 List（多姿势）
  final dynamic pose;
  final Map<String, dynamic> camera;
  final Map<String, dynamic> sceneGuide;
  final Map<String, dynamic> postProcess;
  final int createdAt;
  final int updatedAt;
  final bool isBuiltin;
  final bool isRecommended;
  /// 模板来源标记（v14 新增）：'builtin' | 'custom' | 'remote'
  /// - builtin: 系统内置模板（is_builtin=1）
  /// - custom: 用户自定义模板（is_builtin=0，本地创建/导入）
  /// - remote: 后端动态模板（is_builtin=0，从后端同步）
  /// 保留 is_builtin 列以兼容现有查询，source 是更细粒度的来源标记。
  final String source;

  TemplateRecord({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.category,
    required this.classification,
    required this.tags,
    required this.tagIds,
    required this.price,
    required this.cover,
    this.coverData,
    this.images,
    required this.description,
    required this.referenceSource,
    this.shortDesc = '',
    this.ambienceJson = '{}',
    required this.composition,
    required this.pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
    required this.createdAt,
    required this.updatedAt,
    required this.isBuiltin,
    required this.isRecommended,
    this.source = 'builtin',
  });

  Map<String, Object?> toRow() {
    return {
      Tables.colId: id,
      Tables.colName: name,
      Tables.colAuthor: author,
      Tables.colVersion: version,
      Tables.colCategory: category,
      Tables.colClassificationJson: jsonEncode(classification),
      Tables.colTagsJson: jsonEncode(tags),
      Tables.colTagIdsJson: jsonEncode(tagIds),
      Tables.colPrice: price,
      Tables.colCover: cover,
      Tables.colCoverData: coverData,
      // images_json 列定义为 NOT NULL DEFAULT '[]'，images 为 null（旧模板）时回退 '[]'，
      // 显式传 null 会违反 NOT NULL 约束。
      Tables.colImagesJson: jsonEncode(
        images?.map(_imageToJson).toList() ?? const [],
      ),
      Tables.colDescription: description,
      Tables.colReferenceSource: referenceSource,
      Tables.colShortDesc: shortDesc,
      Tables.colAmbienceJson: ambienceJson,
      Tables.colCompositionJson: jsonEncode(composition),
      Tables.colPoseJson: jsonEncode(pose),
      Tables.colCameraJson: jsonEncode(camera),
      Tables.colSceneGuideJson: jsonEncode(sceneGuide),
      Tables.colPostProcessJson: jsonEncode(postProcess),
      Tables.colIsBuiltin: isBuiltin ? 1 : 0,
      Tables.colIsRecommended: isRecommended ? 1 : 0,
      Tables.colSource: source,
      Tables.colCreatedAt: createdAt,
      Tables.colUpdatedAt: updatedAt,
    };
  }

  static TemplateRecord fromRow(Map<String, Object?> row) {
    return TemplateRecord(
      id: row[Tables.colId] as String,
      name: row[Tables.colName] as String,
      author: (row[Tables.colAuthor] as String?) ?? '',
      version: (row[Tables.colVersion] as String?) ?? '1.0.0',
      category: row[Tables.colCategory] as String,
      classification: _decodeJsonMap(row[Tables.colClassificationJson]),
      tags: _decodeJsonList(row[Tables.colTagsJson]),
      tagIds: _decodeJsonList(row[Tables.colTagIdsJson]),
      price: (row[Tables.colPrice] as num?)?.toInt() ?? 0,
      cover: (row[Tables.colCover] as String?) ?? '',
      coverData: row[Tables.colCoverData] as String?,
      images: _decodeImages(row[Tables.colImagesJson]),
      description: (row[Tables.colDescription] as String?) ?? '',
      referenceSource: (row[Tables.colReferenceSource] as String?) ?? '',
      shortDesc: (row[Tables.colShortDesc] as String?) ?? '',
      ambienceJson: (row[Tables.colAmbienceJson] as String?) ?? '{}',
      composition: _decodeJsonMap(row[Tables.colCompositionJson]),
      pose: _decodeJsonAny(row[Tables.colPoseJson]),
      camera: _decodeJsonMap(row[Tables.colCameraJson]),
      sceneGuide: _decodeJsonMap(row[Tables.colSceneGuideJson]),
      postProcess: _decodeJsonMap(row[Tables.colPostProcessJson]),
      createdAt: (row[Tables.colCreatedAt] as num).toInt(),
      updatedAt: (row[Tables.colUpdatedAt] as num).toInt(),
      isBuiltin: (row[Tables.colIsBuiltin] as num?)?.toInt() == 1,
      isRecommended: (row[Tables.colIsRecommended] as num?)?.toInt() == 1,
      // 旧数据库迁移后无 source 列时回退到按 is_builtin 推断
      source: (row[Tables.colSource] as String?) ??
          ((row[Tables.colIsBuiltin] as num?)?.toInt() == 1
              ? 'builtin'
              : 'custom'),
    );
  }

  TemplateRecord copyWith({
    String? id,
    String? name,
    String? author,
    String? version,
    String? category,
    Map<String, dynamic>? classification,
    List<String>? tags,
    List<String>? tagIds,
    int? price,
    String? cover,
    String? coverData,
    List<TemplateImage>? images,
    String? description,
    String? referenceSource,
    String? shortDesc,
    String? ambienceJson,
    Map<String, dynamic>? composition,
    dynamic pose,
    Map<String, dynamic>? camera,
    Map<String, dynamic>? sceneGuide,
    Map<String, dynamic>? postProcess,
    int? createdAt,
    int? updatedAt,
    bool? isBuiltin,
    bool? isRecommended,
    String? source,
  }) {
    return TemplateRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      version: version ?? this.version,
      category: category ?? this.category,
      classification: classification ?? this.classification,
      tags: tags ?? this.tags,
      tagIds: tagIds ?? this.tagIds,
      price: price ?? this.price,
      cover: cover ?? this.cover,
      coverData: coverData ?? this.coverData,
      images: images ?? this.images,
      description: description ?? this.description,
      referenceSource: referenceSource ?? this.referenceSource,
      shortDesc: shortDesc ?? this.shortDesc,
      ambienceJson: ambienceJson ?? this.ambienceJson,
      composition: composition ?? this.composition,
      pose: pose ?? this.pose,
      camera: camera ?? this.camera,
      sceneGuide: sceneGuide ?? this.sceneGuide,
      postProcess: postProcess ?? this.postProcess,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isRecommended: isRecommended ?? this.isRecommended,
      source: source ?? this.source,
    );
  }

  static Map<String, dynamic> _decodeJsonMap(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }

  /// 通用 JSON 解码：返回原样结构（旧单个 Map 或新版 List 数组），无法解码时返回 null。
  static dynamic _decodeJsonAny(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw);
    }
    return null;
  }

  static Map<String, dynamic> _imageToJson(TemplateImage img) =>
      <String, dynamic>{'url': img.url, if (img.data != null) 'data': img.data};

  /// 解析 images_json 列。空数组 `[]` 返回空 List（非 null）；无数据返回 null。
  static List<TemplateImage>? _decodeImages(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return null;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => TemplateImage(
                url: (e['url'] as String?) ?? '',
                data: e['data'] as String?,
              ))
          .toList();
    }
    return null;
  }

  static List<String> _decodeJsonList(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>();
    }
    return <String>[];
  }
}

class TemplatesDao {
  TemplatesDao(this._db);

  final Database _db;

  Future<List<TemplateRecord>> getAll({String? category}) async {
    final where = category != null ? '${Tables.colCategory} = ?' : null;
    final whereArgs = category != null ? [category] : null;
    final rows = await _db.query(
      Tables.customTemplates,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 获取内置模板（可选筛选 recommended / price / paidOnly / category）
  Future<List<TemplateRecord>> getBuiltin({
    bool? isRecommended,
    int? price,
    bool paidOnly = false,
    String? category,
  }) async {
    final where = <String>['${Tables.colIsBuiltin} = ?'];
    final args = <Object>[1];
    if (isRecommended != null) {
      where.add('${Tables.colIsRecommended} = ?');
      args.add(isRecommended ? 1 : 0);
    }
    if (price != null) {
      where.add('${Tables.colPrice} = ?');
      args.add(price);
    }
    if (paidOnly) {
      where.add('${Tables.colPrice} > ?');
      args.add(0);
    }
    if (category != null) {
      where.add('${Tables.colCategory} = ?');
      args.add(category);
    }
    final rows = await _db.query(
      Tables.customTemplates,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '${Tables.colPrice} ASC, ${Tables.colName} ASC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 获取推荐候选池：内置推荐位（is_builtin=1 且 is_recommended=1）∪ 全部远程模板（source='remote'）。
  ///
  /// 供个性化推荐引擎使用：候选池既要保留内置"官方推荐位"，也要纳入后台实时下发的
  /// 全部远程模板（后台新增的运营模板 should 参与推荐）。远程模板入库统一
  /// is_recommended=false（见 TemplateMapper.metaToRecord），因此这里不能用
  /// (is_builtin=1 OR source='remote') AND is_recommended=1，否则会过滤掉全部远程模板。
  Future<List<TemplateRecord>> getRecommendedCandidatePool() async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: '(${Tables.colIsBuiltin} = ? AND ${Tables.colIsRecommended} = ?) '
          'OR ${Tables.colSource} = ?',
      whereArgs: [1, 1, 'remote'],
      orderBy: '${Tables.colPrice} ASC, ${Tables.colName} ASC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 仅获取用户自定义模板（source='custom'）。
  ///
  /// 严格按 source='custom' 过滤，排除后端动态模板（source='remote'），
  /// 避免远程模板被误归入"我的模板"列表。
  /// 旧数据库（无 source 列，已迁移）回退值为 'custom'，兼容正常。
  Future<List<TemplateRecord>> getCustomOnly() async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: '${Tables.colSource} = ?',
      whereArgs: ['custom'],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 获取内置 + 后端动态模板（is_builtin=1 OR source='remote'）。
  ///
  /// 用于"全部模板"页默认视图：展示所有非用户自定义模板（系统内置 + 服务器下发）。
  /// 按 sortOrder ASC、updatedAt DESC 排序，内置模板优先。
  Future<List<TemplateRecord>> getBuiltinAndRemote({
    bool? isRecommended,
    int? price,
    bool paidOnly = false,
    String? category,
  }) async {
    final where = <String>[
      '(${Tables.colIsBuiltin} = ? OR ${Tables.colSource} = ?)',
    ];
    final args = <Object>[1, 'remote'];
    if (isRecommended != null) {
      where.add('${Tables.colIsRecommended} = ?');
      args.add(isRecommended ? 1 : 0);
    }
    if (price != null) {
      where.add('${Tables.colPrice} = ?');
      args.add(price);
    }
    if (paidOnly) {
      where.add('${Tables.colPrice} > ?');
      args.add(0);
    }
    if (category != null) {
      where.add('${Tables.colCategory} = ?');
      args.add(category);
    }
    final rows = await _db.query(
      Tables.customTemplates,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '${Tables.colPrice} ASC, ${Tables.colName} ASC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  Future<TemplateRecord?> getById(String id) async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TemplateRecord.fromRow(rows.first);
  }

  /// Upsert: 按 id 插入或更新
  Future<void> upsert(TemplateRecord record) async {
    await _db.insert(
      Tables.customTemplates,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(String id) async {
    return _db.delete(
      Tables.customTemplates,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM ${Tables.customTemplates}');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // === v14: 远程模板同步相关方法 ===

  /// 获取用户自定义 + 后端动态模板（source IN ('custom','remote')）。
  ///
  /// 用于 [allTemplatesProvider] 合并展示：内置模板来自 TemplateRegistry，
  /// 此处补充非内置部分。按 updated_at DESC 排序（最近更新的在前）。
  Future<List<TemplateRecord>> getCustomAndRemote() async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: "${Tables.colSource} IN ('custom', 'remote')",
      orderBy: '${Tables.colUpdatedAt} DESC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 获取后端动态模板（source = 'remote'）。
  ///
  /// 用于需要单独处理远程模板的场景（如全量同步前对比本地与远端列表）。
  Future<List<TemplateRecord>> getRemote() async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: '${Tables.colSource} = ?',
      whereArgs: ['remote'],
      orderBy: '${Tables.colUpdatedAt} DESC',
    );
    return rows.map(TemplateRecord.fromRow).toList();
  }

  /// 删除本地缓存中已不在后端列表的 remote 模板。
  ///
  /// 用于全量同步流程：拉取后端 list 后，比对本地 source='remote' 的模板，
  /// 删除后端已下架或不存在的，避免本地缓存膨胀。
  /// 当 [validIds] 为空集时，删除所有 remote 模板（谨慎调用）。
  Future<int> pruneRemoteTemplates(Set<String> validIds) async {
    // 安全策略：validIds 为空时也执行清理（后端清空场景）
    final rows = await _db.query(
      Tables.customTemplates,
      columns: [Tables.colId],
      where: '${Tables.colSource} = ?',
      whereArgs: ['remote'],
    );
    final localIds = rows.map((r) => r[Tables.colId] as String).toList();
    final toDelete = localIds.where((id) => !validIds.contains(id)).toList();
    if (toDelete.isEmpty) return 0;
    // 分批删除（SQLite IN 子句参数上限考虑）
    var deleted = 0;
    const batchSize = 100;
    for (var i = 0; i < toDelete.length; i += batchSize) {
      final end = (i + batchSize < toDelete.length) ? i + batchSize : toDelete.length;
      final batch = toDelete.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      deleted += await _db.delete(
        Tables.customTemplates,
        where: '${Tables.colId} IN ($placeholders) AND ${Tables.colSource} = ?',
        whereArgs: [...batch, 'remote'],
      );
    }
    return deleted;
  }

  /// 删除本地已不在后端列表的分类（后台删除/停用后同步清理）。
  ///
  /// 用于分类全量同步流程：拉取后端分类后，比对本地 template_categories，
  /// 删除后端已删除/已停用的分类，避免本地缓存膨胀、分类页残留已删除分类。
  /// 分类 key 全局唯一（作为路由参数与模板引用），按 key 集合比对即可。
  /// 当 [validKeys] 为空集时，删除所有本地分类（后端清空场景）。
  Future<int> pruneStaleCategories(Set<String> validKeys) async {
    final rows = await _db.query(
      Tables.templateCategories,
      columns: [Tables.colKey],
    );
    final localKeys =
        rows.map((r) => r[Tables.colKey] as String).toSet().toList();
    final toDelete =
        localKeys.where((k) => !validKeys.contains(k)).toList();
    if (toDelete.isEmpty) return 0;
    // 分批删除（SQLite IN 子句参数上限考虑）
    var deleted = 0;
    const batchSize = 100;
    for (var i = 0; i < toDelete.length; i += batchSize) {
      final end =
          (i + batchSize < toDelete.length) ? i + batchSize : toDelete.length;
      final batch = toDelete.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      deleted += await _db.delete(
        Tables.templateCategories,
        where: '${Tables.colKey} IN ($placeholders)',
        whereArgs: batch,
      );
    }
    return deleted;
  }

  // === v14: 分类管理相关方法 ===

  /// 获取分类列表。
  ///
  /// - [activeOnly] = true：仅返回 isActive=1 的分类（客户端展示用）
  /// - [activeOnly] = false：返回所有分类（Admin 管理用，Flutter 端通常不需要）
  /// - [level]：可选，按层级过滤（1=type / 2=style / 3=method）
  /// - [parentKey]：可选，按父分类 key 过滤（一级分类的 parentKey 为 NULL）
  /// 按 sortOrder ASC 排序。
  Future<List<TemplateCategoryRecord>> getCategories({
    bool activeOnly = true,
    int? level,
    String? parentKey,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (activeOnly) {
      where.add('${Tables.colIsActive} = ?');
      args.add(1);
    }
    if (level != null) {
      where.add('${Tables.colLevel} = ?');
      args.add(level);
    }
    if (parentKey != null) {
      where.add('${Tables.colParentKey} = ?');
      args.add(parentKey);
    } else if (level == 1) {
      // 查询一级分类时，parent_key IS NULL
      where.add('${Tables.colParentKey} IS NULL');
    }
    final whereClause = where.isNotEmpty ? where.join(' AND ') : null;
    final rows = await _db.query(
      Tables.templateCategories,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: '${Tables.colSortOrder} ASC',
    );
    return rows.map(TemplateCategoryRecord.fromRow).toList();
  }

  /// 按层级查询分类。
  ///
  /// - level=1：一级分类（type），parent_key IS NULL
  /// - level=2：二级分类（style），parent_key 为某个一级 key
  /// - level=3：三级分类（method），parent_key 为某个二级 key
  Future<List<TemplateCategoryRecord>> getCategoriesByLevel(int level,
      {bool activeOnly = true}) async {
    return getCategories(activeOnly: activeOnly, level: level);
  }

  /// 按父分类 key 查询子分类。
  ///
  /// 用于级联选择：选中一级 → 查二级（parentKey=一级key）；
  /// 选中二级 → 查三级（parentKey=二级key）。
  Future<List<TemplateCategoryRecord>> getCategoriesByParent(
    String parentKey, {
    bool activeOnly = true,
  }) async {
    return getCategories(activeOnly: activeOnly, parentKey: parentKey);
  }

  /// 获取一级分类下的所有二级分类（style）。
  Future<List<TemplateCategoryRecord>> getStylesForType(String typeKey,
      {bool activeOnly = true}) async {
    return getCategoriesByParent(typeKey, activeOnly: activeOnly);
  }

  /// 获取二级分类下的所有三级分类（method）。
  Future<List<TemplateCategoryRecord>> getMethodsForStyle(String styleKey,
      {bool activeOnly = true}) async {
    return getCategoriesByParent(styleKey, activeOnly: activeOnly);
  }

  /// 获取指定分类的子树 key 集合（含自身 + 所有后代 key）。
  ///
  /// 用于「该分类下的模板 = 包含子孙级」的过滤：模板列表按此集合筛，
  /// 模板的分类叶子路径命中的即算（spec 2026-08-17-template-category-4level-design.md §6.3）。
  ///
  /// - 一级点击 → 二级独立页（[TemplatesCategoryPage]）；
  /// - 二级点击 → 模板列表页 `TemplatesAllPage(category=该二级key)`，
  ///   此时把该二级 key 及其所有后代 key 展开成集合，用于 subtree 模板查询。
  Future<Set<String>> getSubtreeKeys(
    String key, {
    bool activeOnly = true,
  }) async {
    final all = await getCategories(activeOnly: activeOnly);
    final byParent = <String, List<TemplateCategoryRecord>>{};
    for (final c in all) {
      if (c.parentKey != null) {
        byParent.putIfAbsent(c.parentKey!, () => []).add(c);
      }
    }
    final result = <String>{key};
    final queue = <String>[key];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = byParent[current] ?? const <TemplateCategoryRecord>[];
      for (final child in children) {
        if (result.add(child.key)) {
          queue.add(child.key);
        }
      }
    }
    return result;
  }

  /// 统计每个候选分类 key 下（含子孙级）的模板数量。
  ///
  /// 统计口径与模板列表过滤保持一致：模板的分类叶子路径
  /// （category / style / majorStyle / subStyle / method）中任意一个 key
  /// 命中该分类的子树 key 集合即算（spec-4level §6.3）。
  /// 模板来源：builtin + remote（与模板库概览一致）。
  /// 用于分类卡片下方的「N 套模板」展示。
  Future<Map<String, int>> countTemplatesBySubtree(
    List<String> categoryKeys, {
    bool activeOnly = true,
  }) async {
    final result = <String, int>{for (final k in categoryKeys) k: 0};
    if (categoryKeys.isEmpty) return result;

    // 逐个候选分类展开子树 key 集合
    final subtreeByKey = <String, Set<String>>{};
    for (final k in categoryKeys) {
      subtreeByKey[k] = await getSubtreeKeys(k, activeOnly: activeOnly);
    }

    final items = await getBuiltinAndRemote();
    for (final t in items) {
      final cls = t.classification;
      final style = cls['style'] as String?;
      final method = cls['method'] as String?;
      final majorStyle = cls['majorStyle'] as String?;
      final subStyle = cls['subStyle'] as String?;
      for (final k in categoryKeys) {
        final set = subtreeByKey[k]!;
        if (set.contains(t.category) ||
            (style != null && set.contains(style)) ||
            (method != null && set.contains(method)) ||
            (majorStyle != null && set.contains(majorStyle)) ||
            (subStyle != null && set.contains(subStyle))) {
          result[k] = result[k]! + 1;
        }
      }
    }
    return result;
  }
  /// 获取完整的三级分类树。
  ///
  /// 返回一级分类列表，每个一级分类的 [TemplateCategoryNode.children] 含二级节点，
  /// 二级节点的 children 含三级节点。
  /// 用于需要一次性加载完整分类树的场景（如分类管理页）。
  Future<List<TemplateCategoryNode>> getCategoryTree(
      {bool activeOnly = true}) async {
    final all = await getCategories(activeOnly: activeOnly);
    final byParent = <String?, List<TemplateCategoryRecord>>{};
    for (final c in all) {
      byParent.putIfAbsent(c.parentKey, () => []).add(c);
    }
    final roots = byParent[null] ?? <TemplateCategoryRecord>[];
    return roots.map((r) => _buildNode(r, byParent)).toList();
  }

  TemplateCategoryNode _buildNode(
    TemplateCategoryRecord record,
    Map<String?, List<TemplateCategoryRecord>> byParent,
  ) {
    final children = byParent[record.key] ?? <TemplateCategoryRecord>[];
    return TemplateCategoryNode(
      record: record,
      children: children.map((c) => _buildNode(c, byParent)).toList(),
    );
  }

  /// Upsert 分类记录。
  ///
  /// 先按 (key, parent_key) 删除已有记录（parent_key 为 NULL 时用 IS NULL 精确匹配），
  /// 再插入新记录。不能依赖 UNIQUE(key, parent_key) 做 REPLACE：SQLite 唯一索引将
  /// NULL 视为互不相同，一级分类（parent_key IS NULL）的唯一约束永远不触发，
  /// REPLACE 会不断累积重复行。
  ///
  /// 用于：
  /// - v14 迁移时种子化 7 个系统分类
  /// - v17 迁移时种子化二三级系统分类
  /// - 后端分类同步时 upsert 到本地
  Future<void> upsertCategory(TemplateCategoryRecord record) async {
    await _db.transaction((txn) async {
      // 防御性清理：插入 level>1 分类时，删除可能存在的 corrupted level=1 记录
      // （key 相同但 level=1 且 parent_key IS NULL），避免概览页出现二级分类。
      // 与 v19 迁移逻辑配合，防止远程同步重新引入 corrupted 数据。
      if (record.level > 1) {
        await txn.delete(
          Tables.templateCategories,
          where:
              '${Tables.colKey} = ? AND ${Tables.colLevel} = 1 AND ${Tables.colParentKey} IS NULL',
          whereArgs: [record.key],
        );
      }
      if (record.parentKey == null) {
        await txn.delete(
          Tables.templateCategories,
          where: '${Tables.colKey} = ? AND ${Tables.colParentKey} IS NULL',
          whereArgs: [record.key],
        );
      } else {
        await txn.delete(
          Tables.templateCategories,
          where: '${Tables.colKey} = ? AND ${Tables.colParentKey} = ?',
          whereArgs: [record.key, record.parentKey],
        );
      }
      await txn.insert(Tables.templateCategories, record.toRow());
    });
  }
}

/// 分类树节点（三级树形结构）。
///
/// 用于 [TemplatesDao.getCategoryTree] 返回完整分类树。
class TemplateCategoryNode {
  const TemplateCategoryNode({
    required this.record,
    required this.children,
  });

  final TemplateCategoryRecord record;
  final List<TemplateCategoryNode> children;
}

/// 模板分类记录（v14 新增，v17 扩展为三级树形）。
///
/// 与后端 `template_categories` 表字段对齐（除 created_at 外），
/// 用于分类瀑布流数据源 + 后端同步缓存。
///
/// v17 扩展字段：
/// - [id]：自增主键（v17 新增，替代 key 作为 PRIMARY KEY）
/// - [parentKey]：父分类 key，一级为 null
/// - [level]：层级 1=type / 2=style / 3=method
class TemplateCategoryRecord {
  /// 自增主键（v17 新增）。从 DB 读取时有值，新建时为 null。
  final int? id;
  final String key;
  final String name;
  /// 父分类 key。一级分类为 null，二级为一级 key，三级为二级 key。
  final String? parentKey;
  /// 层级：1=type（一级） / 2=style（二级） / 3=method（三级）
  final int level;
  /// 图标 URL（后端托管，空字符串表示使用 Flutter 端内置 Material Icons 回退映射）
  final String iconUrl;
  /// 简短描述（可为空，仅一二级分类展示，来自后端）
  final String description;
  final int sortOrder;
  /// 是否为系统保留分类（1=key 锁定不可改不可删，与后端 is_system 对齐）
  final bool isSystem;
  /// 是否激活展示（1=展示，0=隐藏）
  final bool isActive;
  final int updatedAt;

  const TemplateCategoryRecord({
    this.id,
    required this.key,
    required this.name,
    this.parentKey,
    this.level = 1,
    this.iconUrl = '',
    this.description = '',
    this.sortOrder = 0,
    this.isSystem = false,
    this.isActive = true,
    this.updatedAt = 0,
  });

  Map<String, Object?> toRow() {
    return {
      // id 自增主键由 DB 分配，不写入（除非从 DB 读取后回写）
      Tables.colKey: key,
      Tables.colName: name,
      Tables.colParentKey: parentKey,
      Tables.colLevel: level,
      Tables.colIconUrl: iconUrl,
      Tables.colDescription: description,
      Tables.colSortOrder: sortOrder,
      Tables.colIsSystem: isSystem ? 1 : 0,
      Tables.colIsActive: isActive ? 1 : 0,
      Tables.colUpdatedAt: updatedAt,
    };
  }

  static TemplateCategoryRecord fromRow(Map<String, Object?> row) {
    return TemplateCategoryRecord(
      id: (row[Tables.colId] as num?)?.toInt(),
      key: row[Tables.colKey] as String,
      name: row[Tables.colName] as String,
      parentKey: row[Tables.colParentKey] as String?,
      level: (row[Tables.colLevel] as num?)?.toInt() ?? 1,
      iconUrl: (row[Tables.colIconUrl] as String?) ?? '',
      description: (row[Tables.colDescription] as String?) ?? '',
      sortOrder: (row[Tables.colSortOrder] as num?)?.toInt() ?? 0,
      isSystem: (row[Tables.colIsSystem] as num?)?.toInt() == 1,
      isActive: (row[Tables.colIsActive] as num?)?.toInt() == 1,
      updatedAt: (row[Tables.colUpdatedAt] as num?)?.toInt() ?? 0,
    );
  }

  TemplateCategoryRecord copyWith({
    int? id,
    String? key,
    String? name,
    String? parentKey,
    int? level,
    String? iconUrl,
    String? description,
    int? sortOrder,
    bool? isSystem,
    bool? isActive,
    int? updatedAt,
  }) {
    return TemplateCategoryRecord(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      parentKey: parentKey ?? this.parentKey,
      level: level ?? this.level,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
