import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'tables.dart';
import 'dao/templates_dao.dart';
import 'dao/scenes_dao.dart';
import 'dao/gallery_dao.dart';

const String _kDbName = 'lumira.db';
const int _kDbVersion = 1;

/// 数据库 Provider
/// 在应用启动时首次 read 时初始化（lazy），后续 read 返回同一实例
final databaseProvider = FutureProvider<Database>((ref) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, _kDbName);
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
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  batch.insert(Tables.userSettings, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });

  await batch.commit(noResult: true);
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // 当前 v1，未来版本迁移在此扩展
  // 不做 destructive 迁移（不 DROP TABLE），保留用户数据
}
