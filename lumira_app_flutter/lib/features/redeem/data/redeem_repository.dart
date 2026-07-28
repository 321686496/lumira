import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'redeem_models.dart';

/// 兑换码 Repository 抽象
abstract class RedeemRepository {
  /// POST /redeem/code
  ///
  /// 提交类操作，无离线回退
  Future<RedeemCodeResponse> redeem(RedeemCodeRequest req);
}

class RemoteRedeemRepository implements RedeemRepository {
  final ApiClient _api;

  RemoteRedeemRepository(this._api);

  @override
  Future<RedeemCodeResponse> redeem(RedeemCodeRequest req) async {
    return _api.post(
      '/redeem/code',
      body: req.toJson(),
      fromJson: (j) => RedeemCodeResponse.fromJson(j as Map<String, dynamic>),
    );
  }
}

final redeemRepositoryProvider = FutureProvider<RedeemRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteRedeemRepository(api);
});
