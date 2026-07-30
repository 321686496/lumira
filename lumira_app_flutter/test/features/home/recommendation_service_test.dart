import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/growth_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/home/services/recommendation_service.dart';

/// RecommendationService 单元测试
///
/// 覆盖场景：
/// 1. 新用户槽位 1（totalPhotos < 3 → 第一条为新用户引导）
/// 2. 老用户槽位 5 重复（totalPhotos >= 3 → 2 条探索 banner）
/// 3. 冷启动全 fallback（无 gallery / 无 favorites / 无 kits → 5 条均来自系统推荐）
/// 4. 5 条 banner 去重（templateId 不重复）
void main() {
  late Database db;
  late GalleryDao galleryDao;
  late ScenesDao scenesDao;
  late TemplatesDao templatesDao;
  late CompositionKitsDao kitsDao;
  late GrowthDao growthDao;
  late RecommendationService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('rec_service_test_');
    final dbPath = p.join(tempDir.path, 'test_rec.db');
    db = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    galleryDao = GalleryDao(db);
    scenesDao = ScenesDao(db);
    templatesDao = TemplatesDao(db);
    kitsDao = CompositionKitsDao(db);
    growthDao = GrowthDao(db);
    service = RecommendationService(
      galleryDao: galleryDao,
      scenesDao: scenesDao,
      templatesDao: templatesDao,
      kitsDao: kitsDao,
      growthDao: growthDao,
    );
  });

  tearDown(() async => db.close());

  group('RecommendationService.buildBanners', () {
    test('新用户槽位 1：totalPhotos < 3 → 第一条为新用户引导', () async {
      // Seed: 5 个不同分类的 recommended 模板（保证 fallback 充足）
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      // Seed: 2 gallery items (totalPhotos=2 < 3 → 新用户)
      // 关联 scene 有 related_category='portrait'，使 countByCategory 返回 {'portrait': 2}
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      await _seedGalleryItem(db, id: 'g1', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await _seedGalleryItem(db, id: 'g2', sceneId: 'scene_p1', templateId: 'tpl_p1');

      // 设置 user_progress.total_photos = 2
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 2},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 应有 5 条 banner
      expect(banners.length, 5);

      // 槽位 1：新用户引导
      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.tag, '新手友好');
      expect(banners.first.title, '新手友好场景');
      expect(banners.first.subtitle, '从咖啡馆开始你的拍摄之旅');
      expect(banners.first.route, '/capture/scene-guide?scene=preset_cafe');

      // 槽位 2：基于最近拍摄分类（portrait）
      // 应使用 tpl_p1（portrait 类别 recommended 模板）
      expect(banners[1].id, 'banner_recent_category');
      expect(banners[1].tag, '常拍分类');
      expect(banners[1].title, '继续拍人像');
      expect(banners[1].route, '/templates/detail?templateId=tpl_p1');
    });

    test('老用户槽位 5 重复：totalPhotos >= 3 → 2 条探索 banner', () async {
      // Seed: 5 个不同分类的 recommended 模板
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      // Seed: 5 gallery items 都在 portrait 类别（totalPhotos=5 → 老用户）
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }

      // 设置 user_progress.total_photos = 5
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 应有 5 条 banner
      expect(banners.length, 5);

      // 槽位 1 不应出现（老用户）
      expect(banners.first.id, isNot('banner_new_user_guide'));

      // 应有 2 条探索 banner（banner_exploration + banner_exploration_extra）
      final explorationBanners =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(explorationBanners.length, 2,
          reason: '老用户应通过槽位 5 补位得到 2 条探索 banner');

      // 两条探索 banner 的 id 应不同
      expect(explorationBanners.first.id != explorationBanners.last.id, isTrue);
      // 两条探索 banner 应使用不同的分类
      expect(explorationBanners.first.title != explorationBanners.last.title,
          isTrue,
          reason: '两条探索 banner 应针对不同分类');
    });

    test('冷启动全 fallback：无 gallery / 无 favorites / 无 kits → 5 条均来自系统推荐', () async {
      // Seed: 5 个 recommended 模板，不 seed 任何 gallery/favorites/kits
      // total_photos = 0 → 新用户 → 槽位 1 为新用户引导
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      // 不 seed gallery_items / scenes / composition_kits
      // user_progress.total_photos 保持默认 0 → 新用户

      final banners = await service.buildBanners();

      // 应有 5 条 banner
      expect(banners.length, 5);

      // 槽位 1：新用户引导（无 template）
      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.route, '/capture/scene-guide?scene=preset_cafe');

      // 槽位 2-5：均应跳转到 /templates/detail?templateId=xxx
      final templateRoutes = banners
          .where((b) => b.route.startsWith('/templates/detail?templateId='))
          .toList();
      expect(templateRoutes.length, 4,
          reason: '槽位 2/3/4/5 均应 fallback 到系统推荐模板');

      // 槽位 2 的 tag 应为 "编辑精选"（无 topCategory fallback）
      expect(banners[1].tag, '编辑精选');
      expect(banners[2].tag, '编辑精选');
      expect(banners[3].tag, '编辑精选');
    });

    test('5 条 banner 去重：templateId 不重复', () async {
      // Seed: 6 个不同分类的 recommended 模板（保证充足）
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');
      await _seedTemplate(db, id: 'tpl_m1', name: '微距模板', category: 'macro', isRecommended: true, description: '微距模板');

      // Seed: 3 gallery items（totalPhotos=3 → 老用户，触发槽位 5 补位）
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 3; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 3},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 应有 5 条 banner
      expect(banners.length, 5);

      // 收集所有 banner 中的 templateId（从 route 提取）
      final templateIds = banners
          .where((b) => b.route.contains('templateId='))
          .map((b) => b.route.split('templateId=').last)
          .toList();

      // 所有 templateId 应唯一
      expect(templateIds.toSet().length, templateIds.length,
          reason: 'templateId 在 5 条 banner 中应全部唯一');

      // 应至少有 4 个 template-based banner（老用户：槽位 2/3/4/5/5-extra）
      expect(templateIds.length, greaterThanOrEqualTo(4));
    });

    test('收藏场景：slot 3 使用 favorite scene 的名称与路由', () async {
      // Seed: 充足模板 + 1 个收藏场景（带 name，模拟用户自定义场景）
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      // 用户自定义场景（isFavorite=1，name 非空）
      await _seedScene(db, id: 'scene_user_1', name: '我的咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: true);

      // 老用户
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 3; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 3},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      expect(banners.length, 5);

      // 应存在 id='banner_favorite_scene' 的 banner
      final favBanner = banners.firstWhere((b) => b.id == 'banner_favorite_scene');
      expect(favBanner.title, '我的咖啡馆灵感');
      expect(favBanner.tag, '收藏场景');
      expect(favBanner.route, '/capture/scene-guide?scene=scene_user_1');
    });

    test('HomeBannerItem 字段完整性：每条 banner 字段非空', () async {
      // 最小数据集验证：所有 banner 必填字段都有值
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      final banners = await service.buildBanners();

      expect(banners.length, 5);
      for (final b in banners) {
        expect(b.id, isNotEmpty, reason: 'id 不能为空');
        expect(b.title, isNotEmpty, reason: 'title 不能为空');
        expect(b.subtitle, isNotEmpty, reason: 'subtitle 不能为空');
        expect(b.imageSeed, isNotEmpty, reason: 'imageSeed 不能为空');
        expect(b.tag, isNotEmpty, reason: 'tag 不能为空');
        expect(b.route, isNotEmpty, reason: 'route 不能为空');
        // route 应是合法的内部路由
        expect(b.route.startsWith('/'), isTrue,
            reason: 'route 应以 / 开头：${b.route}');
      }
    });
  });
}

