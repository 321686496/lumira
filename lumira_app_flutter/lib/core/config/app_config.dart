import 'package:flutter/foundation.dart';

/// 应用环境配置
///
/// baseUrl 通过 --dart-define=API_BASE_URL=xxx 切换
/// 默认指向 Android 模拟器宿主机（10.0.2.2 = host loopback）
/// 真机调试时需替换为开发机局域网 IP，例如
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000/api/v1
class AppConfig {
  const AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://10.0.2.2:8880/api/v1',
    defaultValue: 'https://lumira.iwtle.top/api/v1',
    // defaultValue: 'http://124.71.61.105/lumira/api/v1',
  );

  static const int connectTimeoutMs = 8000;
  static const int receiveTimeoutMs = 10000;

  /// App 版本号（与 pubspec.yaml version 对齐：1.0.0+1）
  /// 通过 --dart-define=APP_VERSION=xxx 覆盖，未传入时回退默认值
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static bool get isRelease => kReleaseMode;
}
