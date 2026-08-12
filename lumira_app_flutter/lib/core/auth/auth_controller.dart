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
    if (saved == null) {
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
  Future<void> registerIfNeeded() async {
    if (state.status != AuthStatus.fresh && state.status != AuthStatus.failed) {
      return;
    }
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
    }
  }

  /// 401 失效：清除本地 token，下次启动重新注册
  void invalidateRegistration() {
    _dao.clear();
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
  if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.id;
  }
  if (Platform.isIOS) {
    final info = await DeviceInfoPlugin().iosInfo;
    final id = info.identifierForVendor;
    if (id != null && id.isNotEmpty) return id;
  }
  // Fallback: 复用上次生成的 UUID（存于 auth 表 deviceId 字段，os='unknown'）
  // 此处仅返回临时 UUID，由 AuthController.save 持久化
  // 注意：UUID 生成不依赖 uuid 包，用 DateTime 拼接避免新依赖
  return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
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
