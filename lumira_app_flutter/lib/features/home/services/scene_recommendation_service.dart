// lib/features/home/services/scene_recommendation_service.dart
//
// 场景推荐服务（3+1 混合算法）
//
// 槽位分配：
// 1. 最常去场景（按 gallery_items 中 scene_id 计数最多）
// 2. 次常去场景的同类（同 scene.category）但不同的场景
// 3. 第三常去场景的同类但不同的场景
//    - 若常去场景不足 3 个，从同类未拍过场景补
// 4. 系统推荐：用户从未拍过的场景，优先不同 category 增加新鲜感
//
// 不足 4 条时，从预设场景按未拍过优先补齐
//
// 数据源：
// - ScenesDao.getAll()：自定义场景（DB 完整数据）+ 内置场景收藏标记（DB 仅 name='' 标记）
// - ScenePresetsData.allScenePresets：内置预设场景完整数据
// - GalleryDao.countByScene(sceneId)：每场景照片数

import 'package:flutter/foundation.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../capture/data/scene_presets_data.dart';
import '../data/home_mock_data.dart';

/// 统一场景信息（自定义 + 预设合并视图）
class _SceneInfo {
  final String id;
  final String name;
  final String vibe;
  final String category; // light/outdoor/indoor/mood（预设）或 SceneRecord.category
  final bool isCustom; // 自定义场景（DB 有完整数据）
  final bool isPreset; // 内置预设
  final bool isFavorite;
  final String coverUrl; // 场景封面（自定义=SceneRecord.coverUrl，预设=exampleImages 首图）

  const _SceneInfo({
    required this.id,
    required this.name,
    required this.vibe,
    required this.category,
    required this.isCustom,
    required this.isPreset,
    required this.isFavorite,
    this.coverUrl = '',
  });
}

class SceneRecommendationService {
  SceneRecommendationService({
    required GalleryDao galleryDao,
    required ScenesDao scenesDao,
    this.maxSlots = 4,
  })  : _galleryDao = galleryDao,
        _scenesDao = scenesDao;

  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;
  final int maxSlots;

