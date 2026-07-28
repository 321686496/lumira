import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/api_cache_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'rewards_models.dart';

/// 奖励 Repository 抽象
abstract class RewardsRepository {
  /// GET /rewards
  ///
  /// 离线回退：网络失败时返回上次缓存的列表
  Future<RewardsList> list();

  /// POST /rewards/:id/claim
  ///
  /// 提交类操作，无离线回退
  Future<ClaimResult> claim(int id);
}

class RemoteRewardsRepository implements RewardsRepository {
  final ApiClient _api;
  final ApiCacheDao _cache;

  static const _kCacheKeyList = 'rewards_list';

  RemoteRewardsRepository({
    required ApiClient api,
    required ApiCacheDao cache,
  })  : _api = api,
        _cache = cache;

  @override
  Future<RewardsList> list() async {
    try {
      final list = await _api.get(
        '/rewards',
        fromJson: (j) => RewardsList.fromJson(j as Map<String, dynamic>),
      );
      await _cache.save(_kCacheKeyList, jsonEncode(list.toJson()));
      return list;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cache.load(_kCacheKeyList);
        if (cached != null) {
          return RewardsList.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      rethrow;
    }
  }

  @override
  Future<ClaimResult> claim(int id) async {
    return _api.post(
      '/rewards/$id/claim',
      fromJson: (j) => ClaimResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

final rewardsRepositoryProvider = FutureProvider<RewardsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  final cache = await ref.watch(apiCacheDaoProvider.future);
  return RemoteRewardsRepository(api: api, cache: cache);
});

final rewardsListProvider = FutureProvider<RewardsList>((ref) async {
  final repo = await ref.watch(rewardsRepositoryProvider.future);
  return repo.list();
});
