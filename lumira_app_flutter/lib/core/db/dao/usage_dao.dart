// lumira_app_flutter/lib/core/db/dao/usage_dao.dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 统计对象类型：模板 / 场景
enum UsageItemType { template, scene }

/// 统计事件类型
enum UsageEventType { openDetail, useShoot, sceneSelect }

String eventTypeName(UsageEventType t) {
  if (t == UsageEventType.openDetail) return 'open_detail';
  if (t == UsageEventType.useShoot) return 'use_shoot';
  return 'scene_select';
}

/// 一条全站汇总（usage_stats 行）
class UsageStat {
  UsageStat(this.itemType, this.itemId, this.eventType, this.count);

  final String itemType;
  final String itemId;
  final String eventType;
  final int count;
}

class UsageDao {
  UsageDao(this._db);

  final Database _db;

  /// 记录一条未同步埋点事件（client_event_id 唯一，重复上报幂等）。
  Future<void> enqueueEvent({
    required String clientEventId,
    required UsageItemType itemType,
    required String itemId,
    required String itemSource,
    required UsageEventType eventType,
    required int occurredAt,
  }) async {
    await _db.insert(
      Tables.usageEvents,
      {
        Tables.colClientEventId: clientEventId,
        Tables.colItemType: itemType.name,
        Tables.colItemId: itemId,
        Tables.colItemSource: itemSource,
        Tables.colEventType: eventTypeName(eventType),
        Tables.colOccurredAt: occurredAt,
        Tables.colSynced: 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 取全部待上报事件（按发生时间升序）。
  Future<List<Map<String, Object?>>> getUnsyncedEvents() async {
    return _db.query(
      Tables.usageEvents,
      where: '${Tables.colSynced} = ?',
      whereArgs: [0],
      orderBy: '${Tables.colOccurredAt} ASC, id ASC',
    );
  }

  /// 将指定 client_event_id 标记为已同步。
  Future<void> markSynced(List<String> clientEventIds) async {
    if (clientEventIds.isEmpty) return;
    final idList = clientEventIds.map((e) => "'${e.replaceAll("'", "''")}'").join(',');
    await _db.rawUpdate(
      'UPDATE ${Tables.usageEvents} SET ${Tables.colSynced} = 1 '
      'WHERE ${Tables.colClientEventId} IN ($idList)',
    );
  }

  /// 覆盖写入全站汇总快照（冲突替换）。
  Future<void> setStats(List<UsageStat> stats) async {
    if (stats.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final s in stats) {
      batch.insert(
        Tables.usageStats,
        {
          Tables.colItemType: s.itemType,
          Tables.colItemId: s.itemId,
          Tables.colEventType: s.eventType,
          Tables.colCount: s.count,
          Tables.colUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 取某个 item 某事件类型的次数（远程汇总优先，本地快照兜底返回 0）。
  Future<int> countFor(String itemType, String itemId, String eventType) async {
    final rows = await _db.query(
      Tables.usageStats,
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} = ? AND ${Tables.colEventType} = ?',
      whereArgs: [itemType, itemId, eventType],
      limit: 1,
    );
    if (rows.isNotEmpty) return (rows.first[Tables.colCount] as num).toInt();
    return 0;
  }

  /// 一次查询取回多个 item 的三类事件次数（WHERE item_type=? AND item_id IN (...)）。
  Future<Map<String, ItemUsageCounts>> countMap(
      String itemType, List<String> itemIds) async {
    if (itemIds.isEmpty) return const {};
    final placeholders = List.filled(itemIds.length, '?').join(',');
    final rows = await _db.query(
      Tables.usageStats,
      where:
          '${Tables.colItemType} = ? AND ${Tables.colItemId} IN ($placeholders)',
      whereArgs: [itemType, ...itemIds],
    );
    final result = <String, ItemUsageCounts>{};
    for (final r in rows) {
      final id = r[Tables.colItemId] as String;
      final et = r[Tables.colEventType] as String;
      final c = (r[Tables.colCount] as num).toInt();
      final e = result.putIfAbsent(id, () => ItemUsageCounts());
      if (et == 'use_shoot') {
        e.useShoot = c;
      } else if (et == 'open_detail') {
        e.openDetail = c;
      } else if (et == 'scene_select') {
        e.sceneSelect = c;
      }
    }
    return result;
  }
}

/// 某个 item 三类事件次数汇总。
class ItemUsageCounts {
  int useShoot = 0;
  int openDetail = 0;
  int sceneSelect = 0;
}