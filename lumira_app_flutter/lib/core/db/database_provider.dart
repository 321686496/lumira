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
import '../../core/auth/auth_dao.dart';
import '../../features/onboarding/data/questionnaire_dao.dart';
import '../../features/profile/data/profile_dao.dart';

const String _kDbName = 'lumira.db';
const int _kDbVersion = 16;

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

  // === template_categories（v13 新增，分类管理） ===
  batch.execute('''
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
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  batch.insert(Tables.userSettings, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  await batch.commit(noResult: true);

  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute(ChallengeHistoryTable.indexDateSql);
  await db.execute(ChallengeHistoryTable.indexCategorySql);

  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);

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
      ${Tables.colSyncedAt} INTEGER
    )
  ''');

  // === v16: 探店打卡 ===
  await db.execute(CheckinTable.createSql);
  await db.execute(CheckinTable.indexVisitedAtSql);
  await db.execute(CheckinPhotoTable.createSql);
  await db.execute(CheckinPhotoTable.indexCheckinSql);

  // === 种子化预置数据（修复：fresh install 时不触发 _onUpgrade，需在 _onCreate 中显式调用 seeder） ===
  // _onUpgrade 仅在 oldVersion < 4 时调用 BuiltinDataSeeder.seedAll，
  // 但 fresh install 直接创建 v10 数据库不会触发 _onUpgrade，导致模板表为空。
  // 此处显式调用 seeder 确保新安装也能看到内置模板。
  try {
    // v13: 预置 7 个系统分类（与内置 7 类对齐，保证离线兜底）
    await BuiltinDataSeeder.seedCategories(db);
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
