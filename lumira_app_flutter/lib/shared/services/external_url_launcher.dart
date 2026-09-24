import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 跨平台打开外部链接（http/https）服务
///
/// OHOS 端 url_launcher 无原生实现，优先走原生通道
/// MethodChannel('lumira/open_url')（uiAbility.context.openLink 拉起系统浏览器，
/// 见 ohos/.../plugins/OpenUrlPlugin.ets）；通道未注册（非 OHOS 构建）抛
/// MissingPluginException 时回退 url_launcher（iOS/Android）。
class ExternalUrlLauncher {
  ExternalUrlLauncher._();

  static final ExternalUrlLauncher instance = ExternalUrlLauncher._();

  static const String _channelName = 'lumira/open_url';

  final MethodChannel _channel = const MethodChannel(_channelName);

  /// 用系统浏览器打开外部链接，返回是否成功拉起。
  ///
  /// - OHOS：原生 openLink 成功返回 true；失败（无浏览器等）继续尝试
  ///   url_launcher（必然失败）后返回 false，由调用方自行兜底
  /// - iOS/Android：url_launcher 结果
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      if (result == true) return true;
    } on MissingPluginException {
      // 非 OHOS 平台无原生通道，走 url_launcher
    } catch (_) {
      // 原生通道异常（未注册/通信失败），仍尝试 url_launcher 兜底
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}
