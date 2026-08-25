import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../features/profile/providers/growth_providers.dart';
import '../data/home_mock_data.dart';
import '../services/recommendation_service.dart';

/// 首页 Banner 推荐 Provider
///
/// 通过 [RecommendationService] 基于用户真实拍摄历史生成 5 条 banner。
/// FutureProvider 自动缓存，tab 切换不重新计算；
/// 拍摄完成保存到 gallery 后由 capture_page 调 `ref.invalidate` 触发刷新。
final bannerRecommendationProvider =
    FutureProvider<List<HomeBannerItem>>((ref) async {
  final service = RecommendationService(
    galleryDao: await ref.watch(galleryDaoProvider.future),
    scenesDao: await ref.watch(scenesDaoProvider.future),
    templatesDao: await ref.watch(templatesDaoProvider.future),
    kitsDao: await ref.watch(compositionKitsDaoProvider.future),
    growthDao: await ref.watch(growthDaoProvider.future),
    questionnaireDao: await ref.watch(questionnaireDaoProvider.future),
    usageDao: await ref.watch(usageDaoProvider.future),
    interestDao: await ref.watch(userInterestsDaoProvider.future),
  );
  return service.buildBanners();
});
