import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../data/challenge_models.dart';
import 'challenge_tag.dart';

/// 支线挑战行
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue line 39-67
/// 两种态：
/// - done: opacity 0.7，圆形 check 图标（绿色底）
/// - pending: 圆形图标（brand 底）+ 标题 + 进度 + tags 行 + "去完成"按钮
class SubChallengeRow extends ConsumerWidget {
  const SubChallengeRow({
    super.key,
    required this.challenge,
    this.onGoComplete,
  });

  final SubChallenge challenge;
  final VoidCallback? onGoComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final isDone = challenge.status == ChallengeStatus.done;

    return Opacity(
      opacity: isDone ? 0.7 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(20), // 40rpx → 20dp
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
          boxShadow: [
            // 阴影：convex
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(3, 3),
              blurRadius: 7,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(-3, -3),
              blurRadius: 7,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 圆形图标
                _CircleIcon(
                  icon: isDone ? Icons.check : challenge.icon,
                  size: 36, // 72rpx → 36dp
                  background: isDone ? tokens.successSubtle : tokens.brandSubtle,
                  iconColor: isDone ? tokens.success : tokens.brand,
                ),
                const SizedBox(width: 12), // 24rpx → 12dp
                // 标题 + 进度
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontSize: 15, // 30rpx → 15dp
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDone
                            ? '已完成 · ${challenge.progressCurrent}/${challenge.progressTotal}'
                            : '未完成 · ${challenge.progressCurrent}/${challenge.progressTotal}',
                        style: TextStyle(
                          fontSize: 13, // 26rpx → 13dp
                          color: tokens.textTertiary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isDone)
                  ChallengeTagWidget(
                    tag: ChallengeTag(
                      label: '+${challenge.rewardXP} XP',
                      color: ChallengeTagColor.gold,
                    ),
                  ),
              ],
            ),
            // pending 态额外的 tags + 按钮
            if (!isDone) ...[
              const SizedBox(height: 14), // margin-bottom 28rpx → 14dp
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: challenge.tags
                    .map((t) => ChallengeTagWidget(tag: t))
                    .toList(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 100, // 自适应内容宽度
                  child: LumiraButton(
                    label: '去完成',
                    onPressed: onGoComplete,
                    variant: LumiraButtonVariant.brand,
                    expand: false,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.size,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
      ),
      child: Icon(icon, size: size * 0.55, color: iconColor),
    );
  }
}