  /// 构建 4 条场景推荐
  Future<List<SceneReco>> build() async {
    try {
      // 1. 收集所有场景：用户自定义（DB creator='user'）+ 内置预设（代码常量）
      final dbScenes = await _scenesDao.getAll();

      // 内置系统场景的收藏标记从 DB 读取（内置场景 DB 仅持久化 is_favorite）。
      final presetFavorites = <String>{
        for (final s in dbScenes)
          if (s.creator == 'system' && s.isFavorite) s.id,
      };

      // 真正由用户创建的自定义场景（creator='user'，跳过空名占位行）。
      // 注意：不能把 getAll() 里所有 name 非空的行都当作自定义——种子内置场景
      // 以 creator='system' 写入同一张表，若误判会带上 "我的场景" 徽章、且其
      // coverUrl 为空导致封面不显示。
      final userScenes = dbScenes
          .where((s) => s.creator == 'user' && s.name.isNotEmpty)
          .toList();
      const presetScenes = ScenePresetsData.allScenePresets;

      // 2. 统计每场景照片数
      final sceneCounts = <String, int>{};
      for (final s in userScenes) {
        sceneCounts[s.id] = await _galleryDao.countByScene(s.id);
      }
      for (final s in presetScenes) {
        sceneCounts[s.id] = await _galleryDao.countByScene(s.id);
      }

      // 3. 构建统一场景列表
      final allScenes = <_SceneInfo>[];
      // 用户自定义场景（DB 完整数据，含用户上传封面）
      for (final s in userScenes) {
        allScenes.add(_SceneInfo(
          id: s.id,
          name: s.name,
          vibe: s.vibe,
          category: s.category,
          isCustom: true,
          isPreset: false,
          isFavorite: s.isFavorite,
          coverUrl: s.coverUrl,
        ));
      }
      // 内置预设场景（数据来自代码常量；不再叠加 DB 中 creator='system' 的行，
      // 避免身份歧义 / 空封面，收藏态统一取自 presetFavorites）
      for (final s in presetScenes) {
        allScenes.add(_SceneInfo(
          id: s.id,
          name: s.name,
          vibe: s.vibe,
          category: s.category,
          isCustom: false,
          isPreset: true,
          isFavorite: presetFavorites.contains(s.id),
          coverUrl: s.exampleImages.isNotEmpty ? s.exampleImages.first : '',
        ));
      }

      if (allScenes.isEmpty) return const [];

      // 4. 常去场景排名（按照片数降序）
      final visited = allScenes.where((s) => (sceneCounts[s.id] ?? 0) > 0).toList()
        ..sort((a, b) => (sceneCounts[b.id] ?? 0).compareTo(sceneCounts[a.id] ?? 0));

      // 未拍过的场景（用于槽位 4 + 补位）
      final unvisited = allScenes.where((s) => (sceneCounts[s.id] ?? 0) == 0).toList();

      // 5. 4 槽位填充
      final result = <SceneReco>[];
      final usedIds = <String>{};

      // 槽位 1：最常去场景
      if (visited.isNotEmpty) {
        final s = visited.first;
        result.add(_toReco(s, sceneCounts[s.id] ?? 0, _badgeForSlot(1, s, true)));
        usedIds.add(s.id);
      }

      // 槽位 2：次常去场景的同类但不同
      if (visited.length > 1) {
        final first = visited[0];
        final sameCategory = visited.where((s) =>
            s.id != first.id &&
            s.category == first.category &&
            !usedIds.contains(s.id)).toList();
        if (sameCategory.isNotEmpty) {
          final s = sameCategory.first;
          result.add(_toReco(s, sceneCounts[s.id] ?? 0, _badgeForSlot(2, s, true)));
          usedIds.add(s.id);
        }
      }
      // 槽位 2 fallback：从同 category 未拍过补
      if (result.length < 2 && visited.isNotEmpty) {
        final first = visited[0];
        final sameCategoryUnvisited = unvisited
            .where((s) => s.category == first.category && !usedIds.contains(s.id))
            .toList();
        if (sameCategoryUnvisited.isNotEmpty) {
          final s = sameCategoryUnvisited.first;
          result.add(_toReco(s, 0, _badgeForSlot(2, s, false)));
          usedIds.add(s.id);
        }
      }

      // 槽位 3：第三常去场景的同类但不同
      if (visited.length > 2) {
        final first = visited[0];
        final second = visited[1];
        final usedCategories = {first.category, second.category};
        // 找第三常去且 category 不同于前两者
        final different = visited.where((s) =>
            !usedIds.contains(s.id) && !usedCategories.contains(s.category)).toList();
        if (different.isNotEmpty) {
          final s = different.first;
          result.add(_toReco(s, sceneCounts[s.id] ?? 0, _badgeForSlot(3, s, true)));
          usedIds.add(s.id);
        } else {
          // 退化：取第三常去
          final s = visited[2];
          if (!usedIds.contains(s.id)) {
            result.add(_toReco(s, sceneCounts[s.id] ?? 0, _badgeForSlot(3, s, true)));
            usedIds.add(s.id);
          }
        }
      }
      // 槽位 3 fallback：从未拍过同 category 补
      while (result.length < 3 && visited.isNotEmpty) {
        final lastVisited = result.last;
        // 同 category 的场景（未使用过的）
        final sameCat = allScenes.where((s) =>
            s.category == _categoryOfName(lastVisited.name, allScenes) &&
            !usedIds.contains(s.id)).toList();
        if (sameCat.isEmpty) break;
        final s = sameCat.first;
        result.add(_toReco(s, sceneCounts[s.id] ?? 0, _badgeForSlot(3, s, false)));
        usedIds.add(s.id);
      }

      // 槽位 4：系统推荐（用户从未拍过，优先不同 category）
      if (result.length < 4) {
        final usedCategories = result.map((r) {
          // 反查 category
          final scene = allScenes.firstWhere((s) => s.id == r.id, orElse: () => allScenes.first);
          return scene.category;
        }).toSet();

        // 优先不同 category 的未拍过
        final freshDifferent = unvisited
            .where((s) => !usedIds.contains(s.id) && !usedCategories.contains(s.category))
            .toList();
        _SceneInfo? picked;
        if (freshDifferent.isNotEmpty) {
          picked = freshDifferent.first;
        } else {
          // 退化：任意未拍过
          final anyFresh = unvisited.where((s) => !usedIds.contains(s.id)).toList();
          if (anyFresh.isNotEmpty) picked = anyFresh.first;
        }
        if (picked != null) {
          result.add(_toReco(picked, 0, '新场景推荐', brand: true));
          usedIds.add(picked.id);
        }
      }

      // 6. 不足 4 条时，从所有未使用场景补齐
      while (result.length < maxSlots) {
        final candidate = allScenes.where((s) => !usedIds.contains(s.id)).toList();
        if (candidate.isEmpty) break;
        final s = candidate.first;
        result.add(_toReco(s, sceneCounts[s.id] ?? 0, '${s.name}拍摄'));
        usedIds.add(s.id);
      }

      return result.take(maxSlots).toList();
    } catch (e) {
      debugPrint('SceneRecommendationService failed: $e');
      return const [];
    }
  }

  /// 反查场景 category（用于槽位 3 fallback 比较已添加 result 的 category）
  /// 简化：通过 name 在 allScenes 中查找
  String _categoryOfName(String name, List<_SceneInfo> allScenes) {
    final match = allScenes.where((s) => s.name == name);
    return match.isNotEmpty ? match.first.category : '';
  }

  /// 槽位徽章文案
  String _badgeForSlot(int slot, _SceneInfo s, bool visited) {
    if (s.isCustom) return '我的场景';
    switch (slot) {
      case 1:
        return '你最常去';
      case 2:
        return visited ? '同类常去' : '同类推荐';
      case 3:
        return visited ? '换个风格' : '同类新场景';
      default:
        return '${s.name}拍摄';
    }
  }

  SceneReco _toReco(_SceneInfo s, int photoCount, String badgeText, {bool brand = false}) {
    return SceneReco(
      id: s.id,
      name: s.name,
      vibe: s.vibe,
      imageSeed: 'scene-home-${s.id}',
      badgeText: badgeText,
      badgeBrand: brand,
      photoCount: photoCount,
      coverUrl: s.coverUrl,
    );
  }
}
