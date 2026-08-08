import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/route_names.dart';
import '../core/router/route_observers.dart';
import '../features/capture/pages/capture_page.dart';
import '../features/capture/pages/capture_preview_page.dart';
import '../features/capture/pages/capture_preview_template_page.dart';
import '../features/capture/pages/capture_scene_detail_page.dart';
import '../features/capture/pages/capture_scene_guide_page.dart';
import '../features/capture/pages/capture_scene_manage_page.dart';
import '../features/capture/watermark/pages/watermark_editor_page.dart';
import '../features/capture/watermark/pages/watermark_manage_page.dart';
import '../features/challenge/pages/challenge_complete_page.dart';
import '../features/challenge/pages/challenge_confirm_page.dart';
import '../features/challenge/pages/challenge_detail_page.dart';
import '../features/challenge/pages/challenge_history_page.dart';
import '../features/challenge/pages/challenge_page.dart';
import '../features/checkin/pages/checkin_detail_page.dart';
import '../features/checkin/pages/checkin_edit_page.dart';
import '../features/checkin/pages/checkin_list_page.dart';
import '../features/gallery/pages/gallery_detail_page.dart';
import '../features/gallery/pages/gallery_diary_page.dart';
import '../features/gallery/pages/gallery_edit_page.dart';
import '../features/gallery/pages/gallery_monthly_digest_page.dart';
import '../features/gallery/pages/gallery_page.dart';
import '../features/gallery/pages/gallery_stats_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/inspiration/pages/inspiration_page.dart';
import '../features/onboarding/pages/questionnaire_page.dart';
import '../features/academy/pages/academy_assignment_page.dart';
import '../features/academy/pages/academy_detail_page.dart';
import '../features/academy/pages/academy_knowledge_page.dart';
import '../features/academy/pages/academy_page.dart';
import '../features/academy/pages/academy_trajectory_page.dart';
import '../features/profile/data/compliance_content.dart';
import '../features/profile/pages/compliance_doc_page.dart';
import '../features/profile/pages/profile_about_page.dart';
import '../features/profile/pages/profile_collection_detail_page.dart';
import '../features/profile/pages/profile_collection_edit_page.dart';
import '../features/profile/pages/profile_collections_page.dart';
import '../features/profile/pages/profile_edit_page.dart';
import '../features/profile/pages/composition_kit_detail_page.dart';
import '../features/profile/pages/composition_kits_page.dart';
import '../features/profile/pages/profile_fragment_detail_page.dart';
import '../features/profile/pages/profile_growth_page.dart';
import '../features/profile/pages/profile_notifications_page.dart';
import '../features/profile/pages/profile_invite_page.dart';
import '../features/profile/pages/profile_share_code_page.dart';
import '../features/profile/pages/profile_my_templates_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/profile_settings_page.dart';
import '../features/profile/pages/profile_theme_page.dart';
import '../features/points/pages/points_wallet_page.dart';
import '../features/redeem/pages/redeem_page.dart';
import '../features/rewards/pages/rewards_page.dart';
import '../features/scenes/pages/scenes_page.dart';
import '../features/shootkit/pages/shootkit_editor_page.dart';
import '../features/splash/pages/splash_page.dart';
import '../features/templates/pages/templates_all_page.dart';
import '../features/templates/pages/templates_detail_page.dart';
import '../features/templates/pages/templates_drafts_page.dart';
import '../features/templates/pages/templates_editor_page.dart';
import '../features/templates/pages/templates_page.dart';
import '../features/templates/pages/templates_recommend_page.dart';
import '../features/templates/pages/templates_unlock_page.dart';
import '../features/templates/pages/export_detail_page.dart';

