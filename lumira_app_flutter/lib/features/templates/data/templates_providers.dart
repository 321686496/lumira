// lib/features/templates/data/templates_providers.dart
//
// 模板页真实数据 Provider：
// - userPreferenceProvider：累计作品数 + 最常用分类及占比（来自 GalleryDao + TemplatesDao）
// - freeBuiltinTemplatesProvider：免费内置模板列表（缓存，避免 FutureBuilder 反复加载）
//
// 对照：lumira-app/src/composables/useRecommendation.ts 中的 userPreference computed

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../recommend/template_ranking.dart';
import '../recommend/daily_recommendator.dart';
import '../data/templates_mock_data.dart';
import '../data/templates_browse_mock_data.dart';
import 'remote_templates_providers.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/template_grid.dart';

/// 各模板在本机已拍摄的照片数（模板卡片「已拍 N 张」角标）。
///
/// 与「全部模板页 / 我的收藏页」同源（GalleryDao.countByTemplate），
/// 供发现页 Hero 推荐卡与「更多模板」卡共用，保证四处卡片角标口径一致。
final templateUsageCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  return galleryDao.countByTemplate();
});

/// 用户拍摄偏好 Provider
/// 实现：从 GalleryDao 统计照片总数和按模板分类的拍摄数，计算最常用分类及其占比。
/// 对照 Vue 版 useRecommendation.ts line 37-54 (topCategory) + line 173-186 (userPreference)。
final userPreferenceProvider = FutureProvider<UserPreference>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  final total = await galleryDao.count();
  if (total == 0) {
    return const UserPreference(
      totalPhotos: 0,
      topCategory: '',
      topCategoryPercentage: 0,
    );
  }

  // 按模板 ID 统计照片数，再聚合到模板分类维度
  final templateCounts = await galleryDao.countByTemplate();
  final categoryCounts = <String, int>{};
  for (final entry in templateCounts.entries) {
    final tpl = await templatesDao.getById(entry.key);
    if (tpl != null && tpl.category.isNotEmpty) {
      categoryCounts[tpl.category] =
          (categoryCounts[tpl.category] ?? 0) + entry.value;
    }
  }

  // 找出最常用分类
  String topCategory = '';
  int maxCount = 0;
  categoryCounts.forEach((cat, count) {
    if (count > maxCount) {
      maxCount = count;
      topCategory = cat;
    }
  });

  final rawPercent = total > 0 ? (maxCount * 100 / total).round() : 0;
  final percentage = rawPercent < 0
      ? 0
      : (rawPercent > 100 ? 100 : rawPercent);

  return UserPreference(
    totalPhotos: total,
    topCategory: topCategory,
    topCategoryPercentage: percentage,
  );
});

/// 免费内置模板列表 Provider（"更多模板" section 数据源备选）
///
/// 用 FutureProvider 缓存查询结果，避免 FutureBuilder 在每次 build 时
/// 重新调用 dao.getBuiltin(price: 0) 导致反复进入 loading 状态。
final freeBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  return dao.getBuiltin(price: 0);
});

/// 「更多模板」栏目数据源
///
/// 取免费内置模板，展示逻辑为：前 3 个为最热门模板（按 useShoot*2 + openDetail
/// 热度排序），后 3 个为最新上架的模板（按 updatedAt 降序）。热门与最新部分重叠
/// 时按模板去重，保证实际展示不超过展示位所需的模板数。
final hotAndNewTemplatesProvider = FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final usageDao = await ref.watch(usageDaoProvider.future);

  final all = await dao.getBuiltin(price: 0);
  if (all.isEmpty) return const [];
  if (all.length <= 6) return all;

  // 热度：useShoot*2 + openDetail，降序取前 3
  final counts = await usageDao.countMap('template', all.map((t) => t.id).toList());
  final hot = [...all]..sort((a, b) {
        final pa = (counts[a.id]?.useShoot ?? 0) * 2 + (counts[a.id]?.openDetail ?? 0);
        final pb = (counts[b.id]?.useShoot ?? 0) * 2 + (counts[b.id]?.openDetail ?? 0);
        return pb.compareTo(pa);
      });

  // 最新：updatedAt 降序，跳过已入选热门的前 3 个，凑满 3 个"最新上架"
  final newest = [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final seen = <String>{};
  final result = <TemplateRecord>[];
  for (final t in hot.take(3)) {
    if (seen.add(t.id)) result.add(t);
  }
  for (final t in newest) {
    if (result.length >= 6) break;
    if (seen.add(t.id)) result.add(t);
  }
  return result;
});

