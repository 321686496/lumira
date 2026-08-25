import 'package:sqflite/sqflite.dart';
import '../tables.dart';

/// 用户兴趣画像记录（scope=category|major_style|style，key=对应维度）
class UserInterest {
  final String scope;
  final String key;
  final double score;
  final int lastSignalAt;
  const UserInterest({
    required this.scope,
    required this.key,
    required this.score,
    required this.lastSignalAt,
  });
}

/// 用户兴趣画像 DAO（增量读写，DB 全表仅百余行量级）
class InterestDao {
  final Database _db;
  InterestDao(this._db);

  /// 读单个维度键；无记录返回 null
  Future<UserInterest?> read(String scope, String key) async {
    final rows = await _db.query(
      UserInterestsTable.name,
      where: '${UserInterestsTable.colScope} = ? AND ${UserInterestsTable.colKey} = ?',
      whereArgs: [scope, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return UserInterest(
      scope: r[UserInterestsTable.colScope] as String,
      key: r[UserInterestsTable.colKey] as String,
      score: (r[UserInterestsTable.colScore] as num).toDouble(),
      lastSignalAt: (r[UserInterestsTable.colLastSignalAt] as num).toInt(),
    );
  }

  /// 读全量画像：'{scope}:{key}' -> 记录
  Future<Map<String, UserInterest>> getAll() async {
    final rows = await _db.query(UserInterestsTable.name);
    return {
      for (final r in rows)
        '${r[UserInterestsTable.colScope]}:${r[UserInterestsTable.colKey]}': UserInterest(
          scope: r[UserInterestsTable.colScope] as String,
          key: r[UserInterestsTable.colKey] as String,
          score: (r[UserInterestsTable.colScore] as num).toDouble(),
          lastSignalAt: (r[UserInterestsTable.colLastSignalAt] as num).toInt(),
        ),
    };
  }

  /// 覆盖写某维度键（调用方已完成时间衰减+加权）
  Future<void> upsert({
    required String scope,
    required String key,
    required double score,
    required int at,
  }) async {
    await _db.insert(
      UserInterestsTable.name,
      {
        UserInterestsTable.colScope: scope,
        UserInterestsTable.colKey: key,
        UserInterestsTable.colScore: score,
        UserInterestsTable.colLastSignalAt: at,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}