import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'points_models.dart';

/// 积分 Repository 抽象
abstract class PointsRepository {
  /// GET /points/balance
  Future<PointsBalance> getBalance();

  /// GET /points/transactions?limit=&offset=
  Future<PointsTransactions> listTransactions({
    int limit = 50,
    int offset = 0,
  });

  /// POST /points/earn
  ///
  /// 事件型积分领取（幂等）：
  /// - type='shoot_daily'：每日首次拍摄（refId 由服务端按日期计算）
  /// - type='challenge'：完成挑战（refId=challengeId）
  Future<PointEarnResult> earn({required String type, String? refId});
}

class RemotePointsRepository implements PointsRepository {
  final ApiClient _api;

  RemotePointsRepository(this._api);

  @override
  Future<PointsBalance> getBalance() {
    return _api.get(
      '/points/balance',
      fromJson: (j) => PointsBalance.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<PointsTransactions> listTransactions({
    int limit = 50,
    int offset = 0,
  }) {
    return _api.get(
      '/points/transactions',
      query: {'limit': limit, 'offset': offset},
      fromJson: (j) => PointsTransactions.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<PointEarnResult> earn({required String type, String? refId}) {
    return _api.post(
      '/points/earn',
      body: {
        'type': type,
        if (refId != null && refId.isNotEmpty) 'refId': refId,
      },
      fromJson: (j) => PointEarnResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

final pointsRepositoryProvider = FutureProvider<PointsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemotePointsRepository(api);
});
