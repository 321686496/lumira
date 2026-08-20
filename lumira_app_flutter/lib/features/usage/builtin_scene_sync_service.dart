// lumira_app_flutter/lib/features/usage/builtin_scene_sync_service.dart
//
// 内置场景名称同步：启动联网时把 App 内置场景（CaptureSceneMockData）的 id/当前名称
// 全量上报到后端 builtin_scenes 注册表，使后台能展示内置场景名称。
// 离线/失败静默返回 false，下次启动再同步，不影响功能。

import '../../../core/network/api_client.dart';
import '../capture/data/capture_scene_mock_data.dart';

/// 网络抽象（便于单测注入 fake）。
abstract class BuiltinSceneNetwork {
  /// 全量上报内置场景。path: POST /usage/builtin-scenes。
  Future<void> syncBuiltinScenes(Map<String, dynamic> body);
}

/// 基于全局 [ApiClient] 的网络实现。
class DioBuiltinSceneNetwork implements BuiltinSceneNetwork {
  DioBuiltinSceneNetwork(this._api);
  final ApiClient _api;

  @override
  Future<void> syncBuiltinScenes(Map<String, dynamic> body) async {
    await _api.post<Map<String, dynamic>>(
      '/usage/builtin-scenes',
      body: body,
      fromJson: (j) => (j as Map).cast<String, dynamic>(),
    );
  }
}

class BuiltinSceneSyncService {
  BuiltinSceneSyncService(this._network);
  final BuiltinSceneNetwork _network;

  /// 上报全量内置场景；返回 true 表示上报成功。
  Future<bool> syncBuiltinScenes() async {
    try {
      final items = CaptureSceneMockData.presetScenes
          .map((s) => {'id': s.id, 'name': s.name})
          .toList();
      await _network.syncBuiltinScenes({'items': items});
      return true;
    } catch (_) {
      return false;
    }
  }
}