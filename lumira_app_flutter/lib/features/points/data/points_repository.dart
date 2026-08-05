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
}

final pointsRepositoryProvider = FutureProvider<PointsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemotePointsRepository(api);
});
