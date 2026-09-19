import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'core/auth/auth_controller.dart';
import 'core/compliance/compliance_gate.dart';
import 'core/config/app_config.dart';
import 'core/db/database_provider.dart';
import 'core/startup/post_compliance_init.dart';
import 'core/router/route_names.dart';
import 'core/services/deep_link_service.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/system_brightness_watcher.dart';
import 'core/utils/safe_share.dart';
import 'core/utils/share_reporter.dart';
import 'features/capture/data/capture_state.dart';
import 'features/points/data/points_repository.dart';
import 'features/profile/data/growth_models.dart';
import 'features/profile/data/profile_models.dart';
import 'features/profile/services/growth_xp_provider.dart';
import 'features/templates/services/template_import_service.dart';
import 'features/templates/services/template_share_code.dart';
import 'features/templates/widgets/template_import_sheet.dart';
import 'shared/widgets/lumira/feedback/lumira_toast.dart';

/// 应用根 Widget（接入 ProviderScope + routerProvider + appThemeProvider）
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);

    return SystemBrightnessWatcher(
      child: MaterialApp.router(
        title: '如画 Lumira',
        debugShowCheckedModeBanner: false,
        theme: appTheme.toThemeData(),
        routerConfig: router,
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 框架级异常兜底：release 下 FlutterError 默认只 dump 到控制台，界面上没有任何反馈，
  // 用户看到的就是"白屏"。这里显式上报，便于 hilog / 崩溃平台定位。
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _reportFatal(details.exception, details.stack);
  };

  Object? bootError;
  StackTrace? bootStack;

  // 启动链整体放进 zone：任何逃逸到这里的异常都会被捕获，最后兜底渲染错误页，
  // 而不是留下一个白屏。
  await runZonedGuarded(
    _bootstrapAndRun,
    (Object error, StackTrace stack) {
      bootError ??= error;
      bootStack ??= stack;
      _reportFatal(error, stack);
    },
  );

  if (bootError != null) {
    // 启动失败（典型：sqflite 原生库缺失导致 _createBootstrapDaos 抛异常）
    // —— 宁可把错误显示出来，也不要白屏。
    runApp(_BootErrorApp(error: bootError!, stack: bootStack));
  }
}

/// 把致命错误打到控制台（release 下也会输出，鸿蒙上会进 hilog）。
void _reportFatal(Object error, StackTrace? stack) {
  FlutterError.dumpErrorToConsole(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'Lumira bootstrap',
    ),
  );
}

/// Bootstrap 失败时的兜底 UI。
///
/// 原先 main() 在 runApp 之前会 await sqflite 初始化（_createBootstrapDaos），
/// 一旦原生库缺失或数据库损坏抛异常，runApp 永远不会执行 —— 用户只看到白屏，
/// 且没有任何可反馈的信息。这里把异常直接渲染出来，至少能自证问题。
class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '启动失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  '应用初始化时发生错误。请重启应用；若持续出现，请联系客服并提供下面的信息。',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '${stack == null ? error : '$error\n\n$stack'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 启动链：全部初始化 + runApp。
///
/// 任何异常向上抛给 main 里的 runZonedGuarded，由它决定渲染错误页。
Future<void> _bootstrapAndRun() async {
  // 性能(OHOS): 调大解码位图缓存上限（Flutter 默认 100MB / 1000 张）。
  // 四个 Tab 页常驻 + 图片密集，默认上限会在滚动时频繁淘汰已解码缩略图；
  // 而 ln 引擎 dart:ui 图片解码慢，滚动回看/新卡入屏会因重新解码掉帧。
  // 提到 200MB / 600 张：既容纳 4 页缩略图避免频繁淘汰，又不至于撑爆 OHOS 内存。
  PaintingBinding.instance.imageCache.maximumSize = 600;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;

  // 锁定竖屏方向：UI 整体保持竖屏，绝不随设备旋转到横屏（避免 iOS 横屏后整体布局
  // 被拉伸挤压、取景器都看不全）。
  // 横屏拍摄的适配不依赖整屏旋转，而是走加速度传感器（见 capture_page/level_sensor_service）：
  //   - 成片方向：横持手机时拍出的照片按原相机逻辑转 90° 成为横图；
  //   - 悬浮模板信息卡：横持时单独旋转该卡到可读角度，其余 UI 不变。
  // 启动性能：不 await 此项，避免阻塞首帧。
  // ignore: unawaited_futures
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // == 延迟首帧：不 await sqflite 打开/种子化，立刻构造容器并 runApp。
  //    数据库打开、内置模板种子化、求快版本读取、auth bootstrap 全部挪到
  //    [_initStartupAsync] 后台异步执行，Splash 首帧即刻渲染。
  //    （AppGallery Connect 审核「启动加载完成时延 ≤1100ms」被此项阻塞导致超基准。）
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => _createAuthController(ref)),
    ],
  );

  // 分享积分上报：调起系统分享即计分（每日首享 +2，幂等由后端保证）
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

  // 分享降级反馈：share_plus 不可用（鸿蒙）降级到剪贴板时，Toast 告知用户结果
  SafeShare.onFallback = (message) {
    // 注意：不能用 Overlay.of(rootNavigatorKey.currentContext!)——Navigator 自身的
    // context 位于它创建的 Overlay 之上，向上查找会抛 "No Overlay widget found"。
    // 应通过 NavigatorState.overlay 获取 OverlayState 后直接显示。
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    LumiraToast.showWithOverlay(overlay, message);
  };

  // 深链监听：冷启动链接 + 运行中链接
  // ignore: unawaited_futures
  DeepLinkService.instance.start(
    onTemplateLink: (link) => _handleTemplateLink(container, link),
  );

  // 恢复持久化的主题与 UI 风格（内部异步读 DB，后台执行，不阻塞首帧）
  // ignore: unawaited_futures
  restoreThemePreferences(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  // 后台初始化链：DB 打开(含首装种子化) → 合规版本 → auth bootstrap → 就绪标记。
  // 交由 runZonedGuarded 捕获，任何异常都走 [_initStartupAsync] 内的兜底而非白屏。
  // ignore: unawaited_futures
  _initStartupAsync(container);
}

