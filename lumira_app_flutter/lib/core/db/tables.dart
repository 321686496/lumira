/// 所有数据库表名与列名常量。
/// 字段设计基于 uni-app 源码逆向研究：
/// e:\Project\photo_post\.superpowers\sdd\task-1.4-research.md
class Tables {
  Tables._();

  // === custom_templates ===
  static const String customTemplates = 'custom_templates';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colAuthor = 'author';
  static const String colVersion = 'version';
  static const String colCategory = 'category';
  static const String colClassificationJson = 'classification_json';
  static const String colTagsJson = 'tags_json';
  static const String colTagIdsJson = 'tag_ids_json';
  static const String colPrice = 'price';
  static const String colCover = 'cover';
  static const String colCoverData = 'cover_data';
  static const String colDescription = 'description';
  static const String colReferenceSource = 'reference_source';
  static const String colCompositionJson = 'composition_json';
  static const String colPoseJson = 'pose_json';
  static const String colCameraJson = 'camera_json';
  static const String colSceneGuideJson = 'scene_guide_json';
  static const String colPostProcessJson = 'post_process_json';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  // === scenes ===
  static const String scenes = 'scenes';
  static const String colIcon = 'icon';
  static const String colStyle = 'style';
  static const String colFilterJson = 'filter_json';
  static const String colVibe = 'vibe';
  static const String colExampleImagesJson = 'example_images_json';
  static const String colTipsJson = 'tips_json';
  static const String colWhereToShoot = 'where_to_shoot';
  static const String colBestTime = 'best_time';
  static const String colRelatedCategory = 'related_category';
  static const String colRecommendedTagIdsJson = 'recommended_tag_ids_json';
  // colTagIdsJson 已在 custom_templates 段声明（值同为 'tag_ids_json'），此处不重复声明
  static const String colCreator = 'creator';
  static const String colIsFavorite = 'is_favorite';

  // === custom_templates 扩展列（v4 迁移新增） ===
  static const String colIsBuiltin = 'is_builtin';
  static const String colIsRecommended = 'is_recommended';

  // === custom_templates 扩展列（v13 迁移新增，标记来源） ===
  // 取值：'builtin' | 'custom' | 'remote'
  static const String colSource = 'source';

  // === template_categories 表（v13 迁移新增，分类管理） ===
  static const String templateCategories = 'template_categories';
  static const String colIconUrl = 'icon_url';
  static const String colSortOrder = 'sort_order';
  static const String colIsSystem = 'is_system';
  static const String colIsActive = 'is_active';

  // === user_settings 扩展列（v4 迁移新增） ===
  static const String colSeedV3Done = 'seed_v3_done';

  // === user_settings 扩展列（v6 迁移新增） ===
  static const String colAutoDeblur = 'auto_deblur';

  // === user_settings 扩展列（v9 迁移新增，自由模式参数持久化） ===
  static const String colFreeModeCamera = 'free_mode_camera';
  static const String colFreeModePostProcess = 'free_mode_post_process';
  static const String colFreeModeComposition = 'free_mode_composition';

  // === composition_kits 表（M2 用，v4 迁移同步创建） ===
  // 注：colSceneId / colTemplateId 复用 gallery_items 段已声明的同名常量
  static const String compositionKits = 'composition_kits';
  static const String colCameraOverridesJson = 'camera_overrides_json';
  static const String colNote = 'note';
  static const String colCoverUrl = 'cover_url';
  static const String colLastUsedAt = 'last_used_at';
  static const String colUsageCount = 'usage_count';

  // === academy_learning_trajectory 表（M6 用，v4 迁移同步创建） ===
  static const String academyLearningTrajectory = 'academy_learning_trajectory';
  static const String colCourseId = 'course_id';
  static const String colCompletedAt = 'completed_at';
  static const String colSequence = 'sequence';

  // === gallery_items ===
  static const String galleryItems = 'gallery_items';
  static const String colDataUrl = 'data_url';
  static const String colFilePath = 'file_path';
  static const String colSceneId = 'scene_id';
  static const String colTemplateId = 'template_id';
  static const String colKitId = 'kit_id';
  static const String colMood = 'mood';
  static const String colLut = 'lut';

  // === gallery_items 扩展列（v7 迁移新增） ===
  static const String colOriginalPath = 'original_path';
  static const String colTransform = 'transform';
  static const String colPostProcess = 'post_process';

  // === gallery_items 扩展列（v8 迁移新增） ===
  static const String colGalleryItemIsFavorite = 'is_favorite';

