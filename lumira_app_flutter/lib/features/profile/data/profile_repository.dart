import '../../../core/network/api_client.dart';
import 'profile_models.dart';

/// 个人资料 Repository 抽象
abstract class ProfileRepository {
  /// GET /profile，返回当前设备资料（后端无记录时懒创建默认）
  Future<ProfileData> fetch();

  /// PATCH /profile，更新资料并返回更新后结果
  Future<ProfileData> update({
    required String? username,
    required String? avatarSeed,
  });
}

/// 远程实现
class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<ProfileData> fetch() {
    return _api.get<ProfileData>(
      '/profile',
      fromJson: (j) => ProfileData.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<ProfileData> update({
    required String? username,
    required String? avatarSeed,
  }) async {
    final updated = await _api.patch<ProfileData>(
      '/profile',
      body: {
        if (username != null) 'username': username,
        if (avatarSeed != null) 'avatarSeed': avatarSeed,
      },
      fromJson: (j) => ProfileData.fromJson(j as Map<String, dynamic>),
    );
    // ApiClient.patch 签名返回 Future<T?>，但 fromJson 恒返回非空对象；
    // 此处空值兜底仅为满足静态类型，实际不可达。
    return updated ?? const ProfileData(username: '', avatarSeed: '');
  }
}
