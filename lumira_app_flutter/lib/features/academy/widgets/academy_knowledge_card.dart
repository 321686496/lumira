import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/academy_models.dart';

/// 知识卡片（横向滑动展示用）
class AcademyKnowledgeCard extends ConsumerWidget {
  const AcademyKnowledgeCard({
    super.key,
    required this.card,
    required this.isFavorited,
    required this.onTap,
    required this.onFavorite,
  });

  final KnowledgeCard card;
  final bool isFavorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: NeuCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面图
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        card.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: tokens.surfaceAlt,
                          child: Icon(Icons.image_outlined, color: tokens.textTertiary),
                        ),
                      ),
                    ),
                  ),
                  // 主题标签
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        card.topic.label,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
                  // 收藏按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isFavorited ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 标题与副标题
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
