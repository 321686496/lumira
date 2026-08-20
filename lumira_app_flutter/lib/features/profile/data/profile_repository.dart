import 'dart:typed_data';

import 'package:dio/dio.dart';

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
    String? gender,
    List<String>? favoriteCategories,
    List<String>? painPoints,
    String? skillLevel,
    List<String>? expectations,
    List<String>? commonScenes,
    String? shootFrequency,
    String? avatarUrl,
  });

  /// POST /profile/avatar 上传自定义头像，返回 {avatarUrl}
  Future<String> uploadAvatarBytes(Uint8List bytes, String filename);
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
    String? gender,
    List<String>? favoriteCategories,
    List<String>? painPoints,
    String? skillLevel,
    List<String>? expectations,
    List<String>? commonScenes,
    String? shootFrequency,
    String? avatarUrl,
  }) async {
    final updated = await _api.patch<ProfileData>(
      '/profile',
      body: {
        if (username != null) 'username': username,
        if (avatarSeed != null) 'avatarSeed': avatarSeed,
        if (gender != null) 'gender': gender,
        if (favoriteCategories != null) 'favoriteCategories': favoriteCategories,
        if (painPoints != null) 'painPoints': painPoints,
        if (skillLevel != null) 'skillLevel': skillLevel,
        if (expectations != null) 'expectations': expectations,
        if (commonScenes != null) 'commonScenes': commonScenes,
        if (shootFrequency != null) 'shootFrequency': shootFrequency,
        'avatarUrl': avatarUrl,
      },
      fromJson: (j) => ProfileData.fromJson(j as Map<String, dynamic>),
    );
    // ApiClient.patch 签名返回 Future<T?>，但 fromJson 恒返回非空对象；
    // 此处空值兜底仅为满足静态类型，实际不可达。
    return updated ?? const ProfileData(username: '', avatarSeed: '');
  }

  @override
  Future<String> uploadAvatarBytes(Uint8List bytes, String filename) {
    return _api.multipartPost<String>(
      '/profile/avatar',
      fields: const {},
      files: [MultipartFile.fromBytes(bytes, filename: filename)],
      fileField: 'avatar',
      fromJson: (j) => (j as Map<String, dynamic>)['avatarUrl'] as String,
    );
  }
}
