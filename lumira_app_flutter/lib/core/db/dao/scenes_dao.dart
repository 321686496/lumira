import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';

class SceneRecord {
  final String id;
  final String name;
  final String icon;
  final String category;
  final String style;
  final Map<String, dynamic> filter;
  final String vibe;
  final String description;
  final List<String> exampleImages;
  final List<String> tips;
  final String whereToShoot;
  final String bestTime;
  final Map<String, dynamic> sceneGuide;
  final String relatedCategory;
  final List<String> recommendedTagIds;
  final List<String> tagIds;
  final String creator; // 'user' | 'system'
  final bool isFavorite;
  final int createdAt;
  final int updatedAt;

  SceneRecord({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    required this.style,
    required this.filter,
    required this.vibe,
    required this.description,
    required this.exampleImages,
    required this.tips,
    required this.whereToShoot,
    required this.bestTime,
    required this.sceneGuide,
    required this.relatedCategory,
    required this.recommendedTagIds,
    required this.tagIds,
    required this.creator,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toRow() {
    return {
      Tables.colId: id,
      Tables.colName: name,
      Tables.colIcon: icon,
      Tables.colCategory: category,
      Tables.colStyle: style,
      Tables.colFilterJson: jsonEncode(filter),
      Tables.colVibe: vibe,
      Tables.colDescription: description,
      Tables.colExampleImagesJson: jsonEncode(exampleImages),
      Tables.colTipsJson: jsonEncode(tips),
      Tables.colWhereToShoot: whereToShoot,
      Tables.colBestTime: bestTime,
      Tables.colSceneGuideJson: jsonEncode(sceneGuide),
      Tables.colRelatedCategory: relatedCategory,
      Tables.colRecommendedTagIdsJson: jsonEncode(recommendedTagIds),
      Tables.colTagIdsJson: jsonEncode(tagIds),
      Tables.colCreator: creator,
      Tables.colIsFavorite: isFavorite ? 1 : 0,
      Tables.colCreatedAt: createdAt,
      Tables.colUpdatedAt: updatedAt,
    };
  }

  static SceneRecord fromRow(Map<String, Object?> row) {
    return SceneRecord(
      id: row[Tables.colId] as String,
      name: row[Tables.colName] as String,
      icon: (row[Tables.colIcon] as String?) ?? '',
      category: row[Tables.colCategory] as String,
      style: (row[Tables.colStyle] as String?) ?? '',
      filter: _decodeJsonMap(row[Tables.colFilterJson]),
      vibe: (row[Tables.colVibe] as String?) ?? '',
      description: (row[Tables.colDescription] as String?) ?? '',
      exampleImages: _decodeJsonList(row[Tables.colExampleImagesJson]),
      tips: _decodeJsonList(row[Tables.colTipsJson]),
      whereToShoot: (row[Tables.colWhereToShoot] as String?) ?? '',
      bestTime: (row[Tables.colBestTime] as String?) ?? '',
      sceneGuide: _decodeJsonMap(row[Tables.colSceneGuideJson]),
      relatedCategory: (row[Tables.colRelatedCategory] as String?) ?? '',
      recommendedTagIds: _decodeJsonList(row[Tables.colRecommendedTagIdsJson]),
      tagIds: _decodeJsonList(row[Tables.colTagIdsJson]),
      creator: (row[Tables.colCreator] as String?) ?? 'user',
      isFavorite: (row[Tables.colIsFavorite] as num?)?.toInt() == 1,
      createdAt: (row[Tables.colCreatedAt] as num).toInt(),
      updatedAt: (row[Tables.colUpdatedAt] as num).toInt(),
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

class ScenesDao {
  ScenesDao(this._db);

  final Database _db;

  Future<List<SceneRecord>> getCustomScenes() async {
    final rows = await _db.query(
      Tables.scenes,
      where: '${Tables.colCreator} = ?',
      whereArgs: ['user'],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(SceneRecord.fromRow).toList();
  }

  Future<List<SceneRecord>> getFavorites() async {
    final rows = await _db.query(
      Tables.scenes,
      where: '${Tables.colIsFavorite} = ?',
      whereArgs: [1],
    );
    return rows.map(SceneRecord.fromRow).toList();
  }

  /// 切换收藏标记（upsert minimal row 仅含 id + is_favorite）
  /// 用于内置场景：内置场景完整数据由代码常量提供，DB 只持久化收藏标记
  Future<void> toggleFavorite(String sceneId, bool favorite) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      Tables.scenes,
      where: '${Tables.colId} = ?',
      whereArgs: [sceneId],
      limit: 1,
    );
    if (existing.isEmpty) {
      // 内置场景首次收藏：插入最小行（仅 id + is_favorite + 必填字段）
      await _db.insert(Tables.scenes, {
        Tables.colId: sceneId,
        Tables.colName: '',
        Tables.colCategory: '',
        Tables.colCreator: 'system',
        Tables.colIsFavorite: favorite ? 1 : 0,
        Tables.colCreatedAt: now,
        Tables.colUpdatedAt: now,
      });
    } else {
      await _db.update(
        Tables.scenes,
        {
          Tables.colIsFavorite: favorite ? 1 : 0,
          Tables.colUpdatedAt: now,
        },
        where: '${Tables.colId} = ?',
        whereArgs: [sceneId],
      );
    }
  }

  Future<void> upsert(SceneRecord record) async {
    await _db.insert(
      Tables.scenes,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(String id) async {
    return _db.delete(
      Tables.scenes,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> countCustom() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.scenes} WHERE ${Tables.colCreator} = ?',
      ['user'],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
