import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uni_links/uni_links.dart' as uni_links;

import '../../features/templates/services/template_share_code.dart';

/// 统一 URL 深链接收服务。
///
/// 平台分发：
/// - HarmonyOS：自定义 MethodChannel `lumira/deep_link`（见 ohos DeepLinkPlugin.ets）
/// - Android / 其他：uni_links 插件
/// 均封装为 [getInitialLink] + [onLink]，业务层只关心链接字符串。
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  String? _initial;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<String>.broadcast();

  /// 运行中收到的深链（冷启动 initial 链接也会先推送）
  Stream<String> get onLink => _controller.stream;

  void Function(String link)? onTemplateLink;

  /// 启动监听：读取冷启动链接 + 订阅运行中链接。
  Future<void> start({void Function(String link)? onTemplateLink}) async {
    this.onTemplateLink = onTemplateLink;
    _controller.stream.listen(_dispatch);

    final initial = await getInitialLink();
    if (initial != null && initial.isNotEmpty) {
      // 等首帧挂载后再分发，确保 navigator 就绪
      WidgetsBinding.instance.addPostFrameCallback((_) => _dispatch(initial));
    }
    _subscribeStream();
  }

  /// 冷启动时的初始链接（null = 无）
  Future<String?> getInitialLink() async {
    if (_initial != null) return _initial;
    try {
      if (Platform.operatingSystem == 'ohos') {
        const channel = MethodChannel('lumira/deep_link');
        final link = await channel.invokeMethod<String>('getInitialLink');
        _initial = (link == null || link.isEmpty) ? null : link;
        return _initial;
      }
      final link = await uni_links.getInitialLink();
      _initial = link;
      return _initial;
    } catch (_) {
      // 插件缺失 / 平台不支持 → 静默降级（粘贴导入通路保留）
      return null;
    }
  }

  void _subscribeStream() {
    if (Platform.operatingSystem == 'ohos') return; // OHOS 走插件通道
    _sub ??= uni_links.uriLinkStream.listen((uri) {
      final link = uri?.toString();
      if (link != null && link.isNotEmpty) {
        _controller.add(link);
      }
    });
  }

  void _dispatch(String link) {
    if (isTemplateLink(link)) {
      onTemplateLink?.call(link);
    }
  }

  /// 判断链接是否命中模板深链（可被 [TemplateShareCode.parseLink] 解析）
  static bool isTemplateLink(String link) {
    return TemplateShareCode.parseLink(link) != null;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
