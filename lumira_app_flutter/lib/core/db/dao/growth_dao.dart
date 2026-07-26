import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/profile/data/growth_models.dart';

/// 成长中心只读 DAO
/// 聚合 user_progress / challenge_history / gallery_items / academy_course_progress 表
class GrowthDao {
  GrowthDao(this._db);

  final Database _db;

  /// 获取总 XP。
  /// 优先用 user_progress.xp；若为 0 则降级到 challenge_history.reward_xp 求和。
  Future<int> getTotalXP() async {
    final rows = await _db.query(Tables.userProgress, where: '${Tables.colId} = ?', whereArgs: [1]);
    if (rows.isNotEmpty) {
      final xp = (rows.first[Tables.colXp] as num?)?.toInt() ?? 0;
      if (xp > 0) return xp;
    }
    // 降级：challenge_history 求和
    final sumRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${ChallengeHistoryTable.colRewardXp}), 0) AS s FROM ${ChallengeHistoryTable.name} WHERE ${ChallengeHistoryTable.colStatus} = ?',
      ['completed'],
    );
    return Sqflite.firstIntValue(sumRows) ?? 0;
  }

  /// 等级 = XP / 500 + 1
  Future<int> getLevel() async {
    final xp = await getTotalXP();
    return xp ~/ 500 + 1;
  }

  /// 获取成就墙（6 项）。
  /// 优先从 user_progress.achievements_json 反序列化；无记录时返回 6 项占位。
  Future<List<AchievementRecord>> getAchievements() async {
    final rows = await _db.query(Tables.userProgress, where: '${Tables.colId} = ?', whereArgs: [1]);
    if (rows.isEmpty) return kPlaceholderAchievements;
    final raw = rows.first[Tables.colAchievementsJson] as String?;
    if (raw == null || raw.isEmpty || raw == '[]') return kPlaceholderAchievements;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      // 反序列化每条成就，与占位合并（占位提供 name/description/iconKey）
      final unlockedMap = <String, int>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final id = m['id'] as String?;
        final ts = m['unlockedAt'] as int?;
        if (id != null) unlockedMap[id] = ts ?? 0;
      }
      return kPlaceholderAchievements.map((a) {
        if (unlockedMap.containsKey(a.id)) {
          return AchievementRecord(
            id: a.id,
            name: a.name,
            description: a.description,
            iconKey: a.iconKey,
            unlocked: true,
            unlockedAt: unlockedMap[a.id],
          );
        }
        return a;
      }).toList();
    } catch (_) {
      return kPlaceholderAchievements;
    }
  }

  /// 获取成长轨迹（最近 4 条，时间倒序）。
  /// 聚合 challenge_history.completed_at + gallery_items.created_at（milestone）
  /// 简化：仅聚合这两条流；academy_course_progress 完成事件在 M6 任务接入
  Future<List<GrowthTrajectoryRecord>> getGrowthTrajectory() async {
    final challengeRows = await _db.rawQuery('''
      SELECT ${ChallengeHistoryTable.colId} AS eid,
             ${ChallengeHistoryTable.colTitle} AS title,
             ${ChallengeHistoryTable.colCompletedAt} AS ts
      FROM ${ChallengeHistoryTable.name}
      WHERE ${ChallengeHistoryTable.colStatus} = ? AND ${ChallengeHistoryTable.colCompletedAt} IS NOT NULL
    ''', ['completed']);

    final galleryRows = await _db.rawQuery('''
      SELECT ${Tables.colId} AS eid, ${Tables.colCreatedAt} AS ts
      FROM ${Tables.galleryItems}
      ORDER BY ${Tables.colCreatedAt} ASC
    ''');

    final events = <GrowthTrajectoryRecord>[];
    for (final r in challengeRows) {
      events.add(GrowthTrajectoryRecord(
        eventId: r['eid'] as String,
        type: 'challenge',
        title: r['title'] as String? ?? '挑战完成',
        timestamp: (r['ts'] as num).toInt(),
      ));
    }
    // gallery 取首张作为里程碑
    if (galleryRows.isNotEmpty) {
      final first = galleryRows.first;
      events.add(GrowthTrajectoryRecord(
        eventId: first['eid'] as String,
        type: 'milestone',
        title: '首次拍摄',
        timestamp: (first['ts'] as num).toInt(),
      ));
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(4).toList();
  }

  /// 获取每日活跃度（用于 112 格热力图）。
  /// 聚合 challenge_history.completed_at + gallery_items.created_at 按日期 GROUP BY。
  Future<Map<String, int>> getDailyActivity() async {
    final rows = await _db.rawQuery('''
      SELECT date(${ChallengeHistoryTable.colCompletedAt} / 1000, 'unixepoch') AS d, COUNT(*) AS c
      FROM ${ChallengeHistoryTable.name}
      WHERE ${ChallengeHistoryTable.colStatus} = ? AND ${ChallengeHistoryTable.colCompletedAt} IS NOT NULL
      GROUP BY d
      UNION ALL
      SELECT date(${Tables.colCreatedAt} / 1000, 'unixepoch') AS d, COUNT(*) AS c
      FROM ${Tables.galleryItems}
      GROUP BY d
    ''', ['completed']);
    final result = <String, int>{};
    for (final r in rows) {
      final d = r['d'] as String?;
      final c = (r['c'] as num?)?.toInt() ?? 0;
      if (d != null) result[d] = (result[d] ?? 0) + c;
    }
    return result;
  }
}
