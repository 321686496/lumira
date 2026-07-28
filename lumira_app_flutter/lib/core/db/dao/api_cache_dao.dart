import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 通用 API 响应缓存（key-value JSON）
///
/// 用于离线回退：每个远程 Repository 调用成功后 save，
/// 网络失败时 load 返回上次缓存的 payload
class ApiCacheDao {
  final Database _db;
  ApiCacheDao(this._db);

  Future<String?> load(String key) async {
    final rows = await _db.query(
      Tables.apiCache,
      where: '${Tables.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[Tables.colPayload] as String;
  }

  Future<void> save(String key, String payload) async {
    await _db.delete(Tables.apiCache, where: '${Tables.colKey} = ?', whereArgs: [key]);
    await _db.insert(Tables.apiCache, {
      Tables.colKey: key,
      Tables.colPayload: payload,
      Tables.colCachedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clear(String key) async {
    await _db.delete(Tables.apiCache, where: '${Tables.colKey} = ?', whereArgs: [key]);
  }
}
