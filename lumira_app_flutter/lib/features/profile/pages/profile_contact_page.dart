import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/buttons/lumira_button.dart';
import '../../../shared/widgets/lumira/feedback/lumira_toast.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// ===== 联系我们页配置 =====
/// 上线前请替换为真实内容（当前为演示占位值）。
const String kContactEmail = '15575712021@163.com';
const String kContactWechat = 'h15575712021';

/// 微信群「加入群聊」二维码承载数据。
/// 微信群二维码实际编码的是群邀请链接/口令，替换为真实群二维码的 payload 后，
/// 页面会用 qr_flutter 实时渲染成可被微信扫码加入的二维码。
const String kWechatGroupQrData =
    'https://weixin.qq.com/g/REPLACE_WITH_REAL_GROUP_LINK';
const String kWechatGroupQrNote = '群二维码 7 天内有效，失效可在意见反馈中留言，我们会拉你入群';

/// 联系我们页
///
/// 提供三种联系方式：加入官方群聊（微信群二维码）、发送邮箱反馈（mailto）、
/// 添加微信号（复制）。视觉风格与「关于如画」页一致：LumiraNav + 渐变背景 + 卡片。
class ProfileContactPage extends ConsumerWidget {
  const ProfileContactPage({super.key});

  Future<void> _copy(
    BuildContext context,
    ThemeTokens tokens,
    String text,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) LumiraToast.show(context, message);
  }

  /// 调用系统邮件客户端发送反馈；失败（如 OHOS 无 url_launcher 原生实现）降级为复制邮箱。
  Future<void> _sendEmail(BuildContext context, ThemeTokens tokens) async {
    final query = [
      'subject=${Uri.encodeQueryComponent('如画 Lumira 用户反馈')}',
      'body=${Uri.encodeQueryComponent('你好，如画团队：\n\n')}',
    ].join('&');
    final uri = Uri(scheme: 'mailto', path: kContactEmail, query: query);
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        await _copy(context, tokens, kContactEmail, '未找到邮件应用，已复制邮箱地址');
      }
    } catch (_) {
      // OHOS 等无原生实现平台：降级为复制邮箱地址
      if (context.mounted) {
        await _copy(context, tokens, kContactEmail, '已复制邮箱地址');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '联系我们',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Stack(
        children: [
          // 背景装饰
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.6),
                  radius: 1.3,
                  colors: [
                    tokens.brandSubtle.withOpacity(0.45),
                    tokens.brandLight.withOpacity(0.15),
                    tokens.canvas,
                  ],
                  stops: const [0.0, 0.4, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Intro(tokens: tokens),
                  const SizedBox(height: 16),
                  _GroupChatCard(
                    tokens: tokens,
                    onCopyLink: () => _copy(
                      context,
                      tokens,
                      kWechatGroupQrData,
                      '群聊链接已复制',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EmailCard(
                    tokens: tokens,
                    onSendEmail: () => _sendEmail(context, tokens),
                    onCopyEmail: () => _copy(
                      context,
                      tokens,
                      kContactEmail,
                      '邮箱地址已复制',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WechatCard(
                    tokens: tokens,
                    onCopyWechat: () => _copy(
                      context,
                      tokens,
                      kContactWechat,
                      '微信号已复制',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '你的每一条反馈，都是如画变好的动力',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          '和如画聊聊',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '加群交流、邮件反馈、添加微信，我们随时在线',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 卡片统一外壳：图标 + 标题 + 副标题 + 内容
class _ContactSection extends StatelessWidget {
  const _ContactSection({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final ThemeTokens tokens;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// 加入官方群聊：微信群二维码
class _GroupChatCard extends StatelessWidget {
  const _GroupChatCard({required this.tokens, required this.onCopyLink});
  final ThemeTokens tokens;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return _ContactSection(
      tokens: tokens,
      icon: Icons.groups_outlined,
      title: '加入官方群聊',
      subtitle: '扫码加入如画交流群，和摄影师们一起聊聊',
      children: [
        // 二维码（需浅色底保证扫码识别，属功能需要）
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.divider, width: 1),
            ),
            child: QrImageView(
              data: kWechatGroupQrData,
              version: QrVersions.auto,
              size: 176,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '微信扫一扫，加入群聊',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            kWechatGroupQrNote,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary, height: 1.4),
          ),
        ),
        const SizedBox(height: 14),
        LumiraButton(
          variant: ButtonVariant.secondary,
          onPressed: onCopyLink,
          child: const Text('复制群聊链接'),
        ),
      ],
    );
  }
}

/// 发送邮箱反馈：mailto 调用系统邮件
class _EmailCard extends StatelessWidget {
  const _EmailCard({
    required this.tokens,
    required this.onSendEmail,
    required this.onCopyEmail,
  });
  final ThemeTokens tokens;
  final VoidCallback onSendEmail;
  final VoidCallback onCopyEmail;

  @override
  Widget build(BuildContext context) {
    return _ContactSection(
      tokens: tokens,
      icon: Icons.email_outlined,
      title: '发送邮箱反馈',
      subtitle: '问题、建议、合作，都欢迎写信告诉我们',
      children: [
        _InfoRow(
          tokens: tokens,
          label: '反馈邮箱',
          value: kContactEmail,
          onTap: onCopyEmail,
        ),
        const SizedBox(height: 4),
        Text(
          '我们会在 1-3 个工作日内回复',
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
        const SizedBox(height: 14),
        LumiraButton(
          variant: ButtonVariant.primary,
          onPressed: onSendEmail,
          child: const Text('发送邮件'),
        ),
      ],
    );
  }
}

/// 添加微信号：复制微信号
class _WechatCard extends StatelessWidget {
  const _WechatCard({required this.tokens, required this.onCopyWechat});
  final ThemeTokens tokens;
  final VoidCallback onCopyWechat;

  @override
  Widget build(BuildContext context) {
    return _ContactSection(
      tokens: tokens,
      icon: Icons.chat_bubble_outline,
      title: '添加微信号',
      subtitle: '加好友聊聊，或邀请你进群',
      children: [
        _InfoRow(
          tokens: tokens,
          label: '微信号',
          value: kContactWechat,
          onTap: onCopyWechat,
        ),
        const SizedBox(height: 4),
        Text(
          '复制微信号后，去微信搜索添加即可',
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
        const SizedBox(height: 14),
        LumiraButton(
          variant: ButtonVariant.secondary,
          onPressed: onCopyWechat,
          child: const Text('复制微信号'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.label,
    required this.value,
    this.onTap,
  });
  final ThemeTokens tokens;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: tokens.textTertiary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.copy_outlined, size: 15, color: tokens.brand),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}
