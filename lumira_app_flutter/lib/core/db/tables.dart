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
  // 自定义场景封面图（base64 data URL）。colCoverUrl 常量在 composition_kits 段声明（值 'cover_url'），此处复用

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
  // === template_categories 扩展列（v17 迁移新增，三级树形分类） ===
  // parent_key: 父分类 key，一级为 NULL；level: 1=type / 2=style / 3=method
  // colLevel 复用 user_progress 段已声明的 'level' 常量
  static const String colParentKey = 'parent_key';

  // === user_settings 扩展列（v4 迁移新增） ===
  static const String colSeedV3Done = 'seed_v3_done';

  // === user_settings 扩展列（v6 迁移新增） ===
  static const String colAutoDeblur = 'auto_deblur';

  // === user_settings 扩展列（v9 迁移新增，自由模式参数持久化） ===
  static const String colFreeModeCamera = 'free_mode_camera';
  static const String colFreeModePostProcess = 'free_mode_post_process';
  static const String colFreeModeComposition = 'free_mode_composition';

  // === user_settings 扩展列（v21 迁移新增，水印设置持久化） ===
  // 存储 WatermarkSettings.toJson() 的 JSON 字符串
  static const String colWatermarkSettings = 'watermark_settings';

  // === user_settings 扩展列（v22 迁移新增，拍摄页偏好持久化） ===
  // 前后置摄像头选择（'front' / 'back'）与照片比例（'fullscreen' / '4:3' / '1:1' 等）
  static const String colCameraFacing = 'camera_facing';
  static const String colAspectRatio = 'aspect_ratio';

  // === user_settings 扩展列（v34 迁移新增，模板信息卡显示偏好持久化） ===
  // 套用模板时顶部的可折叠模板信息卡是否被用户隐藏（1=隐藏，0=显示，默认显示）
  static const String colTemplateInfoCardHidden = 'template_info_card_hidden';

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
  static const colFragmentsJson = 'fragments_json';
  static const colAchievementsJson = 'achievements_json';
  /// 已领取升级积分奖励的最高等级（v26 迁移新增；0=未领取任何）
  static const String colXpRewardClaimedLevel = 'xp_reward_claimed_level';

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

  // === user_profile 表（v15 迁移新增，单行表 id=1） ===
  static const String userProfile = 'user_profile';
  static const String colUsername = 'username';
  static const String colAvatarSeed = 'avatar_seed';
  // colSyncedAt 复用 questionnaire 段声明（值同为 'synced_at'），此处不重复声明
  static const String colGender = 'gender';
  static const String colFavoriteCategoriesJson = 'favorite_categories_json';
  static const String colPainPointsJson = 'pain_points_json';
  static const String colSkillLevel = 'skill_level';
  static const String colExpectationsJson = 'expectations_json';
  static const String colCommonScenesJson = 'common_scenes_json';
  static const String colShootFrequency = 'shoot_frequency';
  static const String colAvatarUrl = 'avatar_url';

  // === watermark_templates 表（v20 迁移新增，自定义水印模板） ===
  // colId / colName / colCreatedAt 复用前面已声明的同名常量
  static const String watermarkTemplates = 'watermark_templates';
  static const String colType = 'type';
  static const String colConfig = 'config';

  // === tutorial_reads 表（v23 迁移新增，小教程已读记录） ===
  // colId 复用已声明常量（值 'id'）
  static const String tutorialReads = 'tutorial_reads';
  static const String colTutorialReadAt = 'read_at';

  // === user_tags / item_tags 表（v24 迁移新增，用户自定义标签 + 搜索） ===
  // colId / colName / colCreatedAt 复用前面已声明的同名常量
  static const String userTags = 'user_tags';
  static const String itemTags = 'item_tags';
  static const String colItemType = 'item_type';
  static const String colItemId = 'item_id';
  static const String colTagId = 'tag_id';

  // === usage_events / usage_stats 表（v28 迁移新增，使用次数统计） ===
  // colItemType / colItemId 复用 item_tags 段声明（值同为 'item_type' / 'item_id'）
  static const String usageEvents = 'usage_events';
  static const String colClientEventId = 'client_event_id';
  static const String colItemSource = 'item_source';
  static const String colEventType = 'event_type';
  static const String colOccurredAt = 'occurred_at';
  static const String colSynced = 'synced';

  static const String usageStats = 'usage_stats';
  static const String colCount = 'count';
  // colUpdatedAt 复用 custom_templates 段声明（值同为 'updated_at'）

  // === notifications 表（v32 迁移新增，通知中心） ===
  // colId / colSource 复用前面已声明的同名常量（值 'id' / 'source'）
  static const String notifications = 'notifications';
  static const String colRemoteId = 'remote_id';
  static const String colKind = 'kind';
  static const String colRead = 'read';          // 0 未读 1 已读
  static const String colCleared = 'cleared';    // 0 未清除 1 已清除
  static const String colTimeMs = 'time_ms';
  // title/body 用独立常量 colTitleN / colBodyN，避免与既有 colName 等成员冲突
  static const String colTitleN = 'title';
  static const String colBodyN = 'body';
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

