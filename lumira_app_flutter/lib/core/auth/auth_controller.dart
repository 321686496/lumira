import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_dao.dart';
import 'auth_state.dart';
import '../../features/profile/data/profile_models.dart';

/// 设备注册结果
///
/// 注：原 plan 使用 Dart 3.0+ record 语法 `({String token, bool isNewDevice})`，
/// 但项目环境为 Dart 2.19.6（鸿蒙 Flutter 3.7.12），不支持 records，故改用等价简单类。
class RegisterResult {
  final String token;
  final bool isNewDevice;
  final ProfileData? profile;

  const RegisterResult({
    required this.token,
    required this.isNewDevice,
    this.profile,
  });
}

/// 鉴权控制器
///
/// 负责：
/// 1. 启动时从 sqflite 加载已存的 token/deviceId
/// 2. 未注册时调用 /device/register 拿新 token
/// 3. 401 失效时清除本地 token，下次启动重新注册
class AuthController extends StateNotifier<AuthState> {
  final AuthDaoLike _dao;
  final Future<String> Function() _resolveDeviceId;
  final String Function() _resolveOs;
  final Future<RegisterResult> Function({
    required String deviceId,
    required String os,
  }) _doRegister;
  final Future<void> Function(RegisterResult result)? _onRegistered;

  /// 注册进行中标志，防止并发触发多次 /device/register 相互覆盖状态
  bool _registering = false;

  AuthController({
    required AuthDaoLike dao,
    required Future<String> Function() resolveDeviceId,
    required String Function() resolveOs,
    required Future<RegisterResult> Function({
      required String deviceId,
      required String os,
    }) doRegister,
    Future<void> Function(RegisterResult result)? onRegistered,
  })  : _dao = dao,
        _resolveDeviceId = resolveDeviceId,
        _resolveOs = resolveOs,
        _doRegister = doRegister,
        _onRegistered = onRegistered,
        super(const AuthState());

  /// 当前 token（供 AuthInterceptor 注入）
  String? get currentToken => state.token;

  /// 启动加载本地 auth 状态
  Future<void> bootstrap() async {
    final saved = await _dao.load();
    // token 为空视为未注册（fresh）：401 失效时 clearToken 只清 token、
    // 保留 deviceId，此时启动不应带着空 token 发请求，而应重新注册（沿用原 deviceId）。
    if (saved == null || saved.token.isEmpty) {
      state = const AuthState(status: AuthStatus.fresh);
    } else {
      state = AuthState(
        status: AuthStatus.registered,
        token: saved.token,
        deviceId: saved.deviceId,
        os: saved.os,
        isNewDevice: saved.isNewDevice,
      );
    }
  }

