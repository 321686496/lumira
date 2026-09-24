import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../domain/scene_preset.dart';
import 'capture_state.dart';
import 'scene_presets_data.dart';
import 'scene_record_mapper.dart';

/// 合并场景排序：选中场景 → 最近拍摄使用过的场景 → 其余场景。
///
/// 排序只做去重和顺序调整，不会新增或过滤场景；来源仍由调用方给全量列表。
List<ScenePreset> orderCaptureScenes({
  required List<ScenePreset> allScenes,
  required List<String> recentSceneIds,
  String? activeId,
}) {
  final sceneById = {for (final scene in allScenes) scene.id: scene};
  final orderedIds = <String>[
    if (activeId != null && sceneById.containsKey(activeId)) activeId,
    ...recentSceneIds.where(sceneById.containsKey),
    ...sceneById.keys,
  ];

  final seen = <String>{};
  final result = <ScenePreset>[];
  for (final id in orderedIds) {
    if (!seen.add(id)) continue;
    result.add(sceneById[id]!);
  }
  return result;
}

/// 拍摄页场景数据源。
///
/// 以场景管理使用的 `scenes` 表为全量来源；DB 中只有收藏占位的内置场景
/// 会用代码常量补齐完整信息。最近拍摄照片用于把常用场景前置。
final captureScenePresetsProvider =
    FutureProvider.autoDispose<List<ScenePreset>>((ref) async {
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final activeId = ref.watch(CaptureState.activeScenePresetIdProvider);

  final records = await scenesDao.getAll();
  final sceneById = {
    for (final scene in ScenePresetsData.allScenePresets) scene.id: scene,
  };
  for (final record in records) {
    if (record.name.trim().isEmpty) continue;
    sceneById[record.id] = sceneRecordToCustom(record);
  }

  final recentSceneIds = await galleryDao.getRecentSceneIds(limit: 50);
  return orderCaptureScenes(
    allScenes: sceneById.values.toList(),
    recentSceneIds: recentSceneIds,
    activeId: activeId,
  );
});

/// 选择场景封面：自定义封面 → 本地打包封面 → 示例图首张。
///
/// 内置场景无论数据里的 exampleImages 是 picsum 还是其它网络地址，都优先用
/// App 内打包的 `assets/images/scenes/scene_<id>.jpg`，避免冷启动联网等待。
String sceneCoverUrl(ScenePreset scene) {
  if (scene is CustomScenePreset && scene.cover.isNotEmpty) {
    return scene.cover;
  }
  final local = ScenePresetsData.localCoverOf(scene.id);
  if (local.isNotEmpty) return local;
  return scene.exampleImages.isNotEmpty ? scene.exampleImages.first : '';
}
