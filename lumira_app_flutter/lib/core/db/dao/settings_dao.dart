import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/domain/photo_template.dart';
import '../../../features/capture/watermark/models/watermark_settings.dart';

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

  /// 读取自由模式相机参数（未设置时返回 null）
  Future<CameraParams?> getFreeModeCamera() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModeCamera],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModeCamera] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CameraParams.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式相机参数
  Future<void> setFreeModeCamera(CameraParams value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModeCamera: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取自由模式后期参数（未设置时返回 null）
  Future<PostProcess?> getFreeModePostProcess() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModePostProcess],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModePostProcess] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PostProcess.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式后期参数
  Future<void> setFreeModePostProcess(PostProcess value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModePostProcess: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取自由模式构图参数（未设置时返回 null）
  Future<Composition?> getFreeModeComposition() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModeComposition],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModeComposition] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Composition.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式构图参数
  Future<void> setFreeModeComposition(Composition value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModeComposition: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取水印设置（未设置时返回 null）
  Future<WatermarkSettings?> getWatermarkSettings() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colWatermarkSettings],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colWatermarkSettings] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WatermarkSettings.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存水印设置
  Future<void> setWatermarkSettings(WatermarkSettings value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colWatermarkSettings: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
