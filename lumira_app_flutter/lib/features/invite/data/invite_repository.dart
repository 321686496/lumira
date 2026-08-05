import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'invite_models.dart';

/// 邀请 Repository
///
/// 复用 [invite_models.dart] 中已定义的请求/响应模型：
/// - [InviteCode]（POST /invite/generate）
/// - [ActivateInviteRequest] / [ActivateInviteResponse]（POST /invite/activate）
/// - [InviteStats]（GET /invite/stats，旧契约：currentTier / nextTier / unlockedRewards）
///
/// 新增 [InvitePointsStats] 用于积分体系下的新契约：
/// `{ totalInvites, rewardPointsPerInvite, totalEarnedFromInvite, currentBalance }`
abstract class InviteRepository {
  /// POST /invite/generate
  Future<InviteCode> generate();

  /// POST /invite/activate
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req);

  /// GET /invite/stats（旧契约，供 ProfileInvitePage 使用）
  Future<InviteStats> stats();
}

class RemoteInviteRepository implements InviteRepository {
  final ApiClient _api;

  RemoteInviteRepository(this._api);

  @override
  Future<InviteCode> generate() {
    return _api.post(
      '/invite/generate',
      fromJson: (j) => InviteCode.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req) {
    return _api.post(
      '/invite/activate',
      body: req.toJson(),
      fromJson: (j) =>
          ActivateInviteResponse.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<InviteStats> stats() {
    return _api.get(
      '/invite/stats',
      fromJson: (j) => InviteStats.fromJson(j as Map<String, dynamic>),
    );
  }
}

final inviteRepositoryProvider = FutureProvider<InviteRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteInviteRepository(api);
});

/// 旧契约的邀请统计 Provider（供 ProfileInvitePage 使用）
///
/// 包装 [inviteRepositoryProvider]，调用 `stats()` 获取 [InviteStats]。
final inviteStatsProvider = FutureProvider<InviteStats>((ref) async {
  final repo = await ref.watch(inviteRepositoryProvider.future);
  return repo.stats();
});

/// 积分体系下的邀请统计（新契约）
///
/// 后端：`GET /invite/stats` 返回
/// `{ totalInvites, rewardPointsPerInvite, totalEarnedFromInvite, currentBalance }`
@immutable
class InvitePointsStats {
  final int totalInvites;
  final int rewardPointsPerInvite;
  final int totalEarnedFromInvite;
  final int currentBalance;

  const InvitePointsStats({
    required this.totalInvites,
    required this.rewardPointsPerInvite,
    required this.totalEarnedFromInvite,
    required this.currentBalance,
  });

  factory InvitePointsStats.fromJson(Map<String, dynamic> j) =>
      InvitePointsStats(
        totalInvites: (j['totalInvites'] as num?)?.toInt() ?? 0,
        rewardPointsPerInvite:
            (j['rewardPointsPerInvite'] as num?)?.toInt() ?? 0,
        totalEarnedFromInvite:
            (j['totalEarnedFromInvite'] as num?)?.toInt() ?? 0,
        currentBalance: (j['currentBalance'] as num?)?.toInt() ?? 0,
      );
}

/// 积分体系邀请统计 Repository（新契约）
///
/// 与 [InviteRepository] 分离，避免与旧 [InviteStats] 模型冲突。
abstract class InvitePointsRepository {
  /// GET /invite/stats（新契约）
  Future<InvitePointsStats> pointsStats();
}

class RemoteInvitePointsRepository implements InvitePointsRepository {
  final ApiClient _api;

  RemoteInvitePointsRepository(this._api);

  @override
  Future<InvitePointsStats> pointsStats() {
    return _api.get(
      '/invite/stats',
      fromJson: (j) => InvitePointsStats.fromJson(j as Map<String, dynamic>),
    );
  }
}

final invitePointsRepositoryProvider =
    FutureProvider<InvitePointsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteInvitePointsRepository(api);
});
