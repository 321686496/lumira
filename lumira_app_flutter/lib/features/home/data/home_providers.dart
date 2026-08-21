// lib/features/home/data/home_providers.dart
//
// 首页真实数据 Provider：
// - homeStreakProvider：连续拍摄 + 本周拍摄状态（来自 shootingCheckinProvider 统一打卡数据）
// - homeRecentShotsProvider：最近拍摄 5 张（来自 GalleryDao，含真实图片源）
// - homeStatsProvider：收藏 / 总经验 / 作品数（来自 GalleryDao + GrowthDao）
// - homeSceneRecosProvider：场景推荐 4 个（SceneRecommendationService 3+1 算法）
// - homeInspirationProvider：今日灵感（InspirationService：日期+天气+智能文案）
// - homeTipsProvider：拍照小贴士（TipRecommendationService：基于偏好推荐）
//
// 对照：lumira-app/src/pages/home/index.vue script setup 中的真实数据集成

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../gallery/providers/gallery_diary_providers.dart' as gallery;
import '../../profile/providers/growth_providers.dart';
import '../data/home_mock_data.dart';
import '../data/inspiration_models.dart';
import '../services/inspiration_service.dart';
import '../services/scene_recommendation_service.dart';
import '../services/tip_recommendation_service.dart';
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

/// 首页连续拍摄 Provider
/// 实现：基于 shootingCheckinProvider 统一拍摄打卡数据（连续天数 + 本周 7 天状态）
final homeStreakProvider = FutureProvider<HomeStreakStatus>((ref) async {
  final checkin = await ref.watch(gallery.shootingCheckinProvider.future);
  // 直接复用 shootingCheckin 的 weekDays 与 streakDays
  return HomeStreakStatus(
    streakDays: checkin.streakDays,
    weekDays: checkin.weekDays
        .map((wd) => WeekDay(
              label: wd.label,
              done: wd.done,
              today: wd.today,
            ))
        .toList(),
  );
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

  final result = await Future.wait(photos.asMap().entries.map((entry) async {
    final i = entry.key;
    final p = entry.value;
    String name = '作品 ${i + 1}';
    String category = '作品';
    IconData icon = Icons.image_outlined;

    // 优先用模板信息
    if (p.templateId != null && p.templateId!.isNotEmpty) {
      final tpl = await templatesDao.getById(p.templateId!);
      if (tpl != null) {
        name = tpl.name;
        category = _categoryLabel(tpl.category);
        icon = _categoryIcon(tpl.category);
      }
    } else if (p.sceneId != null && p.sceneId!.isNotEmpty) {
      // 其次用场景信息（DB 自定义场景）
      final scene = await scenesDao.getById(p.sceneId!);
      if (scene != null && scene.name.isNotEmpty) {
        name = scene.name;
        category = _sceneCategoryLabel(scene.category);
        icon = _sceneCategoryIcon(scene.category);
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
        }
      }
    }

    final imageSeed = 'photo-${p.id}';

    return RecentShot(
      name: name,
      category: category,
      icon: icon,
      imageSeed: imageSeed,
      // 真实拍摄时间：用于卡片展示相对时间
      createdAt: DateTime.fromMillisecondsSinceEpoch(p.createdAt),
      // 真实收藏状态：卡片右下角展示
      isFavorite: p.isFavorite,
      // 复用来源：供"再拍一次"直达对应模板/场景拍摄
      templateId: p.templateId,
      sceneId: p.sceneId,
      // 真实照片源：优先 filePath，其次 dataUrl，最后 originalPath
      // RecentShotCard 中根据优先级渲染（filePath 用 Image.file，dataUrl 用 Image.memory）
      imageFilePath: p.filePath,
      imageDataUrl: p.dataUrl,
      imageOriginalPath: p.originalPath,
    );
  }));
  return result;
});

/// 首页统计 Provider
/// 实现：收藏数 / 总经验 XP / 作品数（"获赞"功能因 UGC 审核限制已替换为"总经验"）
final homeStatsProvider = FutureProvider<HomeStats>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final growthSummary = await ref.watch(growthLevelProvider.future);

  final totalPhotosFuture = galleryDao.count();
  final favoritesFuture = galleryDao.getFavorites();
  final totalPhotos = await totalPhotosFuture;
  final favorites = await favoritesFuture;
  final totalXp = growthSummary.currentXp;

  return HomeStats(
    favorites: favorites.length,
    totalXp: totalXp,
    totalPhotos: totalPhotos,
  );
});

/// 首页场景推荐 Provider
/// 实现：SceneRecommendationService 3+1 混合算法
/// - 槽位 1：最常去场景
/// - 槽位 2：次常去场景的同类
/// - 槽位 3：第三常去场景的同类
/// - 槽位 4：系统推荐（从未拍过，优先不同 category）
/// 不足时从预设场景补齐
final homeSceneRecosProvider =
    FutureProvider<List<SceneReco>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);

  final service = SceneRecommendationService(
    galleryDao: galleryDao,
    scenesDao: scenesDao,
  );
  final result = await service.build();
  if (result.isEmpty) return HomeMockData.scenes; // fallback
  return result;
});

/// 首页今日灵感 Provider
/// 实现：InspirationService（日期 + 天气 + 智能 description）
/// 失败时返回 fallback
final homeInspirationProvider =
    FutureProvider<HeroInspiration>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final apiClient = await ref.watch(apiClientProvider.future);

  final service = InspirationService(
    galleryDao: galleryDao,
    apiClient: apiClient,
  );
  try {
    return await service.build();
  } catch (_) {
    return HeroInspiration.fallback;
  }
});

/// 首页拍照小贴士 Provider
/// 实现：TipRecommendationService（基于用户最近 30 天拍摄偏好）
/// 失败时返回 fallback（HomeMockData.tips）
final homeTipsProvider =
    FutureProvider<List<ShootingTip>>((ref) async {
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  final service = TipRecommendationService(
    galleryDao: galleryDao,
    templatesDao: templatesDao,
  );
  final result = await service.build();
  if (result.isEmpty) return HomeMockData.tips;
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
