import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'tables.dart';
import 'dao/templates_dao.dart';
import 'dao/scenes_dao.dart';
import 'dao/gallery_dao.dart';
import 'seeders/builtin_data_seeder.dart';
import '../../features/challenge/data/challenge_dao.dart';
import '../../features/academy/data/academy_dao.dart';
import 'dao/composition_kits_dao.dart';
import 'dao/api_cache_dao.dart';
import 'dao/settings_dao.dart';
import 'dao/watermark_dao.dart';
import 'dao/tutorial_read_dao.dart';
import 'dao/tags_dao.dart';
import 'dao/usage_dao.dart';
import '../../features/academy/data/academy_content.dart';
import '../../core/auth/auth_dao.dart';
import '../../features/onboarding/data/questionnaire_dao.dart';
import '../../features/profile/data/profile_dao.dart';
import '../../features/notification/data/notification_dao.dart';
import 'dao/search_history_dao.dart';

const String _kDbName = 'lumira.db';
const int _kDbVersion = 34;

/// 数据库 Provider
/// 使用 sqflite 原生插件（CPF-Flutter 鸿蒙适配版）的 getDatabasesPath()
final databaseProvider = FutureProvider<Database>((ref) async {
  final dbDir = await getDatabasesPath();
  final dbPath = p.join(dbDir, _kDbName);
  final db = await openDatabase(
    dbPath,
    version: _kDbVersion,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
  ref.onDispose(db.close);
  return db;
});

final templatesDaoProvider = FutureProvider<TemplatesDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TemplatesDao(db);
});

final scenesDaoProvider = FutureProvider<ScenesDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ScenesDao(db);
});

final galleryDaoProvider = FutureProvider<GalleryDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return GalleryDao(db);
});

final challengeDaoProvider = FutureProvider<ChallengeDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ChallengeDao(db);
});

final academyDaoProvider = FutureProvider<AcademyDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AcademyDao(db);
});

final compositionKitsDaoProvider = FutureProvider<CompositionKitsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CompositionKitsDao(db);
});

final authDaoProvider = FutureProvider<AuthDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AuthDao(db);
});

final apiCacheDaoProvider = FutureProvider<ApiCacheDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ApiCacheDao(db);
});

final settingsDaoProvider = FutureProvider<SettingsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SettingsDao(db);
});

final questionnaireDaoProvider = FutureProvider<QuestionnaireDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return QuestionnaireDao(db);
});

final userProfileDaoProvider = FutureProvider<UserProfileDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UserProfileDao(db);
});

final watermarkDaoProvider = FutureProvider<WatermarkDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return WatermarkDao(db);
});

final tutorialReadDaoProvider = FutureProvider<TutorialReadDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TutorialReadDao(db);
});

final userTagsDaoProvider = FutureProvider<TagsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TagsDao(db);
});

final usageDaoProvider = FutureProvider<UsageDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UsageDao(db);
});

final notificationDaoProvider = FutureProvider<NotificationDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return NotificationDao(db);
});

final searchHistoryDaoProvider = FutureProvider<SearchHistoryDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SearchHistoryDao(db);
});

