import 'package:flutter/foundation.dart';

/// 个人资料（用户名 + 头像 seed，随设备存储）
@immutable
class ProfileData {
  final String username;
  final String avatarSeed;

  /// 上次成功同步时间戳（秒），null 表示待同步
  final int? syncedAt;

  const ProfileData({
    required this.username,
    required this.avatarSeed,
    this.syncedAt,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) {
    return ProfileData(
      username: (j['username'] as String?) ?? '',
      avatarSeed: (j['avatarSeed'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'avatarSeed': avatarSeed,
      };

  ProfileData copyWith({String? username, String? avatarSeed, int? syncedAt}) {
    return ProfileData(
      username: username ?? this.username,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
