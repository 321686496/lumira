// lib/core/db/seeders/dev_gallery_seeder.dart
//
// 开发期演示数据 Seeder：向内部相册（gallery_items）灌入一批「使用了模板拍摄」的照片。
//
// 背景与动机：
// - 模拟器当前 shell 非 root，无法直接写 app 沙箱数据库与系统媒体库；
//   本 seeder 在 App 进程内运行，把随 HAP 打包的 dev_seed 图片 asset 复制到
//   应用文档目录，再写入 gallery_items 表并绑定真实模板 template_id，
//   使相册页能加载图片同时显示「使用了模板拍摄」的标记。
// - 仅开发期启用（通过 --dart-define=LUMIRA_DEV_SEED_PROFILE=1 开启）；
//   生产 release 不编译此逻辑（编译期常量裁剪，见 kLumiraDevSeedEnabled）。
//
// 数据源与覆盖：
// - 图片来源：assets/images/dev_seed/*.jpg（14 张，覆盖 portrait / landscape /
//   food / street / night / macro / still-life 七大类，比例 9:16 / 16:9 / 3:4 /
//   4:3 / 1:1）。
// - template_id：绑定 TemplateRegistry 中真实内置模板 id（soft_portrait、
//   golden_landscape、food_flat_lay、street_bw、night_cityscape、macro_flower、
//   indoor_still_life），保证每张照片都能解析到「使用了哪个模板」。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../utils/safe_temp_dir.dart';

/// 是否启用开发期相册演示数据 seed。
///
/// 用编译期常量裁剪：release（未传 define）为 false，触发 DCE 移除此逻辑，
/// 不影响线上包体积与行为。
const bool kLumiraDevSeedEnabled = bool.fromEnvironment(
  'LUMIRA_DEV_SEED_PROFILE',
  defaultValue: false,
);

/// 单张演示照片配置。
class DevGallerySeed {
  final String assetPath;
  final String templateId;
  final String? sceneId;
  final String? mood;
  final int daysAgo;
  const DevGallerySeed({
    required this.assetPath,
    required this.templateId,
    this.sceneId,
    this.mood,
    this.daysAgo = 0,
  });
}

/// 演示照片清单：asset 文件名（assets/images/dev_seed/ 下）→ 绑定模板。
/// templateId 均为 TemplateRegistry 中真实存在的内置模板 id。
const List<DevGallerySeed> _kSeeds = [
  // === 人像 portrait ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_portrait_soft_9x16.jpg',
    templateId: 'soft_portrait',
    mood: '温柔',
    daysAgo: 0,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_portrait_cafe_3x4.jpg',
    templateId: 'cafe_portrait',
    mood: '治愈',
    daysAgo: 1,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_portrait_sweet_1x1.jpg',
    templateId: 'sweet_girl_portrait',
    mood: '甜美',
    daysAgo: 3,
  ),
  // === 风光 landscape ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_landscape_golden_16x9.jpg',
    templateId: 'golden_landscape',
    mood: '震撼',
    daysAgo: 1,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_landscape_lake_4x3.jpg',
    templateId: 'fresh_lake',
    mood: '清新',
    daysAgo: 2,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_landscape_valley_9x16.jpg',
    templateId: 'epic_valley',
    mood: '壮阔',
    daysAgo: 5,
  ),
  // === 美食 food ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_food_brunch_1x1.jpg',
    templateId: 'overhead_brunch',
    mood: '满足',
    daysAgo: 0,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_food_closeup_3x4.jpg',
    templateId: 'closeup_soup',
    mood: '治愈',
    daysAgo: 2,
  ),
  // === 街拍 street ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_street_bw_4x3.jpg',
    templateId: 'street_bw',
    mood: '电影感',
    daysAgo: 4,
  ),
  // === 夜景 night ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_night_neon_9x16.jpg',
    templateId: 'neon_river',
    mood: '霓虹',
    daysAgo: 1,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_night_starry_9x16.jpg',
    templateId: 'starry_milkyway',
    mood: '浪漫',
    daysAgo: 6,
  ),
  // === 微距 macro ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_macro_flower_1x1.jpg',
    templateId: 'macro_flower',
    mood: '细腻',
    daysAgo: 0,
  ),
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_macro_object_3x4.jpg',
    templateId: 'object_watch',
    mood: '质感',
    daysAgo: 3,
  ),
  // === 静物 still-life ===
  DevGallerySeed(
    assetPath: 'assets/images/dev_seed/seed_still_life_16x9.jpg',
    templateId: 'minimal_book',
    mood: '简约',
    daysAgo: 7,
  ),
];

/// 执行开发期相册 seed。
///
/// 幂等：若已在文档目录存在同名图片（表示已 seed 过），整批跳过，
/// 避免每次启动重复灌入造成相册重复。失败静默（try/catch 由调用方负责）。
Future<bool> seedDevGallery(Database db) async {
  if (!kLumiraDevSeedEnabled) return false;

  // 落盘目录：应用文档目录。
  final docs = await getSafeDocumentsDirectory();
  final seedDir = Directory('${docs.path}${Platform.pathSeparator}dev_seed');
  await seedDir.create(recursive: true);

  // 幂等检查：图片已存在即认为已 seed 过。
  final first = _kSeeds.first;
  if (File('${seedDir.path}${Platform.pathSeparator}${_assetName(first.assetPath)}').existsSync()) {
    debugPrint('[dev_seed] 相册演示数据已 seed，跳过');
    return false;
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  int inserted = 0;

  for (final seed in _kSeeds) {
    // 1. 读取 asset 并落盘到文档目录
    final fileName = _assetName(seed.assetPath);
    final dest = File('${seedDir.path}${Platform.pathSeparator}$fileName');
    try {
      final data = await rootBundle.load(seed.assetPath);
      await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } catch (e) {
      debugPrint('[dev_seed] ${seed.assetPath} 落盘失败: $e');
      continue;
    }

    // 2. 写入 gallery_items：filePath 指向已落盘图片。
    final Map<String, Object?> record = {
      Tables.colId: 'dev_${now}_$inserted',
      Tables.colDataUrl: null,
      Tables.colFilePath: dest.path,
      Tables.colOriginalPath: null,
      Tables.colTransform: null,
      Tables.colPostProcess: null,
      Tables.colSceneId: seed.sceneId,
      Tables.colTemplateId: seed.templateId,
      Tables.colKitId: null,
      Tables.colMood: seed.mood,
      Tables.colLut: null,
      Tables.colGalleryItemIsFavorite: 0,
      Tables.colGalleryItemHidden: 0,
      Tables.colCreatedAt: now - seed.daysAgo * 86400000,
    };
    try {
      await db.insert(Tables.galleryItems, record);
      inserted++;
    } catch (e) {
      debugPrint('[dev_seed] gallery_items 写入失败: $e');
    }
  }

  debugPrint('[dev_seed] 相册演示数据 seed 完成，共插入 $inserted 张');
  return inserted > 0;
}

String _assetName(String assetPath) {
  final idx = assetPath.lastIndexOf('/');
  return idx >= 0 ? assetPath.substring(idx + 1) : assetPath;
}