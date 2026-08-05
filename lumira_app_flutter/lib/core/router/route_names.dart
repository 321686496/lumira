/// 所有路由名与路径常量。
/// 来源：uni-app lumira-app/src/pages.json（34 个页面，1:1 映射）
class RouteNames {
  RouteNames._();

  // === 路径常量 ===
  // 注意：GoRouter 路径以 / 开头，对应 uni-app pages/ 下的文件路径
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String templates = '/templates';
  static const String challenge = '/challenge';
  static const String profile = '/profile';
  static const String capture = '/capture';
  static const String capturePreview = '/capture/preview';
  static const String capturePreviewTemplate = '/capture/preview-template';
  static const String captureSceneGuide = '/capture/scene-guide';
  static const String captureSceneManage = '/capture/scene-manage';
  static const String captureSceneDetail = '/capture/scene-detail';
  static const String templatesDetail = '/templates/detail';
  static const String templatesUnlock = '/templates/unlock';
  static const String templatesEditor = '/templates/editor';
  static const String templatesDrafts = '/templates/drafts';
  static const String templatesRecommend = '/templates/recommend';
  static const String templatesAll = '/templates/all';
  static const String challengeDetail = '/challenge/detail';
  static const String challengeHistory = '/challenge/history';
  static const String challengeConfirm = '/challenge/confirm';
  static const String challengeComplete = '/challenge/complete';
  static const String inspiration = '/inspiration';
  static const String gallery = '/gallery';
  static const String galleryDetail = '/gallery/detail';
  static const String galleryEdit = '/gallery/edit';
  static const String galleryDiary = '/gallery/diary';
  static const String galleryStats = '/gallery/stats';
  static const String galleryMonthlyDigest = '/gallery/monthly-digest';
  static const String profileSettings = '/profile/settings';
  static const String profileSettingsTheme = '/profile/settings/theme';
  static const String profileGrowth = '/profile/growth';
  static const String profileInvite = '/profile/invite';
  static const String profileShareCode = '/profile/share-code';
  static const String profileAcademy = '/profile/academy';
  static const String profileAcademyDetail = '/profile/academy-detail';
  static const String profileAcademyKnowledge = '/profile/academy-knowledge';
  static const String profileAcademyAssignment = '/profile/academy-assignment';
  static const String profileCollections = '/profile/collections';
  static const String profileCollectionDetail = '/profile/collection-detail';
  static const String profileCollectionEdit = '/profile/collection-edit';
  static const String profileMyTemplates = '/profile/my-templates';
  static const String profileFragmentDetail = '/profile/fragment-detail';
  static const String profileNotifications = '/profile/notifications';
  static const String profileAbout = '/profile/about';
  static const String profileComplianceAgreement = '/profile/settings/agreement';
  static const String profileCompliancePrivacy = '/profile/settings/privacy';
  static const String profileComplianceSdk = '/profile/settings/sdk';
  static const String scenes = '/scenes';
  static const String shootkitEditor = '/shootkit/editor';
  static const String academyTrajectory = '/academy/trajectory';
  static const String profileCompositionKits = '/profile/composition-kits';
  static const String profileCompositionKitDetail = '/profile/composition-kit-detail';
  static const String profileRewards = '/profile/rewards';
  static const String profileRedeem = '/profile/redeem';
  static const String pointsWallet = '/points/wallet';
  static const String invite = '/invite';

  // === 查询参数键名 ===
  static const String paramTemplateId = 'templateId';
  static const String paramSceneId = 'sceneId';
  static const String paramScene = 'scene';
  static const String paramTab = 'tab';
  static const String paramChallengeId = 'challengeId';
  static const String paramPhotoId = 'photoId';
  static const String paramCollectionId = 'collectionId';
  static const String paramAcademyId = 'academyId';
  static const String paramMode = 'mode';
  static const String paramKitId = 'kitId';
  static const String paramCategory = 'category';
  static const String paramFrom = 'from';

  // === 工具方法 ===
  /// 构建 templateId 查询参数 URL
  /// 用于模板详情/解锁/编辑/拍摄预览页等需要传递 templateId 的场景
  static String withTemplateId(String path, String templateId) {
    return '$path?$paramTemplateId=$templateId';
  }

  /// 构建 sceneId 查询参数 URL
  static String withSceneId(String path, String sceneId) {
    return '$path?$paramSceneId=$sceneId';
  }

  /// 构建多参数 URL
  static String build(String path, Map<String, String> params) {
    if (params.isEmpty) return path;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$path?$query';
  }
}
