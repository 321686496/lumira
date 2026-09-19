import 'package:flutter/services.dart';

/// OHOS 原生扫码服务（HarmonyOS Scan Kit 默认界面扫码）
///
/// mobile_scanner 在 OHOS 平台无原生实现，相机扫码改为调用系统级扫码界面
/// （@kit.ScanKit scanBarcode.startScanForResult，见 ohos/.../plugins/ScanPlugin.ets）：
/// - 相机权限由系统扫码界面预授权，调用期间处于安全访问状态，无需应用自行申请
/// - 扫码界面自带相册识码入口（原生侧开启 enableAlbum）
///
/// 返回识别到的原始文本；用户取消返回 null；其他失败抛 PlatformException；
/// 原生侧未注册通道（非 OHOS 构建）抛 MissingPluginException。
class OhosScanService {
  OhosScanService._();

  static final OhosScanService instance = OhosScanService._();

  static const String _channelName = 'lumira/scan';

  final MethodChannel _channel = const MethodChannel(_channelName);

  /// 启动系统扫码界面并返回识别到的原始文本。
  ///
  /// - 用户取消扫码：返回 null
  /// - 平台未实现（非 OHOS 构建 / 原生侧未注册通道）：抛 MissingPluginException
  /// - 扫码失败：抛 PlatformException
  Future<String?> scan() async {
    try {
      final result = await _channel.invokeMethod<String>('startScan');
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELED') return null;
      rethrow;
    }
  }
}
