import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/usage/builtin_scene_sync_service.dart';

class FakeBuiltinNetwork implements BuiltinSceneNetwork {
  Map<String, dynamic>? lastBody;
  bool shouldFail = false;
  @override
  Future<void> syncBuiltinScenes(Map<String, dynamic> body) async {
    if (shouldFail) throw Exception('offline');
    lastBody = body;
  }
}

void main() {
  test('syncBuiltinScenes 上报 items 全量并返回 true', () async {
    final net = FakeBuiltinNetwork();
    final svc = BuiltinSceneSyncService(net);
    final ok = await svc.syncBuiltinScenes();
    expect(ok, isTrue);
    final items = (net.lastBody!['items'] as List);
    expect(items, isNotEmpty);
    final first = items.first as Map;
    expect(first, contains('id'));
    expect(first, contains('name'));
  });

  test('离线失败返回 false 不抛', () async {
    final net = FakeBuiltinNetwork()..shouldFail = true;
    final svc = BuiltinSceneSyncService(net);
    expect(await svc.syncBuiltinScenes(), isFalse);
  });
}