import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';

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
  final String description;
  final String referenceSource;
  final Map<String, dynamic> composition;
  final Map<String, dynamic> pose;
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
    required this.description,
    required this.referenceSource,
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
      Tables.colDescription: description,
      Tables.colReferenceSource: referenceSource,
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
      description: (row[Tables.colDescription] as String?) ?? '',
      referenceSource: (row[Tables.colReferenceSource] as String?) ?? '',
      composition: _decodeJsonMap(row[Tables.colCompositionJson]),
      pose: _decodeJsonMap(row[Tables.colPoseJson]),
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
    String? description,
    String? referenceSource,
    Map<String, dynamic>? composition,
    Map<String, dynamic>? pose,
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
      description: description ?? this.description,
      referenceSource: referenceSource ?? this.referenceSource,
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

  /// 仅获取用户自定义模板（is_builtin=0）
  Future<List<TemplateRecord>> getCustomOnly() async {
    final rows = await _db.query(
      Tables.customTemplates,
      where: '${Tables.colIsBuiltin} = ?',
      whereArgs: [0],
      orderBy: '${Tables.colCreatedAt} DESC',
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

  /// Upsert 分类记录（按 UNIQUE(key, parent_key) 约束 REPLACE）。
  ///
  /// 用于：
  /// - v14 迁移时种子化 7 个系统分类
  /// - v17 迁移时种子化二三级系统分类
  /// - 后端分类同步时 upsert 到本地
  Future<void> upsertCategory(TemplateCategoryRecord record) async {
    await _db.insert(
      Tables.templateCategories,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      sortOrder: sortOrder ?? this.sortOrder,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
