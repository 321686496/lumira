// lib/features/notification/notification_ui_utils.dart
//
// 通知中心 UI 共享工具：类别图标 / 时间文本 / 关联业务路由。
// 由「通知列表页」与「通知详情页」共用，避免重复实现。

import 'package:flutter/material.dart';

import '../../core/router/route_names.dart';
import 'notification_models.dart';

/// 通知类别 → 图标。
IconData notificationIconFor(String kind) {
  switch (kind) {
    case 'streak':
      return Icons.local_fire_department_outlined; // 连续打卡
    case 'challenge':
      return Icons.emoji_events_outlined; // 今日挑战
    case 'achievement':
      return Icons.star_outline; // 成就/成长
    case 'template':
      return Icons.layers_outlined; // 模板库
    case 'system':
      return Icons.info_outline; // 系统
    case 'announcement':
      return Icons.campaign_outlined; // 后端公告
    default:
      return Icons.notifications_outlined;
  }
}

/// 时间戳（毫秒）→ 展示文本（今天 HH:mm / 昨天 HH:mm / 今年 M月d日 / 跨年 yyyy/M/d）。
String notificationTimeText(int timeMs) {
  final now = DateTime.now();
  final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  if (diff == 0) return '今天 $hh:$mm';
  if (diff == 1) return '昨天 $hh:$mm';
  if (dt.year == now.year) return '${dt.month}月${dt.day}日';
  return '${dt.year}/${dt.month}/${dt.day}';
}

/// 本地事件类别 → 关联业务路由；remote 公告或系统类返回 null（无关联页面）。
String? notificationLocalRoute(String kind) {
  switch (kind) {
    case 'streak':
      return RouteNames.checkinList; // 连续打卡
    case 'challenge':
      return RouteNames.challenge; // 今日挑战
    case 'achievement':
      return RouteNames.profileGrowth; // 成就/成长
    case 'template':
      return RouteNames.templates; // 模板库
    case 'system':
    default:
      return null; // 系统/公告类无对应页面
  }
}

/// 根据整条通知解析应跳转的目标路由。
///
/// - remote 公告：无关联页面，返回 null。
/// - template（新模板上新）：优先直达该模板详情（`/templates/detail?templateId=`），
///   无 templateId 的历史旧记录回退到「模板库列表」。
/// - 其它本地事件：按类别跳对应业务页（即 [notificationLocalRoute]）。
String? notificationTargetRoute(NotificationItem item) {
  if (item.source != 'local') return null;
  if (item.kind == 'template') {
    final tid = item.templateId;
    if (tid != null && tid.isNotEmpty) {
      return RouteNames.withTemplateId(RouteNames.templatesDetail, tid);
    }
    return RouteNames.templates; // 兜底：无 id 的旧记录 → 模板库
  }
  return notificationLocalRoute(item.kind);
}