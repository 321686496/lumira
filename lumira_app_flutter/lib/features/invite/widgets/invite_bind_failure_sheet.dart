import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 邀请码绑定失败弹窗。
///
/// 展示绑定失败的明确原因（老用户不能绑定、邀请码无效、已绑定过、网络异常等），
/// 视觉跟随当前 UI 风格 / 主题，不硬编码颜色。
Future<void> showInviteBindFailureSheet(
  BuildContext context, {
  String title = '绑定失败',
  required String reason,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => InviteBindFailureSheet(title: title, reason: reason),
  );
}

/// 绑定失败弹窗内容
class InviteBindFailureSheet extends ConsumerWidget {
  const InviteBindFailureSheet({
    super.key,
    this.title = '绑定失败',
    required this.reason,
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(appTheme.cardRadius),
          boxShadow: isNeu ? tokens.shadowConvex : null,
          border: isNeu
              ? null
              : Border.all(color: tokens.divider, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tokens.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 22,
                    color: tokens.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: tokens.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        ),
      ),
    );
  }
}