import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'device_models.dart';

/// 设备 Repository 抽象
abstract class DeviceRepository {
  /// POST /device/register
  ///
  /// 注册设备并获取 JWT token
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req);
}

/// 远程实现（直接调用后端，无离线回退）
class RemoteDeviceRepository implements DeviceRepository {
  final ApiClient _api;

  RemoteDeviceRepository(this._api);

  @override
  Future<RegisterDeviceResponse> register(RegisterDeviceRequest req) async {
    return _api.post(
      '/device/register',
      body: req.toJson(),
      fromJson: (j) => RegisterDeviceResponse.fromJson(j as Map<String, dynamic>),
    );
  }
}

/// 全局 Provider
///
/// 注意：依赖 apiClientProvider（FutureProvider），故 repository 也是 FutureProvider
final deviceRepositoryProvider = FutureProvider<DeviceRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteDeviceRepository(api);
});
