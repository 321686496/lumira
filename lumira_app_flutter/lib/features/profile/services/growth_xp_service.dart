import 'package:sqflite/sqflite.dart';

import '../../../core/db/dao/growth_dao.dart';
import '../../../core/db/tables.dart';
import '../../points/data/points_models.dart';
import '../data/growth_models.dart';

/// 经验台账写入 + 升级积分领取服务。
/// 各行为 Hook 在完成对应事件后调用 [award]；随后调用 [claimLevelRewards]。
class GrowthXpService {
  GrowthXpService(this.db, {required this.earnLevelReward});

  final Database db;
  final Future<PointEarnResult> Function(String level) earnLevelReward;

  /// 写一条经验台账（幂等）。source: 'shoot_daily'|'challenge'|'course'|'share'。
  /// 返回该记录是否首次写入（true=新增，false=已存在忽略）。
  Future<bool> award({
    required String source,
    required int amount,
    required String refId,
  }) async {
    if (amount <= 0 || refId.isEmpty) return false;
    final count = await db.insert(
      XpEventsTable.name,
      {
        'id': '$source:$refId',
        XpEventsTable.colSource: source,
        XpEventsTable.colAmount: amount,
        XpEventsTable.colRefId: refId,
        XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return count > 0;
  }

  /// 领取 (claimedLevel, currentLevel] 内所有存在奖励的等级。幂等：
  /// 已领取的跳过；网络失败即停（保留未领取，下次再试）。返回本次新发放的等级数。
  Future<int> claimLevelRewards() async {
    final dao = GrowthDao(db);
    final xp = await dao.getTotalXP();
    final level = levelForXp(xp);

    // 读当前已领取到哪一级
    final rows = await db.query(
      Tables.userProgress,
      columns: [Tables.colXpRewardClaimedLevel],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
      limit: 1,
    );
    final claimed = rows.isEmpty
        ? 0
        : ((rows.first[Tables.colXpRewardClaimedLevel] as num?)?.toInt() ?? 0);

    var newlyGranted = 0;
    var nextClaimed = claimed;
    for (var lv = claimed + 1; lv <= level; lv++) {
      final reward = levelReward(lv);
      if (reward == null) continue; // 该级无奖励，仍然推进但不发奖
      try {
        final result = await earnLevelReward('$lv');
        // 后端幂等：granted 或已 granted 都视为已领取
        nextClaimed = lv;
        if (result.granted) newlyGranted++;
      } catch (_) {
        // 离线/网络异常：停在此级，保留下次重试（不推进 nextClaimed）
        break;
      }
    }

    if (nextClaimed > claimed) {
      await db.rawUpdate('''
        UPDATE ${Tables.userProgress}
        SET ${Tables.colXpRewardClaimedLevel} = ?
        WHERE ${Tables.colId} = 1
      ''', [nextClaimed]);
    }
    return newlyGranted;
  }
}