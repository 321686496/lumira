import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import 'inspiration_content.dart';
import 'tutorial_models.dart';
import 'tutorial_recommendation_service.dart';

Future<String?> _topCategoryFromDao(GalleryDao dao) async {
  final counts = await dao.countByCategory();
  if (counts.isEmpty) return null;
  final entries = counts.entries.where((e) => e.value > 0).toList();
  if (entries.isEmpty) return null;
  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

/// 今日可拍：本地拍摄统计 + 当前时段排序内置场景/模板
final todayShootProvider = FutureProvider<List<TodayShootItem>>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  String? top;
  try {
    top = await _topCategoryFromDao(dao);
  } catch (_) {}
  return InspirationContent.pickTodayShoot(top, DateTime.now());
});

/// 拍摄小课堂：问卷偏好 + 近 30 天拍摄行为 + 已读状态 个性化推荐
final tutorialPicksProvider = FutureProvider<List<ShootingTutorial>>((ref) async {
  final questionnaireDao = await ref.watch(questionnaireDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final readDao = await ref.watch(tutorialReadDaoProvider.future);
  return TutorialRecommendationService(
    questionnaireDao: questionnaireDao,
    galleryDao: galleryDao,
    readDao: readDao,
  ).recommend();
});

/// 已读教程 id 集合
final tutorialReadIdsProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(tutorialReadDaoProvider.future);
  return dao.getReadIds();
});

/// 灵感图集：内置静态素材（无个性化、无网络）
final inspirationGalleryProvider = Provider<List<InspirationGalleryItem>>(
  (ref) => InspirationContent.galleryItems,
);