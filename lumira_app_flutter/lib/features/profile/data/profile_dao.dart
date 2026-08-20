import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';
import 'profile_models.dart';

/// 个人资料 DAO（单行表 user_profile，id=1）
class UserProfileDao {
  UserProfileDao(this._db);

  final Database _db;

  /// 读取本地资料（无记录返回 null）
  Future<ProfileData?> get() async {
    final rows = await _db.query(
      Tables.userProfile,
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final username = row[Tables.colUsername] as String? ?? '';
    final avatarSeed = row[Tables.colAvatarSeed] as String? ?? '';
    if (username.isEmpty && avatarSeed.isEmpty) return null;
    return ProfileData(
      username: username,
      avatarSeed: avatarSeed,
      syncedAt: row[Tables.colSyncedAt] as int?,
      gender: row[Tables.colGender] as String?,
      favoriteCategories: _parseList(row[Tables.colFavoriteCategoriesJson]),
      painPoints: _parseList(row[Tables.colPainPointsJson]),
      skillLevel: row[Tables.colSkillLevel] as String?,
      expectations: _parseList(row[Tables.colExpectationsJson]),
      commonScenes: _parseList(row[Tables.colCommonScenesJson]),
      shootFrequency: row[Tables.colShootFrequency] as String?,
      avatarUrl: row[Tables.colAvatarUrl] as String?,
    );
  }

  /// 把 nullable TEXT JSON 列表解析为字符串列表；null 或解析失败返回空列表
  List<String> _parseList(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is List) return decoded.whereType<String>().toList();
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// 写入资料（覆盖单行）
  Future<void> upsert(ProfileData profile, int updatedAt) async {
    await _db.insert(
      Tables.userProfile,
      {
        Tables.colId: 1,
        Tables.colUsername: profile.username,
        Tables.colAvatarSeed: profile.avatarSeed,
        Tables.colUpdatedAt: updatedAt,
        Tables.colSyncedAt: null,
        Tables.colGender: profile.gender,
        Tables.colFavoriteCategoriesJson: jsonEncode(profile.favoriteCategories),
        Tables.colPainPointsJson: jsonEncode(profile.painPoints),
        Tables.colSkillLevel: profile.skillLevel,
        Tables.colExpectationsJson: jsonEncode(profile.expectations),
        Tables.colCommonScenesJson: jsonEncode(profile.commonScenes),
        Tables.colShootFrequency: profile.shootFrequency,
        Tables.colAvatarUrl: profile.avatarUrl,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 标记已同步
  Future<void> markSynced(int syncedAt) async {
    await _db.update(
      Tables.userProfile,
      {Tables.colSyncedAt: syncedAt},
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
  }

  /// 是否有待同步的本地修改（无记录返回 false）
  Future<bool> hasUnsynced() async {
    final rows = await _db.query(
      Tables.userProfile,
      columns: [Tables.colSyncedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    return rows.first[Tables.colSyncedAt] == null;
  }
}