/// 探店打卡主表（v16 迁移新增）
class CheckinTable {
  static const String name = 'checkins';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colPlace = 'place';
  static const String colCategory = 'category';
  static const String colRating = 'rating';
  static const String colNote = 'note';
  static const String colVisitedAt = 'visited_at';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static const String createSql = '''
    CREATE TABLE $name (
      $colId TEXT PRIMARY KEY,
      $colName TEXT NOT NULL,
      $colPlace TEXT NOT NULL DEFAULT '',
      $colCategory TEXT NOT NULL DEFAULT '',
      $colRating INTEGER NOT NULL DEFAULT 0,
      $colNote TEXT NOT NULL DEFAULT '',
      $colVisitedAt INTEGER NOT NULL,
      $colCreatedAt INTEGER NOT NULL,
      $colUpdatedAt INTEGER NOT NULL
    )
  ''';

  static const String indexVisitedAtSql =
      'CREATE INDEX idx_checkins_visited_at ON $name ($colVisitedAt DESC)';
}

/// 探店打卡-照片关联表（v16 迁移新增，仿 collection_photos）
class CheckinPhotoTable {
  static const String name = 'checkin_photos';
  static const String colCheckinId = 'checkin_id';
  static const String colPhotoId = 'photo_id';
  static const String colPosition = 'position';

  static const String createSql = '''
    CREATE TABLE $name (
      $colCheckinId TEXT NOT NULL,
      $colPhotoId TEXT NOT NULL,
      $colPosition INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY ($colCheckinId, $colPhotoId),
      FOREIGN KEY ($colCheckinId) REFERENCES ${CheckinTable.name}(${CheckinTable.colId}) ON DELETE CASCADE
    )
  ''';

  static const String indexCheckinSql =
      'CREATE INDEX idx_checkin_photos_checkin ON $name ($colCheckinId)';
}

/// 自定义水印模板表（v20 迁移新增）
/// config 列存储 WatermarkTemplate.toJson() 的 JSON 字符串。
class WatermarkTemplatesTable {
  static const String name = Tables.watermarkTemplates;

  static const String createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colType} TEXT NOT NULL,
      ${Tables.colConfig} TEXT NOT NULL,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''';

  static const String indexCreatedAtSql =
      'CREATE INDEX IF NOT EXISTS idx_watermark_templates_created_at ON $name (${Tables.colCreatedAt} DESC)';
}

/// 经验台账表（v26 迁移新增）
/// 单行真实数据源：等级 = SUM(amount)；id = "{source}:{refId}" 保证幂等。
class XpEventsTable {
  static const name = 'xp_events';
  static const colSource = 'source'; // 'shoot_daily'|'challenge'|'course'|'share'
  static const colAmount = 'amount';
  static const colRefId = 'ref_id';
  static const colCreatedAt = 'created_at';

  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      id TEXT PRIMARY KEY,
      $colSource TEXT NOT NULL,
      $colAmount INTEGER NOT NULL,
      $colRefId TEXT NOT NULL,
      $colCreatedAt INTEGER NOT NULL
    )
  ''';
  static const indexSql =
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_xp_events_source_ref ON $name ($colSource, $colRefId)';
}

/// 搜索历史表（v33 迁移新增，搜索模块）
/// scope 取值：'template' | 'scene' | 'academy'（隔离三类内容，互不串扰）
class SearchHistoryTable {
  static const name = 'search_history';
  static const colId = 'id';
  static const colScope = 'scope';
  static const colKeyword = 'keyword';
  static const colSearchCount = 'search_count';
  static const colLastSearchedAt = 'last_searched_at';

  static const createSql = '''
    CREATE TABLE IF NOT EXISTS $name (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colScope TEXT NOT NULL,
      $colKeyword TEXT NOT NULL,
      $colSearchCount INTEGER NOT NULL DEFAULT 1,
      $colLastSearchedAt INTEGER NOT NULL
    )
  ''';
  static const indexSql =
      'CREATE INDEX IF NOT EXISTS idx_search_history_scope_time ON $name ($colScope, $colLastSearchedAt DESC)';
}

