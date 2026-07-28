import 'package:flutter/foundation.dart';

/// 鉴权状态
enum AuthStatus {
  /// 初始加载中
  loading,
  /// 未注册，需要调用 /device/register
  fresh,
  /// 已注册，token 可用
  registered,
  /// 注册失败
  failed,
}

/// 鉴权状态数据
@immutable
class AuthState {
  final AuthStatus status;
  final String? token;
  final String? deviceId;
  final String? os; // 'android' | 'ios' | 'harmonyos'
  final bool isNewDevice;
  final String? lastError;

  const AuthState({
    this.status = AuthStatus.loading,
    this.token,
    this.deviceId,
    this.os,
    this.isNewDevice = false,
    this.lastError,
  });

  /// 是否需要触发注册
  bool get needsRegistration => status == AuthStatus.fresh;

  /// 是否就绪（可发请求）
  bool get isReady => status == AuthStatus.registered;

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? deviceId,
    String? os,
    bool? isNewDevice,
    String? lastError,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      os: os ?? this.os,
      isNewDevice: isNewDevice ?? this.isNewDevice,
      lastError: lastError ?? this.lastError,
    );
  }
}
