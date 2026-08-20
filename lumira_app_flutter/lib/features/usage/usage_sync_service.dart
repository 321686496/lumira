// lumira_app_flutter/lib/features/usage/usage_sync_service.dart
//
// 使用次数同步服务：联网时将本地未同步埋点事件批量上报后端，并拉取全站汇总
// 次数写入 usage_stats 快照，供推荐/搜索/排序作为流行度权重读取。
//
// 离线/弱网时静默失败（返回 false），下次触发再同步，功能不降级。

import '../../../core/db/dao/usage_dao.dart';
import '../../../core/db/tables.dart';
import '../../../core/network/api_client.dart';

/// 网络抽象（便于单测注入 fake）。
abstract class UsageNetwork {
  /// 批量上报事件。path: POST /usage/events。
  Future<void> postEvents(Map<String, dynamic> body);

  /// 拉取全站汇总。path: GET /usage/stats?itemType=template|scene。
  Future<Map<String, dynamic>> fetchStats(Map<String, dynamic> query);
}

/// 基于全局 [ApiClient] 的网络实现（baseUrl 含 /api/v1，自动带鉴权头）。
class DioUsageNetwork implements UsageNetwork {
  DioUsageNetwork(this._api);

  final ApiClient _api;

  @override
  Future<void> postEvents(Map<String, dynamic> body) async {
    await _api.post<Map<String, dynamic>>(
      '/usage/events',
      body: body,
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchStats(Map<String, dynamic> query) async {
    return _api.get<Map<String, dynamic>>(
      '/usage/stats',
      query: query,
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}

class UsageSyncService {
  UsageSyncService(this._dao, this._network);

  final UsageDao _dao;
  final UsageNetwork _network;

  /// 同步：上报未同步事件 + 拉取模板/场景全站次数。
  /// 返回 false 表示离线/失败（静默，下次再试）。
  Future<bool> runSync() async {
    try {
      await _uploadPending();
      await _pullStats('template');
      await _pullStats('scene');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 上报所有待同步事件；成功后标记已同步（幂等）。
  Future<void> _uploadPending() async {
    final unsynced = await _dao.getUnsyncedEvents();
    if (unsynced.isEmpty) return;

    final events = <Map<String, Object?>>[];
    for (final r in unsynced) {
      events.add({
        'clientEventId': r[Tables.colClientEventId],
        'itemType': r[Tables.colItemType],
        'itemId': r[Tables.colItemId],
        'itemSource': r[Tables.colItemSource],
        'eventType': r[Tables.colEventType],
        'occurredAt': r[Tables.colOccurredAt],
      });
    }

    await _network.postEvents({'events': events});
    final ids = events
        .map((e) => e['clientEventId'] as String)
        .toList();
    await _dao.markSynced(ids);
  }

  /// 拉取某类对象的全站汇总，写入 usage_stats 快照（冲突替换）。
  Future<void> _pullStats(String itemType) async {
    final resp = await _network.fetchStats({'itemType': itemType});
    final items = resp['items'] as List<dynamic>? ?? const [];

    final stats = <UsageStat>[];
    for (final raw in items) {
      final it = raw as Map<String, dynamic>;
      final itemId = it['itemId'] as String;
      stats.add(UsageStat(
          itemType, itemId, 'use_shoot', (it['useShoot'] as num?)?.toInt() ?? 0));
      stats.add(UsageStat(
          itemType, itemId, 'open_detail', (it['openDetail'] as num?)?.toInt() ?? 0));
      stats.add(UsageStat(
          itemType, itemId, 'scene_select', (it['sceneSelect'] as num?)?.toInt() ?? 0));
    }
    await _dao.setStats(stats);
  }
}