/// 后台创建 AuthController：所有 DAO 依赖以惰性 Future 注入，
/// 首个操作时才解析 sqflite（authDaoProvider.future 会触发 DB 打开/种子化）。
AuthController _createAuthController(Ref ref) {
  return AuthController(
    dao: ref.read(authDaoProvider.future),
    resolveDeviceId: () async =>
        defaultResolveDeviceId(await ref.read(authDaoProvider.future)),
    resolveOs: defaultResolveOs,
    doRegister: _doRegister,
    onRegistered: (result) async {
      final profile = result.profile;
      if (profile == null) return;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final profileDao = await ref.read(userProfileDaoProvider.future);
      await profileDao.upsert(profile, now);
    },
  );
}

/// 启动后台初始化（fire-and-forget，不阻塞首帧）。
///
/// 顺序：确保 DB 打开（首装时在此完成内置模板种子化）→ 读合规版本 →
/// auth bootstrap（loading→registered/fresh）→ 置 [bootstrapDoneProvider] 就绪 →
/// 非待同意则跑 post-compliance 初始化链。
Future<void> _initStartupAsync(ProviderContainer container) async {
  try {
    // 首装最耗时：openDatabase onCreate 全量种子化内置模板/分类/场景。
    await container.read(databaseProvider.future);

    // 合规门控：本地已同意版本与当前合规版本不一致即需先征得同意、
    // 在此之前不得联网/采集（注册、上报设备信息等全部延后到同意后由
    // runPostComplianceInit 执行）。
    final settingsDao = await container.read(settingsDaoProvider.future);
    final awaitingCompliance =
        await settingsDao.getComplianceVersion() != complianceCurrentVersion;
    container.read(complianceAwaitingProvider.notifier).state = awaitingCompliance;

    // auth bootstrap：从 sqflite 加载已存的 token/deviceId
    await container.read(authControllerProvider.notifier).bootstrap();

    container.read(bootstrapDoneProvider.notifier).state = true;

    // 已同意（非首启）直接跑初始化链
    if (!awaitingCompliance) {
      // ignore: unawaited_futures
      runPostComplianceInit(container);
    }
  } catch (e, st) {
    // 后台初始化失败：绝不白屏。记录日志，并把 auth 置为 failed 让 Splash 显示
    // 「网络连接失败 + 重试」。同时标记就绪，避免 Splash 无限转圈。
    _reportFatal(e, st);
    container.read(authControllerProvider.notifier).markStartupFailed(e);
    container.read(bootstrapDoneProvider.notifier).state = true;
  }
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

  final registerData = await collectDeviceInfo(os);
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

/// 处理模板深链：完整 JSON → 直接导入；否则打开导入面板让用户手动操作。
void _handleTemplateLink(ProviderContainer container, String link) {
  // 合规门控优先：待同意时深链一律忽略，禁止导入/导航/弹出导入面板，
  // 否则会绕过合规弹窗从 Splash 跳走。待用户同意并正常进入首页后此跳转自然丢弃。
  if (container.read(complianceAwaitingProvider)) return;
  final parsed = TemplateShareCode.parseLink(link);
  if (parsed == null || parsed['meta'] is! Map) {
    // 无法解析或为轻量形式 → 打开导入面板手动粘贴/选择
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      TemplateImportSheet.show(context, onImported: (_) {});
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
    final context = rootNavigatorKey.currentContext;
    // ignore: use_build_context_synchronously
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.ok ? result.message : '导入失败：${result.error}'),
    ));
    if (result.ok) {
      GoRouter.of(context).go(RouteNames.profileMyTemplates);
    }
  });
}
