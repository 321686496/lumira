import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
import 'core/network/api_client.dart';
import 'core/router/route_names.dart';
import 'core/services/deep_link_service.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/safe_share.dart';
import 'core/utils/share_reporter.dart';
import 'features/capture/data/capture_state.dart';
import 'features/points/data/points_repository.dart';
import 'features/profile/data/growth_models.dart';
import 'features/profile/data/profile_dao.dart';
import 'features/profile/data/profile_models.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/profile/services/growth_xp_provider.dart';
import 'features/templates/services/template_import_service.dart';
import 'features/templates/services/template_share_code.dart';
import 'features/templates/widgets/template_import_sheet.dart';
import 'features/usage/usage_providers.dart';
import 'shared/widgets/lumira/feedback/lumira_toast.dart';

/// 应用根 Widget（接入 ProviderScope + routerProvider + appThemeProvider）
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);

    return MaterialApp.router(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      theme: appTheme.toThemeData(),
      routerConfig: router,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏方向：UI 整体保持竖屏，绝不随设备旋转到横屏（避免 iOS 横屏后整体布局
  // 被拉伸挤压、取景器都看不全）。
  // 横屏拍摄的适配不依赖整屏旋转，而是走加速度传感器（见 capture_page/level_sensor_service）：
  //   - 成片方向：横持手机时拍出的照片按原相机逻辑转 90° 成为横图；
  //   - 悬浮模板信息卡：横持时单独旋转该卡到可读角度，其余 UI 不变。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 1. 等待 sqflite 就绪并取出 AuthDao + UserProfileDao
  final daos = await _createBootstrapDaos();

  // 2. 创建 AuthController 并 bootstrap（从 sqflite 加载已存的 token/deviceId）
  final authController = AuthController(
    dao: daos.authDao,
    resolveDeviceId: () => defaultResolveDeviceId(daos.authDao),
    resolveOs: defaultResolveOs,
    doRegister: _doRegister,
    onRegistered: (result) async {
      final profile = result.profile;
      if (profile == null) return;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await daos.profileDao.upsert(profile, now);
    },
  );

  await authController.bootstrap();

  // 3. 若未注册则后台触发（不阻塞 UI，由 splash 监听状态）
  // ignore: invalid_use_of_protected_member
  if (authController.state.needsRegistration) {
    authController.registerIfNeeded(); // fire-and-forget
  }

  // 4. 注入 authController 到全局 Provider，启动 app
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => authController),
    ],
  );

  // 4.5 分享积分上报：调起系统分享即计分（每日首享 +2，幂等由后端保证）
  ShareReporter.onShare = () async {
    try {
      final repo = await container.read(pointsRepositoryProvider.future);
      await repo.earn(type: 'share');
      // 每日首享经验（+20）写台账 + 结算升级奖励
      try {
        final db = await container.read(databaseProvider.future);
        await awardAndClaim(
          db: db,
          repo: repo,
          source: 'share',
          amount: 20,
          refId: utc8DateStr(),
        );
      } catch (_) {
        // 网络/鉴权失败静默
      }
    } catch (_) {
      // 网络/鉴权失败静默，不影响分享主流程
    }
  };

  // 4.55 分享降级反馈：share_plus 不可用（鸿蒙）降级到剪贴板时，Toast 告知用户结果
  SafeShare.onFallback = (message) {
    // 注意：不能用 Overlay.of(rootNavigatorKey.currentContext!)——Navigator 自身的
    // context 位于它创建的 Overlay 之上，向上查找会抛 "No Overlay widget found"。
    // 应通过 NavigatorState.overlay 获取 OverlayState 后直接显示。
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    LumiraToast.showWithOverlay(overlay, message);
  };

  // 4.6 深链监听：冷启动链接 + 运行中链接
  // ignore: unawaited_futures
  DeepLinkService.instance.start(
    onTemplateLink: (link) => _handleTemplateLink(container, link),
  );

  // 4.7 恢复持久化的主题与 UI 风格（写回 StateProvider，供首帧生效）
  // ignore: unawaited_futures
  restoreThemePreferences(container);

  // 5. 设备信息补传（修复历史版本平台信息缺失/误判，不阻塞启动）
  //
  // 注意：原来的 `if (!needsRegistration)` 判断会误触发——registerIfNeeded() 调用后
  // 状态已同步变为 loading，needsRegistration 立即为 false，导致未注册设备也提前
  // 发出 PATCH /device/info（token 尚未就绪）→ 无 Authorization → 401。
  // 统一改为先等待注册完成拿到有效 token，再执行鉴权请求。
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) {
    if (!ok) return; // 注册失败：静默，splash 会显示重试入口
    _reportDeviceInfo(container, defaultResolveOs());
  });

  // 6. 初始化个人资料：拉取/补传。同样等待注册完成拿到 token 后再执行。
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) async {
    if (!ok) return;
    final sync = await container.read(profileSyncServiceProvider.future);
    await sync.ensureLoadedIfMissing();
    await sync.syncPendingIfNeeded();
  });

  // 6.5 使用次数同步（启动时上报未同步埋点 + 拉取全站次数；失败静默不阻塞启动）
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) async {
    if (!ok) return;
    try {
      final us = await container.read(usageSyncServiceProvider.future);
      await us.runSync();
    } catch (_) {
      // 网络/鉴权失败静默
    }
  });

  // 6.6 内置模板名称同步（同步 id/名称到后端；失败静默不阻塞启动）
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) async {
    if (!ok) return;
    try {
      final bts = await container.read(builtinTemplateSyncServiceProvider.future);
      await bts.syncBuiltinTemplates();
    } catch (_) {
      // 网络/鉴权失败静默
    }
  });

  // 6.7 内置场景名称同步（同步 id/名称到后端；失败静默不阻塞启动）
  // ignore: unawaited_futures
  authController.ensureRegistered().then((ok) async {
    if (!ok) return;
    try {
      final bss = await container.read(builtinSceneSyncServiceProvider.future);
      await bss.syncBuiltinScenes();
    } catch (_) {
      // 网络/鉴权失败静默
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

/// Bootstrap 阶段所需的 DAO 集合（Dart 2.19 无 records，用私有类承载）
class _BootstrapDaos {
  final AuthDao authDao;
  final UserProfileDao profileDao;
  const _BootstrapDaos({required this.authDao, required this.profileDao});
}

/// 创建临时 ProviderContainer 用于 bootstrap 阶段读取 authDaoProvider / userProfileDaoProvider
Future<_BootstrapDaos> _createBootstrapDaos() async {
  final container = ProviderContainer();
  await container.read(databaseProvider.future);
  final authDao = await container.read(authDaoProvider.future);
  final profileDao = await container.read(userProfileDaoProvider.future);
  return _BootstrapDaos(authDao: authDao, profileDao: profileDao);
}

/// 设备注册回调
///
/// 注意：原 plan 使用 Dart 3.0+ record 语法 `({String token, bool isNewDevice})`，
/// 但项目环境为 Dart 2.19.6（鸿蒙 Flutter 3.7.12），不支持 records，
/// 改用 RegisterResult 类（定义于 auth_controller.dart）
Future<RegisterResult> _doRegister({
  required String deviceId,
  required String os,
}) async {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConfig.connectTimeoutMs,
    receiveTimeout: AppConfig.receiveTimeoutMs,
    headers: {'Content-Type': 'application/json'},
  ));

  final registerData = await _collectDeviceInfo(os);
  registerData['deviceId'] = deviceId;

  final resp = await dio.post('/device/register', data: registerData);
  final body = resp.data as Map<String, dynamic>;
  final profileJson = body['profile'];
  return RegisterResult(
    token: body['token'] as String,
    isNewDevice: body['isNewDevice'] as bool,
    profile: profileJson is Map<String, dynamic>
        ? ProfileData.fromJson(profileJson)
        : null,
  );
}

/// 采集设备信息
///
/// 注意：鸿蒙（HarmonyOS）环境下 Platform.isAndroid / isIOS 均为 false，
/// 若按平台分支填充字段会导致平台、系统版本、型号全部缺失。
/// 故始终填充 platform（= os）与 appVersion，版本/型号用 try-catch 尽力采集：
/// 鸿蒙 Flutter 提供 androidInfo 兼容实现，失败再回退 iosInfo，最终回退 os。
Future<Map<String, dynamic>> _collectDeviceInfo(String os) async {
  final deviceInfo = DeviceInfoPlugin();
  final data = <String, dynamic>{
    'platform': os,
    'appVersion': '1.0.0',
  };
  try {
    final androidInfo = await deviceInfo.androidInfo;
    data['osVersion'] = '${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    data['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
  } catch (_) {
    try {
      final iosInfo = await deviceInfo.iosInfo;
      data['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      data['deviceModel'] = iosInfo.utsname.machine;
    } catch (_) {
      data['osVersion'] = os;
    }
  }
  return data;
}

/// 已注册设备启动时补传设备信息（PATCH /device/info，JWT 鉴权，失败静默）
Future<void> _reportDeviceInfo(ProviderContainer container, String os) async {
  try {
    final client = await container.read(apiClientProvider.future);
    final info = await _collectDeviceInfo(os);
    await client.patch<bool>('/device/info', body: info, fromJson: (_) => true);
  } catch (_) {
    // 网络/鉴权失败不影响启动
  }
}

/// 处理模板深链：完整 JSON → 直接导入；否则打开导入面板让用户手动操作。
void _handleTemplateLink(ProviderContainer container, String link) {
  final parsed = TemplateShareCode.parseLink(link);
  if (parsed == null || !(parsed['meta'] is Map)) {
    // 无法解析或为轻量形式 → 打开导入面板手动粘贴/选择
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      TemplateImportSheet.show(ctx, onImported: (_) {});
    }
    return;
  }

  // 完整 JSON → 直接导入本地
  // ignore: unawaited_futures
  container.read(templatesDaoProvider.future).then((dao) async {
    final result = await TemplateImportService.importJson(
      parsed,
      dao: dao,
      invalidateTemplates: () async {
        container.invalidate(CaptureState.allTemplatesProvider);
      },
    );
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(result.ok ? result.message : '导入失败：${result.error}'),
    ));
    if (result.ok) {
      GoRouter.of(ctx).go(RouteNames.profileMyTemplates);
    }
  });
}
