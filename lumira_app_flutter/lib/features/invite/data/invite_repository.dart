import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/api_cache_dao.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import 'invite_models.dart';

/// 邀请 Repository 抽象
abstract class InviteRepository {
  /// POST /invite/generate
  Future<InviteCode> generateCode();

  /// POST /invite/activate
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req);

  /// GET /invite/stats
  ///
  /// 离线回退：网络失败时返回上次缓存的 stats
  Future<InviteStats> getStats();
}

/// 远程实现（getStats 离线回退缓存）
class RemoteInviteRepository implements InviteRepository {
  final ApiClient _api;
  final ApiCacheDao _cache;

  static const _kCacheKeyStats = 'invite_stats';

  RemoteInviteRepository({
    required ApiClient api,
    required ApiCacheDao cache,
  })  : _api = api,
        _cache = cache;

  @override
  Future<InviteCode> generateCode() async {
    return _api.post(
      '/invite/generate',
      fromJson: (j) => InviteCode.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req) async {
    return _api.post(
      '/invite/activate',
      body: req.toJson(),
      fromJson: (j) => ActivateInviteResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<InviteStats> getStats() async {
    try {
      final stats = await _api.get(
        '/invite/stats',
        fromJson: (j) => InviteStats.fromJson(j as Map<String, dynamic>),
      );
      // 缓存最新结果
      await _cache.save(_kCacheKeyStats, jsonEncode(stats.toJson()));
      return stats;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = await _cache.load(_kCacheKeyStats);
        if (cached != null) {
          return InviteStats.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      rethrow;
    }
  }
}

/// 全局 Provider
final inviteRepositoryProvider = FutureProvider<InviteRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  final cache = await ref.watch(apiCacheDaoProvider.future);
  return RemoteInviteRepository(api: api, cache: cache);
});

/// InviteStats FutureProvider（带自动刷新）
final inviteStatsProvider = FutureProvider<InviteStats>((ref) async {
  final repo = await ref.watch(inviteRepositoryProvider.future);
  return repo.getStats();
});
