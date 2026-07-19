import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/challenge_models.dart';

/// 挑战标签（lumira-tag 的 Flutter 实现）
///
/// 视觉规格来源：lumira-app/src/App.vue lumira-tag-gold/green/red
class ChallengeTagWidget extends ConsumerWidget {
  const ChallengeTagWidget({super.key, required this.tag});

  final ChallengeTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final colors = _TagColors.from(tokens, tag.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 20rpx 8rpx → 10 4
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6), // 12rpx → 6dp
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.showCheckIcon) ...[
            Icon(Icons.check, size: 11, color: colors.text), // 22rpx → 11dp
            const SizedBox(width: 4),
          ],
          Text(
            tag.label,
            style: TextStyle(
              fontSize: 11, // 22rpx → 11dp
              fontWeight: FontWeight.w500,
              color: colors.text,
              letterSpacing: 0.4, // 0.04em
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TagColors {
  const _TagColors({required this.background, required this.text});

  final Color background;
  final Color text;

  static _TagColors from(ThemeTokens tokens, ChallengeTagColor color) {
    switch (color) {
      case ChallengeTagColor.gold:
        return _TagColors(
          background: tokens.brandSubtle,
          text: tokens.brandText,
        );
      case ChallengeTagColor.green:
        return _TagColors(
          background: tokens.successSubtle,
          text: tokens.success,
        );
      case ChallengeTagColor.red:
        return _TagColors(
          background: tokens.dangerSubtle,
          text: tokens.danger,
        );
    }
  }
}
