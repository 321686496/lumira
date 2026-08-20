import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 历史搜索区块：词条 pill + 右上「清空」。
class SearchHistorySection extends ConsumerWidget {
  const SearchHistorySection({
    super.key,
    required this.keywords,
    required this.onTap,
    required this.onDelete,
    required this.onClear,
  });

  final List<String> keywords;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('历史搜索',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child:
                    Icon(Icons.delete_outline, size: 16, color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keywords)
                _KeywordPill(
                  label: k,
                  tokens: tokens,
                  onTap: () => onTap(k),
                  onDelete: () => onDelete(k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 热门搜索区块：序号 + 词条。
class SearchHotSection extends ConsumerWidget {
  const SearchHotSection({super.key, required this.keywords, required this.onTap});

  final List<String> keywords;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (keywords.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('热门搜索',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (var i = 0; i < keywords.length; i++)
                GestureDetector(
                  onTap: () => onTap(keywords[i]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: i < 3 ? tokens.brand : tokens.textTertiary)),
                      const SizedBox(width: 8),
                      Text(keywords[i],
                          style:
                              TextStyle(fontSize: 13, color: tokens.textPrimary)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 为你推荐区块：模板分类卡（横向滚动）。
class SearchRecommendTemplateSection extends ConsumerWidget {
  const SearchRecommendTemplateSection({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<MapEntry<String, String>> items; // key -> 中文标签
  final ValueChanged<String> onTap; // 传中文标签（填充关键词）

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 模板',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final e = items[i];
                return GestureDetector(
                  onTap: () => onTap(e.value),
                  child: Container(
                    width: 88,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 场景（风格词条）。
class SearchRecommendSceneSection extends ConsumerWidget {
  const SearchRecommendSceneSection({
    super.key,
    required this.styles,
    required this.onTap,
  });

  final List<String> styles;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (styles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 场景',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in styles)
                GestureDetector(
                  onTap: () => onTap(s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(s,
                        style:
                            TextStyle(fontSize: 12, color: tokens.textSecondary)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 美学院（主题/等级词条）。
class SearchRecommendAcademySection extends ConsumerWidget {
  const SearchRecommendAcademySection({
    super.key,
    required this.topics,
    required this.levels,
    required this.onTap,
  });

  final List<String> topics; // 中文主题
  final List<String> levels; // 中文等级
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 美学院',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in topics)
                GestureDetector(
                  onTap: () => onTap(t),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(t,
                        style:
                            TextStyle(fontSize: 12, color: tokens.textSecondary)),
                  ),
                ),
              for (final l in levels)
                GestureDetector(
                  onTap: () => onTap(l),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: tokens.divider, width: 1),
                    ),
                    child: Text(l,
                        style: TextStyle(fontSize: 12, color: tokens.brand)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeywordPill extends StatelessWidget {
  const _KeywordPill({
    required this.label,
    required this.tokens,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(onTap: onTap, child: Text(label,
              style: TextStyle(fontSize: 12, color: tokens.textPrimary))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}
