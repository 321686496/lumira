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
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/data/operation_banners.dart';
import 'package:lumira_app_flutter/features/home/services/recommendation_service.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_dao.dart';

/// RecommendationService 单元测试
///
/// 覆盖场景（4 槽位语义）：
/// 1. 新用户无运营位：引导 + 收藏位 fallback + 探索（3 条）
/// 2. 老用户无运营位：常拍 + 收藏位 fallback + 2 条探索（4 条）
/// 3. 运营位 slot 0：各条件命中/优先级/新用户不满足
/// 4. 冷启动全 fallback / 去重 / 收藏场景 / 老用户判定自愈 / 字段完整性
/// 5. 文案钩子：探索位社会证明、常拍位情绪化标题
void main() {
  late Database db;
  late GalleryDao galleryDao;
  late ScenesDao scenesDao;
  late TemplatesDao templatesDao;
  late CompositionKitsDao kitsDao;
  late GrowthDao growthDao;
  late QuestionnaireDao questionnaireDao;
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
    questionnaireDao = QuestionnaireDao(db);
    service = RecommendationService(
      galleryDao: galleryDao,
      scenesDao: scenesDao,
      templatesDao: templatesDao,
      kitsDao: kitsDao,
      growthDao: growthDao,
      questionnaireDao: questionnaireDao,
    );
  });

  tearDown(() async => db.close());

  group('RecommendationService.buildBanners', () {
    test('新用户：引导占 slot 1，探索文案为社会证明（3 条）', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_p2', name: '人像进阶', category: 'portrait', isRecommended: true, description: '进阶质感人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      await _seedGalleryItem(db, id: 'g1', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await _seedGalleryItem(db, id: 'g2', sceneId: 'scene_p1', templateId: 'tpl_p1');

      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 2},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 4 槽位语义：新用户无运营位 → 引导 + 收藏位 fallback + 探索 = 3 条
      expect(banners.length, 3);

      // slot 1（新用户前置判断）：新用户引导
      expect(banners[0].id, 'banner_new_user_guide');
      expect(banners[0].tag, '新手友好');
      expect(banners[0].title, '新手友好场景');
      expect(banners[0].subtitle, '从咖啡馆开始你的拍摄之旅');
      expect(banners[0].route, '/capture/scene-detail?sceneId=preset_cafe');
      expect(banners[0].type, BannerType.recommend);

      // slot 2：无收藏/套件 → 系统推荐 fallback；bannerId 带来源模板 id，
      // 且排除最近用过的 tpl_p1（相册存在该模板照片）
      expect(banners[1].id, 'banner_favorite_scene_fallback');
      expect(banners[1].bannerId, startsWith('banner_favorite_scene_fallback:'));
      expect(banners[1].bannerId, isNot(contains('tpl_p1')));

      // slot 3：探索新鲜感，社会证明文案
      expect(banners[2].id, 'banner_exploration');
      expect(banners[2].title, '大家都在拍人像');
      expect(banners[2].bannerId, startsWith('banner_exploration:'));

      // 全部为个性化位
      expect(banners.every((b) => b.type == BannerType.recommend), isTrue);
    });

    test('老用户：无运营位 → 4 条，2 条探索补位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_p2', name: '人像进阶', category: 'portrait', isRecommended: true, description: '进阶质感人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 4 条；首槽不再是新手引导
      expect(banners.length, 4);
      expect(banners.first.id, isNot('banner_new_user_guide'));

      // slot 1：常拍分类（无 shortDesc → 功能型标题回退），排除最近用过的 tpl_p1
      expect(banners[0].id, 'banner_recent_category');
      expect(banners[0].tag, '常拍分类');
      expect(banners[0].title, '继续拍人像');
      expect(banners[0].bannerId, 'banner_recent_category:tpl_p2');
      expect(banners[0].subtitle, '你最近常拍人像，试试这套模板');

      // 老用户无运营位 → 补一条探索，共 2 条
      final explorationBanners =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(explorationBanners.length, 2);
      expect(explorationBanners.first.id != explorationBanners.last.id, isTrue);
      expect(explorationBanners.first.title != explorationBanners.last.title, isTrue);
    });

    test('冷启动全 fallback：新用户无任何数据 → 引导 + 2 条系统推荐', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '适合新手的自然光人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光摄影模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食摄影模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      final banners = await service.buildBanners();

      // 新用户：引导 + 收藏位 fallback + 探索 = 3 条
      expect(banners.length, 3);
      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.route, '/capture/scene-detail?sceneId=preset_cafe');

      // 收藏位 fallback 与探索位均来自系统推荐模板
      final templateRoutes = banners
          .where((b) => b.route.startsWith('/templates/detail?templateId='))
          .toList();
      expect(templateRoutes.length, 2,
          reason: '收藏位 fallback + 探索位均为系统推荐模板');

      expect(banners[1].tag, '为你精选');
      expect(banners[2].tag, '探索新鲜');
    });

    test('4 条 banner 去重：templateId 不重复', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');
      await _seedTemplate(db, id: 'tpl_m1', name: '微距模板', category: 'macro', isRecommended: true, description: '微距模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 3; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 3},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // 老用户无运营位：4 条全部为模板类
      expect(banners.length, 4);
      final templateIds = banners
          .where((b) => b.route.contains('templateId='))
          .map((b) => b.route.split('templateId=').last)
          .toList();
      expect(templateIds.length, 4);
      expect(templateIds.toSet().length, templateIds.length,
          reason: 'templateId 在 4 条 banner 中应全部唯一');
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

      expect(banners.length, 4);

      // 应存在 id='banner_favorite_scene' 的 banner
      final favBanner = banners.firstWhere((b) => b.id == 'banner_favorite_scene');
      expect(favBanner.title, '我的咖啡馆灵感');
      expect(favBanner.tag, '收藏场景');
      expect(favBanner.route, '/capture/scene-detail?sceneId=scene_user_1');
    });

    test('老用户判定自愈：user_progress.total_photos 恒 0（历史 Bug）但有≥3张相册照片 → 不再推新手友好场景', () async {
      // 模拟历史版本 Bug：total_photos 从未递增（保持 0），但相册里其实已有照片
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      // 相册里有 4 张照片，但 user_progress.total_photos 未更新（保持 0）
      for (var i = 0; i < 4; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      // 不更新 user_progress，total_photos 保持默认 0

      final banners = await service.buildBanners();

      // 应被判定为老用户：首槽不再是新手友好场景
      expect(banners.first.id, isNot('banner_new_user_guide'));
      // 4 条，且老用户无运营位时有 2 条探索
      expect(banners.length, 4);
      final exploration =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(exploration.length, 2);
    });

    test('HomeBannerItem 字段完整性：每条 banner 字段非空', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');

      final banners = await service.buildBanners();

      expect(banners.length, 3);
      for (final b in banners) {
        expect(b.id, isNotEmpty, reason: 'id 不能为空');
        expect(b.title, isNotEmpty, reason: 'title 不能为空');
        expect(b.subtitle, isNotEmpty, reason: 'subtitle 不能为空');
        expect(b.imageSeed, isNotEmpty, reason: 'imageSeed 不能为空');
        expect(b.tag, isNotEmpty, reason: 'tag 不能为空');
        expect(b.route, isNotEmpty, reason: 'route 不能为空');
        expect(b.route.startsWith('/'), isTrue,
            reason: 'route 应以 / 开头：${b.route}');
        expect(b.trackingId, isNotEmpty, reason: 'trackingId 不能为空');
        expect(b.type, BannerType.recommend);
      }
    });

    test('运营位 slot 0：老用户未绑定邀请 → 邀请运营位占位且不补探索', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedTemplate(db, id: 'tpl_f1', name: '美食模板', category: 'food', isRecommended: true, description: '美食模板');
      await _seedTemplate(db, id: 'tpl_s1', name: '街拍模板', category: 'street', isRecommended: true, description: '街拍模板');
      await _seedTemplate(db, id: 'tpl_n1', name: '夜景模板', category: 'night', isRecommended: true, description: '夜景模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasBoundInviter: false),
      );

      expect(banners.length, 4);
      // slot 0：运营位
      expect(banners.first.id, 'op_invite');
      expect(banners.first.type, BannerType.operation);
      expect(banners.first.bannerId, 'op_invite');
      expect(banners.first.tag, '邀请有礼');
      expect(banners.first.route, '/invite');
      // slot 0 有运营位 → 老用户不补探索，仅 1 条
      final exploration =
          banners.where((b) => b.id.startsWith('banner_exploration')).toList();
      expect(exploration.length, 1);
      // 其余槽位仍是个性化
      expect(banners[1].id, 'banner_recent_category');
      expect(banners[2].id, 'banner_favorite_scene_fallback');
    });

    test('运营位 slot 0：已绑定邀请但有积分 → 积分运营位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(
          hasBoundInviter: true,
          pointsBalance: 30,
        ),
      );

      expect(banners.first.id, 'op_points');
      expect(banners.first.type, BannerType.operation);
      expect(banners.first.route, '/points/wallet');
    });

    test('运营位 slot 0：存在未解锁付费模板 → 上新运营位', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasLockedTemplate: true),
      );

      expect(banners.first.id, 'op_unlock');
      expect(banners.first.route, '/templates/unlock');
    });

    test('运营位 slot 0：多条件满足 → 目录顺序优先（邀请）', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(
          hasBoundInviter: false,
          pointsBalance: 30,
          hasLockedTemplate: true,
        ),
      );

      expect(banners.first.id, 'op_invite');
    });

    test('新用户不满足邀请条件（即使未绑定）→ slot 0 让位引导', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      await _seedGalleryItem(db, id: 'g1', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await _seedGalleryItem(db, id: 'g2', sceneId: 'scene_p1', templateId: 'tpl_p1');
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 2},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners(
        operationInputs: const OperationUserInputs(hasBoundInviter: false),
      );

      expect(banners.first.id, 'banner_new_user_guide');
      expect(banners.first.type, BannerType.recommend);
    });

    test('文案钩子：常拍模板有 shortDesc 时标题用它', () async {
      await _seedTemplate(db, id: 'tpl_p1', name: '人像基础', category: 'portrait', isRecommended: true, description: '人像模板');
      await _seedTemplate(db, id: 'tpl_p2', name: '人像进阶', category: 'portrait', isRecommended: true, description: '进阶质感人像模板', shortDesc: '雷阵雨后的街头光影');
      await _seedTemplate(db, id: 'tpl_l1', name: '风光基础', category: 'landscape', isRecommended: true, description: '风光模板');
      await _seedScene(db, id: 'scene_p1', name: '咖啡馆', category: 'cafe', relatedCategory: 'portrait', isFavorite: false);
      for (var i = 0; i < 5; i++) {
        await _seedGalleryItem(db, id: 'g$i', sceneId: 'scene_p1', templateId: 'tpl_p1');
      }
      await db.update(Tables.userProgress, {Tables.colTotalPhotos: 5},
          where: '${Tables.colId} = ?', whereArgs: [1]);

      final banners = await service.buildBanners();

      // slot 1：排除最近用过的 tpl_p1 → tpl_p2，标题用其 shortDesc（情绪价值）
      expect(banners[0].id, 'banner_recent_category');
      expect(banners[0].title, '雷阵雨后的街头光影');
      expect(banners[0].subtitle, '你最近常拍人像，试试这套模板');
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
      ${Tables.colCoverUrl} TEXT NOT NULL DEFAULT '',
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
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  // composition_kits
  await db.execute(CompositionKitsTable.createSql);
  // questionnaire（单行表，id=1；与 database_provider v12 迁移保持一致）
  await db.execute('''
    CREATE TABLE ${Tables.questionnaire} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSubmittedAt} INTEGER,
      ${Tables.colSyncedAt} INTEGER
    )
  ''');
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
  String shortDesc = '',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert(Tables.customTemplates, {
    Tables.colId: id,
    Tables.colName: name,
    Tables.colCategory: category,
    Tables.colDescription: description,
    Tables.colShortDesc: shortDesc,
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
