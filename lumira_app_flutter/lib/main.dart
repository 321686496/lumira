import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_dao.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
import 'core/theme/theme_controller.dart';

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

  // 1. 等待 sqflite 就绪并取出 AuthDao
  final authDao = await _createAuthDao();

  // 2. 创建 AuthController 并 bootstrap（从 sqflite 加载已存的 token/deviceId）
  final authController = AuthController(
    dao: authDao,
    resolveDeviceId: () => defaultResolveDeviceId(authDao),
    resolveOs: defaultResolveOs,
    doRegister: _doRegister,
  );

  await authController.bootstrap();

  // 3. 若未注册则后台触发（不阻塞 UI，由 splash 监听状态）
  // ignore: invalid_use_of_protected_member
  if (authController.state.needsRegistration) {
    authController.registerIfNeeded(); // fire-and-forget
  }

  // 4. 注入 authController 到全局 Provider，启动 app
  runApp(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
      ),
      child: const MyApp(),
    ),
  );
}

/// 创建临时 ProviderContainer 用于 bootstrap 阶段读取 authDaoProvider
Future<AuthDao> _createAuthDao() async {
  final container = ProviderContainer();
  await container.read(databaseProvider.future);
  final dao = await container.read(authDaoProvider.future);
  return dao;
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
  // 创建一个无鉴权拦截的 Dio 直接调用 /device/register
  // （此时 AuthController 未就绪，无法用 apiClientProvider）
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: AppConfig.connectTimeoutMs,
    receiveTimeout: AppConfig.receiveTimeoutMs,
    headers: {'Content-Type': 'application/json'},
  ));
  final resp = await dio.post('/device/register', data: {
    'deviceId': deviceId,
    // 后端 RegisterDeviceDto 只接受 deviceId 和 alias，os 字段会被 forbidNonWhitelisted 拒绝
    // 后端通过 IP 推断地域，不需要 os 信息
    // 如未来后端需要 os，在此处重新添加 'os': os
  });
  final body = resp.data as Map<String, dynamic>;
  return RegisterResult(
    token: body['token'] as String,
    isNewDevice: body['isNewDevice'] as bool,
  );
}
