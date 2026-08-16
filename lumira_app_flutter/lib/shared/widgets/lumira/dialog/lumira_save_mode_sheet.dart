import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import 'lumira_bottom_sheet.dart';

/// 保存方式
enum SaveMode {
  /// 替换原图：覆盖当前照片，保留编辑历史
  replace,

  /// 另存为新照片：创建副本，不影响原图
  duplicate,
}

/// 弹出「保存方式」选择弹窗。
///
/// 返回 [SaveMode]；用户取消时返回 null。
Future<SaveMode?> showLumiraSaveModeSheet({
  required BuildContext context,
}) {
  return showLumiraBottomSheet<SaveMode>(
    context: context,
    builder: (ctx) => const _SaveModeSheet(),
  );
}

class _SaveModeSheet extends ConsumerWidget {
  const _SaveModeSheet();

  void _pick(BuildContext context, SaveMode mode) {
    Navigator.of(context).pop(mode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '保存方式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
        _SaveModeOption(
          icon: Icons.swap_horiz,
          title: '替换原图',
          subtitle: '覆盖当前照片，保留编辑历史',
          tokens: tokens,
          onTap: () => _pick(context, SaveMode.replace),
        ),
        const SizedBox(height: 8),
        _SaveModeOption(
          icon: Icons.content_copy_outlined,
          title: '另存为新照片',
          subtitle: '创建副本，不影响原图',
          tokens: tokens,
          onTap: () => _pick(context, SaveMode.duplicate),
        ),
      ],
    );
  }
}

class _SaveModeOption extends StatelessWidget {
  const _SaveModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}