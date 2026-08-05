import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/growth_dao.dart';
import '../data/growth_models.dart';
import '../data/profile_mock_data.dart';
import 'profile_providers.dart';

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

/// 个人中心 UserProfile Provider
/// 聚合 GrowthDao（等级/XP）+ GalleryDao（作品数/收藏数）+ TemplatesDao（模板数）
/// 对照：lumira-app/src/pages/profile/index.vue 的 userProfile computed
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final profile = await ref.watch(profileDataProvider.future);
  final growth = await ref.watch(growthLevelProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  final photosCount = await galleryDao.count();
  final favorites = await galleryDao.getFavorites();
  final templatesCount = await templatesDao.count();

  final maxXp = growth.level * 500;

  return UserProfile(
    name: profile?.username ?? '如画用户',
    avatarSeed: profile?.avatarSeed ?? 'lumira-user-001',
    level: growth.level,
    levelName: growth.levelName,
    currentXp: growth.currentXp,
    maxXp: maxXp,
    photosCount: photosCount,
    templatesCount: templatesCount,
    collectionsCount: favorites.length,
  );
});

/// 下一等级名称（用于 _HeroCard 底部「升级至 XX」文案）
final nextLevelNameProvider = FutureProvider<String>((ref) async {
  final growth = await ref.watch(growthLevelProvider.future);
  return _levelName(growth.level + 1);
});
