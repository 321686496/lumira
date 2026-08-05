import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/challenge_models.dart';
import 'challenge_tag.dart';

/// 主挑战卡（支持 pending / done 两态）
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue line 8-32
/// - pending 态：badge + 标题 + 描述 + tags + "去拍照"按钮
/// - done 态：圆形 check 图标 + "今日挑战已完成" + 描述 + tags + 分隔线 + 16:9 作品图
class MainChallengeCard extends ConsumerWidget {
  const MainChallengeCard({
    super.key,
    required this.challenge,
    this.onGoCapture,
  });

  final MainChallenge challenge;

  /// pending 态"去拍照"按钮回调（由父组件传入，携带 challengeId 跳拍摄页）
  final VoidCallback? onGoCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = challenge.status == ChallengeStatus.done;

    if (isDone) {
      return _buildDoneCard(context);
    }
    return _buildPendingCard(context);
  }

  /// 已完成态：原视觉规格
  Widget _buildDoneCard(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：圆形 check + 标题/描述/tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF5EDDB),
                ),
                child: const Icon(
                  Icons.check,
                  size: 22,
                  color: Color(0xFF8C7340),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFFC9A96E),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            challenge.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: challenge.tags
                          .map((t) => ChallengeTagWidget(tag: t))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                challenge.coverImage ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEAE5DC),
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// pending 态：突出"去拍照"行动按钮
  Widget _buildPendingCard(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF5EDDB),
                  border: Border.all(
                    color: const Color(0xFFC9A96E).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  size: 22,
                  color: Color(0xFF8C7340),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今日挑战 · 未完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 描述
          Text(
            challenge.description,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // tags
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: challenge.tags
                .map((t) => ChallengeTagWidget(tag: t))
                .toList(),
          ),
          const SizedBox(height: 16),
          // "去拍照"按钮
          if (onGoCapture != null)
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: onGoCapture,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.camera_alt_outlined),
                  SizedBox(width: 8),
                  Text('去拍照'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
