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
import '../data/templates_mock_data.dart';

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

/// 推荐内置模板列表 Provider（"今日为你推荐" section 数据源）
///
/// 同上，缓存查询结果避免 FutureBuilder 反复 loading。
///
/// 个性化排序：基于 TemplateRanking（50/50 熟/新混合 + 画像三维权重 + 全站热度）
/// 对推荐内置模板排序，输出排序后的「今日为你推荐」列表。
final recommendedBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final base = await dao.getBuiltin(isRecommended: true);
  if (base.isEmpty) return const [];

  try {
    // 画像：'{scope}:{key}' -> score
    final interestsDao = await ref.watch(userInterestsDaoProvider.future);
    final portrait = <String, double>{};
    final all = await interestsDao.getAll();
    for (final e in all.entries) {
      portrait[e.key] = e.value.score;
    }

    // 热度：use_shoot*2 + open_detail
    final usageDao = await ref.watch(usageDaoProvider.future);
    final counts =
        await usageDao.countMap('template', base.map((t) => t.id).toList());
    final popularity = <String, int>{
      for (final t in base)
        t.id: ((counts[t.id]?.useShoot ?? 0) * 2 + (counts[t.id]?.openDetail ?? 0)),
    };

    final ctx = RankingContext(
      portrait: portrait,
      popularity: popularity,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final scores = TemplateRanking().scoreAll(base, ctx);
    return TemplateRanking().mixExplore(scores);
  } catch (e) {
    debugPrint('[recommend] today recommend ranking failed (silent fallback): $e');
    return base;
  }
});
