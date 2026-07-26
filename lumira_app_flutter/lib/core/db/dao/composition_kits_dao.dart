import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/profile/data/composition_kit_models.dart';

/// 组合套件 DAO（CRUD + usage 计数）
class CompositionKitsDao {
  CompositionKitsDao(this._db);

  final Database _db;

  /// 获取所有套件，按 created_at DESC（最新在前）
  Future<List<CompositionKit>> getAll() async {
    final rows = await _db.query(
      Tables.compositionKits,
      orderBy: 'created_at DESC',
    );
    return rows.map(CompositionKit.fromRow).toList();
  }

  /// 按 ID 查询，未找到返回 null
  Future<CompositionKit?> getById(String id) async {
    final rows = await _db.query(
      Tables.compositionKits,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CompositionKit.fromRow(rows.first);
  }

  /// 插入套件，返回插入的 ID
  Future<String> insert(CompositionKit kit) async {
    await _db.insert(
      Tables.compositionKits,
      kit.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return kit.id;
  }

  /// 更新套件（按 id）
  Future<void> update(CompositionKit kit) async {
    await _db.update(
      Tables.compositionKits,
      kit.toRow(),
      where: 'id = ?',
      whereArgs: [kit.id],
    );
  }

  /// 删除套件，返回受影响行数
  Future<int> delete(String id) async {
    return _db.delete(
      Tables.compositionKits,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 使用次数 +1 并更新 last_used_at 为当前时间
  Future<void> incrementUsage(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE ${Tables.compositionKits} SET usage_count = usage_count + 1, last_used_at = ? WHERE id = ?',
      [now, id],
    );
  }

  /// 总数
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM ${Tables.compositionKits}');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
