import 'dart:io';

/// camerawesome 系列库的三端差异委托。
/// 三端 CamerawesomeCameraService 共用一份业务代码，
/// delegate 负责处理平台特定行为差异。
class CamerawesomeDelegate {
  const CamerawesomeDelegate({
    required this.platformTag,
    required this.zoomIsMultiplier,
  });

  /// 'ohos' | 'ios' | 'android'
  final String platformTag;

  /// OHOS: true（CamerawesomePlugin.setZoom 期望真实倍数 1.0=1x）
  /// iOS/Android: false（SensorConfig.setZoom 归一化到 [0,1]）
  final bool zoomIsMultiplier;

  static const ohos = CamerawesomeDelegate(
    platformTag: 'ohos',
    zoomIsMultiplier: true,
  );
  static const ios = CamerawesomeDelegate(
    platformTag: 'ios',
    zoomIsMultiplier: false,
  );
  static const android = CamerawesomeDelegate(
    platformTag: 'android',
    zoomIsMultiplier: false,
  );

  static CamerawesomeDelegate forCurrentPlatform() {
    if (Platform.isIOS) return ios;
    if (Platform.isAndroid) return android;
    return ohos; // HarmonyOS / fallback
  }
}
