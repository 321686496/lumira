import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../notification/notification_models.dart';
import '../../notification/notification_ui_utils.dart';

/// 通知详情页
///
/// 进入时展示单条通知的完整内容（图标 / 标题 / 完整正文 / 时间 / 来源），
/// 由列表页通过 [GoRouter] `extra` 传入 [item]。
/// 本地事件类通知（打卡/挑战/成就/模板）底部提供「去查看」按钮跳转对应业务页；
/// 后端公告等无关联页面的类型不显示该按钮。
class ProfileNotificationDetailPage extends ConsumerWidget {
  const ProfileNotificationDetailPage({super.key, required this.item});

  final NotificationItem item;

  IconData get _icon => notificationIconFor(item.kind);
  String get _time => notificationTimeText(item.timeMs);

  /// 关联业务路由：模板上新直达模板详情；无关联页面返回 null。
  String? get _route => notificationTargetRoute(item);

  void _back(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final route = _route;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '通知详情',
        transparent: true,
        leading: _BackButton(tokens: tokens, onTap: () => _back(context)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 头部：类别图标 + 标题 + 时间
              NeuCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tokens.brandSubtle,
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(_icon, size: 22, color: tokens.brandText),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: tokens.divider),
                    const SizedBox(height: 16),
                    // 完整正文（不再截断）
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.source == 'local' ? '来源：本地事件' : '来源：官方公告',
                      style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ),
              // 关联页面入口（仅本地事件类且有对应页面时显示）
              if (route != null) ...[
                const SizedBox(height: 16),
                _ActionCard(
                  icon: _icon,
                  label: '去查看',
                  onTap: () => GoRouter.of(context).push(route),
                  tokens: tokens,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: tokens.textTertiary),
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
        child:
            Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}