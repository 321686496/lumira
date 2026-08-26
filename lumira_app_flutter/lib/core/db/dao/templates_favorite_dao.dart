import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 模板收藏 DAO：独立关系表，模板 id 为主键，覆盖全来源（builtin/custom/remote）。
class TemplatesFavoriteDao {
  TemplatesFavoriteDao(this._db);

  final Database _db;

  Future<bool> isFavorite(String templateId) async {
    final rows = await _db.query(
      Tables.templateFavorites,
      columns: [Tables.colId],
      where: '${Tables.colId} = ?',
      whereArgs: [templateId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addFavorite(String templateId) async {
    await _db.insert(
      Tables.templateFavorites,
      {
        Tables.colId: templateId,
        Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String templateId) async {
    await _db.delete(
      Tables.templateFavorites,
      where: '${Tables.colId} = ?',
      whereArgs: [templateId],
    );
  }

  Future<bool> toggleFavorite(String templateId) async {
    if (await isFavorite(templateId)) {
      await removeFavorite(templateId);
      return false;
    }
    await addFavorite(templateId);
    return true;
  }

  Future<List<String>> getFavoriteIds() async {
    final rows = await _db.query(
      Tables.templateFavorites,
      columns: [Tables.colId],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map((r) => r[Tables.colId] as String).toList();
  }

  Future<int> countFavorites() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.templateFavorites}',
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}