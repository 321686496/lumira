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
    );
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
