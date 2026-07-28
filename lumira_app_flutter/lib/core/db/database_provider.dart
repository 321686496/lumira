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
import '../../core/auth/auth_dao.dart';

const String _kDbName = 'lumira.db';
const int _kDbVersion = 5;

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
  batch.execute('CREATE INDEX IF NOT EXISTS idx_custom_templates_category ON ${Tables.customTemplates}(${Tables.colCategory})');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_custom_templates_created_at ON ${Tables.customTemplates}(${Tables.colCreatedAt} DESC)');

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
  batch.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_gallery_items_created_at ON ${Tables.galleryItems}(${Tables.colCreatedAt} DESC)');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_gallery_items_scene_id ON ${Tables.galleryItems}(${Tables.colSceneId})');

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
