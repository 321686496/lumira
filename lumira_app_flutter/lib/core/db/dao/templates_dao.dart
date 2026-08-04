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
}
