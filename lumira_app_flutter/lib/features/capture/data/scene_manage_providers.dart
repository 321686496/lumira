// lib/features/capture/data/scene_manage_providers.dart
//
// 场景管理页的 DB 数据源：自定义场景 + 收藏场景。
// 均以 scenes 表为准（真实数据），内置预设场景（代码常量）与 DB 收藏标记合并展示。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'capture_scene_mock_data.dart';
import 'scene_record_mapper.dart';

/// 自定义场景列表（creator='user'，按创建时间倒序）。
final customScenesProvider = FutureProvider.autoDispose<List<CustomScenePreset>>(
  (ref) async {
    final dao = await ref.watch(scenesDaoProvider.future);
    final records = await dao.getCustomScenes();
    return records.map(sceneRecordToCustom).toList();
  },
);

/// 收藏场景列表。
///
/// 收藏标记以 DB is_favorite 为准。内置预设场景完整数据由代码常量提供，
/// 自定义/系统场景用 DB 记录兜底展示。
final favoriteScenesProvider = FutureProvider.autoDispose<List<ScenePreset>>(
  (ref) async {
    final dao = await ref.watch(scenesDaoProvider.future);
    final records = await dao.getFavorites();
    if (records.isEmpty) return <ScenePreset>[];

    final customScenes = await ref.watch(customScenesProvider.future);
    final customById = {for (final c in customScenes) c.id: c};
    final presetById = {
      for (final p in CaptureSceneMockData.presetScenes) p.id: p,
    };

    final result = <ScenePreset>[];
    for (final rec in records) {
      final preset = presetById[rec.id];
      if (preset != null) {
        result.add(preset);
        continue;
      }
      final custom = customById[rec.id];
      if (custom != null) {
        result.add(custom);
        continue;
      }
      // 兜底：系统同步场景等其它来源记录直接展示
      result.add(sceneRecordToPreset(rec));
    }
    return result;
  },
);