import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../theme/theme_tokens.dart';
import '../../../features/capture/domain/photo_template.dart';
import '../../../features/watermark/models/watermark_settings.dart';

/// 用户设置 DAO（单行表 user_settings，id=1）
///
/// 对齐项目 DAO 模式：持有 Database 引用，FutureProvider 注入。
/// 三端通用（sqflite CPF-Flutter fork 已适配 OHOS）。
class SettingsDao {
  SettingsDao(this._db);

  final Database _db;

  /// 读取主题 key（user_settings.theme_key，默认 warmWhite）
  Future<ThemeKey> getThemeKey() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colThemeKey],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return ThemeKey.warmWhite;
    final raw = rows.first[Tables.colThemeKey] as String?;
    return _parseThemeKey(raw);
  }

  /// 保存主题 key
  Future<void> setThemeKey(ThemeKey key) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colThemeKey: key.name,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取 UI 风格（user_settings.ui_style，默认 neumorphic）
  Future<UIStyle> getUiStyle() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colUiStyle],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return UIStyle.neumorphic;
    final raw = rows.first[Tables.colUiStyle] as String?;
    return _parseUiStyle(raw);
  }

  /// 保存 UI 风格
  Future<void> setUiStyle(UIStyle style) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colUiStyle: style.name,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 按枚举名解析主题 key，非法值回退默认
  ThemeKey _parseThemeKey(String? raw) {
    for (final k in ThemeKey.values) {
      if (k.name == raw) return k;
    }
    return ThemeKey.warmWhite;
  }

  /// 按枚举名解析 UI 风格，非法值回退默认
  UIStyle _parseUiStyle(String? raw) {
    for (final s in UIStyle.values) {
      if (s.name == raw) return s;
    }
    return UIStyle.neumorphic;
  }

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

  /// 读取水平仪开关（默认 true=开启，无行或缺省时保持当前默认开启行为）
  Future<bool> getLevelEnabled() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colLevelEnabled],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return true;
    return (rows.first[Tables.colLevelEnabled] as int?) == 1;
  }

  /// 设置水平仪开关
  Future<void> setLevelEnabled(bool value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colLevelEnabled: value ? 1 : 0,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取快门声音开关（默认 true=开启，无行或缺省时保持默认开启）
  Future<bool> getShutterSound() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colShutterSound],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return true;
    return (rows.first[Tables.colShutterSound] as int?) == 1;
  }

  /// 设置快门声音开关
  Future<void> setShutterSound(bool value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colShutterSound: value ? 1 : 0,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取默认拍摄分辨率（user_settings.default_resolution，默认 'high'）
  /// 合法值为 'high' / 'standard' / 'smooth'，非法或缺省回退 'high'
  Future<String> getDefaultResolution() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colDefaultResolution],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return 'high';
    final raw = rows.first[Tables.colDefaultResolution] as String;
    return (raw == 'high' || raw == 'standard' || raw == 'smooth') ? raw : 'high';
  }

  /// 设置默认拍摄分辨率（'high' / 'standard' / 'smooth'）
  Future<void> setDefaultResolution(String value) async {
    final normalized = (value == 'standard' || value == 'smooth') ? value : 'high';
    await _db.update(
      Tables.userSettings,
      {
        Tables.colDefaultResolution: normalized,
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

  /// 读取持久化的前后置摄像头选择（未设置时返回 null）
  Future<String?> getCameraFacing() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colCameraFacing],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final v = rows.first[Tables.colCameraFacing] as String?;
    return (v == 'front' || v == 'back') ? v : null;
  }

  /// 保存前后置摄像头选择（'front' / 'back'）
  Future<void> setCameraFacing(String facing) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colCameraFacing: facing,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取持久化的照片比例选择（未设置时返回 null）
  Future<String?> getAspectRatio() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colAspectRatio],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final v = rows.first[Tables.colAspectRatio] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 保存照片比例选择（'fullscreen' / '4:3' / '1:1' 等）
  Future<void> setAspectRatio(String ratio) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colAspectRatio: ratio,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取套用模板时的顶部模板信息卡是否被隐藏（默认 false=显示）
  Future<bool> getTemplateInfoCardHidden() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colTemplateInfoCardHidden],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    return (rows.first[Tables.colTemplateInfoCardHidden] as int?) == 1;
  }

  /// 保存套用模板时的顶部模板信息卡显示偏好（true=隐藏，false=显示）
  Future<void> setTemplateInfoCardHidden(bool hidden) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colTemplateInfoCardHidden: hidden ? 1 : 0,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