/// GoRouter Provider
/// 34 个路由与 uni-app pages.json 1:1 对应
final routerProvider = Provider<GoRouter>((ref) {
  final observer = ref.watch(lumiraRouteObserverProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    observers: [observer],
    routes: [
      // === 主流程 ===
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (context, state) => QuestionnairePage(
          fromSettings: state.queryParams[RouteNames.paramFrom] == 'settings',
        ),
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // === 拍摄流程 ===
      GoRoute(
        path: RouteNames.capture,
        name: 'capture',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          final sceneId = state.queryParams[RouteNames.paramScene];
          final kitId = state.queryParams[RouteNames.paramKitId];
          final challengeId = state.queryParams[RouteNames.paramChallengeId];
          return CapturePage(
            templateId: templateId,
            sceneId: sceneId,
            kitId: kitId,
            challengeId: challengeId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.capturePreview,
        name: 'capturePreview',
        builder: (context, state) {
          final photoUrl = state.queryParams['photoUrl'];
          final photoId = state.queryParams[RouteNames.paramPhotoId];
          final aspectRatio = state.queryParams['aspectRatio'];
          final challengeId = state.queryParams[RouteNames.paramChallengeId];
          return CapturePreviewPage(
            photoUrl: photoUrl,
            photoId: photoId,
            aspectRatio: aspectRatio,
            challengeId: challengeId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.capturePreviewTemplate,
        name: 'capturePreviewTemplate',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          final draftId = state.queryParams['draftId'];
          return CapturePreviewTemplatePage(
            templateId: templateId,
            draftId: draftId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.captureSceneGuide,
        name: 'captureSceneGuide',
        builder: (context, state) {
          // 接收 scene 参数（uni-app: /pages/capture/scene-guide?scene=xxx）
          final scene = state.queryParams[RouteNames.paramScene];
          return CaptureSceneGuidePage(scene: scene);
        },
      ),
      GoRoute(
        path: RouteNames.captureSceneManage,
        name: 'captureSceneManage',
        builder: (context, state) {
          final tab = state.queryParams[RouteNames.paramTab];
          return CaptureSceneManagePage(initialTab: tab);
        },
      ),
      GoRoute(
        path: RouteNames.captureSceneDetail,
        name: 'captureSceneDetail',
        builder: (context, state) {
          final sceneId = state.queryParams[RouteNames.paramSceneId];
          return CaptureSceneDetailPage(sceneId: sceneId);
        },
      ),

      // === 模板 ===
      GoRoute(
        path: RouteNames.templates,
        name: 'templates',
        builder: (context, state) => const TemplatesPage(),
      ),
      GoRoute(
        path: RouteNames.templatesDetail,
        name: 'templatesDetail',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          return TemplatesDetailPage(templateId: templateId);
        },
      ),
      GoRoute(
        path: RouteNames.templatesUnlock,
        name: 'templatesUnlock',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          return TemplatesUnlockPage(templateId: templateId);
        },
      ),
      GoRoute(
        path: RouteNames.templatesEditor,
        name: 'templatesEditor',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          final draftId = state.queryParams['draftId'];
          return TemplatesEditorPage(templateId: templateId, draftId: draftId);
        },
      ),
      GoRoute(
        path: RouteNames.templatesDrafts,
        name: 'templatesDrafts',
        builder: (context, state) => const TemplatesDraftsPage(),
      ),
      GoRoute(
        path: RouteNames.templatesRecommend,
        name: 'templatesRecommend',
        builder: (context, state) => const TemplatesRecommendPage(),
      ),
      GoRoute(
        path: RouteNames.templatesAll,
        name: 'templatesAll',
        builder: (context, state) {
          final scene = state.queryParams[RouteNames.paramScene];
          final category = state.queryParams[RouteNames.paramCategory];
          return TemplatesAllPage(scene: scene, category: category);
        },
      ),
      GoRoute(
        path: RouteNames.templatesExportDetail,
        name: 'templatesExportDetail',
        builder: (context, state) {
          final filePath = state.queryParams['filePath'] ?? '';
          final templateName = state.queryParams['templateName'] ?? '';
          final usePptpl = state.queryParams['usePptpl'] == 'true';
          return ExportDetailPage(
            filePath: filePath,
            templateName: templateName,
            usePptpl: usePptpl,
          );
        },
      ),

      // === 挑战 ===
      GoRoute(
        path: RouteNames.challenge,
        name: 'challenge',
        builder: (context, state) => const ChallengePage(),
      ),
      GoRoute(
        path: RouteNames.challengeDetail,
        name: 'challengeDetail',
        builder: (context, state) {
          final challengeId = state.queryParams[RouteNames.paramChallengeId];
          final date = state.queryParams[RouteNames.paramDate];
          return ChallengeDetailPage(challengeId: challengeId, date: date);
        },
      ),
      GoRoute(
        path: RouteNames.challengeHistory,
        name: 'challengeHistory',
        builder: (context, state) => const ChallengeHistoryPage(),
      ),
      GoRoute(
        path: RouteNames.challengeConfirm,
        name: 'challengeConfirm',
        builder: (context, state) {
          final challengeId =
              state.queryParams[RouteNames.paramChallengeId] ?? '';
          final photoId = state.queryParams[RouteNames.paramPhotoId] ?? '';
          return ChallengeConfirmPage(
            challengeId: challengeId,
            photoId: photoId,
          );
        },
      ),
      GoRoute(
        path: RouteNames.challengeComplete,
        name: 'challengeComplete',
        builder: (context, state) {
          final challengeId = state.queryParams[RouteNames.paramChallengeId] ?? '';
          final rewardXp = int.tryParse(
                  state.queryParams['rewardXp'] ?? '') ??
              0;
          final challengeTitle = state.queryParams['title'] ?? '';
          return ChallengeCompletePage(
            challengeId: challengeId,
            rewardXp: rewardXp,
            challengeTitle: challengeTitle,
          );
        },
      ),

      // === 灵感 / 相册 ===
      GoRoute(
        path: RouteNames.inspiration,
        name: 'inspiration',
        builder: (context, state) => const InspirationPage(),
      ),
      GoRoute(
        path: RouteNames.gallery,
        name: 'gallery',
        builder: (context, state) => const GalleryPage(),
      ),
      GoRoute(
        path: RouteNames.galleryDetail,
        name: 'galleryDetail',
        builder: (context, state) {
          final photoId = state.queryParams[RouteNames.paramPhotoId];
          return GalleryDetailPage(photoId: photoId);
        },
      ),
      GoRoute(
        path: RouteNames.galleryEdit,
        name: 'galleryEdit',
        builder: (context, state) {
          final photoId = state.queryParams[RouteNames.paramPhotoId];
          return GalleryEditPage(photoId: photoId);
        },
      ),
      GoRoute(
        path: RouteNames.galleryDiary,
        name: 'galleryDiary',
        builder: (context, state) => const GalleryDiaryPage(),
      ),
      GoRoute(
        path: RouteNames.galleryStats,
        name: 'galleryStats',
        builder: (context, state) => const GalleryStatsPage(),
      ),
      GoRoute(
        path: RouteNames.galleryMonthlyDigest,
        name: 'galleryMonthlyDigest',
        builder: (context, state) => const GalleryMonthlyDigestPage(),
      ),

      // === 探店打卡 ===
      GoRoute(
        path: RouteNames.checkinList,
        name: 'checkinList',
        builder: (context, state) => const CheckinListPage(),
      ),
      GoRoute(
        path: RouteNames.checkinDetail,
        name: 'checkinDetail',
        builder: (context, state) => CheckinDetailPage(
          checkinId: state.queryParams[RouteNames.paramCheckinId],
        ),
      ),
      GoRoute(
        path: RouteNames.checkinEdit,
        name: 'checkinEdit',
        builder: (context, state) => CheckinEditPage(
          checkinId: state.queryParams[RouteNames.paramCheckinId],
          photoId: state.queryParams[RouteNames.paramPhotoId],
        ),
      ),

      // === 个人中心 ===
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: RouteNames.profileEdit,
        name: 'profileEdit',
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: RouteNames.profileSettings,
        name: 'profileSettings',
        builder: (context, state) => const ProfileSettingsPage(),
      ),
      GoRoute(
        path: RouteNames.profileSettingsTheme,
        name: 'profileSettingsTheme',
        builder: (context, state) => const ProfileThemePage(),
      ),
      GoRoute(
        path: RouteNames.profileSettingsWatermark,
        name: 'profileSettingsWatermark',
        builder: (context, state) => const WatermarkManagePage(),
      ),
      GoRoute(
        path: RouteNames.profileSettingsWatermarkEdit,
        name: 'profileSettingsWatermarkEdit',
        builder: (context, state) {
          final templateId =
              state.queryParams[RouteNames.paramTemplateId];
          return WatermarkEditorPage(templateId: templateId);
        },
      ),
      GoRoute(
        path: RouteNames.profileGrowth,
        name: 'profileGrowth',
        builder: (context, state) => const ProfileGrowthPage(),
      ),
      GoRoute(
        path: RouteNames.profileInvite,
        name: 'profileInvite',
        builder: (context, state) => const ProfileInvitePage(),
      ),
      GoRoute(
        path: RouteNames.profileShareCode,
        name: 'profileShareCode',
        builder: (context, state) => const ProfileShareCodePage(),
      ),
      GoRoute(
        path: RouteNames.profileAcademy,
        name: 'profileAcademy',
        builder: (context, state) => const AcademyPage(),
      ),
      GoRoute(
        path: RouteNames.profileAcademyDetail,
        name: 'profileAcademyDetail',
        builder: (context, state) {
          final academyId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyDetailPage(academyId: academyId);
        },
      ),
      GoRoute(
        path: RouteNames.profileAcademyAssignment,
        name: 'profileAcademyAssignment',
        builder: (context, state) {
          final academyId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyAssignmentPage(academyId: academyId);
        },
      ),
      GoRoute(
        path: RouteNames.profileAcademyKnowledge,
        name: 'profileAcademyKnowledge',
        builder: (context, state) {
          final cardId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyKnowledgePage(cardId: cardId);
        },
      ),
      GoRoute(
        path: RouteNames.academyTrajectory,
        name: 'academyTrajectory',
        builder: (context, state) => const AcademyTrajectoryPage(),
      ),
      GoRoute(
        path: RouteNames.profileCollections,
        name: 'profileCollections',
        builder: (context, state) => const ProfileCollectionsPage(),
      ),
      GoRoute(
        path: RouteNames.profileCollectionDetail,
        name: 'profileCollectionDetail',
        builder: (context, state) {
          final collectionId = state.queryParams[RouteNames.paramCollectionId];
          return ProfileCollectionDetailPage(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: RouteNames.profileCollectionEdit,
        name: 'profileCollectionEdit',
        builder: (context, state) {
          final collectionId =
              state.queryParams[RouteNames.paramCollectionId];
          return ProfileCollectionEditPage(collectionId: collectionId);
        },
      ),
      GoRoute(
        path: RouteNames.profileMyTemplates,
        name: 'profileMyTemplates',
        builder: (context, state) => const ProfileMyTemplatesPage(),
      ),
      GoRoute(
        path: RouteNames.profileCompositionKits,
        name: 'profileCompositionKits',
        builder: (context, state) => const CompositionKitsPage(),
      ),
      GoRoute(
        path: RouteNames.profileCompositionKitDetail,
        name: 'profileCompositionKitDetail',
        builder: (context, state) {
          final kitId = state.queryParams[RouteNames.paramKitId];
          return CompositionKitDetailPage(kitId: kitId ?? '');
        },
      ),
      GoRoute(
        path: RouteNames.profileFragmentDetail,
        name: 'profileFragmentDetail',
        builder: (context, state) => const ProfileFragmentDetailPage(),
      ),
      GoRoute(
        path: RouteNames.profileNotifications,
        name: 'profileNotifications',
        builder: (context, state) => const ProfileNotificationsPage(),
      ),
      GoRoute(
        path: RouteNames.profileAbout,
        name: 'profileAbout',
        builder: (context, state) => const ProfileAboutPage(),
      ),
      GoRoute(
        path: RouteNames.profileComplianceAgreement,
        name: 'profileComplianceAgreement',
        builder: (context, state) => const ComplianceDocPage(
          title: '用户协议',
          updatedAt: ComplianceDocs.agreementUpdatedAt,
          sections: ComplianceDocs.agreement,
        ),
      ),
      GoRoute(
        path: RouteNames.profileCompliancePrivacy,
        name: 'profileCompliancePrivacy',
        builder: (context, state) => const ComplianceDocPage(
          title: '隐私政策',
          updatedAt: ComplianceDocs.privacyUpdatedAt,
          sections: ComplianceDocs.privacy,
        ),
      ),
      GoRoute(
        path: RouteNames.profileComplianceSdk,
        name: 'profileComplianceSdk',
        builder: (context, state) => const ComplianceDocPage(
          title: '个人信息清单与第三方SDK目录',
          updatedAt: ComplianceDocs.sdkUpdatedAt,
          sections: ComplianceDocs.sdk,
        ),
      ),
      GoRoute(
        path: RouteNames.profileRewards,
        name: 'profileRewards',
        builder: (context, state) => const RewardsPage(),
      ),
      GoRoute(
        path: RouteNames.profileRedeem,
        name: 'profileRedeem',
        builder: (context, state) => const RedeemPage(),
      ),

      // === 积分 / 邀请 ===
      GoRoute(
        path: RouteNames.pointsWallet,
        name: 'pointsWallet',
        builder: (context, state) => const PointsWalletPage(),
      ),
      GoRoute(
        path: RouteNames.invite,
        name: 'invite',
        builder: (context, state) => const ProfileInvitePage(),
      ),

      // === 场景 ===
      GoRoute(
        path: RouteNames.scenes,
        name: 'scenes',
        builder: (context, state) => const ScenesPage(),
      ),

      // === 拍摄套件 ===
      GoRoute(
        path: RouteNames.shootkitEditor,
        name: 'shootkitEditor',
        builder: (context, state) {
          final kitId = state.queryParams[RouteNames.paramKitId];
          final sceneId = state.queryParams[RouteNames.paramSceneId];
          return ShootkitEditorPage(kitId: kitId, sceneId: sceneId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.location}'),
      ),
    ),
  );
});