/// 推荐模板列表 Provider（"今日为你推荐" section 数据源）
///
/// 同上，缓存查询结果避免 FutureBuilder 反复 loading。
///
/// 个性化排序：基于 TemplateRanking（50/50 熟/新混合 + 画像三维权重 + 全站热度）
/// 对推荐候选池排序，输出排序后的「今日为你推荐」列表。
///
/// 候选池 = 内置推荐位 ∪ 全部远程模板（后台实时下发，纳入推荐以提供活水）。
final recommendedBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  // 先等线上模板同步完成，再读取候选池并排序，避免"先用不含远程模板的本地池
  // 算出一批初始卡片、线上更新后再整批刷新"的闪烁。网络失败时静默降级本地候选池
  // （保留离线可用性）；后续同步成功会因 watch 依赖自动重算。
  try {
    await ref.watch(remoteTemplatesSyncProvider.future);
  } catch (_) {}

  final dao = await ref.watch(templatesDaoProvider.future);
  final base = await dao.getRecommendedCandidatePool();
  if (base.isEmpty) return const [];

  try {
    // 画像：'{scope}:{key}' -> score
    final interestsDao = await ref.watch(userInterestsDaoProvider.future);
    final portrait = <String, double>{};
    final all = await interestsDao.getAll();
    for (final e in all.entries) {
      portrait[e.key] = e.value.score;
    }

    // 热度：全站累计 use_shoot*2 + open_detail
    final usageDao = await ref.watch(usageDaoProvider.future);
    final counts =
        await usageDao.countMap('template', base.map((t) => t.id).toList());

    // 近 30 天本机信号（时效软化，缓解老模板霸榜）
    final sinceMs = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final recent = await usageDao.recentPopularity(
        'template', base.map((t) => t.id).toList(), sinceMs);

    const alpha = 0.5; // 全站累计 : 近30天本机 = 50 : 50
    final popularity = <String, int>{
      for (final t in base)
        t.id: ((((counts[t.id]?.useShoot ?? 0) * 2 +
                        (counts[t.id]?.openDetail ?? 0)) *
                    alpha) +
                (((recent[t.id]?.useShoot ?? 0) * 2 +
                        (recent[t.id]?.openDetail ?? 0)) *
                    (1 - alpha)))
            .round(),
    };

    final ctx = RankingContext(
      portrait: portrait,
      popularity: popularity,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final scores = TemplateRanking().scoreAll(base, ctx);
    final mixed = TemplateRanking().mixExplore(scores);
    final daily = const DailyRecommendator().build(
      mixed.map((t) => t.id).toList(),
      DateTime.now(),
      cap: 10,
    );
    final byId = {for (final t in mixed) t.id: t};
    return [
      for (final d in daily)
        if (byId[d.templateId] != null) byId[d.templateId]!,
    ];
  } catch (e) {
    debugPrint('[recommend] today recommend ranking failed (silent fallback): $e');
    return base;
  }
});

/// 已收藏的模板 id 集合（收藏状态 UI 的唯一数据源）。
/// 收藏/取消后 `ref.invalidate(favoriteTemplateIdsProvider)` 触发重建。
/// autoDispose：页面退出（路由弹出、无监听者）即释放，重新进入时自动拉取最新收藏。
final favoriteTemplateIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final dao = await ref.watch(templatesFavoriteDaoProvider.future);
  final ids = await dao.getFavoriteIds();
  return ids.toSet();
});

