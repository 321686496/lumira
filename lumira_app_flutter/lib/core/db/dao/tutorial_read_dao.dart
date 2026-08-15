import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 小教程已读记录 DAO（tutorial_reads 表，v23）
class TutorialReadDao {
  TutorialReadDao(this._db);

  final Database _db;

  /// 所有已读教程 id
  Future<Set<String>> getReadIds() async {
    final rows = await _db.query(Tables.tutorialReads);
    return rows.map((r) => r[Tables.colId] as String).toSet();
  }

  /// 标记已读（幂等，重复标记自动覆盖）
  Future<void> markRead(String tutorialId) async {
    await _db.insert(
      Tables.tutorialReads,
      {
        Tables.colId: tutorialId,
        Tables.colTutorialReadAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 取消已读（预留，供测试/重置）
  Future<void> markUnread(String tutorialId) async {
    await _db.delete(
      Tables.tutorialReads,
      where: '${Tables.colId} = ?',
      whereArgs: [tutorialId],
    );
  }
}