  /// 触发设备注册（仅当 fresh 状态时执行）
  ///
  /// 并发安全：用 [_registering] 防抖，避免 401 风暴或启动多入口同时触发重复注册，
  /// 导致多个注册流程互相 invalidate、把新 token 冲掉而卡在 splash。
  Future<void> registerIfNeeded() async {
    if (_registering) return;
    if (state.status != AuthStatus.fresh && state.status != AuthStatus.failed) {
      return;
    }
    _registering = true;
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final deviceId = await _resolveDeviceId();
      final os = _resolveOs();
      final resp = await _doRegister(deviceId: deviceId, os: os);
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = AuthRecord(
        deviceId: deviceId,
        os: os,
        token: resp.token,
        isNewDevice: resp.isNewDevice,
        registeredAt: now,
      );
      await _dao.save(record);
      try {
        await _onRegistered?.call(resp);
      } catch (_) {
        // 资料落库失败不阻塞注册流程
      }
      state = AuthState(
        status: AuthStatus.registered,
        token: resp.token,
        deviceId: deviceId,
        os: os,
        isNewDevice: resp.isNewDevice,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.failed,
        lastError: e.toString(),
      );
    } finally {
      _registering = false;
    }
  }

  /// 等待注册完成（拿到有效 token）
  ///
  /// - 已注册：立即返回 true
  /// - fresh/failed：先触发注册（并发安全），再等待状态收敛到 registered / failed
  /// - 超时（12s）或失败：返回 false，调用方静默跳过鉴权任务
  ///
  /// 用于在启动阶段把「需要鉴权」的后台任务门控到注册完成后执行，
  /// 避免在 token 就绪前发出无 Authorization 的请求而收到 401。
  Future<bool> ensureRegistered() async {
    if (state.status == AuthStatus.registered) return true;
    if (state.status == AuthStatus.fresh || state.status == AuthStatus.failed) {
      // ignore: unawaited_futures
      registerIfNeeded();
    }

    final completer = Completer<bool>();
    late final StreamSubscription<AuthState> sub;
    sub = stream.listen(
      (next) {
        if (next.status == AuthStatus.registered) {
          if (!completer.isCompleted) completer.complete(true);
        } else if (next.status == AuthStatus.failed) {
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    // 订阅后复查当前状态，避免状态在 listen 前后已收敛造成的漏判
    final current = state;
    if (current.status == AuthStatus.registered) {
      if (!completer.isCompleted) completer.complete(true);
    } else if (current.status == AuthStatus.failed) {
      if (!completer.isCompleted) completer.complete(false);
    }

    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => false,
    );
    await sub.cancel();
    return result;
  }

  /// 401 失效：清除本地 token，保留 deviceId（下次启动/自动重注册沿用同一设备标识）
  ///
  /// 并发安全：若已有注册在进行则直接返回，避免 401 风暴中多个 onError
  /// 把 in-flight 注册的 loading 状态覆盖回 fresh——那会让 splash 短暂进入
  /// 「无 spinner 也无重试按钮」的空白态，用户点击原重试位置没有任何反应。
  void invalidateRegistration() {
    if (_registering) return;
    _dao.clearToken(); // 只清 token，不清 deviceId，避免重注册被判为新设备导致数据隔离
    state = const AuthState(status: AuthStatus.fresh);
  }
}

/// 默认的 deviceId 解析器
///
/// 平台分支：
/// - Android / HarmonyOS(ohos): AndroidInfo.id（系统 Settings.Secure.ANDROID_ID，
///   鸿蒙兼容 Android API 同样可用）
/// - iOS: IosInfo.identifierForVendor
/// - 其他 fallback: UUID v4 持久化到 sqflite
Future<String> defaultResolveDeviceId(AuthDao dao) async {
  // 优先复用本地已保存的 deviceId：
  // 注册时先查 auth 表是否有记录，有则沿用，避免任何采集抖动/失败把 deviceId
  // 换成新值——那会让后端误判为新设备（isNewDevice=true）而隔离原有数据。
  try {
    final saved = await dao.load();
    if (saved != null && saved.deviceId.isNotEmpty) return saved.deviceId;
  } catch (_) {
    // 读取失败则继续走平台采集
  }
  if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.id;
    } catch (_) {
      // 鸿蒙/部分设备采集失败：回退，避免注册在取 deviceId 时抛异常而卡在 splash
    }
  }
  if (Platform.isIOS) {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final id = info.identifierForVendor;
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {
      // 采集失败：同上回退
    }
  }
  // Fallback: 复用上次生成的 UUID（存于 auth 表 deviceId 字段，os='unknown'）
  // 此处仅返回临时 UUID，由 AuthController.save 持久化
  // 注意：UUID 生成不依赖 uuid 包，用 DateTime 拼接避免新依赖
  return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
}

/// FNV-1a 64 位稳定哈希，转十六进制。
///
/// 不依赖 crypto 包，跨实例/跨进程可复现。元素间以 '|' 分隔参与者，
/// 避免 ["ab","c"] 与 ["a","bc"] 这类排列产生相同哈希。
/// 注：Dart int 为 64 位有符号，offset basis 用其有符号等价形式，
/// 乘法依赖原生 64 位回绕得到正确哈希，返回前清除符号位得到规范十六进制。
String fnv1a64Hex(Iterable<String> parts) {
  // FNV-1a 64-bit offset basis 的有符号等价（14695981039346656037 - 2^64）
  var hash = -3750763034362895579;
  const prime = 1099511628211; // 0x100000001b3
  for (final part in parts) {
    for (final unit in part.codeUnits) {
      hash = (hash ^ unit) * prime;
    }
    // 段分隔符
    hash = (hash ^ 0x7C) * prime; // '|'
  }
  hash &= 0x7FFFFFFFFFFFFFFF; // 清除符号位，转成非负十六进制
  return hash.toRadixString(16);
}

/// 默认的 os 解析器
///
/// 鸿蒙识别：CPF-Flutter（ohos 分支）下 Platform.operatingSystem 返回 'ohos'，
/// 该方式已在 templates_editor_page / export_detail_page 中验证有效。
/// 注意：不能依赖 Platform.isAndroid 判断鸿蒙——鸿蒙兼容 Android API 时 isAndroid 为 true，
/// 不传 --dart-define=HARMONY=true 会误判为 android；isAndroid 为 false 时又会走末尾兜底 android。
String defaultResolveOs() {
  if (Platform.operatingSystem == 'ohos') return 'harmonyos';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'android';
}

/// 全局 AuthController Provider
///
/// 默认实现使用 defaultResolveDeviceId / defaultResolveOs
/// 测试时通过 override 替换
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  // 注意：authDaoProvider 是 FutureProvider，需异步读取
  // 这里使用 ref.watch 配合 .future，会在第一次访问时挂起
  // 改用 lazy 模式：在 main.dart bootstrap 中显式注入 dao
  throw UnimplementedError('Use override in main.dart to provide AuthController with dao');
});
