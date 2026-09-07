import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../rewards/data/rewards_models.dart';
import '../../../shared/widgets/lumira/lumira.dart';

/// 邀请码绑定成功弹窗。
///
/// 展示通过邀请码「达成后」可获得的奖励明细 + 达成条件说明，
/// 让用户明确知道绑定后能得到什么、以及需要满足什么条件。
/// 视觉跟随当前 UI 风格 / 主题，不做任何颜色硬编码。
Future<void> showInviteBindSuccessSheet(
  BuildContext context, {
  required String conditionText,
  List<RewardItem> rewards = const [],
  String? inviterDeviceId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => InviteBindSuccessSheet(
      conditionText: conditionText,
      rewards: rewards,
      inviterDeviceId: inviterDeviceId,
    ),
  );
}

/// 绑定成功弹窗内容
class InviteBindSuccessSheet extends ConsumerWidget {
  const InviteBindSuccessSheet({
    super.key,
    required this.conditionText,
    this.rewards = const [],
    this.inviterDeviceId,
  });

  final String conditionText;
  final List<RewardItem> rewards;
  final String? inviterDeviceId;

  static IconData _iconFor(RewardType type) {
    switch (type) {
      case RewardType.points:
        return Icons.stars_outlined;
      case RewardType.unlockCount:
        return Icons.lock_open_outlined;
      case RewardType.achievement:
        return Icons.emoji_events_outlined;
      case RewardType.template:
        return Icons.photo_outlined;
      case RewardType.templatePack:
        return Icons.photo_library_outlined;
    }
  }

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
                    color: tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_giftcard, size: 22, color: tokens.brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '邀请码绑定成功',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (inviterDeviceId != null && inviterDeviceId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '已与好友建立邀请关系',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
            ],
            if (rewards.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '完成首次拍照后，你将获得：',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 8),
              // 奖励明细列表
              ...rewards.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _iconFor(r.type),
                          size: 18,
                          color: tokens.brand,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.displayLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.brandText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 8),
            // 达成条件说明
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bolt_outlined, size: 16, color: tokens.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      conditionText,
                      style: TextStyle(
                        fontSize: 12,
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