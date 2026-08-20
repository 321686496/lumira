// lib/features/notification/notification_repository.dart
//
// 后端公告 Repository。
// 包装 ApiClient（dio）调用后端 REST 接口，接口对应 spec（DeviceAuthGuard）：
//   GET /notifications  - 公告列表（设备定向，返回 { notifications: [...] }）
//
// 失败抛 ApiException（由 ApiClient classifyDioError 转换），
// 调用方（remoteNotificationsSyncProvider）捕获后静默降级到本地 sqflite 缓存。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// 后端公告 DTO（单条）。
@immutable
class RemoteNotificationDto {
  const RemoteNotificationDto({
    required this.id,
    required this.title,
    required this.body,
    required this.iconKey,
    required this.category,
    this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final String body;
  final String iconKey;

  /// 公告类别（映射本地 kind）。
  final String category;

  /// 生效起始时间（毫秒，可为空）。
  final int? startAt;

  /// 失效结束时间（毫秒，可为空）。
  final int? endAt;

  factory RemoteNotificationDto.fromJson(Map<String, dynamic> j) {
    final startAt = j['startAt'];
    final endAt = j['endAt'];
    return RemoteNotificationDto(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      iconKey: j['iconKey'] as String? ?? 'announcement',
      category: j['category'] as String? ?? 'announcement',
      startAt: startAt == null ? null : (startAt as num).toInt(),
      endAt: endAt == null ? null : (endAt as num).toInt(),
    );
  }
}

/// `GET /notifications` 响应体。
@immutable
class NotificationListDto {
  const NotificationListDto(this.notifications);

  final List<RemoteNotificationDto> notifications;

  factory NotificationListDto.fromJson(Map<String, dynamic> j) =>
      NotificationListDto(
        (j['notifications'] as List<dynamic>?)
                ?.map((e) => RemoteNotificationDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const <RemoteNotificationDto>[],
      );
}

/// 后端公告 Repository。
abstract class RemoteNotificationsRepository {
  Future<NotificationListDto> fetchRemote();
}

class RemoteNotificationsRepositoryImpl implements RemoteNotificationsRepository {
  RemoteNotificationsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<NotificationListDto> fetchRemote() async {
    return _api.get(
      '/notifications',
      fromJson: (j) => NotificationListDto.fromJson(j as Map<String, dynamic>),
    );
  }
}

/// 远程公告 Repository Provider。
///
/// 复用全局 [apiClientProvider]（baseUrl 含 /api/v1 前缀）。
final remoteNotificationsProvider =
    FutureProvider<RemoteNotificationsRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteNotificationsRepositoryImpl(api);
});