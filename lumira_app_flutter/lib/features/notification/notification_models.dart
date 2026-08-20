// lib/features/notification/notification_models.dart
//
// 通知中心 UI 模型。
// NotificationItem 是通知中心页展示的直接数据源，由 DAO 记录（NotificationRecord）转换而来，
// 不含任何网络/DB 逻辑，仅聚合展示所需字段。
//
// source='remote'（后端公告）| 'local'（本地 app 事件通知），可据此区分点击跳转行为。

import 'data/notification_dao.dart';

/// 一条通知（UI 模型）。
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.source,
    this.remoteId,
    required this.kind,
    required this.title,
    required this.body,
    required this.timeMs,
    required this.read,
  });

  /// 本地主键：local 通知用本地生成 id；remote 通知与存储 id 一致（后端公告 id）。
  final String id;

  /// 'remote'（后端公告）| 'local'（本地 app 事件）。
  final String source;

  /// 后端公告 id（source='remote' 时有值；local 为 null）。
  final String? remoteId;

  /// 通知类别：如 'announcement' / 'streak' / 'challenge' / 'achievement' / 'template' / 'system'。
  final String kind;

  final String title;
  final String body;

  /// 时间戳（毫秒）。
  final int timeMs;

  /// 是否已读。
  final bool read;

  factory NotificationItem.fromRecord(NotificationRecord r) => NotificationItem(
        id: r.id,
        source: r.source,
        remoteId: r.remoteId,
        kind: r.kind,
        title: r.title,
        body: r.body,
        timeMs: r.timeMs,
        read: r.read == 1,
      );

  /// 转为 DAO 记录（用于本地写入）。
  NotificationRecord toRecord() => NotificationRecord(
        id: id,
        source: source,
        remoteId: remoteId,
        kind: kind,
        title: title,
        body: body,
        timeMs: timeMs,
        read: read ? 1 : 0,
      );
}