// lumira_app_flutter/lib/features/usage/builtin_template_sync_service.dart
//
// 内置模板名称同步：启动联网时把 App 内置模板（TemplateRegistry）的 id/当前名称
// 全量上报到后端 builtin_templates 注册表，使后台能展示内置模板名称。
// 离线/失败静默返回 false，下次启动再同步，不影响功能。

import '../../../core/network/api_client.dart';
import '../../../features/capture/data/template_registry.dart';

/// 网络抽象（便于单测注入 fake）。
abstract class BuiltinTemplateNetwork {
  /// 全量上报内置模板。path: POST /usage/builtin-templates。
  Future<void> syncBuiltinTemplates(Map<String, dynamic> body);
}

/// 基于全局 [ApiClient] 的网络实现。
class DioBuiltinTemplateNetwork implements BuiltinTemplateNetwork {
  DioBuiltinTemplateNetwork(this._api);
  final ApiClient _api;

  @override
  Future<void> syncBuiltinTemplates(Map<String, dynamic> body) async {
    await _api.post<Map<String, dynamic>>(
      '/usage/builtin-templates',
      body: body,
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}

class BuiltinTemplateSyncService {
  BuiltinTemplateSyncService(this._network);
  final BuiltinTemplateNetwork _network;

  /// 上报全量内置模板；返回 true 表示上报成功。
  Future<bool> syncBuiltinTemplates() async {
    try {
      final items = TemplateRegistry.allTemplates
          .map((t) => {'id': t.meta.id, 'name': t.meta.name})
          .toList();
      await _network.syncBuiltinTemplates({'items': items});
      return true;
    } catch (_) {
      return false;
    }
  }
}