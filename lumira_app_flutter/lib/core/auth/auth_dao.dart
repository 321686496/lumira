import 'package:sqflite/sqflite.dart';

import '../db/tables.dart';

/// AuthDao 抽象接口（用于测试 mock）
abstract class AuthDaoLike {
  Future<AuthRecord?> load();
  Future<void> save(AuthRecord r);
  Future<void> clear();
}

/// 本地持久化的鉴权记录
class AuthRecord {
  final String deviceId;
  final String os;
  final String token;
  final bool isNewDevice;
  final int registeredAt;

  const AuthRecord({
    required this.deviceId,
    required this.os,
    required this.token,
    required this.isNewDevice,
    required this.registeredAt,
  });

  factory AuthRecord.fromMap(Map<String, dynamic> m) => AuthRecord(
        deviceId: m[Tables.colDeviceId] as String,
        os: m[Tables.colOs] as String,
        token: m[Tables.colToken] as String,
        isNewDevice: (m[Tables.colIsNewDevice] as int) == 1,
        registeredAt: m[Tables.colRegisteredAt] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        Tables.colDeviceId: deviceId,
        Tables.colOs: os,
        Tables.colToken: token,
        Tables.colIsNewDevice: isNewDevice ? 1 : 0,
        Tables.colRegisteredAt: registeredAt,
      };
}

/// auth 表 CRUD（单行表，id=1）
class AuthDao implements AuthDaoLike {
  final Database _db;
  AuthDao(this._db);

  @override
  Future<AuthRecord?> load() async {
    final rows = await _db.query(Tables.auth, where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;
    return AuthRecord.fromMap(rows.first);
  }

  @override
  Future<void> save(AuthRecord r) async {
    await _db.delete(Tables.auth, where: 'id = ?', whereArgs: [1]);
    await _db.insert(Tables.auth, r.toMap());
  }

  @override
  Future<void> clear() async {
    await _db.delete(Tables.auth, where: 'id = ?', whereArgs: [1]);
  }
}
