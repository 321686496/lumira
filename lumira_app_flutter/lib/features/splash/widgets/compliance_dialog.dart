import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 合规检查弹窗内容（链接式 + 同意/不同意）。
///
/// 由 Splash 通过 [showLumiraDialog] 承载；样式随 8 主题 × 4 风格经
/// `appThemeProvider` 派生，链接用 `tokens.brandText`。
class ComplianceDialog extends ConsumerWidget {
  const ComplianceDialog({super.key, required this.onAgree, required this.onDisagree});

  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35, color: tokens.textPrimary);
    final bodyStyle = TextStyle(fontSize: 13, height: 1.6, color: tokens.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('用户协议与隐私政策', style: titleStyle),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(text: '在使用前，请仔细阅读并充分理解'),
              _link(context, '《用户协议》', RouteNames.profileComplianceAgreement, tokens),
              const TextSpan(text: '、'),
              _link(context, '《隐私政策》', RouteNames.profileCompliancePrivacy, tokens),
              const TextSpan(text: '与'),
              _link(context, '《个人信息清单与第三方SDK目录》', RouteNames.profileComplianceSdk, tokens),
              const TextSpan(text: '。我们非常重视您的隐私。您点击「同意」即表示已阅读并同意上述协议，我们将在您同意后，再开始收集、处理您的个人信息并为您提供服务。'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: LumiraButton(variant: ButtonVariant.secondary, onPressed: onDisagree, child: const _NoWrapLabel('不同意并退出')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LumiraButton(variant: ButtonVariant.primary, onPressed: onAgree, child: const _NoWrapLabel('同意并开始使用')),
            ),
          ],
        ),
      ],
    );
  }

  TextSpan _link(BuildContext context, String text, String route, ThemeTokens tokens) {
    return TextSpan(
      text: text,
      style: TextStyle(color: tokens.brandText, decoration: TextDecoration.underline, decorationColor: tokens.brandText),
      recognizer: TapGestureRecognizer()..onTap = () => context.push(route),
    );
  }
}

/// 按钮标签：窄屏下按钮宽度不足时缩放文本以保持单行，避免「同意并开始使用」被挤压换行。
class _NoWrapLabel extends StatelessWidget {
  const _NoWrapLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}