import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../widgets/account_common.dart';

/// 账号保护页（选择列表）
///
/// 作为「设置 → 账号保护」的入口，提供三项功能的导航选择：
/// 1. 恢复二维码：生成并备份恢复凭证，换机/重装后用其找回账号
/// 2. 找回账号：在新设备/重装后，取回旧账号的全部数据
/// 3. 绑定邮箱：绑定邮箱作为备用找回方式，换机时用邮箱+验证码找回
///
/// 每项卡片含图标 + 标题 + 一句用途说明，点击进入各自功能页（真正的功能在子页实现）。
class AccountProtectionPage extends ConsumerWidget {
  const AccountProtectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '账号保护',
        transparent: true,
        leading: AccountBackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // 顶部总说明
              const AccountGuideCard(
                icon: Icons.shield_outlined,
                title: '账号保护',
                description: '用来防止换手机或重装应用后丢失账号数据。提前做好备份，之后在新设备上就能找回全部数据。',
                tip: '建议换机前先完成备份：生成恢复二维码或绑定邮箱。',
              ),
              const SizedBox(height: 20),
              // 功能选择列表
              NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.qr_code_2_outlined,
                      title: '恢复二维码',
                      subtitle: '生成并保存恢复凭证，换机时扫码或输入恢复码找回',
                      onTap: () => GoRouter.of(context).push(RouteNames.accountRecoveryQr),
                      tokens: tokens,
                    ),
                    _MenuRow(
                      icon: Icons.settings_backup_restore_outlined,
                      title: '找回账号',
                      subtitle: '在新设备/重装后，取回旧账号的全部数据',
                      onTap: () => GoRouter.of(context).push(RouteNames.accountRecover),
                      tokens: tokens,
                    ),
                    _MenuRow(
                      icon: Icons.mark_email_unread_outlined,
                      title: '绑定邮箱',
                      subtitle: '绑定邮箱作为备用找回方式，换机时用邮箱+验证码找回',
                      onTap: () => GoRouter.of(context).push(RouteNames.accountBindEmail),
                      tokens: tokens,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.tokens,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ThemeTokens tokens;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shadowVariant: NeuShadowVariant.convexSubtle,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: tokens.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.4, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20, color: tokens.textTertiary),
        ],
      ),
    );
  }
}