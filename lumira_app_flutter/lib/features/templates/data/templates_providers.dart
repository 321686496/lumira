// lib/features/templates/data/templates_providers.dart
//
// 模板页真实数据 Provider：
// - userPreferenceProvider：累计作品数 + 最常用分类及占比（来自 GalleryDao + TemplatesDao）
// - freeBuiltinTemplatesProvider：免费内置模板列表（缓存，避免 FutureBuilder 反复加载）
//
// 对照：lumira-app/src/composables/useRecommendation.ts 中的 userPreference computed

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
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

/// 免费内置模板列表 Provider（"更多模板" section 数据源）
///
/// 用 FutureProvider 缓存查询结果，避免 FutureBuilder 在每次 build 时
/// 重新调用 dao.getBuiltin(price: 0) 导致反复进入 loading 状态。
final freeBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  return dao.getBuiltin(price: 0);
});

/// 推荐内置模板列表 Provider（"今日为你推荐" section 数据源）
///
/// 同上，缓存查询结果避免 FutureBuilder 反复 loading。
final recommendedBuiltinTemplatesProvider =
    FutureProvider<List<TemplateRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  return dao.getBuiltin(isRecommended: true);
});