Future<void> _onCreate(Database db, int version) async {
  final batch = db.batch();

  // === custom_templates ===
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
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
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
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
  batch.execute('CREATE INDEX IF NOT EXISTS idx_custom_templates_category ON ${Tables.customTemplates}(${Tables.colCategory})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_custom_templates_created_at ON ${Tables.customTemplates}(${Tables.colCreatedAt} DESC)');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_custom_templates_source ON ${Tables.customTemplates}(${Tables.colSource})');

  // === template_categories（v13 新增，v17 改为三级树形分类） ===
  // 主键改为自增 id（method 级 key 在不同 style 下重复，如 'normal'），
  // UNIQUE(key, parent_key) 保证同父级下 key 不重复。
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.templateCategories} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colKey} TEXT NOT NULL,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colParentKey} TEXT,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colUpdatedAt} INTEGER NOT NULL,
      UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
    )
  ''');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_template_categories_parent ON ${Tables.templateCategories}(${Tables.colParentKey})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_template_categories_level ON ${Tables.templateCategories}(${Tables.colLevel})');

  // === scenes ===
  // 仅存储用户自定义场景 + 内置场景的 is_favorite 标记
  // 内置场景的完整数据由代码常量提供
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
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
  batch.execute('CREATE INDEX IF NOT EXISTS idx_scenes_category ON ${Tables.scenes}(${Tables.colCategory})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_scenes_is_favorite ON ${Tables.scenes}(${Tables.colIsFavorite}) WHERE ${Tables.colIsFavorite} = 1');

  // === gallery_items ===
  // 图片本体优先存文件路径（file_path），data_url 保留兼容旧数据
  // v7: 新增 original_path / transform / post_process 列（非破坏性编辑支持）
  // v8: 新增 is_favorite 列（精选集"我的收藏"派生用）
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.galleryItems} (
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
  batch.execute('CREATE INDEX IF NOT EXISTS idx_gallery_items_created_at ON ${Tables.galleryItems}(${Tables.colCreatedAt} DESC)');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_gallery_items_scene_id ON ${Tables.galleryItems}(${Tables.colSceneId})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_gallery_items_is_favorite ON ${Tables.galleryItems}(${Tables.colGalleryItemIsFavorite})');

  // === user_progress (单行表，id=1) ===
  // uni-app 中未持久化，Flutter 端新增
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userProgress} (
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
  // 初始化单行
  batch.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  // === user_settings (单行表，id=1) ===
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userSettings} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colThemeKey} TEXT NOT NULL DEFAULT 'warmWhite',
      ${Tables.colUiStyle} TEXT NOT NULL DEFAULT 'neumorphic',
      ${Tables.colFollowSystem} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCaptureFullscreen} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colGridEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLevelEnabled} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colShutterSound} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colWatermark} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSeedV3Done} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colAutoDeblur} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colFreeModeCamera} TEXT,
      ${Tables.colFreeModePostProcess} TEXT,
      ${Tables.colFreeModeComposition} TEXT,
      ${Tables.colWatermarkSettings} TEXT,
      ${Tables.colCameraFacing} TEXT,
      ${Tables.colAspectRatio} TEXT,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  batch.insert(Tables.userSettings, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  // === user_tags / item_tags 表（v24，用户自定义标签 + 搜索） ===
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userTags} (
      ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colName} TEXT NOT NULL UNIQUE,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.itemTags} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
    )
  ''');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');

  await batch.commit(noResult: true);

  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute(ChallengeHistoryTable.indexDateSql);
  await db.execute(ChallengeHistoryTable.indexCategorySql);

  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
  await db.execute(AcademyTables.cfCreateSql);

  await db.execute(CompositionKitsTable.createSql);
  await db.execute(AcademyLearningTrajectoryTable.createSql);

  // === v5: auth + api_cache 表 ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.auth} (
      id INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colDeviceId} TEXT NOT NULL,
      ${Tables.colOs} TEXT NOT NULL,
      ${Tables.colToken} TEXT NOT NULL,
      ${Tables.colIsNewDevice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colRegisteredAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.apiCache} (
      ${Tables.colKey} TEXT PRIMARY KEY,
      ${Tables.colPayload} TEXT NOT NULL,
      ${Tables.colCachedAt} INTEGER NOT NULL
    )
  ''');

  // === v8: collections / collection_photos 表（精选集功能） ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.tableCollections} (
      ${Tables.colCollectionId} TEXT PRIMARY KEY,
      ${Tables.colCollectionName} TEXT NOT NULL,
      ${Tables.colCollectionDescription} TEXT,
      ${Tables.colCollectionCoverPhotoId} TEXT,
      ${Tables.colCollectionType} TEXT NOT NULL,
      ${Tables.colCollectionSourceMeta} TEXT,
      ${Tables.colCollectionPhotoCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionCreatedAt} INTEGER NOT NULL,
      ${Tables.colCollectionUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_type ON ${Tables.tableCollections}(${Tables.colCollectionType})');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON ${Tables.tableCollections}(${Tables.colCollectionUpdatedAt})');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.tableCollectionPhotos} (
      ${Tables.colCollectionPhotoCollectionId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoPhotoId} TEXT NOT NULL,
      ${Tables.colCollectionPhotoSortOrder} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCollectionPhotoAddedAt} INTEGER NOT NULL,
      PRIMARY KEY (${Tables.colCollectionPhotoCollectionId}, ${Tables.colCollectionPhotoPhotoId}),
      FOREIGN KEY (${Tables.colCollectionPhotoCollectionId}) REFERENCES ${Tables.tableCollections}(${Tables.colCollectionId}) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_collection_photos_collection ON ${Tables.tableCollectionPhotos}(${Tables.colCollectionPhotoCollectionId})');

  // === v12: questionnaire 表 ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.questionnaire} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSubmittedAt} INTEGER,
      ${Tables.colSyncedAt} INTEGER
    )
  ''');

  // === v15: user_profile 表（单行表 id=1，个人资料本地副本） ===
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.userProfile} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colUsername} TEXT NOT NULL,
      ${Tables.colAvatarSeed} TEXT NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL,
      ${Tables.colSyncedAt} INTEGER,
      ${Tables.colGender} TEXT,
      ${Tables.colFavoriteCategoriesJson} TEXT,
      ${Tables.colPainPointsJson} TEXT,
      ${Tables.colSkillLevel} TEXT,
      ${Tables.colExpectationsJson} TEXT,
      ${Tables.colCommonScenesJson} TEXT,
      ${Tables.colShootFrequency} TEXT,
      ${Tables.colAvatarUrl} TEXT
    )
  ''');

  // === v16: 探店打卡 ===
  await db.execute(CheckinTable.createSql);
  await db.execute(CheckinTable.indexVisitedAtSql);
  await db.execute(CheckinPhotoTable.createSql);
  await db.execute(CheckinPhotoTable.indexCheckinSql);

  // === v20: 自定义水印模板表 ===
  await db.execute(WatermarkTemplatesTable.createSql);
  await db.execute(WatermarkTemplatesTable.indexCreatedAtSql);

  // === v26: xp_events 经验台账表 ===
  await db.execute(XpEventsTable.createSql);
  await db.execute(XpEventsTable.indexSql);
  await _addColumnIfNotExists(
    db,
    Tables.userProgress,
    Tables.colXpRewardClaimedLevel,
    'INTEGER NOT NULL DEFAULT 0',
  );
  // 回填历史真实经验（challenge + course；失败静默）
  try {
    await _backfillXpLedger(db);
  } catch (e) {
    debugPrint('xp_events backfill (onCreate) failed: $e');
  }

  // === v29: usage_events / usage_stats 表（使用次数统计） ===
  try {
    await _createUsageTables(db);
  } catch (e) {
    debugPrint('usage tables (onCreate) failed: $e');
  }

  // === v32: notifications 表（本地通知中心） ===
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${Tables.notifications} (
        ${Tables.colId} TEXT PRIMARY KEY,
        ${Tables.colSource} TEXT NOT NULL,
        ${Tables.colRemoteId} TEXT,
        ${Tables.colKind} TEXT NOT NULL,
        ${Tables.colTitleN} TEXT NOT NULL,
        ${Tables.colBodyN} TEXT NOT NULL,
        ${Tables.colTimeMs} INTEGER NOT NULL,
        ${Tables.colRead} INTEGER NOT NULL DEFAULT 0,
        ${Tables.colCleared} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_cleared ON ${Tables.notifications}(${Tables.colCleared})');
  } catch (e) {
    debugPrint('notifications table (onCreate) failed: $e');
  }

  // === v33: search_history 表（统一全局搜索页，scope 隔离历史记录） ===
  try {
    await db.execute(SearchHistoryTable.createSql);
    await db.execute(SearchHistoryTable.indexSql);
  } catch (e) {
    debugPrint('search_history table (onCreate) failed: $e');
  }

  // === 种子化预置数据（修复：fresh install 时不触发 _onUpgrade，需在 _onCreate 中显式调用 seeder） ===
  // _onUpgrade 仅在 oldVersion < 4 时调用 BuiltinDataSeeder.seedAll，
  // 但 fresh install 直接创建 v10 数据库不会触发 _onUpgrade，导致模板表为空。
  // 此处显式调用 seeder 确保新安装也能看到内置模板。
  try {
    // v13: 预置 7 个系统分类（与内置 7 类对齐，保证离线兜底）
    await BuiltinDataSeeder.seedCategories(db);
    // v17: 预置二三级系统分类（style/method，三级树形分类）
    await BuiltinDataSeeder.seedStyleMethodCategories(db);
    await BuiltinDataSeeder.seedAll(db);
  } catch (e) {
    debugPrint('BuiltinDataSeeder in onCreate failed: $e');
  }
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // 不做 destructive 迁移（不 DROP TABLE），保留用户数据
  if (oldVersion < 2) {
    await db.execute(ChallengeHistoryTable.createSql);
    await db.execute(ChallengeHistoryTable.indexDateSql);
    await db.execute(ChallengeHistoryTable.indexCategorySql);
  }
  if (oldVersion < 3) {
    await db.execute(AcademyTables.cpCreateSql);
    await db.execute(AcademyTables.asCreateSql);
    await db.execute(AcademyTables.kfCreateSql);
  }
  if (oldVersion < 4) {
    try {
      // v4: 新增 composition_kits / academy_learning_trajectory 表
      await db.execute(CompositionKitsTable.createSql);
      await db.execute(AcademyLearningTrajectoryTable.createSql);

      // custom_templates 新增列（PRAGMA table_info 预检查保证幂等）
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colIsBuiltin,
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colIsRecommended,
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colSeedV3Done,
        'INTEGER NOT NULL DEFAULT 0',
      );

      // v4: 触发种子数据插入（失败时静默回退，spec §9）
      try {
        await BuiltinDataSeeder.seedAll(db);
      } catch (e) {
        // 忽略：DAO 查询返回空列表时由 UI 显示空状态
        debugPrint('BuiltinDataSeeder failed: $e');
      }
    } catch (e) {
      // 静默回退：迁移失败不阻塞应用启动；缺失的表/列在 DAO 层以空列表兜底
      debugPrint('v4 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 5) {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.auth} (
          id INTEGER PRIMARY KEY DEFAULT 1,
          ${Tables.colDeviceId} TEXT NOT NULL,
          ${Tables.colOs} TEXT NOT NULL,
          ${Tables.colToken} TEXT NOT NULL,
          ${Tables.colIsNewDevice} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colRegisteredAt} INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.apiCache} (
          ${Tables.colKey} TEXT PRIMARY KEY,
          ${Tables.colPayload} TEXT NOT NULL,
          ${Tables.colCachedAt} INTEGER NOT NULL
        )
      ''');
    } catch (e) {
      debugPrint('v5 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 6) {
    try {
      // v6: 新增 auto_deblur 列（自动去模糊开关，默认 1=开启）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colAutoDeblur,
        'INTEGER NOT NULL DEFAULT 1',
      );
    } catch (e) {
      debugPrint('v6 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 7) {
    try {
      // v7: 新增 original_path / transform / post_process 列（非破坏性编辑支持）
      await _addColumnIfNotExists(
        db,
        Tables.galleryItems,
        Tables.colOriginalPath,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.galleryItems,
        Tables.colTransform,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.galleryItems,
        Tables.colPostProcess,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v7 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 8) {
    try {
      // v8: gallery_items 新增 is_favorite 列（精选集"我的收藏"派生用）
      await _addColumnIfNotExists(
        db,
        Tables.galleryItems,
        Tables.colGalleryItemIsFavorite,
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_gallery_items_is_favorite ON ${Tables.galleryItems}(${Tables.colGalleryItemIsFavorite})',
      );

      // v8: collections 精选集主表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.tableCollections} (
          ${Tables.colCollectionId} TEXT PRIMARY KEY,
          ${Tables.colCollectionName} TEXT NOT NULL,
          ${Tables.colCollectionDescription} TEXT,
          ${Tables.colCollectionCoverPhotoId} TEXT,
          ${Tables.colCollectionType} TEXT NOT NULL,
          ${Tables.colCollectionSourceMeta} TEXT,
          ${Tables.colCollectionPhotoCount} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCollectionCreatedAt} INTEGER NOT NULL,
          ${Tables.colCollectionUpdatedAt} INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_type ON ${Tables.tableCollections}(${Tables.colCollectionType})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON ${Tables.tableCollections}(${Tables.colCollectionUpdatedAt})');

      // v8: collection_photos 精选集-照片关联表（仅 manual 类型使用）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.tableCollectionPhotos} (
          ${Tables.colCollectionPhotoCollectionId} TEXT NOT NULL,
          ${Tables.colCollectionPhotoPhotoId} TEXT NOT NULL,
          ${Tables.colCollectionPhotoSortOrder} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCollectionPhotoAddedAt} INTEGER NOT NULL,
          PRIMARY KEY (${Tables.colCollectionPhotoCollectionId}, ${Tables.colCollectionPhotoPhotoId}),
          FOREIGN KEY (${Tables.colCollectionPhotoCollectionId}) REFERENCES ${Tables.tableCollections}(${Tables.colCollectionId}) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_collection_photos_collection ON ${Tables.tableCollectionPhotos}(${Tables.colCollectionPhotoCollectionId})');
    } catch (e) {
      debugPrint('v8 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 9) {
    try {
      // v9: 自由模式参数持久化（相机/后期/构图 JSON）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModeCamera,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModePostProcess,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModeComposition,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v9 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 10) {
    try {
      // v10: 重新种子化内置模板
      // 修复：将内置模板从旧的 10 个（TemplatesBrowseMockData.allTemplates）
      // 更新为全量 29 个（TemplateRegistry.allTemplates，含 17 个新增人像模板）。
      // 不影响用户自定义模板（is_builtin=0）。
      await BuiltinDataSeeder.reseedBuiltinTemplates(db);
    } catch (e) {
      debugPrint('v10 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 11) {
    try {
      // v11: 新增 cover_data 列（.pptpl 自包含封面嵌入）
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colCoverData,
        'TEXT',
      );
      // v11: 修复 12 款原始模板的 cover 路径（picsum URL → 本地 asset）
      await BuiltinDataSeeder.reseedBuiltinCovers(db);
    } catch (e) {
      debugPrint('v11 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 12) {
    try {
      // v12: 新增 questionnaire 表（新用户偏好问卷）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.questionnaire} (
          ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
          ${Tables.colAnswersJson} TEXT NOT NULL DEFAULT '{}',
          ${Tables.colSubmittedAt} INTEGER,
          ${Tables.colSyncedAt} INTEGER
        )
      ''');
    } catch (e) {
      debugPrint('v12 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 13) {
    try {
      // v13: challenge_history 新增 photo_ids 列（关联用户提交的照片 id，逗号分隔）
      await _addColumnIfNotExists(
        db,
        ChallengeHistoryTable.name,
        ChallengeHistoryTable.colPhotoIds,
        "TEXT NOT NULL DEFAULT ''",
      );
    } catch (e) {
      debugPrint('v13 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 14) {
    try {
      // v14: 后台动态模板上传功能（spec 2026-08-05-remote-templates-design.md）
      // custom_templates 新增 source 列（标记来源：builtin/custom/remote）
      await _addColumnIfNotExists(
        db,
        Tables.customTemplates,
        Tables.colSource,
        "TEXT NOT NULL DEFAULT 'builtin'",
      );
      // 已有数据按 is_builtin 反推 source 值
      await db.execute(
        "UPDATE ${Tables.customTemplates} SET ${Tables.colSource} = 'custom' WHERE ${Tables.colIsBuiltin} = 0",
      );
      await db.execute(
        "UPDATE ${Tables.customTemplates} SET ${Tables.colSource} = 'builtin' WHERE ${Tables.colIsBuiltin} = 1",
      );
      // source 列索引（加速 remote 模板筛选）
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_custom_templates_source ON ${Tables.customTemplates}(${Tables.colSource})',
      );

      // v14: 新增 template_categories 表（分类管理，支持后端动态分类）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.templateCategories} (
          ${Tables.colKey} TEXT PRIMARY KEY,
          ${Tables.colName} TEXT NOT NULL,
          ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
          ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
          ${Tables.colUpdatedAt} INTEGER NOT NULL
        )
      ''');
      // 预置 7 个系统分类（与内置 7 类对齐，保证离线兜底）
      await BuiltinDataSeeder.seedCategories(db);
    } catch (e) {
      debugPrint('v14 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 15) {
    try {
      // v15: 新增 user_profile 表（单行表 id=1，个人资料本地副本）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.userProfile} (
          ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
          ${Tables.colUsername} TEXT NOT NULL,
          ${Tables.colAvatarSeed} TEXT NOT NULL,
          ${Tables.colUpdatedAt} INTEGER NOT NULL,
          ${Tables.colSyncedAt} INTEGER
        )
      ''');
    } catch (e) {
      debugPrint('v15 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 16) {
    try {
      await db.execute(CheckinTable.createSql);
      await db.execute(CheckinTable.indexVisitedAtSql);
      await db.execute(CheckinPhotoTable.createSql);
      await db.execute(CheckinPhotoTable.indexCheckinSql);
    } catch (e) {
      debugPrint('v16 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 17) {
    try {
      // v17: template_categories 表升级为三级树形分类（spec §11）
      // 新增 parent_key / level 列，主键从 key 改为自增 id + UNIQUE(key, parent_key)
      // SQLite 不支持 ALTER PRIMARY KEY，需重建表：建新表 → 复制 → DROP → RENAME
      await db.execute('''
        CREATE TABLE IF NOT EXISTS template_categories_new (
          ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${Tables.colKey} TEXT NOT NULL,
          ${Tables.colName} TEXT NOT NULL,
          ${Tables.colParentKey} TEXT,
          ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
          ${Tables.colIconUrl} TEXT NOT NULL DEFAULT '',
          ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
          ${Tables.colSortOrder} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colIsSystem} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colIsActive} INTEGER NOT NULL DEFAULT 1,
          ${Tables.colUpdatedAt} INTEGER NOT NULL,
          UNIQUE(${Tables.colKey}, ${Tables.colParentKey})
        )
      ''');
      // 复制旧一级分类数据（parent_key=NULL, level=1）
      await db.execute('''
        INSERT INTO template_categories_new
          (${Tables.colKey}, ${Tables.colName}, ${Tables.colParentKey}, ${Tables.colLevel},
           ${Tables.colIconUrl}, ${Tables.colDescription}, ${Tables.colSortOrder}, ${Tables.colIsSystem}, ${Tables.colIsActive}, ${Tables.colUpdatedAt})
        SELECT ${Tables.colKey}, ${Tables.colName}, NULL, 1,
               ${Tables.colIconUrl}, '', ${Tables.colSortOrder}, ${Tables.colIsSystem}, ${Tables.colIsActive}, ${Tables.colUpdatedAt}
        FROM ${Tables.templateCategories}
      ''');
      await db.execute('DROP TABLE IF EXISTS ${Tables.templateCategories}');
      await db.execute(
          'ALTER TABLE template_categories_new RENAME TO ${Tables.templateCategories}');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_template_categories_parent ON ${Tables.templateCategories}(${Tables.colParentKey})');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_template_categories_level ON ${Tables.templateCategories}(${Tables.colLevel})');
      // 预置所有二三级系统分类（style/method）
      await BuiltinDataSeeder.seedStyleMethodCategories(db);
    } catch (e) {
      debugPrint('v17 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 18) {
    try {
      // v18: 修复分类数据 corrupted 状态（与后端 006_fix_category_duplicates.sql 对齐）
      //
      // 问题：
      //   1. Flutter schema 的 UNIQUE(key, parent_key) 对 NULL parent_key 不生效
      //      （SQLite 将 NULL 视为互不相同），导致 seedCategories 的
      //      ConflictAlgorithm.replace 不触发，每次调用累积重复一级分类。
      //   2. 可能存在 level 与 parent_key 不一致的 corrupted 记录
      //      （如 level=2/3 但 parent_key IS NULL，被 getCategories(level:1)
      //      误返回为一级分类显示在概览页）。
      //
      // 修复：
      //   1. 删除 level 与 parent_key 不一致的记录
      //   2. 清理重复一级分类（每个 key+parent_key 仅保留 MIN(id)）
      //   3. 新增 NULL 安全唯一索引 (key, COALESCE(parent_key, ''))
      //      使后续 INSERT OR IGNORE 对一级分类同样幂等
      await _fixCategoryData(db);
    } catch (e) {
      debugPrint('v18 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 19) {
    try {
      // v19: 删除被误标为一级的二级/三级分类记录
      //
      // v18 遗留问题：v18 的去重按 (key, IFNULL(parent_key, '')) 分组保留 MIN(id)，
      // 但无法捕获以下 corrupted 场景：
      //   - key='japanese', level=1, parent_key=NULL（被误标为一级）
      //   - key='japanese', level=2, parent_key='portrait'（正确的二级分类）
      // 两条记录的 (key, parent_key) 分组不同（('japanese','') vs ('japanese','portrait')），
      // v18 去重后两者均存活。getCategories(level:1) 查询 level=1 AND parent_key IS NULL
      // 会返回 corrupted 的 'japanese' 一级记录，导致概览页出现二级分类。
      //
      // 修复：删除 level=1 且 parent_key IS NULL 且 key 存在于 level>1 记录中的记录。
      // 安全性：7 个合法一级 key（portrait/landscape/food/street/night/macro/still-life）
      // 均不出现在 level>1 的 seed 数据中，因此只会删除 corrupted 记录。
      await db.execute('''
        DELETE FROM ${Tables.templateCategories}
        WHERE ${Tables.colLevel} = 1
          AND ${Tables.colParentKey} IS NULL
          AND ${Tables.colKey} IN (
            SELECT ${Tables.colKey}
            FROM ${Tables.templateCategories}
            WHERE ${Tables.colLevel} > 1
          )
      ''');
    } catch (e) {
      debugPrint('v19 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 20) {
    try {
      // v20: 自定义水印模板表（watermark feature data layer）
      // 存储用户自定义水印模板，config 列保存 WatermarkTemplate.toJson() JSON 字符串。
      // 预置模板（getPresetWatermarks()）不入库，运行时由 presetWatermarksProvider 提供。
      await db.execute(WatermarkTemplatesTable.createSql);
      await db.execute(WatermarkTemplatesTable.indexCreatedAtSql);
    } catch (e) {
      debugPrint('v20 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 21) {
    try {
      // v21: user_settings 新增 watermark_settings TEXT 列（水印设置持久化）
      // 存储 WatermarkSettings.toJson() JSON 字符串
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colWatermarkSettings,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v21 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 22) {
    try {
      // v22: user_settings 新增 camera_facing / aspect_ratio 列（拍摄页偏好持久化）
      // 前后置摄像头选择 + 照片比例，退出拍摄页/App 后下次进入自动恢复
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colCameraFacing,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colAspectRatio,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v22 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 23) {
    try {
      // v23: 小教程已读记录表（拍摄小课堂）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.tutorialReads} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colTutorialReadAt} INTEGER
        )
      ''');
    } catch (e) {
      debugPrint('v23 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 24) {
    try {
      // v24: 用户自定义标签表（标签字典 + 绑定关系）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.userTags} (
          ${Tables.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
          ${Tables.colName} TEXT NOT NULL UNIQUE,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.itemTags} (
          ${Tables.colItemType} TEXT NOT NULL,
          ${Tables.colItemId} TEXT NOT NULL,
          ${Tables.colTagId} INTEGER NOT NULL REFERENCES ${Tables.userTags}(${Tables.colId}) ON DELETE CASCADE,
          ${Tables.colCreatedAt} INTEGER NOT NULL,
          PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId})
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_tag_id ON ${Tables.itemTags}(${Tables.colTagId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_item_tags_item ON ${Tables.itemTags}(${Tables.colItemType}, ${Tables.colItemId})');
    } catch (e) {
      debugPrint('v24 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 25) {
    try {
      await db.execute(AcademyTables.cfCreateSql);
    } catch (e) {
      debugPrint('v25 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 26) {
    try {
      await db.execute(XpEventsTable.createSql);
      await db.execute(XpEventsTable.indexSql);
      await _addColumnIfNotExists(
        db,
        Tables.userProgress,
        Tables.colXpRewardClaimedLevel,
        'INTEGER NOT NULL DEFAULT 0',
      );
      // 回填历史真实经验，确保老用户经验曲线不跳变
      await _backfillXpLedger(db);
    } catch (e) {
      debugPrint('v26 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 27) {
    try {
      // v27: user_profile 新增 8 列（性别/偏好/技能/期望/场景/频率/自定义头像）
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colGender, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colFavoriteCategoriesJson, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colPainPointsJson, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colSkillLevel, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colExpectationsJson, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colCommonScenesJson, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colShootFrequency, 'TEXT');
      await _addColumnIfNotExists(db, Tables.userProfile, Tables.colAvatarUrl, 'TEXT');
    } catch (e) {
      debugPrint('v27 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 28) {
    try {
      // v28: user_settings 新增 theme_key / ui_style 列（主题与 UI 风格持久化）
      // 老库升级需显式补列，否则启动时 SettingsDao 查询会报 no such column。
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colThemeKey,
        "TEXT NOT NULL DEFAULT 'warmWhite'",
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colUiStyle,
        "TEXT NOT NULL DEFAULT 'neumorphic'",
      );
    } catch (e) {
      debugPrint('v28 migration failed (silent fallback): $e');
    }
  }
  if (oldVersion < 29) {
    try {
      // v29: usage_events / usage_stats 表（使用次数统计埋点）
      await _createUsageTables(db);
    } catch (e) {
      debugPrint('v29 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 30) {
    try {
      // v30: template_categories 新增 description 列（简短描述，可为空，仅一二级分类）
      await db.execute(
        'ALTER TABLE ${Tables.templateCategories} ADD COLUMN ${Tables.colDescription} TEXT NOT NULL DEFAULT \'\'');
    } catch (e) {
      debugPrint('v30 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 31) {
    try {
      // v31: scenes 新增 cover_url 列（自定义场景封面图，存 base64 data URL）
      await _addColumnIfNotExists(
        db,
        Tables.scenes,
        Tables.colCoverUrl,
        "TEXT NOT NULL DEFAULT ''",
      );
    } catch (e) {
      debugPrint('v31 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 32) {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${Tables.notifications} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colSource} TEXT NOT NULL,
          ${Tables.colRemoteId} TEXT,
          ${Tables.colKind} TEXT NOT NULL,
          ${Tables.colTitleN} TEXT NOT NULL,
          ${Tables.colBodyN} TEXT NOT NULL,
          ${Tables.colTimeMs} INTEGER NOT NULL,
          ${Tables.colRead} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCleared} INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_cleared ON ${Tables.notifications}(${Tables.colCleared})');
    } catch (e) {
      debugPrint('v32 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 33) {
    try {
      // v33: 搜索历史表（统一全局搜索页 scope 隔离历史记录）
      await db.execute(SearchHistoryTable.createSql);
      await db.execute(SearchHistoryTable.indexSql);
    } catch (e) {
      debugPrint('v33 migration failed (silent fallback): $e');
    }
  }

  if (oldVersion < 34) {
    try {
      // v34: user_settings 新增 template_info_card_hidden 列
      // 套用模板时的可折叠模板信息卡是否被用户隐藏（持久化），老库升级需显式补列
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colTemplateInfoCardHidden,
        'INTEGER NOT NULL DEFAULT 0',
      );
    } catch (e) {
      debugPrint('v34 migration failed (silent fallback): $e');
    }
  }
}

/// 修复 template_categories 表中的 corrupted 数据（v18 迁移）。
///
/// 1. 删除 level 与 parent_key 不一致的记录：
///    - level=1 但 parent_key NOT NULL → 应为 NULL
///    - level>1 但 parent_key IS NULL → 应有父分类
/// 2. 清理重复记录（每个 key+COALESCE(parent_key,'') 仅保留 MIN(id)）
/// 3. 创建 NULL 安全唯一索引
Future<void> _fixCategoryData(Database db) async {
  // 1. 删除 level 与 parent_key 不一致的 corrupted 记录
  // level>1 但 parent_key IS NULL：这些是被误标为一级的二级/三级分类
  await db.execute('''
    DELETE FROM ${Tables.templateCategories}
    WHERE ${Tables.colLevel} > 1 AND ${Tables.colParentKey} IS NULL
  ''');
  // level=1 但 parent_key NOT NULL：这些是被误标为一级但有父分类的记录
  await db.execute('''
    DELETE FROM ${Tables.templateCategories}
    WHERE ${Tables.colLevel} = 1 AND ${Tables.colParentKey} IS NOT NULL
  ''');

  // 2. 清理重复记录（每个 key+COALESCE(parent_key,'') 仅保留 MIN(id)）
  //    与后端 006_fix_category_duplicates.sql 逻辑一致
  await db.execute('''
    DELETE FROM ${Tables.templateCategories}
    WHERE ${Tables.colId} NOT IN (
      SELECT MIN(${Tables.colId})
      FROM ${Tables.templateCategories}
      GROUP BY ${Tables.colKey}, IFNULL(${Tables.colParentKey}, '')
    )
  ''');

  // 3. NULL 安全唯一索引（COALESCE 将 NULL 归一为 ''，使唯一约束对一级分类生效）
  //    sqflite 不支持 COALESCE 在 CREATE UNIQUE INDEX 中直接使用，
  //    故用计算列方式创建表达式索引
  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS uq_category_key_parent_null_safe
    ON ${Tables.templateCategories}(${Tables.colKey}, IFNULL(${Tables.colParentKey}, ''))
  ''');
}

/// 从历史表回填 xp_events 台账（INSERT OR IGNORE 幂等）。
/// - challenge：challenge_history 已完成 → source='challenge', amount=reward_xp, ref_id=id
/// - course：academy_course_progress status='completed' → source='course',
///   amount=该课 rewardXP（AcademyContent 构建 id→rewardXP 映射，找不到的跳过避免虚增）
Future<void> _backfillXpLedger(Database db) async {
  // --- challenge ---
  final chRows = await db.rawQuery('''
    SELECT ${ChallengeHistoryTable.colId} AS id,
           ${ChallengeHistoryTable.colRewardXp} AS xp
    FROM ${ChallengeHistoryTable.name}
    WHERE ${ChallengeHistoryTable.colStatus} = 'done'
  ''');
  for (final r in chRows) {
    final id = r['id'] as String?;
    final xp = (r['xp'] as num?)?.toInt() ?? 0;
    if (id == null || id.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'challenge:$id',
      XpEventsTable.colSource: 'challenge',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: id,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // --- course（id→rewardXP 映射来自 AcademyContent.courses） ---
  final Map<String, int> courseXp = {};
  for (final c in AcademyContent.courses) {
    courseXp[c.id] = c.rewardXP;
  }
  final cpRows = await db.rawQuery('''
    SELECT ${AcademyTables.cpColCourseId} AS cid
    FROM ${AcademyTables.courseProgress}
    WHERE ${AcademyTables.cpColStatus} = 'completed'
  ''');
  for (final r in cpRows) {
    final cid = r['cid'] as String?;
    final xp = cid == null ? 0 : (courseXp[cid] ?? 0);
    if (cid == null || cid.isEmpty || xp <= 0) continue;
    await db.insert(XpEventsTable.name, {
      'id': 'course:$cid',
      XpEventsTable.colSource: 'course',
      XpEventsTable.colAmount: xp,
      XpEventsTable.colRefId: cid,
      XpEventsTable.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

/// 安全添加列：若列已存在则跳过（迁移幂等）
Future<void> _addColumnIfNotExists(
  Database db,
  String table,
  String column,
  String typeClause,
) async {
  final cols = await db.rawQuery('PRAGMA table_info($table)');
  final exists = cols.any((c) => c['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $typeClause');
  }
}

/// 创建使用次数统计表（v29，幂等）。
/// - usage_events：逐条埋点事件（client_event_id 唯一供幂等上报）
/// - usage_stats：全站汇总快照（主键 item_type+item_id+event_type）
Future<void> _createUsageTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageEvents} (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ${Tables.colClientEventId} TEXT NOT NULL UNIQUE,
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colItemSource} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colOccurredAt} INTEGER NOT NULL,
      ${Tables.colSynced} INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.usageStats} (
      ${Tables.colItemType} TEXT NOT NULL,
      ${Tables.colItemId} TEXT NOT NULL,
      ${Tables.colEventType} TEXT NOT NULL,
      ${Tables.colCount} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUpdatedAt} INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colEventType})
    )
  ''');
}
