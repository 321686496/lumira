import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../templates/recommend/template_ranking.dart';
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

  // 个性化：读取兴趣画像，为模板目标 item 计算个人兴趣加成（失败静默回退为空）
  var interestByTemplateId = const <String, double>{};
  try {
    final interestsDao = await ref.watch(userInterestsDaoProvider.future);
    final all = await interestsDao.getAll();
    final portrait = <String, double>{
      for (final e in all.entries) e.key: e.value.score,
    };
    final templatesDao = await ref.watch(templatesDaoProvider.future);
    final ctx = RankingContext(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      portrait: portrait,
    );
    final map = <String, double>{};
    for (final it in InspirationContent.todayShootPool) {
      if (it.target != TodayShootTarget.template) continue;
      final t = await templatesDao.getById(it.targetId);
      if (t != null) {
        map[it.targetId] = TemplateRanking().interestFor(t, ctx);
      }
    }
    interestByTemplateId = map;
  } catch (_) {}

  return InspirationContent.pickTodayShoot(
    top,
    DateTime.now(),
    interestByTemplateId: interestByTemplateId,
  );
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