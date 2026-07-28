import 'package:flutter/foundation.dart';

/// 设备操作系统
///
/// 后端契约：'android' | 'ios' | 'harmonyos'（字符串）
enum DeviceOs {
  android,
  ios,
  harmonyos,
}

extension DeviceOsExt on DeviceOs {
  String toJson() {
    switch (this) {
      case DeviceOs.android:
        return 'android';
      case DeviceOs.ios:
        return 'ios';
      case DeviceOs.harmonyos:
        return 'harmonyos';
    }
  }

  static DeviceOs fromJson(String s) {
    switch (s) {
      case 'android':
        return DeviceOs.android;
      case 'ios':
        return DeviceOs.ios;
      case 'harmonyos':
        return DeviceOs.harmonyos;
      default:
        return DeviceOs.android;
    }
  }
}

/// POST /api/v1/device/register 请求体
@immutable
class RegisterDeviceRequest {
  final String deviceId;
  final DeviceOs os;

  const RegisterDeviceRequest({required this.deviceId, required this.os});

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'os': os.toJson(),
      };
}

/// POST /api/v1/device/register 响应体
///
/// 后端契约：{ token: string, isNewDevice: boolean }
@immutable
class RegisterDeviceResponse {
  final String token;
  final bool isNewDevice;

  const RegisterDeviceResponse({
    required this.token,
    required this.isNewDevice,
  });

  factory RegisterDeviceResponse.fromJson(Map<String, dynamic> j) {
    return RegisterDeviceResponse(
      token: j['token'] as String,
      isNewDevice: j['isNewDevice'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'isNewDevice': isNewDevice,
      };
}

/// GET /api/v1/device/:id 响应体（管理员端点，Flutter 不主动调用，留作未来扩展）
@immutable
class DeviceRecord {
  final String deviceId;
  final String? alias;
  final int firstSeenAt;
  final int lastSeenAt;
  final String? ipRegion;

  const DeviceRecord({
    required this.deviceId,
    this.alias,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.ipRegion,
  });

  factory DeviceRecord.fromJson(Map<String, dynamic> j) {
    return DeviceRecord(
      deviceId: j['deviceId'] as String,
      alias: j['alias'] as String?,
      firstSeenAt: j['firstSeenAt'] as int,
      lastSeenAt: j['lastSeenAt'] as int,
      ipRegion: j['ipRegion'] as String?,
    );
  }
}