/// 全来源已收藏模板卡片列表（按收藏时间倒序）。
///
/// 排序交给 DAO 的 CreatedAt DESC；按有序收藏 id 命中 builtin/remote/custom 全池记录，
/// 转成「我的收藏」页的网格卡片项。模板已删除时静默跳过。
/// `isCustom` 按 `source == 'custom'` 判定（与 getCustomOnly 口径一致）。
/// autoDispose：收藏页为独立路由，退出即释放，重新进入自动刷新最新收藏列表。
final favoriteTemplatesProvider =
    FutureProvider.autoDispose<List<AllTemplateItem>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final favDao = await ref.watch(templatesFavoriteDaoProvider.future);
  final orderedIds = await favDao.getFavoriteIds();
  if (orderedIds.isEmpty) return const <AllTemplateItem>[];
  final records = <TemplateRecord>[
    ...await dao.getBuiltinAndRemote(),
    ...await dao.getCustomOnly(),
  ];
  final byId = <String, TemplateRecord>{for (final r in records) r.id: r};
  final items = <AllTemplateItem>[];
  for (final id in orderedIds) {
    final r = byId[id];
    if (r == null) continue; // 模板已删，静默跳过
    items.add(templateGridItemFromRecord(r, isCustom: r.source == 'custom'));
  }
  return items;
});

/// 「今日为你推荐」展示项：在 recommendedBuiltinTemplatesProvider 基础上，
/// 为画像命中项生成"匹配你常拍的【…】"四级理由与同分类角标；未命中项保留短简介 + 系统精选。
final todayRecommendationItemsProvider =
    FutureProvider.autoDispose<List<TemplateRecommendation>>((ref) async {
  final ranked = await ref.watch(recommendedBuiltinTemplatesProvider.future);
  if (ranked.isEmpty) return const [];

  // 画像（用于命中判定，复用与 ranking provider 相同的读取方式）
  final interestsDao = await ref.watch(userInterestsDaoProvider.future);
  final portrait = <String, double>{};
  for (final e in (await interestsDao.getAll()).entries) {
    portrait[e.key] = e.value.score;
  }
  final ctx = RankingContext(
    portrait: portrait,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  );
  final ranker = TemplateRanking();

  // 分类中文名表（L2-L4），按父级路径精确解析（同名 L3 拍法如 normal 挂在多个父级下）
  final dao = await ref.watch(templatesDaoProvider.future);
  final categories = await dao.getCategories(activeOnly: false);
  final byKey = <String, List<TemplateCategoryRecord>>{};
  for (final c in categories) {
    byKey.putIfAbsent(c.key, () => []).add(c);
  }
  String nameOf(String key, String? parentKey) {
    final list = byKey[key] ?? const <TemplateCategoryRecord>[];
    if (list.isEmpty) return key;
    if (parentKey == null) return list.first.name;
    final byParent = list.where((c) => c.parentKey == parentKey);
    return (byParent.isNotEmpty ? byParent.first : list.first).name;
  }

  final out = <TemplateRecommendation>[];
  for (final r in ranked) {
    final base = templateRecordToRecommendation(r);
    if (!ranker.isProfileMatch(r, ctx)) {
      out.add(base);
      continue;
    }
    final cls = r.classification;
    // 与 isProfileMatch（interestFor→effectiveL2）保持一致：majorStyle 为空回退 style，
    // 避免"判为命中但理由缺 L2 段"的口径分叉。
    final maj = TemplateRanking.effectiveL2(r);
    final sub = cls['subStyle'] is String ? cls['subStyle'] as String : '';
    final method = cls['method'] is String ? cls['method'] as String : '';
    final seg = <String>[
      TemplatesBrowseMockData.categoryLabel(r.category),
      if (maj.isNotEmpty) nameOf(maj, r.category),
      if (sub.isNotEmpty) nameOf(sub, maj.isEmpty ? null : maj),
      if (method.isNotEmpty) nameOf(method, maj.isEmpty ? null : maj),
    ];
    out.add(TemplateRecommendation(
      id: base.id,
      name: base.name,
      reason: '匹配你常拍的【${seg.join(' · ')}】',
      source: TemplateSource.categoryMatch,
      imageSeed: base.imageSeed,
      category: base.category,
      cover: base.cover,
      coverData: base.coverData,
      price: base.price,
      isCustom: base.isCustom,
      ambience: base.ambience,
    ));
  }
  return out;
});
