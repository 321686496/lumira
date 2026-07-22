import 'package:sqflite/sqflite.dart';
import '../../../core/db/tables.dart';
import 'challenge_models.dart';

class ChallengeDao {
  final Database _db;
  ChallengeDao(this._db);

  Future<void> insert(ChallengeHistoryRecord record) async {
    await _db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: record.id,
      ChallengeHistoryTable.colDate: record.date,
      ChallengeHistoryTable.colChallengeId: record.challengeId,
      ChallengeHistoryTable.colCategory: record.category,
      ChallengeHistoryTable.colTitle: record.title,
      ChallengeHistoryTable.colRewardXp: record.rewardXP,
      ChallengeHistoryTable.colStatus: record.status.name,
      ChallengeHistoryTable.colSelectedAt: record.selectedAt,
      ChallengeHistoryTable.colCompletedAt: record.completedAt,
      ChallengeHistoryTable.colSkippedAt: record.skippedAt,
      ChallengeHistoryTable.colIsDaily: record.isDaily ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String id, ChallengeStatus status, {int? timestamp}) async {
    final map = <String, Object?>{ChallengeHistoryTable.colStatus: status.name};
    if (status == ChallengeStatus.done && timestamp != null) {
      map[ChallengeHistoryTable.colCompletedAt] = timestamp;
    } else if (status == ChallengeStatus.pending && timestamp != null) {
      map[ChallengeHistoryTable.colSkippedAt] = timestamp;
    }
    await _db.update(ChallengeHistoryTable.name, map,
        where: '${ChallengeHistoryTable.colId} = ?', whereArgs: [id]);
  }

  Future<ChallengeHistoryRecord?> getDailyByDate(String date) async {
    final rows = await _db.query(ChallengeHistoryTable.name,
        where: '${ChallengeHistoryTable.colDate} = ? AND ${ChallengeHistoryTable.colIsDaily} = 1',
        whereArgs: [date], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  Future<List<ChallengeHistoryRecord>> getWeeklyHistory(String startDate, String endDate) async {
    final rows = await _db.query(ChallengeHistoryTable.name,
        where: '${ChallengeHistoryTable.colDate} >= ? AND ${ChallengeHistoryTable.colDate} <= ?',
        whereArgs: [startDate, endDate],
        orderBy: '${ChallengeHistoryTable.colDate} ASC');
    return rows.map(_rowToRecord).toList();
  }

  Future<int> countCompleted() async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${ChallengeHistoryTable.name} WHERE ${ChallengeHistoryTable.colStatus} = ?',
        ['done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> countByCategory(String category) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${ChallengeHistoryTable.name} WHERE ${ChallengeHistoryTable.colCategory} = ? AND ${ChallengeHistoryTable.colStatus} = ?',
        [category, 'done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> countDistinctCompletedCategories() async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(DISTINCT ${ChallengeHistoryTable.colCategory}) as cnt FROM ${ChallengeHistoryTable.name} WHERE ${ChallengeHistoryTable.colStatus} = ?',
        ['done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  ChallengeHistoryRecord _rowToRecord(Map<String, Object?> row) {
    return ChallengeHistoryRecord(
      id: row[ChallengeHistoryTable.colId] as String,
      date: row[ChallengeHistoryTable.colDate] as String,
      challengeId: row[ChallengeHistoryTable.colChallengeId] as String,
      category: row[ChallengeHistoryTable.colCategory] as String,
      title: row[ChallengeHistoryTable.colTitle] as String,
      rewardXP: row[ChallengeHistoryTable.colRewardXp] as int,
      status: ChallengeStatus.values.firstWhere((e) => e.name == row[ChallengeHistoryTable.colStatus]),
      selectedAt: row[ChallengeHistoryTable.colSelectedAt] as int,
      completedAt: row[ChallengeHistoryTable.colCompletedAt] as int?,
      skippedAt: row[ChallengeHistoryTable.colSkippedAt] as int?,
      isDaily: (row[ChallengeHistoryTable.colIsDaily] as int) == 1,
    );
  }
}
