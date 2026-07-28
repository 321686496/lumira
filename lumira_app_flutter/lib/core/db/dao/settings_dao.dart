import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 用户设置 DAO（单行表 user_settings，id=1）
///
/// 对齐项目 DAO 模式：持有 Database 引用，FutureProvider 注入。
/// 三端通用（sqflite CPF-Flutter fork 已适配 OHOS）。
class SettingsDao {
  SettingsDao(this._db);

  final Database _db;

  /// 读取自动去模糊开关（默认 true）
  Future<bool> getAutoDeblur() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colAutoDeblur],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return true;
    return (rows.first[Tables.colAutoDeblur] as int?) == 1;
  }

  /// 设置自动去模糊开关
  Future<void> setAutoDeblur(bool value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colAutoDeblur: value ? 1 : 0,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
