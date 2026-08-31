import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/domain/photo_template.dart';

class GalleryItemRecord {
  final String id;
  final String? dataUrl;
  final String? filePath;
  final String? originalPath;
  final TransformParams? transform;
  final PostProcess? postProcess;
  final String? sceneId;
  final String? templateId;
  final String? kitId;
  final String? mood;
  final String? lut;
  final bool isFavorite;
  final bool isHidden;
  final int createdAt;

  GalleryItemRecord({
    required this.id,
    this.dataUrl,
    this.filePath,
    this.originalPath,
    this.transform,
    this.postProcess,
    this.sceneId,
    this.templateId,
    this.kitId,
    this.mood,
    this.lut,
    this.isFavorite = false,
    this.isHidden = false,
    required this.createdAt,
  });

  Map<String, Object?> toRow() {
    return {
      Tables.colId: id,
      Tables.colDataUrl: dataUrl,
      Tables.colFilePath: filePath,
      Tables.colOriginalPath: originalPath,
      Tables.colTransform: transform != null ? jsonEncode(transform!.toJson()) : null,
      Tables.colPostProcess: postProcess != null ? jsonEncode(_postProcessToJson(postProcess!)) : null,
      Tables.colSceneId: sceneId,
      Tables.colTemplateId: templateId,
      Tables.colKitId: kitId,
      Tables.colMood: mood,
      Tables.colLut: lut,
      Tables.colGalleryItemIsFavorite: isFavorite ? 1 : 0,
      Tables.colGalleryItemHidden: isHidden ? 1 : 0,
      Tables.colCreatedAt: createdAt,
    };
  }

  static GalleryItemRecord fromRow(Map<String, Object?> row) {
    return GalleryItemRecord(
      id: row[Tables.colId] as String,
      dataUrl: row[Tables.colDataUrl] as String?,
      filePath: row[Tables.colFilePath] as String?,
      originalPath: row[Tables.colOriginalPath] as String?,
      transform: _parseTransform(row[Tables.colTransform] as String?),
      postProcess: _parsePostProcess(row[Tables.colPostProcess] as String?),
      sceneId: row[Tables.colSceneId] as String?,
      templateId: row[Tables.colTemplateId] as String?,
      kitId: row[Tables.colKitId] as String?,
      mood: row[Tables.colMood] as String?,
      lut: row[Tables.colLut] as String?,
      isFavorite: (row[Tables.colGalleryItemIsFavorite] as num?)?.toInt() == 1,
      isHidden: (row[Tables.colGalleryItemHidden] as num?)?.toInt() == 1,
      createdAt: (row[Tables.colCreatedAt] as num).toInt(),
    );
  }

