import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 知识卡片详情页
class AcademyKnowledgePage extends ConsumerStatefulWidget {
  const AcademyKnowledgePage({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<AcademyKnowledgePage> createState() => _AcademyKnowledgePageState();
}

class _AcademyKnowledgePageState extends ConsumerState<AcademyKnowledgePage> {
  KnowledgeCard? _findCard(List<KnowledgeCard> cards, String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final cards = ref.watch(knowledgeCardsProvider);
    final favoriteIdsAsync = ref.watch(favoriteCardIdsProvider);

    // 如果有 cardId，显示单卡详情；否则显示全部卡片列表
    final card = widget.cardId != null
        ? _findCard(cards, widget.cardId!)
        : null;

    if (card != null) {
      // 单卡详情模式
      final isFav = favoriteIdsAsync.maybeWhen(
        data: (ids) => ids.contains(card.id),
        orElse: () => false,
      );

      return Scaffold(
        backgroundColor: tokens.canvas,
        extendBodyBehindAppBar: true,
        appBar: const LumiraNav(title: '知识卡片', transparent: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: LumiraImage(card.coverImage, fit: BoxFit.cover,
                      errorWidget:  Container(color: tokens.surfaceAlt, child: Icon(Icons.image_outlined, color: tokens.textTertiary)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 标题
                Text(card.title, style: TextStyle(
                  fontFamily: 'Noto Serif SC', fontSize: 22,
                  fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 4),
                Text(card.subtitle, style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
                const SizedBox(height: 16),
                // 收藏按钮
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => ref.read(academyActionsProvider.notifier).toggleFavorite(card.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isFav ? tokens.dangerSubtle : tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: isFav ? tokens.danger : tokens.brandText),
                        const SizedBox(width: 6),
                        Text(isFav ? '已收藏' : '收藏', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isFav ? tokens.danger : tokens.brandText,
                        )),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 正文
                Text(card.body, style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
                const SizedBox(height: 24),
                // 关键要点
                if (card.keyPoints.isNotEmpty) ...[
                  Text('关键要点', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                  )),
                  const SizedBox(height: 12),
                  NeuCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < card.keyPoints.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 20, height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tokens.brandSubtle, shape: BoxShape.circle),
              child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.brandText)),
            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(card.keyPoints[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6))),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // 相关推荐
                Text('相关知识', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 12),
                _RelatedCards(
                  currentCardId: card.id,
                  topic: card.topic,
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 全部卡片列表模式
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '美学知识', transparent: true),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final kc = cards[index];
            final isFav = favoriteIdsAsync.maybeWhen(
              data: (ids) => ids.contains(kc.id),
              orElse: () => false,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: LumiraImage(kc.coverImage, fit: BoxFit.cover,
                            errorWidget:  Container(color: tokens.surfaceAlt, child: Icon(Icons.image_outlined, color: tokens.textTertiary)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kc.title, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(kc.subtitle, style: TextStyle(fontSize: 12, color: tokens.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(4)),
                            child: Text(kc.topic.label, style: TextStyle(fontSize: 10, color: tokens.brandText)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => ref.read(academyActionsProvider.notifier).toggleFavorite(kc.id),
                            child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: isFav ? tokens.danger : tokens.textTertiary),
                          ),
                        ]),
                      ],
                    )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RelatedCards extends ConsumerWidget {
  const _RelatedCards({required this.currentCardId, required this.topic, required this.ref});
  final String currentCardId;
  final AcademyTopic topic;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final tokens = ref.watch(themeTokensProvider);
    final allCards = ref.watch(knowledgeCardsProvider);
    final related = allCards.where((c) => c.id != currentCardId && c.topic == topic).toList();

    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: related.map((kc) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: NeuCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: LumiraImage(kc.coverImage, fit: BoxFit.cover,
                    errorWidget:  Container(color: tokens.surfaceAlt),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kc.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(kc.subtitle, style: TextStyle(fontSize: 11, color: tokens.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        ),
      )).toList(),
    );
  }
}
