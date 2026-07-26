import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/growth_dao.dart';
import '../data/growth_models.dart';

final growthDaoProvider = FutureProvider<GrowthDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return GrowthDao(db);
});

final growthLevelProvider = FutureProvider<GrowthSummary>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  final xp = await dao.getTotalXP();
  final level = await dao.getLevel();
  final xpToNext = ((level) * 500) - xp; // 当前等级剩余 XP
  return GrowthSummary(
    level: level,
    currentXp: xp,
    xpToNextLevel: xpToNext < 0 ? 0 : xpToNext,
    levelName: _levelName(level),
  );
});

final growthAchievementsProvider = FutureProvider<List<AchievementRecord>>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  return dao.getAchievements();
});

final growthTrajectoryProvider = FutureProvider<List<GrowthTrajectoryRecord>>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  return dao.getGrowthTrajectory();
});

final growthHeatmapProvider = FutureProvider<Map<String, int>>((ref) async {
  final dao = await ref.watch(growthDaoProvider.future);
  return dao.getDailyActivity();
});

String _levelName(int level) {
  if (level >= 10) return '大师';
  if (level >= 5) return '专家';
  if (level >= 2) return '进阶';
  return '新手';
}
