import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import 'lumira/lumira.dart';

/// 离线模式提示横幅
///
/// 当 Repository 因网络失败回退缓存时显示
class ApiErrorBanner extends ConsumerWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ApiErrorBanner({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: tokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? '网络连接失败，显示的是上次缓存数据',
              style: TextStyle(
                fontSize: 12,
                color: tokens.danger,
              ),
            ),
          ),
          if (onRetry != null)
            LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
