// lib/features/home/data/home_providers.dart
//
// 首页真实数据 Provider：
// - homeStreakProvider：连续打卡 + 本周打卡状态（来自挑战历史）
// - homeRecentShotsProvider：最近拍摄 5 张（来自 GalleryDao）
// - homeStatsProvider：收藏 / 总经验 / 作品数（来自 GalleryDao + GrowthDao）
// - homeSceneRecosProvider：场景推荐 4 个（按用户拍摄数排序，不足补预设）
//
// 对照：lumira-app/src/pages/home/index.vue script setup 中的真实数据集成

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../challenge/data/challenge_models.dart';
import '../../challenge/data/challenge_providers.dart';
import '../../profile/providers/growth_providers.dart';
import '../data/home_mock_data.dart';
import '../../capture/data/scene_presets_data.dart';
import '../../capture/domain/scene_preset.dart';

/// 本周打卡状态条目
class HomeStreakStatus {
  final int streakDays;
  final List<WeekDay> weekDays;
  const HomeStreakStatus({required this.streakDays, required this.weekDays});

  static const HomeStreakStatus empty = HomeStreakStatus(
    streakDays: 0,
    weekDays: [
      WeekDay(label: '一', done: false, today: false),
      WeekDay(label: '二', done: false, today: false),
      WeekDay(label: '三', done: false, today: false),
      WeekDay(label: '四', done: false, today: false),
      WeekDay(label: '五', done: false, today: false),
      WeekDay(label: '六', done: false, today: false),
      WeekDay(label: '日', done: false, today: false),
    ],
  );
}

/// 首页统计数据
class HomeStats {
  final int favorites;
  final int totalXp;
  final int totalPhotos;
  const HomeStats({
    required this.favorites,
    required this.totalXp,
    required this.totalPhotos,
  });

  static const HomeStats empty =
      HomeStats(favorites: 0, totalXp: 0, totalPhotos: 0);
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 首页连续打卡 Provider
/// 实现：从 ChallengeRepository.getWeeklyHistory() 计算本周打卡状态 + 连续天数
final homeStreakProvider = FutureProvider<HomeStreakStatus>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final history = await repo.getWeeklyHistory();

  final now = DateTime.now();
  final dayOfWeek = now.weekday; // 1=Mon..7=Sun
  final monday =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: dayOfWeek - 1));
  final today = DateTime(now.year, now.month, now.day);

  // 构建打卡日期集合（YYYY-MM-DD）
  final completedDates = <String>{};
  for (final h in history) {
    if (h.status == ChallengeStatus.done) {
      completedDates.add(h.date);
    }
  }

  // 本周 7 天状态
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  final todayStr = _formatDate(today);
  final weekDays = <WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    final ds = _formatDate(d);
    weekDays.add(WeekDay(
      label: labels[i],
      done: completedDates.contains(ds),
      today: ds == todayStr,
    ));
  }

  // 连续打卡天数：从今天往回数（今天已打卡才有连续）
  int streak = 0;
  if (completedDates.contains(todayStr)) {
    streak = 1;
    var cursor = today.subtract(const Duration(days: 1));
    while (completedDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  } else {
    // 今天未打卡：统计昨日往回的连续历史（用作"已连续"展示）
    final yesterday = today.subtract(const Duration(days: 1));
    var cursor = yesterday;
    while (completedDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  return HomeStreakStatus(streakDays: streak, weekDays: weekDays);
});

/// 首页最近拍摄 Provider
/// 实现：从 GalleryDao.getRecent(limit:5) 取最近 5 张照片，按 templateId/sceneId 映射分类
final homeRecentShotsProvider =
    FutureProvider<List<RecentShot>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  final photos = await galleryDao.getRecent(limit: 5);
  if (photos.isEmpty) return const [];

  final result = <RecentShot>[];
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    String name = '作品 ${i + 1}';
    String category = '作品';
    IconData icon = Icons.image_outlined;
    int steps = 6;
    String match = '';
    String progress = '';

    // 优先用模板信息
    if (p.templateId != null && p.templateId!.isNotEmpty) {
      final tpl = await templatesDao.getById(p.templateId!);
      if (tpl != null) {
        name = tpl.name;
        category = _categoryLabel(tpl.category);
        icon = _categoryIcon(tpl.category);
        // sceneGuide 是 Map<String, dynamic>，tips 字段为 List
        final tips = tpl.sceneGuide['tips'];
        steps = tips is List ? tips.length : 8;
      }
    } else if (p.sceneId != null && p.sceneId!.isNotEmpty) {
      // 其次用场景信息（DB 自定义场景）
      final scene = await scenesDao.getById(p.sceneId!);
      if (scene != null && scene.name.isNotEmpty) {
        name = scene.name;
        category = _sceneCategoryLabel(scene.category);
        icon = _sceneCategoryIcon(scene.category);
        steps = scene.tips.isNotEmpty ? scene.tips.length : 6;
      } else {
        // 可能是内置场景预设，DB 仅存收藏标记，从代码常量找完整数据
        ScenePreset? preset;
        for (final s in ScenePresetsData.allScenePresets) {
          if (s.id == p.sceneId) {
            preset = s;
            break;
          }
        }
        if (preset != null) {
          name = preset.name;
          category = _sceneCategoryLabel(preset.category);
          icon = _sceneCategoryIcon(preset.category);
          steps = preset.tips.isNotEmpty ? preset.tips.length : 6;
        }
      }
    }

    // 第一张展示「最新」徽标；3 天内的照片展示「新作品」
    final isLatest = i == 0;
    final isRecent =
        DateTime.now().millisecondsSinceEpoch - p.createdAt < 3 * 24 * 3600 * 1000;
    if (isLatest) {
      match = '最新';
    } else if (isRecent) {
      progress = '新作品';
    }

    final imageSeed = 'photo-${p.id}';

    result.add(RecentShot(
      name: name,
      category: category,
      icon: icon,
      imageSeed: imageSeed,
      steps: steps,
      match: match,
      progress: progress,
    ));
  }
  return result;
});

