import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_controller.dart';
import 'features/profile/data/profile_dao.dart';
import 'features/profile/data/profile_models.dart';
import 'features/profile/providers/profile_providers.dart';

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

  // 5. 已注册设备：启动补传设备信息（修复历史版本平台信息缺失/误判，不阻塞启动）
  // 注意用 defaultResolveOs() 而非 state.os——旧设备可能存了错误的 'android'
  if (!authController.state.needsRegistration) {
    // ignore: unawaited_futures
    _reportDeviceInfo(container, defaultResolveOs());
  }

  // 6. 初始化个人资料：拉取/补传（不阻塞启动）
  container.read(profileSyncServiceProvider.future).then((sync) async {
    await sync.ensureLoadedIfMissing();
    await sync.syncPendingIfNeeded();
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
