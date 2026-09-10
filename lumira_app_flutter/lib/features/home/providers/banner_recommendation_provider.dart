import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../features/profile/providers/growth_providers.dart';
import '../../invite/data/invite_repository.dart';
import '../../points/data/points_repository.dart';
import '../../templates/data/owned_templates_repository.dart';
import '../data/home_mock_data.dart';
import '../data/operation_banners.dart';
import '../data/operation_banners_repository.dart';
import '../services/recommendation_service.dart';

/// 首页 Banner 推荐 Provider
///
/// 通过 [RecommendationService] 基于用户真实拍摄历史生成 4 条 banner
/// （slot 0 运营位 + 3 个个性化位）。
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
  // 并行加载运营位所需条件与远端运营条目目录；
  // 两者各自容错（_tryLoad / operationBanners 三级兜底），不阻塞 Banner 主流程。
  // 远端目录必须注入 buildBanners，否则 slot 0 停留静态 kOperationBanners，
  // 后台改动无法在首页生效（曾因漏传导致死代码）。
  final results = await Future.wait([
    _loadOperationInputs(ref),
    _loadOperationBanners(ref),
  ]);
  final operationInputs = results[0] as OperationUserInputs;
  final operationBanners = results[1] as List<OperationBanner>;
  return service.buildBanners(
    operationInputs: operationInputs,
    operationBanners: operationBanners,
  );
});

/// 汇聚运营位条件所需的用户状态（远端；离线/失败降级为 null → 不出运营位）。
///
/// 三个来源并行拉取、各自容错：
/// - 是否已绑定邀请码：GET /invite/stats → myInviter
/// - 积分余额：GET /points/balance → balance
/// - 是否存在未解锁付费模板：GET /templates/prices + GET /templates/owned
Future<OperationUserInputs> _loadOperationInputs(Ref ref) async {
  final hasBoundInviter = _tryLoad(() async {
    final repo = await ref.watch(inviteRepositoryProvider.future);
    final stats = await repo.stats();
    return stats.myInviter != null;
  });
  final pointsBalance = _tryLoad(() async {
    final repo = await ref.watch(pointsRepositoryProvider.future);
    return (await repo.getBalance()).balance;
  });
  final hasLockedTemplate = _tryLoad(() async {
    final repo = await ref.watch(ownedTemplatesRepositoryProvider.future);
    final prices = await repo.listPrices();
    final owned = await repo.listOwned();
    return prices.prices.any((p) =>
        p.isActive &&
        p.priceCredits > 0 &&
        !owned.templateIds.contains(p.templateId));
  });

  return OperationUserInputs(
    hasBoundInviter: await hasBoundInviter,
    pointsBalance: await pointsBalance,
    hasLockedTemplate: await hasLockedTemplate,
  );
}

/// 运营条目三级兜底：远端（成功则写离线缓存）→ 本地缓存 → 静态 kOperationBanners。
/// 空列表 [] 视为合法下发状态（后台全部停用），不触发兜底。
Future<List<OperationBanner>> _loadOperationBanners(Ref ref) async {
  try {
    final repo = await ref.watch(operationBannersRepositoryProvider.future);
    final banners = await repo.list();
    try {
      final dao = await ref.watch(settingsDaoProvider.future);
      await dao.setOperationBannersCache(banners);
    } catch (_) {/* 缓存写入失败不影响本次渲染 */}
    return banners;
  } catch (_) {
    try {
      final dao = await ref.watch(settingsDaoProvider.future);
      final cached = await dao.getOperationBannersCache();
      if (cached != null) return cached;
    } catch (_) {/* 缓存读取失败走静态目录 */}
    return kOperationBanners;
  }
}

/// 容错加载：失败（离线/接口异常）返回 null，不阻塞 Banner 主流程。
Future<T?> _tryLoad<T>(Future<T> Function() loader) async {
  try {
    return await loader();
  } catch (_) {
    return null;
  }
}
