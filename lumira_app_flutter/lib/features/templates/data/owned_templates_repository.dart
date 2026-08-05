import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../points/data/points_models.dart';

/// GET /templates/owned 单条解锁记录
@immutable
class OwnedTemplateRecord {
  final String id;
  final String templateId;
  final String source;
  final String? sourceDetail;
  final int unlockedAt;

  const OwnedTemplateRecord({
    required this.id,
    required this.templateId,
    required this.source,
    this.sourceDetail,
    required this.unlockedAt,
  });

  factory OwnedTemplateRecord.fromJson(Map<String, dynamic> j) =>
      OwnedTemplateRecord(
        id: j['id']?.toString() ?? '',
        templateId: j['templateId'] as String? ?? '',
        source: j['source'] as String? ?? '',
        sourceDetail: j['sourceDetail'] as String?,
        unlockedAt: (j['unlockedAt'] as num?)?.toInt() ?? 0,
      );
}

/// GET /templates/owned 响应体
@immutable
class OwnedTemplates {
  final List<String> templateIds;
  final List<OwnedTemplateRecord> records;

  const OwnedTemplates({
    required this.templateIds,
    required this.records,
  });

  factory OwnedTemplates.fromJson(Map<String, dynamic> j) {
    final ids = j['templateIds'] as List<dynamic>? ?? const [];
    final recs = j['records'] as List<dynamic>? ?? const [];
    return OwnedTemplates(
      templateIds: ids.map((e) => e.toString()).toList(),
      records: recs
          .map((e) => OwnedTemplateRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// GET /templates/prices 单条价格记录
@immutable
class TemplatePrice {
  final String templateId;
  final int priceCredits;
  final bool isActive;

  const TemplatePrice({
    required this.templateId,
    required this.priceCredits,
    required this.isActive,
  });

  factory TemplatePrice.fromJson(Map<String, dynamic> j) => TemplatePrice(
        templateId: j['templateId'] as String? ?? '',
        priceCredits: (j['priceCredits'] as num?)?.toInt() ?? 0,
        isActive: j['isActive'] as bool? ?? false,
      );
}

/// GET /templates/prices 响应体
@immutable
class TemplatePrices {
  final List<TemplatePrice> prices;

  const TemplatePrices({required this.prices});

  factory TemplatePrices.fromJson(Map<String, dynamic> j) {
    final list = j['prices'] as List<dynamic>? ?? const [];
    return TemplatePrices(
      prices: list
          .map((e) => TemplatePrice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 按 templateId 索引价格表，未配置返回 0
  int priceOf(String templateId) {
    for (final p in prices) {
      if (p.templateId == templateId) return p.priceCredits;
    }
    return 0;
  }
}

/// 已拥有模板 Repository
///
/// 提供 listOwned / listPrices / exchange 三端：
/// - listOwned / listPrices 为只读 GET，缓存到全局 StateProvider
/// - exchange 为提交型 POST，成功后失效 owned 缓存
abstract class OwnedTemplatesRepository {
  Future<OwnedTemplates> listOwned();
  Future<TemplatePrices> listPrices();
  Future<TemplateExchangeResult> exchange(String templateId);
}

class RemoteOwnedTemplatesRepository implements OwnedTemplatesRepository {
  final ApiClient _api;

  RemoteOwnedTemplatesRepository(this._api);

  @override
  Future<OwnedTemplates> listOwned() {
    return _api.get(
      '/templates/owned',
      fromJson: (j) => OwnedTemplates.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<TemplatePrices> listPrices() {
    return _api.get(
      '/templates/prices',
      fromJson: (j) => TemplatePrices.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<TemplateExchangeResult> exchange(String templateId) {
    return _api.post(
      '/templates/exchange',
      body: {'templateId': templateId},
      fromJson: (j) =>
          TemplateExchangeResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

final ownedTemplatesRepositoryProvider =
    FutureProvider<OwnedTemplatesRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteOwnedTemplatesRepository(api);
});

/// 已拥有 templateId 集合缓存
///
/// - 读取：ref.watch(ownedTemplateIdsProvider) 返回 Set<String>
/// - 初始为空集合，加载后填充
/// - 兑换成功后调用 [invalidateOwnedTemplates] 刷新
final ownedTemplateIdsProvider =
    StateProvider<Set<String>>((ref) => const <String>{});

/// 已拥有模板加载状态：async 加载并将结果同步到 [ownedTemplateIdsProvider]
///
/// 用法：进入模板详情页时 ref.watch(ownedTemplatesLoaderProvider)
/// 它会异步把 listOwned 结果写入 ownedTemplateIdsProvider
final ownedTemplatesLoaderProvider = FutureProvider<void>((ref) async {
  final repo = await ref.watch(ownedTemplatesRepositoryProvider.future);
  final owned = await repo.listOwned();
  ref.read(ownedTemplateIdsProvider.notifier).state =
      owned.templateIds.toSet();
});
