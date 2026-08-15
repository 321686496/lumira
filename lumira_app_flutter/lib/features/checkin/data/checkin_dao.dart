import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';
import 'checkin_models.dart';

/// 探店打卡 DAO：管理 checkins 主表 + checkin_photos 关联表
class CheckinDao {
  CheckinDao(this._db);

  final Database _db;

  Future<String> insert(CheckinRecord record) async {
    await _db.insert(
      CheckinTable.name,
      record.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.id;
  }

  Future<void> update(CheckinRecord record) async {
    await _db.update(
      CheckinTable.name,
      record.toRow(),
      where: '${CheckinTable.colId} = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除足迹（手动级联删除照片关联）
  Future<void> delete(String id) async {
    await _db.delete(
      CheckinPhotoTable.name,
      where: '${CheckinPhotoTable.colCheckinId} = ?',
      whereArgs: [id],
    );
    await _db.delete(
      CheckinTable.name,
      where: '${CheckinTable.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<CheckinRecord?> getById(String id) async {
    final rows = await _db.query(
      CheckinTable.name,
      where: '${CheckinTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CheckinRecord.fromRow(rows.first);
  }

  /// 全部足迹，按打卡日期倒序
  Future<List<CheckinRecord>> getAll() async {
    final rows = await _db.query(
      CheckinTable.name,
      orderBy: '${CheckinTable.colVisitedAt} DESC',
    );
    return rows.map(CheckinRecord.fromRow).toList();
  }

  Future<int> countAll() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${CheckinTable.name}',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// 整体替换照片关联（事务内先删后插，position 按列表顺序 0..n-1）
  Future<void> replacePhotos(String checkinId, List<String> photoIds) async {
    await _db.transaction((txn) async {
      await txn.delete(
        CheckinPhotoTable.name,
        where: '${CheckinPhotoTable.colCheckinId} = ?',
        whereArgs: [checkinId],
      );
      for (var i = 0; i < photoIds.length; i++) {
        await txn.insert(
          CheckinPhotoTable.name,
          {
            CheckinPhotoTable.colCheckinId: checkinId,
            CheckinPhotoTable.colPhotoId: photoIds[i],
            CheckinPhotoTable.colPosition: i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// 足迹关联照片 id，按 position 升序
  Future<List<String>> getPhotoIds(String checkinId) async {
    final rows = await _db.query(
      CheckinPhotoTable.name,
      where: '${CheckinPhotoTable.colCheckinId} = ?',
      whereArgs: [checkinId],
      orderBy: '${CheckinPhotoTable.colPosition} ASC',
    );
    return rows
        .map((r) => r[CheckinPhotoTable.colPhotoId] as String)
        .toList();
  }

  /// 获取评分 ≥ 4 的足迹数
  Future<int> countHighRated() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${CheckinTable.name} WHERE ${CheckinTable.colRating} >= 4',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// 获取平均评分（四舍五入到 1 位小数）
  Future<double> avgRating() async {
    final rows = await _db.rawQuery(
      'SELECT AVG(${CheckinTable.colRating}) AS avg FROM ${CheckinTable.name} WHERE ${CheckinTable.colRating} > 0',
    );
    final val = rows.first['avg'];
    if (val == null) return 0.0;
    return (val as num).toDouble();
  }

  /// 获取当年新增足迹数
  Future<int> countThisYear() async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${CheckinTable.name} WHERE ${CheckinTable.colVisitedAt} >= ?',
      [yearStart],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// 获取所有分类（去重，非空）
  Future<List<String>> getAllCategories() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT ${CheckinTable.colCategory} FROM ${CheckinTable.name} '
      'WHERE ${CheckinTable.colCategory} IS NOT NULL AND ${CheckinTable.colCategory} != \'\'',
    );
    return rows
        .map((r) => r[CheckinTable.colCategory] as String)
        .toList();
  }

  /// 按分类筛选足迹
  Future<List<CheckinRecord>> getByCategory(String category) async {
    final rows = await _db.query(
      CheckinTable.name,
      where: '${CheckinTable.colCategory} = ?',
      whereArgs: [category],
      orderBy: '${CheckinTable.colVisitedAt} DESC',
    );
    return rows.map(CheckinRecord.fromRow).toList();
  }

  /// 按评分排序（高分在前，同分按时间倒序）
  Future<List<CheckinRecord>> getByRatingDesc() async {
    final rows = await _db.query(
      CheckinTable.name,
      orderBy: '${CheckinTable.colRating} DESC, ${CheckinTable.colVisitedAt} DESC',
    );
    return rows.map(CheckinRecord.fromRow).toList();
  }
}
