import 'package:flutter/material.dart';

import '../../../shared/widgets/cards/neu_card.dart';
import '../data/challenge_models.dart';
import 'challenge_tag.dart';

/// 主挑战卡（已完成态）
///
/// 视觉规格来源：lumira-app/src/pages/challenge/index.vue line 8-32
/// - 圆形 check 图标（96rpx 圆，brand-subtle 底）
/// - 标题"今日挑战已完成" + 描述
/// - tags 行（gold + green）
/// - 分隔线 + 16:9 作品图
class MainChallengeCard extends StatelessWidget {
  const MainChallengeCard({super.key, required this.challenge});

  final MainChallenge challenge;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(24), // 48rpx → 24dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：圆形 check + 标题/描述/tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 圆形 check 图标
              Container(
                width: 48, // 96rpx → 48dp
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF5EDDB), // brand-subtle（hardcoded 跨主题一致）
                ),
                child: const Icon(
                  Icons.check,
                  size: 22, // 44rpx → 22dp
                  color: Color(0xFF8C7340), // brand-text
                ),
              ),
              const SizedBox(width: 14), // 28rpx → 14dp
              // 标题 + 描述 + tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 14, // 28rpx → 14dp
                          color: Color(0xFFC9A96E), // brand
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            challenge.title,
                            style: const TextStyle(
                              fontSize: 16, // 32rpx → 16dp
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
                        fontSize: 14, // 28rpx → 14dp
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, // 16rpx → 8dp
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
          const SizedBox(height: 16), // margin-top 32rpx → 16dp
          // 分隔线
          Container(
            height: 1, // 2rpx → 1dp
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 16),
          // 16:9 作品图
          ClipRRect(
            borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
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
}
