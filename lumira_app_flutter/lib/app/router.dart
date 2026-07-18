import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/route_names.dart';
import '../core/router/route_observers.dart';

/// 占位页面 widget（Task 2.x 将替换为实际页面）
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Route: $name',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

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
        builder: (context, state) => const _PlaceholderPage(name: 'splash'),
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const _PlaceholderPage(name: 'home'),
      ),

      // === 拍摄流程 ===
      GoRoute(
        path: RouteNames.capture,
        name: 'capture',
        builder: (context, state) => const _PlaceholderPage(name: 'capture'),
      ),
      GoRoute(
        path: RouteNames.capturePreview,
        name: 'capturePreview',
        builder: (context, state) => const _PlaceholderPage(name: 'capturePreview'),
      ),
      GoRoute(
        path: RouteNames.capturePreviewTemplate,
        name: 'capturePreviewTemplate',
        builder: (context, state) => const _PlaceholderPage(name: 'capturePreviewTemplate'),
      ),
      GoRoute(
        path: RouteNames.captureSceneGuide,
        name: 'captureSceneGuide',
        builder: (context, state) {
          // 接收 scene 参数（uni-app: /pages/capture/scene-guide?scene=xxx）
          final scene = state.queryParams[RouteNames.paramScene];
          return _PlaceholderPage(name: 'captureSceneGuide?scene=$scene');
        },
      ),
      GoRoute(
        path: RouteNames.captureSceneManage,
        name: 'captureSceneManage',
        builder: (context, state) {
          final tab = state.queryParams[RouteNames.paramTab];
          return _PlaceholderPage(name: 'captureSceneManage?tab=$tab');
        },
      ),
      GoRoute(
        path: RouteNames.captureSceneDetail,
        name: 'captureSceneDetail',
        builder: (context, state) {
          final sceneId = state.queryParams[RouteNames.paramSceneId];
          return _PlaceholderPage(name: 'captureSceneDetail?sceneId=$sceneId');
        },
      ),

      // === 模板 ===
      GoRoute(
        path: RouteNames.templates,
        name: 'templates',
        builder: (context, state) => const _PlaceholderPage(name: 'templates'),
      ),
      GoRoute(
        path: RouteNames.templatesDetail,
        name: 'templatesDetail',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          return _PlaceholderPage(name: 'templatesDetail?templateId=$templateId');
        },
      ),
      GoRoute(
        path: RouteNames.templatesUnlock,
        name: 'templatesUnlock',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          return _PlaceholderPage(name: 'templatesUnlock?templateId=$templateId');
        },
      ),
      GoRoute(
        path: RouteNames.templatesEditor,
        name: 'templatesEditor',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          return _PlaceholderPage(name: 'templatesEditor?templateId=$templateId');
        },
      ),
      GoRoute(
        path: RouteNames.templatesDrafts,
        name: 'templatesDrafts',
        builder: (context, state) => const _PlaceholderPage(name: 'templatesDrafts'),
      ),
      GoRoute(
        path: RouteNames.templatesRecommend,
        name: 'templatesRecommend',
        builder: (context, state) => const _PlaceholderPage(name: 'templatesRecommend'),
      ),
      GoRoute(
        path: RouteNames.templatesAll,
        name: 'templatesAll',
        builder: (context, state) => const _PlaceholderPage(name: 'templatesAll'),
      ),

      // === 挑战 ===
      GoRoute(
        path: RouteNames.challenge,
        name: 'challenge',
        builder: (context, state) => const _PlaceholderPage(name: 'challenge'),
      ),
      GoRoute(
        path: RouteNames.challengeDetail,
        name: 'challengeDetail',
        builder: (context, state) {
          final challengeId = state.queryParams[RouteNames.paramChallengeId];
          return _PlaceholderPage(name: 'challengeDetail?challengeId=$challengeId');
        },
      ),

      // === 灵感 / 相册 ===
      GoRoute(
        path: RouteNames.inspiration,
        name: 'inspiration',
        builder: (context, state) => const _PlaceholderPage(name: 'inspiration'),
      ),
      GoRoute(
        path: RouteNames.gallery,
        name: 'gallery',
        builder: (context, state) => const _PlaceholderPage(name: 'gallery'),
      ),
      GoRoute(
        path: RouteNames.galleryDetail,
        name: 'galleryDetail',
        builder: (context, state) {
          final photoId = state.queryParams[RouteNames.paramPhotoId];
          return _PlaceholderPage(name: 'galleryDetail?photoId=$photoId');
        },
      ),
      GoRoute(
        path: RouteNames.galleryDiary,
        name: 'galleryDiary',
        builder: (context, state) => const _PlaceholderPage(name: 'galleryDiary'),
      ),
      GoRoute(
        path: RouteNames.galleryMonthlyDigest,
        name: 'galleryMonthlyDigest',
        builder: (context, state) => const _PlaceholderPage(name: 'galleryMonthlyDigest'),
      ),

      // === 个人中心 ===
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const _PlaceholderPage(name: 'profile'),
      ),
      GoRoute(
        path: RouteNames.profileSettings,
        name: 'profileSettings',
        builder: (context, state) => const _PlaceholderPage(name: 'profileSettings'),
      ),
      GoRoute(
        path: RouteNames.profileSettingsTheme,
        name: 'profileSettingsTheme',
        builder: (context, state) => const _PlaceholderPage(name: 'profileSettingsTheme'),
      ),
      GoRoute(
        path: RouteNames.profileGrowth,
        name: 'profileGrowth',
        builder: (context, state) => const _PlaceholderPage(name: 'profileGrowth'),
      ),
      GoRoute(
        path: RouteNames.profileInvite,
        name: 'profileInvite',
        builder: (context, state) => const _PlaceholderPage(name: 'profileInvite'),
      ),
      GoRoute(
        path: RouteNames.profileAcademy,
        name: 'profileAcademy',
        builder: (context, state) => const _PlaceholderPage(name: 'profileAcademy'),
      ),
      GoRoute(
        path: RouteNames.profileAcademyDetail,
        name: 'profileAcademyDetail',
        builder: (context, state) {
          final academyId = state.queryParams[RouteNames.paramAcademyId];
          return _PlaceholderPage(name: 'profileAcademyDetail?academyId=$academyId');
        },
      ),
      GoRoute(
        path: RouteNames.profileCollections,
        name: 'profileCollections',
        builder: (context, state) => const _PlaceholderPage(name: 'profileCollections'),
      ),
      GoRoute(
        path: RouteNames.profileCollectionDetail,
        name: 'profileCollectionDetail',
        builder: (context, state) {
          final collectionId = state.queryParams[RouteNames.paramCollectionId];
          return _PlaceholderPage(name: 'profileCollectionDetail?collectionId=$collectionId');
        },
      ),
      GoRoute(
        path: RouteNames.profileMyTemplates,
        name: 'profileMyTemplates',
        builder: (context, state) => const _PlaceholderPage(name: 'profileMyTemplates'),
      ),

      // === 场景 ===
      GoRoute(
        path: RouteNames.scenes,
        name: 'scenes',
        builder: (context, state) => const _PlaceholderPage(name: 'scenes'),
      ),

      // === 拍摄套件 ===
      GoRoute(
        path: RouteNames.shootkitEditor,
        name: 'shootkitEditor',
        builder: (context, state) => const _PlaceholderPage(name: 'shootkitEditor'),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.location}'),
      ),
    ),
  );
});