/// 测试库 schema：创建所有 RecommendationService 涉及的表
Future<void> _onCreate(Database db, int version) async {
  // gallery_items
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colOriginalPath} TEXT,
      ${Tables.colTransform} TEXT,
      ${Tables.colPostProcess} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  // scenes
  await db.execute('''
    CREATE TABLE ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  // custom_templates
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  // composition_kits
  await db.execute(CompositionKitsTable.createSql);
  // user_progress (单行，id=1，默认 total_photos=0)
  await db.execute('''
    CREATE TABLE ${Tables.userProgress} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colLevelName} TEXT NOT NULL DEFAULT '新手',
      ${Tables.colXp} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colXpToNextLevel} INTEGER NOT NULL DEFAULT 100,
      ${Tables.colTotalPhotos} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUsedTemplates} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colFavorites} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colStreakDays} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLastCheckInDate} TEXT,
      ${Tables.colFragmentsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colAchievementsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}

/// Seed 一个内置模板（is_builtin=1）
Future<void> _seedTemplate(
  Database db, {
  required String id,
  required String name,
  required String category,
  required bool isRecommended,
  required String description,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.customTemplates, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colDescription: description,
    Tables.colIsBuiltin: 1,
    Tables.colIsRecommended: isRecommended ? 1 : 0,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}

/// Seed 一条 gallery 记录
Future<void> _seedGalleryItem(
  Database db, {
  required String id,
  String? sceneId,
  String? templateId,
}) async {
  await db.insert(Tables.galleryItems, {
    Tables.colId: id,
    Tables.colSceneId: sceneId,
    Tables.colTemplateId: templateId,
    Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
  });
}

/// Seed 一个场景记录
Future<void> _seedScene(
  Database db, {
  required String id,
  required String name,
  required String category,
  required String relatedCategory,
  required bool isFavorite,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.scenes, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colRelatedCategory: relatedCategory,
    Tables.colIsFavorite: isFavorite ? 1 : 0,
    Tables.colCreatedAt: now,
    Tables.colUpdatedAt: now,
  });
}
