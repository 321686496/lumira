import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/composition_kit_models.dart';

/// 组合套件 DAO Provider（已在 database_provider.dart 中暴露）
// 重新导出避免循环依赖
export '../../../core/db/database_provider.dart' show compositionKitsDaoProvider;

/// 所有组合套件列表（按 created_at DESC）
final compositionKitsProvider = FutureProvider<List<CompositionKit>>((ref) async {
  final dao = await ref.watch(compositionKitsDaoProvider.future);
  return dao.getAll();
});

/// 按 ID 获取单个套件
final compositionKitByIdProvider =
    FutureProvider.family<CompositionKit?, String>((ref, id) async {
  final dao = await ref.watch(compositionKitsDaoProvider.future);
  return dao.getById(id);
});

/// 套件统计：总数 / 累计使用次数 / 最近使用时间
final compositionKitsStatsProvider = FutureProvider<CompositionKitsStats>((ref) async {
  final kits = await ref.watch(compositionKitsProvider.future);
  final totalCount = kits.length;
  final totalUsage = kits.fold<int>(0, (s, k) => s + k.usageCount);
  final lastUsed = kits
      .map((k) => k.lastUsedAt)
      .whereType<int>()
      .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
  return CompositionKitsStats(
    totalCount: totalCount,
    totalUsage: totalUsage,
    lastUsedAt: lastUsed,
  );
});

class CompositionKitsStats {
  const CompositionKitsStats({
    required this.totalCount,
    required this.totalUsage,
    required this.lastUsedAt,
  });
  final int totalCount;
  final int totalUsage;
  final int? lastUsedAt;
}