  // === user_progress ===
  static const String userProgress = 'user_progress';
  static const String colLevel = 'level';
  static const String colLevelName = 'level_name';
  static const String colXp = 'xp';
  static const String colXpToNextLevel = 'xp_to_next_level';
  static const String colTotalPhotos = 'total_photos';
  static const String colUsedTemplates = 'used_templates';
  static const String colFavorites = 'favorites';
  static const String colStreakDays = 'streak_days';
  static const String colLastCheckInDate = 'last_check_in_date';
  static const String colFragmentsJson = 'fragments_json';
  static const String colAchievementsJson = 'achievements_json';

  // === user_settings ===
  static const String userSettings = 'user_settings';
  static const String colThemeKey = 'theme_key';
  static const String colUiStyle = 'ui_style';
  static const String colFollowSystem = 'follow_system';
  static const String colCaptureFullscreen = 'capture_fullscreen';
  static const String colGridEnabled = 'grid_enabled';
  static const String colLevelEnabled = 'level_enabled';
  static const String colShutterSound = 'shutter_sound';
  static const String colWatermark = 'watermark';

  // === auth 表（v5） ===
  static const String auth = 'auth';
  static const String colDeviceId = 'device_id';
  static const String colOs = 'os';
  static const String colToken = 'token';
  static const String colIsNewDevice = 'is_new_device';
  static const String colRegisteredAt = 'registered_at';

  // === api_cache 表（v5） ===
  static const String apiCache = 'api_cache';
  static const String colKey = 'key';
  static const String colPayload = 'payload';
  static const String colCachedAt = 'cached_at';

  // === collections 表（v8 迁移新增，精选集主表） ===
  static const String tableCollections = 'collections';
  static const String colCollectionId = 'id';
  static const String colCollectionName = 'name';
  static const String colCollectionDescription = 'description';
  static const String colCollectionCoverPhotoId = 'cover_photo_id';
  static const String colCollectionType = 'type';
  static const String colCollectionSourceMeta = 'source_meta';
  static const String colCollectionPhotoCount = 'photo_count';
  static const String colCollectionCreatedAt = 'created_at';
  static const String colCollectionUpdatedAt = 'updated_at';

  // === collection_photos 表（v8 迁移新增，精选集-照片关联表） ===
  static const String tableCollectionPhotos = 'collection_photos';
  static const String colCollectionPhotoCollectionId = 'collection_id';
  static const String colCollectionPhotoPhotoId = 'photo_id';
  static const String colCollectionPhotoSortOrder = 'sort_order';
  static const String colCollectionPhotoAddedAt = 'added_at';

  // === questionnaire 表（v12 迁移新增，单行表 id=1） ===
  static const String questionnaire = 'questionnaire';
  static const String colAnswersJson = 'answers_json';
  static const String colSubmittedAt = 'submitted_at';
  static const String colSyncedAt = 'synced_at';
}

class ChallengeHistoryTable {
  static const name = 'challenge_history';
  static const colId = 'id';
  static const colDate = 'date';
  static const colChallengeId = 'challenge_id';
  static const colCategory = 'category';
  static const colTitle = 'title';
  static const colRewardXp = 'reward_xp';
  static const colStatus = 'status';
  static const colSelectedAt = 'selected_at';
  static const colCompletedAt = 'completed_at';
  static const colSkippedAt = 'skipped_at';
  static const colIsDaily = 'is_daily';
  /// 关联照片 id 列表，逗号分隔（如 "photo-1,photo-2"）
  static const colPhotoIds = 'photo_ids';

  static const createSql = '''
    CREATE TABLE $name (
      $colId TEXT PRIMARY KEY,
      $colDate TEXT NOT NULL,
      $colChallengeId TEXT NOT NULL,
      $colCategory TEXT NOT NULL,
      $colTitle TEXT NOT NULL,
      $colRewardXp INTEGER NOT NULL,
      $colStatus TEXT NOT NULL,
      $colSelectedAt INTEGER NOT NULL,
      $colCompletedAt INTEGER,
      $colSkippedAt INTEGER,
      $colIsDaily INTEGER NOT NULL DEFAULT 0,
      $colPhotoIds TEXT NOT NULL DEFAULT ''
    )
  ''';
  static const indexDateSql = 'CREATE INDEX idx_challenge_history_date ON $name ($colDate DESC)';
  static const indexCategorySql = 'CREATE INDEX idx_challenge_history_category ON $name ($colCategory)';
}

class CompositionKitsTable {
  static const name = Tables.compositionKits;
  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER NOT NULL DEFAULT 0
    )
  ''';
}

class AcademyLearningTrajectoryTable {
  static const name = Tables.academyLearningTrajectory;
  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      ${Tables.colCourseId} TEXT PRIMARY KEY,
      ${Tables.colCompletedAt} INTEGER NOT NULL,
      ${Tables.colSequence} INTEGER NOT NULL
    )
  ''';
}
