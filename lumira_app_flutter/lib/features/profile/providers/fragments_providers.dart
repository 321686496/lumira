// lib/features/profile/providers/fragments_providers.dart
//
// 碎片收集真实数据 Provider：
// 按 SceneCategory（light/outdoor/indoor/mood）分组统计用户拍摄的照片数，
// 每类需拍 5 张才能集齐。照片来源为 GalleryDao，场景分类通过 scene_id 解析：
//   - 内置场景预设：从 ScenePresetsData 代码常量查 category
//   - 用户自定义场景：从 ScenesDao 查 category
//
// 对照：lumira-app/src/pages/profile/fragments.vue 的 fragments computed

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../capture/data/scene_presets_data.dart';
import '../../capture/domain/scene_preset.dart';
import '../data/profile_mock_data.dart';

/// 碎片定义：4 个场景分类
class _FragmentDef {
  final String category;
  final String name;
  final String desc;
  final IconData icon;
  const _FragmentDef({
    required this.category,
    required this.name,
    required this.desc,
    required this.icon,
  });
}

const _kFragmentTarget = 5;

const List<_FragmentDef> _fragmentDefs = [
  _FragmentDef(
    category: SceneCategory.light,
    name: '光线碎片',
    desc: '在光线氛围类场景中拍摄',
    icon: Icons.wb_sunny_outlined,
  ),
  _FragmentDef(
    category: SceneCategory.outdoor,
    name: '室外碎片',
    desc: '在室外环境类场景中拍摄',
    icon: Icons.landscape_outlined,
  ),
  _FragmentDef(
    category: SceneCategory.indoor,
    name: '室内碎片',
    desc: '在室内空间类场景中拍摄',
    icon: Icons.home_outlined,
  ),
  _FragmentDef(
    category: SceneCategory.mood,
    name: '情绪碎片',
    desc: '在情绪氛围类场景中拍摄',
    icon: Icons.favorite_outline,
  ),
];

/// 碎片收集 Provider
/// 实现：从 GalleryDao 读取全部照片，按 scene_id 解析场景 category，分组计数
final fragmentsProvider = FutureProvider<List<FragmentItem>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);

  // 内置场景 id → category 映射
  final presetCategoryMap = <String, String>{};
  for (final s in ScenePresetsData.allScenePresets) {
    presetCategoryMap[s.id] = s.category;
  }

  // 用户自定义场景 id → category 映射
  final customScenes = await scenesDao.getAll();
  final customCategoryMap = <String, String>{};
  for (final s in customScenes) {
    if (s.name.isNotEmpty && s.category.isNotEmpty) {
      customCategoryMap[s.id] = s.category;
    }
  }

  // 读取全部照片，按 category 分组收集 displayUrl
  final photos = await galleryDao.getAll();
  final byCategory = <String, List<String>>{
    SceneCategory.light: <String>[],
    SceneCategory.outdoor: <String>[],
    SceneCategory.indoor: <String>[],
    SceneCategory.mood: <String>[],
  };

  for (final p in photos) {
    final sceneId = p.sceneId;
    if (sceneId == null || sceneId.isEmpty) continue;
    final cat = presetCategoryMap[sceneId] ?? customCategoryMap[sceneId];
    if (cat == null) continue;
    final list = byCategory[cat];
    if (list == null) continue;
    final url = p.dataUrl ?? p.filePath;
    if (url != null && url.isNotEmpty) {
      list.add(url);
    }
  }

  // 构建 FragmentItem，每个分类最多展示 _kFragmentTarget 张图，计数上限 _kFragmentTarget
  return _fragmentDefs.map((def) {
    final urls = byCategory[def.category] ?? const <String>[];
    final current = urls.length < _kFragmentTarget ? urls.length : _kFragmentTarget;
    // 展示的图片最多取前 _kFragmentTarget 张
    final displayUrls = urls.take(_kFragmentTarget).toList();
    return FragmentItem(
      name: def.name,
      icon: def.icon,
      current: current,
      max: _kFragmentTarget,
      photoUrls: displayUrls,
    );
  }).toList();
});

/// 已集齐碎片数
final fragmentCollectedProvider = FutureProvider<int>((ref) async {
  final fragments = await ref.watch(fragmentsProvider.future);
  return fragments.where((f) => f.current >= f.max).length;
});