/// 首页统计 Provider
/// 实现：收藏数 / 总经验 XP / 作品数（"获赞"功能因 UGC 审核限制已替换为"总经验"）
final homeStatsProvider = FutureProvider<HomeStats>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final growthSummary = await ref.watch(growthLevelProvider.future);

  final totalPhotos = await galleryDao.count();
  final favorites = await galleryDao.getFavorites();
  final totalXp = growthSummary.currentXp;

  return HomeStats(
    favorites: favorites.length,
    totalXp: totalXp,
    totalPhotos: totalPhotos,
  );
});

/// 首页场景推荐 Provider
/// 实现：按用户拍摄数排序取前 4，不足补内置预设
final homeSceneRecosProvider =
    FutureProvider<List<SceneReco>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);

  // 收集所有场景：自定义场景（DB）+ 内置预设（代码常量）
  final customScenes = await scenesDao.getAll();
  final presetScenes = ScenePresetsData.allScenePresets;

  // 统计每个场景的照片数
  final sceneCounts = <String, int>{};
  for (final s in customScenes) {
    if (s.name.isNotEmpty) {
      sceneCounts[s.id] = await galleryDao.countByScene(s.id);
    }
  }
  for (final s in presetScenes) {
    sceneCounts[s.id] = await galleryDao.countByScene(s.id);
  }

  // 排序：按照片数降序
  final allIds = <String>[...customScenes.where((s) => s.name.isNotEmpty).map((s) => s.id), ...presetScenes.map((s) => s.id)];
  // 去重（自定义场景 id 不会和预设重复，但保险起见）
  final seen = <String>{};
  final uniqueIds = allIds.where((id) => seen.add(id)).toList();
  uniqueIds.sort((a, b) => (sceneCounts[b] ?? 0).compareTo(sceneCounts[a] ?? 0));

  // 自定义场景按 id 索引
  final customById = <String, SceneRecord>{};
  for (final s in customScenes) {
    customById[s.id] = s;
  }
  final presetById = <String, ScenePreset>{};
  for (final s in presetScenes) {
    presetById[s.id] = s;
  }

  final result = <SceneReco>[];
  for (final id in uniqueIds.take(4)) {
    final count = sceneCounts[id] ?? 0;
    final isCustom = customById.containsKey(id);
    final preset = presetById[id];

    String name;
    String vibe;
    if (isCustom) {
      final s = customById[id]!;
      name = s.name;
      vibe = s.vibe;
    } else if (preset != null) {
      name = preset.name;
      vibe = preset.vibe;
    } else {
      continue;
    }

    String badgeText;
    bool badgeBrand = false;
    if (isCustom) {
      badgeText = '我的场景';
    } else if (count > 0 && result.isEmpty) {
      badgeText = '你最常去';
    } else if (result.length == 2) {
      badgeText = '新场景推荐';
      badgeBrand = true;
    } else {
      badgeText = '$name拍摄';
    }

    result.add(SceneReco(
      id: id,
      name: name,
      vibe: vibe,
      imageSeed: 'scene-home-$id',
      badgeText: badgeText,
      badgeBrand: badgeBrand,
      photoCount: count,
    ));
  }

  return result;
});

// ── 分类标签映射辅助函数 ──

String _categoryLabel(String category) {
  switch (category) {
    case 'portrait':
      return '人像';
    case 'landscape':
      return '风光';
    case 'food':
      return '美食';
    case 'night':
      return '夜景';
    case 'street':
      return '街拍';
    case 'macro':
      return '微距';
    case 'still-life':
      return '静物';
    default:
      return '作品';
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'portrait':
      return Icons.person_outline;
    case 'landscape':
      return Icons.landscape_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'night':
      return Icons.nightlight_outlined;
    case 'street':
      return Icons.directions_walk_outlined;
    case 'macro':
      return Icons.center_focus_strong_outlined;
    case 'still-life':
      return Icons.collections_outlined;
    default:
      return Icons.image_outlined;
  }
}

String _sceneCategoryLabel(String category) {
  switch (category) {
    case SceneCategory.light:
      return '光线氛围';
    case SceneCategory.outdoor:
      return '室外环境';
    case SceneCategory.indoor:
      return '室内空间';
    case SceneCategory.mood:
      return '情绪氛围';
    default:
      return '场景';
  }
}

IconData _sceneCategoryIcon(String category) {
  switch (category) {
    case SceneCategory.light:
      return Icons.wb_sunny_outlined;
    case SceneCategory.outdoor:
      return Icons.landscape_outlined;
    case SceneCategory.indoor:
      return Icons.home_outlined;
    case SceneCategory.mood:
      return Icons.favorite_outline;
    default:
      return Icons.image_outlined;
  }
}