  static TransformParams? _parseTransform(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return TransformParams.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static PostProcess? _parsePostProcess(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PostProcess(
        cropRatio: map['cropRatio'] as String? ?? '3:4',
        color: PostProcessColor(
          brightness: (map['brightness'] as num?)?.toDouble() ?? 0,
          contrast: (map['contrast'] as num?)?.toDouble() ?? 0,
          saturation: (map['saturation'] as num?)?.toDouble() ?? 0,
          temperature: (map['temperature'] as num?)?.toDouble() ?? 0,
          tint: (map['tint'] as num?)?.toDouble() ?? 0,
          highlights: (map['highlights'] as num?)?.toDouble(),
          shadows: (map['shadows'] as num?)?.toDouble(),
          blackPoint: (map['blackPoint'] as num?)?.toDouble(),
          clarity: (map['clarity'] as num?)?.toDouble(),
          vibrance: (map['vibrance'] as num?)?.toDouble(),
          brilliance: (map['brilliance'] as num?)?.toDouble(),
        ),
        smoothStrength: (map['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (map['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (map['vignette'] as num?)?.toInt() ?? 0,
        grain: (map['grain'] as num?)?.toInt() ?? 0,
        legStretch: (map['legStretch'] as num?)?.toInt() ?? 0,
        lut: map['lut'] as String? ?? 'none',
        systemFilter: map['systemFilter'] as String?,
        customCropRect: (map['customCropRect'] as Map<String, dynamic>?) != null
            ? CropRect.fromJson(map['customCropRect'] as Map<String, dynamic>)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _postProcessToJson(PostProcess p) {
    return {
      'cropRatio': p.cropRatio,
      'brightness': p.color.brightness,
      'contrast': p.color.contrast,
      'saturation': p.color.saturation,
      'temperature': p.color.temperature,
      'tint': p.color.tint,
      'highlights': p.color.highlights,
      'shadows': p.color.shadows,
      'blackPoint': p.color.blackPoint,
      'clarity': p.color.clarity,
      'vibrance': p.color.vibrance,
      'brilliance': p.color.brilliance,
      'smoothStrength': p.smoothStrength,
      'sharpen': p.sharpen,
      'vignette': p.vignette,
      'grain': p.grain,
      'legStretch': p.legStretch,
      'lut': p.lut,
      'systemFilter': p.systemFilter,
      if (p.customCropRect != null) 'customCropRect': p.customCropRect!.toJson(),
    };
  }
}

class GalleryDao {
  GalleryDao(this._db);

  final Database _db;

  /// 隐藏照片过滤（从系统相册引入、不在内部相册/列表展示）
  static const String _notHidden = '${Tables.colGalleryItemHidden} != 1';

  /// 获取所有照片（最新在前，对应 uni-app 数组头部插入的语义）
  Future<List<GalleryItemRecord>> getAll({int? limit, int? offset}) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: _notHidden,
      orderBy: '${Tables.colCreatedAt} DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  Future<List<GalleryItemRecord>> getByScene(String sceneId) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: '${Tables.colSceneId} = ? AND $_notHidden',
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

  Future<int> updateMood(String photoId, String? mood) async {
    return _db.update(
      Tables.galleryItems,
      {Tables.colMood: mood},
      where: '${Tables.colId} = ?',
      whereArgs: [photoId],
    );
  }

  /// 更新编辑后的照片信息（非破坏性编辑保存）
  Future<int> updateEdit({
    required String id,
    required String filePath,
    required String? originalPath,
    required TransformParams? transform,
    required PostProcess? postProcess,
  }) {
    final values = <String, Object?>{
      Tables.colFilePath: filePath,
      Tables.colOriginalPath: originalPath,
    };
    if (transform != null) {
      values[Tables.colTransform] = jsonEncode(transform.toJson());
    } else {
      values[Tables.colTransform] = null;
    }
    if (postProcess != null) {
      values[Tables.colPostProcess] = jsonEncode(GalleryItemRecord._postProcessToJson(postProcess));
    } else {
      values[Tables.colPostProcess] = null;
    }
    return _db.update(
      Tables.galleryItems,
      values,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
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

  /// 按拍摄目标分类统计照片数（通过 scene_id JOIN scenes.related_category）
  Future<Map<String, int>> countByCategory() async {
    final rows = await _db.rawQuery('''
      SELECT s.related_category AS category, COUNT(*) AS cnt
      FROM gallery_items g
      LEFT JOIN scenes s ON g.scene_id = s.id
      WHERE s.related_category IS NOT NULL
      GROUP BY s.related_category
    ''');
    final result = <String, int>{};
    for (final row in rows) {
      final cat = row['category'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (cat != null) result[cat] = cnt;
    }
    return result;
  }

  /// 按模板 ID 统计照片数（用于分析用户常拍模板）
  /// 实现：参考 countByCategory()，按 template_id 分组
  Future<Map<String, int>> countByTemplate() async {
    final rows = await _db.rawQuery('''
      SELECT ${Tables.colTemplateId} AS tid, COUNT(*) AS cnt
      FROM ${Tables.galleryItems}
      WHERE ${Tables.colTemplateId} IS NOT NULL
      GROUP BY ${Tables.colTemplateId}
    ''');
    final result = <String, int>{};
    for (final row in rows) {
      final tid = row['tid'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (tid != null) result[tid] = cnt;
    }
    return result;
  }

  /// 按场景风格统计照片数（通过 scene_id JOIN scenes.style）
  /// 实现：参考 countByCategory()，按 scenes.style 分组
  Future<Map<String, int>> countByStyle() async {
    final rows = await _db.rawQuery('''
      SELECT s.style AS style, COUNT(*) AS cnt
      FROM gallery_items g
      LEFT JOIN scenes s ON g.scene_id = s.id
      WHERE s.style IS NOT NULL AND s.style != ''
      GROUP BY s.style
    ''');
    final result = <String, int>{};
    for (final row in rows) {
      final style = row['style'] as String?;
      final cnt = row['cnt'] as int? ?? 0;
      if (style != null) result[style] = cnt;
    }
    return result;
  }

  /// 获取最近拍摄的照片（最新在前，limit 控制数量）
  /// 实现：参考 getAll()，强制 DESC 排序与 limit
  Future<List<GalleryItemRecord>> getRecent({int limit = 10}) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: _notHidden,
      orderBy: '${Tables.colCreatedAt} DESC',
      limit: limit,
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 切换收藏标记（is_favorite 0↔1）
  Future<void> toggleFavorite(String id) async {
    final row = await _db.query(
      Tables.galleryItems,
      columns: [Tables.colGalleryItemIsFavorite],
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    final current = (row.isNotEmpty ? (row.first[Tables.colGalleryItemIsFavorite] as num?)?.toInt() : 0) ?? 0;
    await _db.update(
      Tables.galleryItems,
      {Tables.colGalleryItemIsFavorite: current == 1 ? 0 : 1},
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 显式设置收藏标记
  Future<void> setFavorite(String id, bool favorite) async {
    await _db.update(
      Tables.galleryItems,
      {Tables.colGalleryItemIsFavorite: favorite ? 1 : 0},
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有收藏照片（is_favorite=1，最新在前）
  Future<List<GalleryItemRecord>> getFavorites({int? limit}) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: '${Tables.colGalleryItemIsFavorite} = ? AND $_notHidden',
      whereArgs: [1],
      orderBy: '${Tables.colCreatedAt} DESC',
      limit: limit,
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 按拍摄目标分类筛选照片（JOIN scenes ON scene_id 筛选 related_category）
  /// 实现：参考 countByCategory() 的 JOIN 模式
  Future<List<GalleryItemRecord>> getByCategory(String category, {int? limit}) async {
    final rows = await _db.rawQuery('''
      SELECT g.* FROM ${Tables.galleryItems} g
      LEFT JOIN ${Tables.scenes} s ON g.${Tables.colSceneId} = s.${Tables.colId}
      WHERE s.${Tables.colRelatedCategory} = ?
        AND g.${Tables.colGalleryItemHidden} != 1
      ORDER BY g.${Tables.colCreatedAt} DESC
      ${limit != null ? 'LIMIT ?' : ''}
    ''', limit != null ? [category, limit] : [category]);
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 按模板 ID 筛选照片
  Future<List<GalleryItemRecord>> getByTemplate(String templateId, {int? limit}) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: '${Tables.colTemplateId} = ? AND $_notHidden',
      whereArgs: [templateId],
      orderBy: '${Tables.colCreatedAt} DESC',
      limit: limit,
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 按年份月份筛选照片（created_at 的 YYYY-MM，使用 localtime 与 monthlyCounts 对齐）
  Future<List<GalleryItemRecord>> getByMonth(int year, int month, {int? limit}) async {
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final rows = await _db.rawQuery('''
      SELECT * FROM ${Tables.galleryItems}
      WHERE strftime('%Y', ${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') = ?
        AND strftime('%m', ${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') = ?
        AND ${Tables.colGalleryItemHidden} != 1
      ORDER BY ${Tables.colCreatedAt} DESC
      ${limit != null ? 'LIMIT ?' : ''}
    ''', limit != null ? [yearStr, monthStr, limit] : [yearStr, monthStr]);
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 按某一天筛选照片（拍摄日记「查看更多」当日照片页使用，本地时区）
  Future<List<GalleryItemRecord>> getByDay(DateTime day) async {
    final dateStr =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final rows = await _db.rawQuery('''
      SELECT * FROM ${Tables.galleryItems}
      WHERE date(${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') = ?
        AND ${Tables.colGalleryItemHidden} != 1
      ORDER BY ${Tables.colCreatedAt} DESC
    ''', [dateStr]);
    return rows.map(GalleryItemRecord.fromRow).toList();
  }

  /// 按关键字搜索照片：多字段模糊匹配（场景/模板/心情），最新在前
  Future<List<GalleryItemRecord>> search(String query) async {
    final pattern = '%$query%';
    final rows = await _db.query(
      Tables.galleryItems,
      where: '( ${Tables.colSceneId} LIKE ? OR ${Tables.colTemplateId} LIKE ? OR ${Tables.colMood} LIKE ? ) AND $_notHidden',
      whereArgs: [pattern, pattern, pattern],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(GalleryItemRecord.fromRow).toList();
  }
}
