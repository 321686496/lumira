import 'package:sqflite/sqflite.dart';

import '../../points/data/points_repository.dart';
import 'growth_xp_service.dart';

/// 无 ref 环境（main.dart / repository）构造 GrowthXpService，写台账 + 领取升级奖励。
Future<void> awardAndClaim({
  required Database db,
  required PointsRepository repo,
  required String source,
  required int amount,
  required String refId,
}) async {
  final svc = GrowthXpService(
    db,
    earnLevelReward: (level) => repo.earn(type: 'level_reward', refId: level),
  );
  await svc.award(source: source, amount: amount, refId: refId);
  await svc.claimLevelRewards();
}