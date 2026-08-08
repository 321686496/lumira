import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/capture/watermark/models/watermark_template.dart';

/// 水印模板 DAO（自定义水印模板持久化）。
///
/// 表结构（v20 迁移新增）：
/// - id (TEXT PRIMARY KEY)
/// - name (TEXT NOT NULL)
/// - type (TEXT NOT NULL) - 'preset' | 'custom'
/// - config (TEXT NOT NULL) - WatermarkTemplate.toJson() 的 JSON 字符串
/// - created_at (INTEGER NOT NULL) - 毫秒时间戳
///
/// 对齐项目 DAO 模式：持有 Database 引用，FutureProvider 注入。
/// `config` 字段必须使用 `jsonEncode` / `jsonDecode` 处理，禁止 `.toString()`。
class WatermarkDao {
  WatermarkDao(this._db);

  final Database _db;

  /// 获取所有自定义水印模板（按创建时间倒序）。
  Future<List<WatermarkTemplate>> getAll() async {
    final rows = await _db.query(
      Tables.watermarkTemplates,
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// 按 id 获取单个水印模板，未找到返回 null。
  Future<WatermarkTemplate?> getById(String id) async {
    final rows = await _db.query(
      Tables.watermarkTemplates,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// 插入水印模板（config 存为 JSON 字符串）。
  Future<void> insert(WatermarkTemplate template) async {
    await _db.insert(
      Tables.watermarkTemplates,
      _toRow(template),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 更新水印模板（name + config）。
  Future<int> update(WatermarkTemplate template) async {
    return _db.update(
      Tables.watermarkTemplates,
      {
        Tables.colName: template.name,
        Tables.colType: template.type.name,
        Tables.colConfig: jsonEncode(template.toJson()),
      },
      where: '${Tables.colId} = ?',
      whereArgs: [template.id],
    );
  }

  /// 删除水印模板。
  Future<int> delete(String id) async {
    return _db.delete(
      Tables.watermarkTemplates,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  Map<String, Object?> _toRow(WatermarkTemplate template) {
    return {
      Tables.colId: template.id,
      Tables.colName: template.name,
      Tables.colType: template.type.name,
      Tables.colConfig: jsonEncode(template.toJson()),
      Tables.colCreatedAt: template.createdAt.millisecondsSinceEpoch,
    };
  }

  WatermarkTemplate _fromRow(Map<String, Object?> row) {
    final configRaw = row[Tables.colConfig] as String?;
    if (configRaw == null || configRaw.isEmpty) {
      // config 损坏时返回空模板兜底（避免单条坏数据导致整列表崩溃）
      return WatermarkTemplate(
        id: row[Tables.colId] as String,
        name: (row[Tables.colName] as String?) ?? '',
        type: WatermarkTemplateType.custom,
        elements: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row[Tables.colCreatedAt] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    try {
      final json = jsonDecode(configRaw) as Map<String, dynamic>;
      return WatermarkTemplate.fromJson(json);
    } catch (_) {
      return WatermarkTemplate(
        id: row[Tables.colId] as String,
        name: (row[Tables.colName] as String?) ?? '',
        type: WatermarkTemplateType.custom,
        elements: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row[Tables.colCreatedAt] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }
}
