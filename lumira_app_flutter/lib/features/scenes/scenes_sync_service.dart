// lumira_app_flutter/lib/features/scenes/scenes_sync_service.dart
//
// 系统场景元数据同步服务：联网时从后端拉取系统场景列表写入本地 scenes 表，
// 并把各场景的远程 usage 汇总写入 usage_stats 快照，供列表/详情/推荐读取。
//
// 离线/弱网时静默失败（返回 false），本地种子数据仍可兜底，功能不降级。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/dao/scenes_dao.dart';
import '../../core/db/dao/usage_dao.dart';
import '../../core/db/database_provider.dart';
import '../../core/network/api_client.dart';

/// 场景元数据网络抽象（便于单测注入 fake，风格同 UsageNetwork）。
abstract class ScenesNetwork {
  /// 拉取系统场景元数据。path: GET /scenes。
  Future<Map<String, dynamic>> fetchScenes();
}

/// 基于全局 [ApiClient] 的网络实现（baseUrl 含 /api/v1，自动带鉴权头）。
class ApiScenesNetwork implements ScenesNetwork {
  ApiScenesNetwork(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> fetchScenes() async {
    return _api.get<Map<String, dynamic>>(
      '/scenes',
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}

class ScenesSyncService {
  ScenesSyncService(this._dao, this._usageDao, this._network);

  final ScenesDao _dao;
  final UsageDao _usageDao;
  final ScenesNetwork _network;

  /// 同步系统场景元数据到本地。
  /// 失败/离线抛异常时返回 false（静默，不降级，本地种子仍可用）。
  Future<bool> syncSystem() async {
    try {
      final resp = await _network.fetchScenes();
      final scenes = resp['scenes'] as List<dynamic>? ?? const <dynamic>[];
      for (final raw in scenes) {
        if (raw is! Map) continue;
        final scene = Map<String, dynamic>.from(raw);
        final id = (scene['id'] ?? '') as String;
        if (id.isEmpty) continue;

        final record = _toRecord(scene, id);
        await _syncUsage(scene, id);
        await _dao.upsert(record);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  SceneRecord _toRecord(Map<String, dynamic> scene, String id) {
    return SceneRecord(
      id: id,
      name: scene['name'] as String,
      icon: (scene['icon'] ?? '') as String,
      category: scene['category'] as String,
      style: (scene['style'] ?? '') as String,
      filter: scene['filter'] is Map
          ? Map<String, dynamic>.from(scene['filter'] as Map)
          : <String, dynamic>{},
      vibe: (scene['vibe'] ?? '') as String,
      description: (scene['description'] ?? '') as String,
      exampleImages: _strList(scene['exampleImages']),
      tips: _strList(scene['tips']),
      whereToShoot: (scene['whereToShoot'] ?? '') as String,
      bestTime: (scene['bestTime'] ?? '') as String,
      sceneGuide: <String, dynamic>{}, // 后端暂无
      relatedCategory: (scene['relatedCategory'] ?? '') as String,
      recommendedTagIds: _strList(scene['recommendedTagIds']),
      tagIds: _strList(scene['recommendedTagIds']),
      creator: 'system',
      isFavorite: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: ((scene['updatedAt'] ?? 0) as num).toInt(),
    );
  }

  /// 仅收集 String 元素，非数组返回空列表。
  List<String> _strList(Object? v) {
    if (v is! List) return <String>[];
    return v.whereType<String>().toList();
  }

  /// 写该场景的远程 usage 汇总到 usage_stats（冲突替换）。
  Future<void> _syncUsage(Map<String, dynamic> scene, String id) async {
    final u = scene['usage'] is Map
        ? Map<String, dynamic>.from(scene['usage'] as Map)
        : <String, dynamic>{};
    await _usageDao.setStats([
      UsageStat('scene', id, 'use_shoot', (u['useShoot'] as num?)?.toInt() ?? 0),
      UsageStat('scene', id, 'open_detail', (u['openDetail'] as num?)?.toInt() ?? 0),
      UsageStat('scene', id, 'scene_select', (u['sceneSelect'] as num?)?.toInt() ?? 0),
    ]);
  }
}

/// 全局 ScenesSyncService Provider
final scenesSyncServiceProvider = FutureProvider<ScenesSyncService>((ref) async {
  final dao = await ref.watch(scenesDaoProvider.future);
  final usageDao = await ref.watch(usageDaoProvider.future);
  final api = await ref.watch(apiClientProvider.future);
  return ScenesSyncService(dao, usageDao, ApiScenesNetwork(api));
});