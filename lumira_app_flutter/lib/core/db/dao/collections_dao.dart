import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 精选集类型。
/// - manual：用户手动创建，照片关联存储在 collection_photos 表
/// - auto*：智能派生，由 CollectionService 同步生成，不写 collection_photos 表，
///   详情页通过 [CollectionsDao.getPhotoIdsForAuto] 动态查询 gallery_items
enum CollectionType {
  manual,
  autoRecent,
  autoMonthly,
  autoScene,
  autoCategory,
  autoFavorite;

  /// 持久化用 name（与 enum 名一致，如 'manual' / 'auto_recent'）
  String get value => name;

  static CollectionType fromString(String s) =>
      values.firstWhere((t) => t.name == s);
}

/// 精选集主表记录
class CollectionRecord {
  final String id;
  final String name;
  final String? description;
  final String? coverPhotoId;
  final CollectionType type;
  final Map<String, dynamic>? sourceMeta;
  final int photoCount;
  final int createdAt;
  final int updatedAt;

  CollectionRecord({
    required this.id,
    required this.name,
    this.description,
    this.coverPhotoId,
    required this.type,
    this.sourceMeta,
    this.photoCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 sourceMeta 取指定键的值
  String? metaString(String key) => sourceMeta?[key]?.toString();

  Map<String, Object?> toRow() {
    return {
      Tables.colCollectionId: id,
      Tables.colCollectionName: name,
      Tables.colCollectionDescription: description,
      Tables.colCollectionCoverPhotoId: coverPhotoId,
      Tables.colCollectionType: type.value,
      Tables.colCollectionSourceMeta:
          sourceMeta != null ? jsonEncode(sourceMeta) : null,
      Tables.colCollectionPhotoCount: photoCount,
      Tables.colCollectionCreatedAt: createdAt,
      Tables.colCollectionUpdatedAt: updatedAt,
    };
  }

  static CollectionRecord fromRow(Map<String, Object?> row) {
    return CollectionRecord(
      id: row[Tables.colCollectionId] as String,
      name: row[Tables.colCollectionName] as String,
      description: row[Tables.colCollectionDescription] as String?,
      coverPhotoId: row[Tables.colCollectionCoverPhotoId] as String?,
      type: CollectionType.fromString(row[Tables.colCollectionType] as String),
      sourceMeta: _decodeJsonMap(row[Tables.colCollectionSourceMeta]),
      photoCount: (row[Tables.colCollectionPhotoCount] as num?)?.toInt() ?? 0,
      createdAt: (row[Tables.colCollectionCreatedAt] as num).toInt(),
      updatedAt: (row[Tables.colCollectionUpdatedAt] as num).toInt(),
    );
  }

  static Map<String, dynamic>? _decodeJsonMap(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return null;
  }
}

/// 精选集-照片关联表记录（仅 manual 类型使用）
class CollectionPhotoRecord {
  final String collectionId;
  final String photoId;
  final int sortOrder;
  final int addedAt;

  CollectionPhotoRecord({
    required this.collectionId,
    required this.photoId,
    required this.sortOrder,
    required this.addedAt,
  });

  static CollectionPhotoRecord fromRow(Map<String, Object?> row) {
    return CollectionPhotoRecord(
      collectionId: row[Tables.colCollectionPhotoCollectionId] as String,
      photoId: row[Tables.colCollectionPhotoPhotoId] as String,
      sortOrder: (row[Tables.colCollectionPhotoSortOrder] as num).toInt(),
      addedAt: (row[Tables.colCollectionPhotoAddedAt] as num).toInt(),
    );
  }
}

/// 精选集 DAO：管理 collections 主表 + collection_photos 关联表。
/// auto 类型派生查询直接读 gallery_items，不经过 collection_photos。
class CollectionsDao {
  CollectionsDao(this._db);

  final Database _db;

  // === 主表 CRUD ===

  Future<List<CollectionRecord>> getAll() async {
    final rows = await _db.query(
      Tables.tableCollections,
      orderBy: '${Tables.colCollectionUpdatedAt} DESC',
    );
    return rows.map(CollectionRecord.fromRow).toList();
  }

  Future<List<CollectionRecord>> getByType(CollectionType type) async {
    final rows = await _db.query(
      Tables.tableCollections,
      where: '${Tables.colCollectionType} = ?',
      whereArgs: [type.value],
      orderBy: '${Tables.colCollectionUpdatedAt} DESC',
    );
    return rows.map(CollectionRecord.fromRow).toList();
  }

  Future<CollectionRecord?> getById(String id) async {
    final rows = await _db.query(
      Tables.tableCollections,
      where: '${Tables.colCollectionId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CollectionRecord.fromRow(rows.first);
  }

  /// 插入记录，返回 id
  Future<String> insert(CollectionRecord record) async {
    await _db.insert(
      Tables.tableCollections,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.id;
  }

  Future<void> update(CollectionRecord record) async {
    await _db.update(
      Tables.tableCollections,
      record.toRow(),
      where: '${Tables.colCollectionId} = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除精选集，同时级联删除 collection_photos 关联记录
  /// （sqflite 默认未开启 PRAGMA foreign_keys=ON，需手动级联）
  Future<void> delete(String id) async {
    await _db.delete(
      Tables.tableCollectionPhotos,
      where: '${Tables.colCollectionPhotoCollectionId} = ?',
      whereArgs: [id],
    );
    await _db.delete(
      Tables.tableCollections,
      where: '${Tables.colCollectionId} = ?',
      whereArgs: [id],
    );
  }

  // === 关联表（仅 manual 类型用） ===

  /// 获取精选集的照片关联列表（按 sort_order ASC）
  Future<List<CollectionPhotoRecord>> getPhotos(String collectionId) async {
    final rows = await _db.query(
      Tables.tableCollectionPhotos,
      where: '${Tables.colCollectionPhotoCollectionId} = ?',
      whereArgs: [collectionId],
      orderBy: '${Tables.colCollectionPhotoSortOrder} ASC',
    );
    return rows.map(CollectionPhotoRecord.fromRow).toList();
  }

  /// 添加照片到精选集（sort_order 取当前最大值 +1）
  Future<void> addPhoto(String collectionId, String photoId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrder = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT MAX(${Tables.colCollectionPhotoSortOrder}) AS m '
      'FROM ${Tables.tableCollectionPhotos} '
      'WHERE ${Tables.colCollectionPhotoCollectionId} = ?',
      [collectionId],
    )) ?? -1;
    await _db.insert(
      Tables.tableCollectionPhotos,
      {
        Tables.colCollectionPhotoCollectionId: collectionId,
        Tables.colCollectionPhotoPhotoId: photoId,
        Tables.colCollectionPhotoSortOrder: maxOrder + 1,
        Tables.colCollectionPhotoAddedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removePhoto(String collectionId, String photoId) async {
    await _db.delete(
      Tables.tableCollectionPhotos,
      where:
          '${Tables.colCollectionPhotoCollectionId} = ? AND ${Tables.colCollectionPhotoPhotoId} = ?',
      whereArgs: [collectionId, photoId],
    );
  }

  /// 按 photoIds 顺序重新分配 sort_order（0..n-1）
  Future<void> reorderPhotos(String collectionId, List<String> photoIds) async {
    for (var i = 0; i < photoIds.length; i++) {
      await _db.update(
        Tables.tableCollectionPhotos,
        {Tables.colCollectionPhotoSortOrder: i},
        where:
            '${Tables.colCollectionPhotoCollectionId} = ? AND ${Tables.colCollectionPhotoPhotoId} = ?',
        whereArgs: [collectionId, photoIds[i]],
      );
    }
  }

  Future<void> clearPhotos(String collectionId) async {
    await _db.delete(
      Tables.tableCollectionPhotos,
      where: '${Tables.colCollectionPhotoCollectionId} = ?',
      whereArgs: [collectionId],
    );
  }

  Future<int> countPhotos(String collectionId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.tableCollectionPhotos} '
      'WHERE ${Tables.colCollectionPhotoCollectionId} = ?',
      [collectionId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // === 派生查询（auto 类型用，不读 collection_photos 表） ===
  // 返回 photoId 列表，由 CollectionService 调 GalleryDao 取详情

  /// 按 collection.type 分支动态查询 gallery_items 的 photoId 列表。
  /// manual 类型不应调用此方法（走 [getPhotos]）。
  Future<List<String>> getPhotoIdsForAuto(
    CollectionRecord collection, {
    int limit = 9,
  }) async {
    switch (collection.type) {
      case CollectionType.autoRecent:
        return _queryIds(
          'SELECT ${Tables.colId} FROM ${Tables.galleryItems} '
          'ORDER BY ${Tables.colCreatedAt} DESC LIMIT ?',
          [limit],
        );
      case CollectionType.autoMonthly:
        final year = collection.metaString('year');
        final month = collection.metaString('month');
        if (year == null || month == null) return <String>[];
        return _queryIds(
          'SELECT ${Tables.colId} FROM ${Tables.galleryItems} '
          "WHERE strftime('%Y', ${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') = ? "
          "AND strftime('%m', ${Tables.colCreatedAt} / 1000, 'unixepoch', 'localtime') = ? "
          'ORDER BY ${Tables.colCreatedAt} DESC LIMIT ?',
          [year, month.padLeft(2, '0'), limit],
        );
      case CollectionType.autoScene:
        final sceneId = collection.metaString('sceneId');
        if (sceneId == null) return <String>[];
        return _queryIds(
          'SELECT ${Tables.colId} FROM ${Tables.galleryItems} '
          'WHERE ${Tables.colSceneId} = ? '
          'ORDER BY ${Tables.colCreatedAt} DESC LIMIT ?',
          [sceneId, limit],
        );
      case CollectionType.autoCategory:
        final category = collection.metaString('category');
        if (category == null) return <String>[];
        return _queryIds(
          'SELECT g.${Tables.colId} FROM ${Tables.galleryItems} g '
          'LEFT JOIN ${Tables.scenes} s ON g.${Tables.colSceneId} = s.${Tables.colId} '
          'WHERE s.${Tables.colRelatedCategory} = ? '
          'ORDER BY g.${Tables.colCreatedAt} DESC LIMIT ?',
          [category, limit],
        );
      case CollectionType.autoFavorite:
        return _queryIds(
          'SELECT ${Tables.colId} FROM ${Tables.galleryItems} '
          'WHERE ${Tables.colGalleryItemIsFavorite} = 1 '
          'ORDER BY ${Tables.colCreatedAt} DESC LIMIT ?',
          [limit],
        );
      case CollectionType.manual:
        throw ArgumentError(
          'manual 类型精选集应使用 getPhotos()，不应调用 getPhotoIdsForAuto()',
        );
    }
  }

  Future<List<String>> _queryIds(String sql, List<Object?> args) async {
    final rows = await _db.rawQuery(sql, args);
    return rows.map((r) => r[Tables.colId] as String).toList();
  }
}
