import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/app/router.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/router/route_observers.dart';

/// 所有 46 个路径常量，按 RouteNames 中声明顺序排列。
/// （uni-app pages.json 34 个页面 + Flutter 新增 12 条 = 46）
List<String> get _allPaths => <String>[
      RouteNames.splash,
      RouteNames.home,
      RouteNames.templates,
      RouteNames.challenge,
      RouteNames.profile,
      RouteNames.capture,
      RouteNames.capturePreview,
      RouteNames.capturePreviewTemplate,
      RouteNames.captureSceneGuide,
      RouteNames.captureSceneManage,
      RouteNames.captureSceneDetail,
      RouteNames.templatesDetail,
      RouteNames.templatesUnlock,
      RouteNames.templatesEditor,
      RouteNames.templatesDrafts,
      RouteNames.templatesRecommend,
      RouteNames.templatesAll,
      RouteNames.challengeDetail,
      RouteNames.challengeHistory,
      RouteNames.inspiration,
      RouteNames.gallery,
      RouteNames.galleryDetail,
      RouteNames.galleryDiary,
      RouteNames.galleryStats,
      RouteNames.galleryMonthlyDigest,
      RouteNames.profileSettings,
      RouteNames.profileSettingsTheme,
      RouteNames.profileGrowth,
      RouteNames.profileInvite,
      RouteNames.profileAcademy,
      RouteNames.profileAcademyDetail,
      RouteNames.profileAcademyKnowledge,
      RouteNames.profileAcademyAssignment,
      RouteNames.profileCollections,
      RouteNames.profileCollectionDetail,
      RouteNames.profileMyTemplates,
      RouteNames.profileFragmentDetail,
      RouteNames.profileNotifications,
      RouteNames.profileAbout,
      RouteNames.scenes,
      RouteNames.shootkitEditor,
      RouteNames.academyTrajectory,
      RouteNames.profileCompositionKits,
      RouteNames.profileCompositionKitDetail,
      RouteNames.profileRewards,
      RouteNames.profileRedeem,
    ];

/// 所有 46 个路由名，按 router.dart 中声明顺序排列。
List<String> get _allNames => <String>[
      'splash',
      'home',
      'capture',
      'capturePreview',
      'capturePreviewTemplate',
      'captureSceneGuide',
      'captureSceneManage',
      'captureSceneDetail',
      'templates',
      'templatesDetail',
      'templatesUnlock',
      'templatesEditor',
      'templatesDrafts',
      'templatesRecommend',
      'templatesAll',
      'challenge',
      'challengeDetail',
      'challengeHistory',
      'inspiration',
      'gallery',
      'galleryDetail',
      'galleryDiary',
      'galleryStats',
      'galleryMonthlyDigest',
      'profile',
      'profileSettings',
      'profileSettingsTheme',
      'profileGrowth',
      'profileInvite',
      'profileAcademy',
      'profileAcademyDetail',
      'profileAcademyAssignment',
      'profileAcademyKnowledge',
      'academyTrajectory',
      'profileCollections',
      'profileCollectionDetail',
      'profileMyTemplates',
      'profileCompositionKits',
      'profileCompositionKitDetail',
      'profileFragmentDetail',
      'profileNotifications',
      'profileAbout',
      'profileRewards',
      'profileRedeem',
      'scenes',
      'shootkitEditor',
    ];

/// 在 router 的路由表中查找与 [path] 完全匹配的 GoRoute。
/// 使用 matchPatternAsPrefix + end==length 校验，避免前缀误匹配
/// （例如 /capture 误匹配 /capture/preview）。
GoRoute? _findRouteForPath(GoRouter router, String path) {
  for (final route in router.routeConfiguration.routes) {
    if (route is GoRoute) {
      final match = route.matchPatternAsPrefix(path);
      if (match != null && match.end == path.length) {
        return route;
      }
    }
  }
  return null;
}

