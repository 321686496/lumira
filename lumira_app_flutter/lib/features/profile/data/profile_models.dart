import 'package:flutter/foundation.dart';

/// 个人资料（用户名 + 头像 seed + 偏好，随设备存储）
@immutable
class ProfileData {
  final String username;
  final String avatarSeed;

  /// 上次成功同步时间戳（秒），null 表示待同步
  final int? syncedAt;

  /// 性别：male / female / prefer_not
  final String? gender;

  /// 偏好分类 key 列表
  final List<String> favoriteCategories;

  /// 拍摄痛点 key 列表
  final List<String> painPoints;

  /// 技能水平：beginner / intermediate / advanced / pro
  final String? skillLevel;

  /// 拍摄期望 key 列表
  final List<String> expectations;

  /// 常见拍摄场景 key 列表
  final List<String> commonScenes;

  /// 拍摄频率：rarely / monthly / weekly / daily
  final String? shootFrequency;

  /// 自定义头像 URL（非空用自定义，否则用 picsum seed）
  final String? avatarUrl;

  const ProfileData({
    required this.username,
    required this.avatarSeed,
    this.syncedAt,
    this.gender,
    this.favoriteCategories = const [],
    this.painPoints = const [],
    this.skillLevel,
    this.expectations = const [],
    this.commonScenes = const [],
    this.shootFrequency,
    this.avatarUrl,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) {
    return ProfileData(
      username: (j['username'] as String?) ?? '',
      avatarSeed: (j['avatarSeed'] as String?) ?? '',
      gender: j['gender'] as String?,
      favoriteCategories: ((j['favoriteCategories'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      painPoints: ((j['painPoints'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      skillLevel: j['skillLevel'] as String?,
      expectations: ((j['expectations'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      commonScenes: ((j['commonScenes'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      shootFrequency: j['shootFrequency'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'avatarSeed': avatarSeed,
        if (gender != null) 'gender': gender,
        if (favoriteCategories.isNotEmpty) 'favoriteCategories': favoriteCategories,
        if (painPoints.isNotEmpty) 'painPoints': painPoints,
        if (skillLevel != null) 'skillLevel': skillLevel,
        if (expectations.isNotEmpty) 'expectations': expectations,
        if (commonScenes.isNotEmpty) 'commonScenes': commonScenes,
        if (shootFrequency != null) 'shootFrequency': shootFrequency,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  static const Object _unset = Object();

  ProfileData copyWith({
    String? username,
    String? avatarSeed,
    int? syncedAt,
    Object? gender = _unset,
    List<String>? favoriteCategories,
    List<String>? painPoints,
    Object? skillLevel = _unset,
    List<String>? expectations,
    List<String>? commonScenes,
    Object? shootFrequency = _unset,
    Object? avatarUrl = _unset,
  }) {
    return ProfileData(
      username: username ?? this.username,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      syncedAt: syncedAt ?? this.syncedAt,
      gender: identical(gender, _unset) ? this.gender : gender as String?,
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      painPoints: painPoints ?? this.painPoints,
      skillLevel: identical(skillLevel, _unset) ? this.skillLevel : skillLevel as String?,
      expectations: expectations ?? this.expectations,
      commonScenes: commonScenes ?? this.commonScenes,
      shootFrequency: identical(shootFrequency, _unset) ? this.shootFrequency : shootFrequency as String?,
      avatarUrl: identical(avatarUrl, _unset) ? this.avatarUrl : avatarUrl as String?,
    );
  }
}
