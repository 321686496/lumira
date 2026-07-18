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

  // === gallery_items ===
  static const String galleryItems = 'gallery_items';
  static const String colDataUrl = 'data_url';
  static const String colFilePath = 'file_path';
  static const String colSceneId = 'scene_id';
  static const String colTemplateId = 'template_id';
  static const String colKitId = 'kit_id';
  static const String colMood = 'mood';
  static const String colLut = 'lut';

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
}
