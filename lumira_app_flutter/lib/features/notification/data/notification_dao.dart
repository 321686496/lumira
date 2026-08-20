// lumira_app_flutter/lib/features/notification/data/notification_dao.dart
import 'package:sqflite/sqflite.dart';

import '../../../core/db/tables.dart';

/// 一条通知记录（对应本地 notifications 表的一行）。
///
/// - source='remote' 表示后端下发的公告；source='local' 表示本地 app 事件通知。
/// - 已读（read）/清除（cleared）状态存本机（方案 C）。
class NotificationRecord {
  NotificationRecord({
    required this.id,
    required this.source,
    this.remoteId,
    required this.kind,
    required this.title,
    required this.body,
    required this.timeMs,
    this.read = 0,
    this.cleared = 0,
  });

  /// 主键：local 通知用本地生成 id（幂等去重）；remote 通知即 remote_id。
  final String id;

  /// 'remote'（后端公告） | 'local'（本地 app 事件）
  final String source;

  /// 后端公告 id（source='remote' 时有值；local 为 null）。
  final String? remoteId;

  /// 通知类别：如 'announcement'（后端公告 / 本地事件类型）。
  final String kind;

  final String title;
  final String body;

  /// 时间戳（毫秒）。
  final int timeMs;

  /// 0 未读 / 1 已读。
  final int read;

  /// 0 未清除 / 1 已清除。
  final int cleared;

  Map<String, Object?> toMap() => {
        Tables.colId: id,
        Tables.colSource: source,
        Tables.colRemoteId: remoteId,
        Tables.colKind: kind,
        Tables.colTitleN: title,
        Tables.colBodyN: body,
        Tables.colTimeMs: timeMs,
        Tables.colRead: read,
        Tables.colCleared: cleared,
      };

  NotificationRecord copyWith({int? read, int? cleared}) => NotificationRecord(
        id: id,
        source: source,
        remoteId: remoteId,
        kind: kind,
        title: title,
        body: body,
        timeMs: timeMs,
        read: read ?? this.read,
        cleared: cleared ?? this.cleared,
      );

  factory NotificationRecord.fromRow(Map<String, Object?> row) {
    return NotificationRecord(
      id: row[Tables.colId] as String,
      source: row[Tables.colSource] as String,
      remoteId: row[Tables.colRemoteId] as String?,
      kind: row[Tables.colKind] as String,
      title: row[Tables.colTitleN] as String,
      body: row[Tables.colBodyN] as String,
      timeMs: (row[Tables.colTimeMs] as num).toInt(),
      read: (row[Tables.colRead] as num?)?.toInt() ?? 0,
      cleared: (row[Tables.colCleared] as num?)?.toInt() ?? 0,
    );
  }
}

/// 本地通知中心数据访问对象（notifications 表）。
class NotificationDao {
  NotificationDao(this._db);

  final Database _db;

  /// 合并/更新一条后端公告（主键=remoteId，刷新内容但保留历史已读/清除状态）。
  Future<void> upsertRemote(NotificationRecord r) async {
    final remoteId = r.remoteId ?? r.id;
    if (remoteId.isEmpty) return;
    int read = r.read;
    int cleared = r.cleared;
    final existing = await _getById(remoteId);
    if (existing != null) {
      // 保留已读/清除状态，避免公告更新后被误判为未读
      read = existing.read;
      cleared = existing.cleared;
    }
    await _db.insert(
      Tables.notifications,
      NotificationRecord(
        id: remoteId,
        source: 'remote',
        remoteId: remoteId,
        kind: r.kind,
        title: r.title,
        body: r.body,
        timeMs: r.timeMs,
        read: read,
        cleared: cleared,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 插入一条本地 app 事件通知（id 幂等去重）。
  Future<void> insertLocal(NotificationRecord r) async {
    await _db.insert(
      Tables.notifications,
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 通知列表（仅未清除，按时间倒序）。
  Future<List<NotificationRecord>> list() async {
    final rows = await _db.query(
      Tables.notifications,
      where: '${Tables.colCleared} = ?',
      whereArgs: [0],
      orderBy: '${Tables.colTimeMs} DESC',
    );
    return rows.map(NotificationRecord.fromRow).toList();
  }

  /// 标记单条为已读。
  Future<void> markRead(String id) async {
    await _db.update(
      Tables.notifications,
      {Tables.colRead: 1},
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 全部标记已读。
  Future<void> markAllRead() async {
    await _db.update(Tables.notifications, {Tables.colRead: 1});
  }

  /// 按 id 清除单条（软删，置 cleared=1）。
  Future<void> clearById(String id) async {
    await _db.update(
      Tables.notifications,
      {Tables.colCleared: 1},
      where: '${Tables.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 全部清除（软删，置 cleared=1）。
  Future<void> clearAll() async {
    await _db.update(Tables.notifications, {Tables.colCleared: 1});
  }

  /// 清理后端已不存在的公告：删除 source='remote' 且 remote_id 不在 validIds 的记录。
  /// 本地通知（source='local'）不受影响。
  /// 空集合时跳过（避免远端空列表误清本地公告）。
  Future<void> pruneRemoteIds(Set<String> validIds) async {
    if (validIds.isEmpty) return;
    final placeholders = List.filled(validIds.length, '?').join(',');
    await _db.rawDelete(
      "DELETE FROM ${Tables.notifications} "
      "WHERE ${Tables.colSource} = 'remote' "
      "AND ${Tables.colRemoteId} NOT IN ($placeholders)",
      validIds.toList(),
    );
  }

  /// 未读未清除数量（首页铃铛红点）。
  Future<int> countUnread() async {
    final res = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.notifications} '
      'WHERE ${Tables.colRead} = 0 AND ${Tables.colCleared} = 0',
    );
    if (res.isNotEmpty) return (res.first['c'] as num).toInt();
    return 0;
  }

  /// 按本地 id 取记录（本地事件生成的去重判断）。
  Future<NotificationRecord?> getByLocalKey(String linkKey) async {
    final rows = await _db.query(
      Tables.notifications,
      where: '${Tables.colId} = ?',
      whereArgs: [linkKey],
      limit: 1,
    );
    return rows.isEmpty ? null : NotificationRecord.fromRow(rows.first);
  }

  Future<NotificationRecord?> _getById(String id) async {
    final rows = await _db.query(
      Tables.notifications,
      where: '${Tables.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : NotificationRecord.fromRow(rows.first);
  }
}