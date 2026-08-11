import 'dart:io';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
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

  // 5. 初始化个人资料：拉取/补传（不阻塞启动）
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
  
  final deviceInfo = DeviceInfoPlugin();
  Map<String, dynamic> registerData = {
    'deviceId': deviceId,
  };
  
  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    registerData['platform'] = os;
    registerData['osVersion'] = '${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    registerData['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
    registerData['appVersion'] = '1.0.0';
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    registerData['platform'] = 'ios';
    registerData['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
    registerData['deviceModel'] = iosInfo.utsname.machine;
    registerData['appVersion'] = '1.0.0';
  }
  
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
