import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'operation_banners.dart';

/// 运营 Banner Repository 抽象
abstract class OperationBannersRepository {
  /// GET /banners → 启用中的运营条目（顺序即优先级）。
  /// 空列表是合法状态（后台全部停用）；网络/解析失败抛异常（由调用方走兜底）。
  Future<List<OperationBanner>> list();
}

class RemoteOperationBannersRepository implements OperationBannersRepository {
  RemoteOperationBannersRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<OperationBanner>> list() async {
    final resp = await _api.get('/banners', fromJson: (j) => j as Map<String, dynamic>);
    final rawList = resp['banners'] as List?;
    if (rawList == null) return const [];
    return rawList
        .map((e) => e is Map<String, dynamic> ? operationBannerFromJson(e) : null)
        .whereType<OperationBanner>()
        .toList();
  }
}

final operationBannersRepositoryProvider =
    FutureProvider<OperationBannersRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteOperationBannersRepository(api);
});
