import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';
import 'questionnaire_answers.dart';

/// 问卷 DAO（单行表 questionnaire，id=1）
class QuestionnaireDao {
  QuestionnaireDao(this._db);

  final Database _db;

  /// 读取答案（未填过返回 null）
  Future<QuestionnaireAnswers?> getAnswers() async {
    final rows = await _db.query(
      Tables.questionnaire,
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colAnswersJson] as String?;
    if (raw == null || raw.isEmpty || raw == '{}') return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return QuestionnaireAnswers.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 写入答案（重填覆盖）
  Future<void> upsert(QuestionnaireAnswers answers, int submittedAt) async {
    await _db.insert(
      Tables.questionnaire,
      {
        Tables.colId: 1,
        Tables.colAnswersJson: answers.toJsonString(),
        Tables.colSubmittedAt: submittedAt,
        Tables.colSyncedAt: null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 标记已同步
  Future<void> markSynced(int syncedAt) async {
    await _db.update(
      Tables.questionnaire,
      {Tables.colSyncedAt: syncedAt},
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
  }

  /// 是否已填过问卷
  Future<bool> isCompleted() async {
    final rows = await _db.query(
      Tables.questionnaire,
      columns: [Tables.colSubmittedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    return rows.first[Tables.colSubmittedAt] != null;
  }

  /// 是否有未同步的提交
  Future<bool> hasUnsynced() async {
    final rows = await _db.query(
      Tables.questionnaire,
      columns: [Tables.colSubmittedAt, Tables.colSyncedAt],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return false;
    final submitted = rows.first[Tables.colSubmittedAt];
    final synced = rows.first[Tables.colSyncedAt];
    return submitted != null && synced == null;
  }
}