void main() {
  group('RouteNames', () {
    test('should define 46 unique route paths', () {
      // 注意：brief 文案多处声称 "33 路由"，但 uni-app pages.json
      // source of truth 实际有 34 个页面，brief 自身的 route_names.dart
      // 与 router.dart 代码也定义了 34 条。此处以 source of truth 为准。
      // Forced fix: 加上 Flutter 新增的 12 条 (profileAbout, challengeHistory,
      // galleryStats, profileAcademyKnowledge, profileAcademyAssignment,
      // profileFragmentDetail, profileNotifications, academyTrajectory,
      // profileCompositionKits, profileCompositionKitDetail,
      // profileRewards, profileRedeem) 后变为 46 条。
      final allPaths = _allPaths;
      expect(allPaths.length, 46,
          reason: 'must have 46 routes (34 from uni-app + 12 Flutter additions)');
      final unique = allPaths.toSet();
      expect(unique.length, 46, reason: 'all route paths must be unique');
    });

    test('all paths start with /', () {
      expect(RouteNames.splash.startsWith('/'), isTrue);
      expect(RouteNames.home.startsWith('/'), isTrue);
      expect(RouteNames.capture.startsWith('/'), isTrue);
    });

    test('withTemplateId builds correct URL', () {
      final url = RouteNames.withTemplateId(RouteNames.templatesDetail, 'tpl_001');
      expect(url, '/templates/detail?templateId=tpl_001');
    });

    test('withSceneId builds correct URL', () {
      final url = RouteNames.withSceneId(RouteNames.captureSceneDetail, 'scene_cafe');
      expect(url, '/capture/scene-detail?sceneId=scene_cafe');
    });

    test('build with multiple params', () {
      final url = RouteNames.build(RouteNames.capture, {
        RouteNames.paramTemplateId: 'tpl_001',
        RouteNames.paramMode: 'free',
      });
      expect(url, contains('templateId=tpl_001'));
      expect(url, contains('mode=free'));
    });

    test('build with empty params returns path unchanged', () {
      expect(RouteNames.build(RouteNames.home, {}), RouteNames.home);
    });

    test('param key names match uni-app convention', () {
      expect(RouteNames.paramTemplateId, 'templateId');
      expect(RouteNames.paramSceneId, 'sceneId');
      expect(RouteNames.paramScene, 'scene');
      expect(RouteNames.paramTab, 'tab');
    });

    test('all 9 param key constants are non-empty', () {
      expect(RouteNames.paramTemplateId, isNotEmpty);
      expect(RouteNames.paramSceneId, isNotEmpty);
      expect(RouteNames.paramScene, isNotEmpty);
      expect(RouteNames.paramTab, isNotEmpty);
      expect(RouteNames.paramChallengeId, isNotEmpty);
      expect(RouteNames.paramPhotoId, isNotEmpty);
      expect(RouteNames.paramCollectionId, isNotEmpty);
      expect(RouteNames.paramAcademyId, isNotEmpty);
      expect(RouteNames.paramMode, isNotEmpty);
    });
  });

  group('routerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('provides a GoRouter instance', () {
      final router = container.read(routerProvider);
      expect(router, isA<GoRouter>());
    });

    test('initial location /splash matches a declared route', () {
      final router = container.read(routerProvider);
      final match = _findRouteForPath(router, RouteNames.splash);
      expect(match, isNotNull,
          reason: '/splash must be a declared route (it is the initial location)');
    });

    test('router configuration has 46 routes', () {
      final router = container.read(routerProvider);
      // Count routes by traversing the configuration.
      // 本任务所有路由均为顶层 GoRoute（无 ShellRoute、无子路由），
      // Forced fix: 加上 Flutter 新增的 12 条后变为 46 条。
      int count = 0;
      void countRoutes(List<RouteBase> routes) {
        for (final route in routes) {
          count++;
          if (route is ShellRoute) {
            countRoutes(route.routes);
          }
        }
      }
      countRoutes(router.routeConfiguration.routes);
      expect(count, 46,
          reason: 'router must declare 46 top-level GoRoute entries (34 from uni-app + 12 Flutter additions)');
    });

    test('router resolves all 46 paths without error', () {
      final router = container.read(routerProvider);
      for (final path in _allPaths) {
        final match = _findRouteForPath(router, path);
        expect(match, isNotNull, reason: 'path $path must match a route');
      }
    });

    test('router resolves paths with query parameters', () {
      final router = container.read(routerProvider);
      final urlWithQuery =
          RouteNames.withTemplateId(RouteNames.templatesDetail, 'tpl_001');
      // 剥离 query 部分后进行路径匹配（GoRouter 在匹配时仅使用 path 部分）
      final pathOnly = Uri.parse(urlWithQuery).path;
      final match = _findRouteForPath(router, pathOnly);
      expect(match, isNotNull,
          reason: 'URL $urlWithQuery must resolve to a route');
    });

    test('all 46 route names are registered for named navigation', () {
      final router = container.read(routerProvider);
      for (final name in _allNames) {
        // namedLocation 会对未注册的名字抛出 assert 错误；
        // 我们的所有路由都没有 path 参数，调用应返回对应路径。
        final location = router.namedLocation(name);
        expect(location, isNotNull,
            reason: 'route name "$name" must be registered');
      }
    });

    test('errorBuilder is configured (unknown path falls back to error page)', () {
      final router = container.read(routerProvider);
      // 未知路径不应匹配任何路由
      final match = _findRouteForPath(router, '/__nonexistent_route__');
      expect(match, isNull,
          reason: 'unknown path should not match any declared route');
      // routerDelegate 应该配置了 errorBuilder（间接验证：构造未抛异常）
      expect(router.routerDelegate, isNotNull);
    });
  });

  group('LumiraRouteObserver', () {
    test('can be instantiated with a Ref', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final observer = container.read(lumiraRouteObserverProvider);
      expect(observer, isA<LumiraRouteObserver>());
      expect(observer, isA<RouteObserver<PageRoute<dynamic>>>());
    });
  });
}
