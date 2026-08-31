import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/templates/data/templates_editor_mock_data.dart';
import '../../../features/templates/data/templates_management_mock_data.dart';
import '../../../features/templates/services/template_mapper.dart';
import 'templates_dao.dart';

/// 编辑器草稿 DAO（v51 新增，template_drafts 表）。
///
/// 草稿的载荷是把当前 EditorForm 经 [TemplateMapper.fromEditorForm] 转成
/// [TemplateRecord] 后，用 [TemplateRecord.toRow] JSON 化存入 payload 列。
/// 图片资源（封面/效果图/剪影）保存时已落盘为本地文件，payload 里存绝对路径，
/// 从而绕开 OHOS RDB 2MB 单行上限；恢复时经 fromRow → toEditorForm 还原表单。
class TemplatesDraftsDao {
  TemplatesDraftsDao(this._db);

  final Database _db;

  /// 草稿列表（按最近更新倒序）。单条 payload 解析失败时跳过该条，不阻断整体。
  Future<List<DraftItem>> getAll() async {
    final rows = await _db.query(
      Tables.templateDrafts,
      orderBy: '${Tables.colUpdatedAt} DESC',
    );
    final list = <DraftItem>[];
    for (final row in rows) {
      try {
        final record = _decodeRow(row);
        if (record == null) continue;
        list.add(_toDraftItem(
          row[Tables.colId] as String,
          record,
          (row[Tables.colUpdatedAt] as num).toInt(),
        ));
      } catch (e) {
        debugPrint('DraftsDao: skip broken draft row: $e');
      }
    }
    return list;
  }

  /// 保存/覆盖草稿。payload 为 TemplateRecord.toRow() 的 JSON 字符串。
  Future<void> upsert(String id, String payload, int updatedAt) async {
    await _db.insert(
      Tables.templateDrafts,
      {
        Tables.colId: id,
        Tables.colPayload: payload,
        Tables.colUpdatedAt: updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 恢复草稿为 EditorForm；记录不存在或解析失败返回 null。
  Future<EditorForm?> loadById(String id) async {
    final rows = await _db.query(
      Tables.templateDrafts,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final record = _decodeRow(rows.first);
      if (record == null) return null;
      return TemplateMapper.toEditorForm(record);
    } catch (e) {
      debugPrint('DraftsDao: load draft $id failed: $e');
      return null;
    }
  }

  /// 删除单条草稿。
  Future<void> delete(String id) async {
    await _db.delete(
      Tables.templateDrafts,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 清空全部草稿。
  Future<void> clearAll() async {
    await _db.delete(Tables.templateDrafts);
  }

  /// 把 payload 行解析为 TemplateRecord；payload 为空/非法返回 null。
  TemplateRecord? _decodeRow(Map<String, Object?> row) {
    final payload = row[Tables.colPayload] as String?;
    if (payload == null || payload.isEmpty) return null;
    final map = jsonDecode(payload) as Map<String, Object?>;
    return TemplateRecord.fromRow(map);
  }

  /// TemplateRecord → 草稿列表展示项。
  DraftItem _toDraftItem(String id, TemplateRecord record, int updatedAt) {
    final cam = record.camera;
    return DraftItem(
      id: id,
      name: record.name,
      updatedAt: updatedAt,
      category: record.category,
      exposureCompensation:
          (cam['exposureCompensation'] as num?)?.toDouble() ?? 0.0,
      iso: (cam['iso'] as num?)?.toInt() ?? 200,
      shutterSpeed: (cam['shutterSpeed'] as String?) ?? '1/200',
      cover: _firstCover(record),
    );
  }

  /// 取封面引用：优先 coverData（fromEditorForm 已把首图 data 写到 coverData），
  /// 其次 images[0]，最后兜底 cover 列。
  String _firstCover(TemplateRecord record) {
    if ((record.coverData?.isNotEmpty ?? false)) return record.coverData!;
    final imgs = record.images;
    if (imgs != null && imgs.isNotEmpty) {
      final first = imgs.first;
      if ((first.data?.isNotEmpty ?? false)) return first.data!;
      if (first.url.isNotEmpty) return first.url;
    }
    return record.cover;
  }
}