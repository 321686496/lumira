// lib/features/notification/notification_providers.dart
//
// 通知中心 Provider。
//
// 职责分层：
// - remoteNotificationsSyncProvider: 全量同步后端公告 FutureProvider
//   进入通知中心页时触发，拉取 GET /notifications → 逐条 upsertRemote 到 sqflite
//   → prune 后端已不存在的 remote 公告。网络失败静默（同 remoteTemplatesSyncProvider 模式）。
// - notificationsProvider: 合并后有序列表 FutureProvider
//   触发同步（+ Task 7 的 unreadLocalGeneratedProvider 本地事件生成）→ 读 dao.list() → UI 模型列表。
// - unreadCountProvider: 首页铃铛红点数量（未读未清除）。
// - markAsReadProvider / clearNotificationProvider: DAO 写操作后 invalidate 列表/未读 provider。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'data/notification_dao.dart';
import 'local_notification_generator.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

/// 拉取后端公告 → upsert 到 sqflite（id=remote 主键，保留已读/清除状态）
/// → prune 本地已不在后端列表的 remote 公告。
///
/// 触发时机：进入通知中心页（notificationsProvider 自动点火）。
/// 失败处理：网络失败静默忽略（同 [remoteTemplatesSyncProvider] 模式），UI 用本地缓存。
final remoteNotificationsSyncProvider = FutureProvider<void>((ref) async {
  try {
    final repo = await ref.watch(remoteNotificationsProvider.future);
    final dao = await ref.watch(notificationDaoProvider.future);
    final resp = await repo.fetchRemote();
    final now = DateTime.now().millisecondsSinceEpoch;
    // 阶段 1: upsert 远端公告（timeMs = startAt 或 当前时间）
    for (final n in resp.notifications) {
      final startAt = n.startAt;
      await dao.upsertRemote(NotificationRecord(
        id: n.id,
        source: 'remote',
        remoteId: n.id,
        kind: n.category.isEmpty ? 'announcement' : n.category,
        title: n.title,
        body: n.body,
        timeMs: (startAt != null && startAt > 0) ? startAt : now,
      ));
    }
    // 阶段 2: 清理后端已不存在的 remote 公告（下架/删除）
    final validRemoteIds = resp.notifications.map((n) => n.id).toSet();
    await dao.pruneRemoteIds(validRemoteIds);
  } catch (_) {
    // 网络失败静默：UI 用本地缓存展示
  }
});

/// 通知中心统一列表入口（合并 remote 公告 + local 本地事件，按 timeMs 倒序）。
///
/// 触发时机：通知中心页进入时 watch 本 provider。
/// 副作用：触发 [remoteNotificationsSyncProvider] 远程同步；
/// Task 7 实现 local 应用事件生成后，在此追加点火 unreadLocalGeneratedProvider。
final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  // 点火远程同步（远程公告 → sqflite 缓存）；网络失败静默，不影响本地列表
  ref.watch(remoteNotificationsSyncProvider);
  // 点火本地应用事件生成（未读本地通知 → sqflite）；失败静默，不影响列表
  ref.watch(unreadLocalGeneratedProvider);
  final dao = await ref.watch(notificationDaoProvider.future);
  final records = await dao.list();
  return records.map(NotificationItem.fromRecord).toList();
});

/// 未读未清除通知数量（首页铃铛红点）。
final unreadCountProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(notificationDaoProvider.future);
  return dao.countUnread();
});

/// 标记单条已读，随后刷新列表与未读数。
final markAsReadProvider = Provider<Future<void> Function(String id)>((ref) {
  return (String id) async {
    final dao = await ref.read(notificationDaoProvider.future);
    await dao.markRead(id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  };
});

/// 清除单条（软删），随后刷新列表与未读数。
final clearNotificationProvider = Provider<Future<void> Function(String id)>((ref) {
  return (String id) async {
    final dao = await ref.read(notificationDaoProvider.future);
    await dao.clearById(id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  };
});