import 'package:sqflite/sqflite.dart';

import '../tables.dart';

class GalleryItemRecord {
  final String id;
  final String? dataUrl;
  final String? filePath;
  final String? sceneId;
  final String? templateId;
  final String? kitId;
  final String? mood;
  final String? lut;
  final int createdAt;

  GalleryItemRecord({
    required this.id,
    required this.dataUrl,
    required this.filePath,
    required this.sceneId,
    required this.templateId,
    required this.kitId,
    required this.mood,
    required this.lut,
    required this.createdAt,
  });

  Map<String, Object?> toRow() {
    return {
      Tables.colId: id,
      Tables.colDataUrl: dataUrl,
      Tables.colFilePath: filePath,
      Tables.colSceneId: sceneId,
      Tables.colTemplateId: templateId,
      Tables.colKitId: kitId,
      Tables.colMood: mood,
      Tables.colLut: lut,
      Tables.colCreatedAt: createdAt,
    };
  }

  static GalleryItemRecord fromRow(Map<String, Object?> row) {
    return GalleryItemRecord(
      id: row[Tables.colId] as String,
      dataUrl: row[Tables.colDataUrl] as String?,
      filePath: row[Tables.colFilePath] as String?,
      sceneId: row[Tables.colSceneId] as String?,
      templateId: row[Tables.colTemplateId] as String?,
      kitId: row[Tables.colKitId] as String?,
      mood: row[Tables.colMood] as String?,
      lut: row[Tables.colLut] as String?,
      createdAt: (row[Tables.colCreatedAt] as num).toInt(),
    );
  }
}

class GalleryDao {
  GalleryDao(this._db);

  final Database _db;

  /// 获取所有照片（最新在前，对应 uni-app 数组头部插入的语义）
  Future<List<GalleryItemRecord>> getAll({int? limit, int? offset}) async {
    final rows = await _db.query(
      Tables.galleryItems,
      orderBy: '${Tables.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  Future<List<GalleryItemRecord>> getByScene(String sceneId) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: '${Tables.colSceneId} = ?',
      whereArgs: [sceneId],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  Future<GalleryItemRecord?> getById(String id) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GalleryItemRecord.fromRow(rows.first);
  }

  Future<void> insert(GalleryItemRecord record) async {
    await _db.insert(
      Tables.galleryItems,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateScene(String photoId, String? sceneId) async {
    return _db.update(
      Tables.galleryItems,
      {Tables.colSceneId: sceneId},
      where: '${Tables.colId} = ?',
      whereArgs: [photoId],
    );
  }

  Future<int> delete(String id) async {
    return _db.delete(
      Tables.galleryItems,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM ${Tables.galleryItems}');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countByScene(String sceneId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.galleryItems} WHERE ${Tables.colSceneId} = ?',
      [sceneId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// 按月分组统计（用于 monthly-digest 页）
  Future<List<Map<String, dynamic>>> monthlyCounts() async {
    return _db.rawQuery('''
      SELECT
        strftime('%Y-%m', ${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') AS month,
        COUNT(*) AS cnt
      FROM ${Tables.galleryItems}
      GROUP BY month
      ORDER BY month DESC
    ''');
  }
}
