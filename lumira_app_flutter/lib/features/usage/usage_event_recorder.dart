// lumira_app_flutter/lib/features/usage/usage_event_recorder.dart
import 'dart:math';

import '../../../core/db/dao/usage_dao.dart';

/// 记录模板/场景使用事件。仅内置/后台模板与系统内置场景写入，用户自定义跳过。
class UsageEventRecorder {
  UsageEventRecorder(this._dao);

  final UsageDao _dao;

  /// 模板事件。source: 'builtin' | 'remote' | 'custom'，自定义不记录。
  Future<void> recordTemplate({
    required String templateId,
    required String source,
    required UsageEventType event,
  }) async {
    if (source != 'builtin' && source != 'remote') return;
    await _dao.enqueueEvent(
      clientEventId: _uuid(),
      itemType: UsageItemType.template,
      itemId: templateId,
      itemSource: source,
      eventType: event,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 场景事件。creator: 'system' | 'user'，仅系统内置场景记录。
  Future<void> recordScene({
    required String sceneId,
    required String creator,
    required UsageEventType event,
  }) async {
    if (creator != 'system') return;
    await _dao.enqueueEvent(
      clientEventId: _uuid(),
      itemType: UsageItemType.scene,
      itemId: sceneId,
      itemSource: 'system',
      eventType: event,
      occurredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _uuid() {
    final r = Random();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    // RFC4122 v4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}