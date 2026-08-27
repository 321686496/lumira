import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../notification/notification_models.dart';
import '../../notification/notification_providers.dart';

/// 通知中心页（真实数据实现）
///
/// 进入时 watch [notificationsProvider]，自动触发后端公告同步 + 本地事件生成。
/// 数据源为合并后的 [NotificationItem] 列表（remote 公告 + local 应用事件）。
class ProfileNotificationsPage extends ConsumerWidget {
  const ProfileNotificationsPage({super.key});

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  /// 全部标记已读。
  Future<void> _markAll(WidgetRef ref) async {
    final dao = await ref.read(notificationDaoProvider.future);
    await dao.markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  /// 清空全部（软删）。
  Future<void> _clearAll(WidgetRef ref) async {
    final dao = await ref.read(notificationDaoProvider.future);
    await dao.clearAll();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  /// 标记单条已读（经 provider，自动刷新未读数与列表）。
  Future<void> _markRead(WidgetRef ref, String id) async {
    await ref.read(markAsReadProvider)(id);
  }

  /// 清除单条（经 provider，自动刷新未读数与列表）。
  Future<void> _clearOne(WidgetRef ref, String id) async {
    await ref.read(clearNotificationProvider)(id);
  }

  /// 点击一行：后端公告只标记已读；本地通知标记已读后跳转对应页面。
  void _onTap(WidgetRef ref, BuildContext context, NotificationItem n) {
    _markRead(ref, n.id);
    if (n.source != 'local') return;
    final String? route = _localRoute(n.kind);
    if (route != null) {
      GoRouter.of(context).push(route);
    }
  }

  /// 本地通知类别 → 目标路由（打卡/挑战/成就/模板）。
  String? _localRoute(String kind) {
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
        return null; // 系统类无对应页面，仅标记已读
    }
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'streak':
        return Icons.local_fire_department_outlined;
      case 'challenge':
        return Icons.emoji_events_outlined;
      case 'achievement':
        return Icons.star_outline;
      case 'template':
        return Icons.layers_outlined;
      case 'system':
        return Icons.info_outline;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(int timeMs) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final notifications = ref.watch(notificationsProvider).value ?? const <NotificationItem>[];

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '通知中心',
        transparent: true,
        leading: _BackButton(tokens: tokens, onTap: () => _back(context)),
        actions: [
          LumiraNavButton(
            icon: Icons.done_all_outlined,
            tooltip: '全部已读',
            onPressed: () => _markAll(ref),
          ),
          LumiraNavButton(
            icon: Icons.delete_outline,
            tooltip: '清空',
            onPressed: () => _clearAll(ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          notifications.isEmpty
          ? Center(
              child: LumiraSurface(
                radius: 14,
                padding: const EdgeInsets.all(20),
                child: Text(
                  '暂无通知',
                  style: TextStyle(color: tokens.textTertiary),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (_, i) {
                final n = notifications[i];
                return Dismissible(
                  key: ValueKey('notif_${n.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _clearOne(ref, n.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: tokens.dangerSubtle,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(Icons.delete_outline, color: tokens.danger),
                  ),
                  child: _NotificationRow(
                    item: n,
                    icon: _iconFor(n.kind),
                    timeText: _formatTime(n.timeMs),
                    onTap: () => _onTap(ref, context, n),
                    tokens: tokens,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 单条通知卡片行（风格自适应）
class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({
    required this.item,
    required this.icon,
    required this.timeText,
    required this.onTap,
    required this.tokens,
  });

  final NotificationItem item;
  final IconData icon;
  final String timeText;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !item.read;
    return NeuCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未读左侧指示点
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: unread ? tokens.brand : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tokens.brandText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}