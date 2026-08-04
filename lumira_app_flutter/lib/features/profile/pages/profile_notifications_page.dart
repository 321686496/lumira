import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 通知中心页（占位实现）
/// 展示 5 条 mock 通知，长按可清除单条。
class ProfileNotificationsPage extends ConsumerStatefulWidget {
  const ProfileNotificationsPage({super.key});

  @override
  ConsumerState<ProfileNotificationsPage> createState() =>
      _ProfileNotificationsPageState();
}

class _NotificationItem {
  final String id;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
  });
}

const List<_NotificationItem> _kMockNotifications = [
  _NotificationItem(id: 'n1', title: '连续打卡', body: '你的连续打卡已 7 天', time: '今天', icon: Icons.local_fire_department_outlined),
  _NotificationItem(id: 'n2', title: '模板更新', body: '新模板已上线', time: '今天', icon: Icons.layers_outlined),
  _NotificationItem(id: 'n3', title: '挑战提醒', body: '今日挑战尚未完成', time: '昨天', icon: Icons.emoji_events_outlined),
  _NotificationItem(id: 'n4', title: '成就解锁', body: '你解锁了「初次拍摄」成就', time: '2 天前', icon: Icons.star_outline),
  _NotificationItem(id: 'n5', title: '系统通知', body: '如画 v1.2 已发布', time: '3 天前', icon: Icons.info_outline),
];

class _ProfileNotificationsPageState extends ConsumerState<ProfileNotificationsPage> {
  late List<_NotificationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(_kMockNotifications);
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  void _onLongPress(int index) {
    setState(() {
      _items.removeAt(index);
    });
    LumiraToast.show(context, '已清除', duration: const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '通知中心',
        transparent: true,
        leading: _BackButton(tokens: tokens, onTap: _back),
      ),
      body: _items.isEmpty
          ? Center(
              child: Text('暂无通知', style: TextStyle(color: tokens.textTertiary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: tokens.divider),
              itemBuilder: (_, i) {
                final n = _items[i];
                return GestureDetector(
                  onLongPress: () => _onLongPress(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: tokens.surface,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tokens.brandSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, size: 20, color: tokens.brandText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                  const Spacer(),
                                  Text(n.time, style: TextStyle(fontSize: 11, color: tokens.textTertiary)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(n.body, style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
