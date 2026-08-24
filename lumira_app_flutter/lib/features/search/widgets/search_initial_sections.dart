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

/// 为你推荐区块：模板分类卡（横向卡片，图标 + 标签）。
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
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final e = items[i];
                return _RecommendCard.template(
                  tokens: tokens,
                  key: e.key,
                  label: e.value,
                  onTap: () => onTap(e.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 场景（图标卡片）。
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
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 场景',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: styles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecommendCard.scene(
                tokens: tokens,
                label: styles[i],
                onTap: () => onTap(styles[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 美学院（主题/等级图标卡片）。
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
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('为你推荐 · 美学院',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topics.length + levels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                if (i < topics.length) {
                  return _RecommendCard.academyTopic(
                    tokens: tokens,
                    label: topics[i],
                    onTap: () => onTap(topics[i]),
                  );
                }
                final l = levels[i - topics.length];
                return _RecommendCard.academyLevel(
                  tokens: tokens,
                  label: l,
                  onTap: () => onTap(l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 统一的推荐图标卡片：圆形品牌色底图标 + 下方单行标签。
class _RecommendCard extends StatelessWidget {
  const _RecommendCard({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.tint,
    required this.hasBg,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final Color tint;
  /// 是否给整卡上品牌淡色底（true=主题等强调项）。
  final bool hasBg;
  final VoidCallback onTap;

  factory _RecommendCard.template({
    required ThemeTokens tokens,
    required String key,
    required String label,
    required VoidCallback onTap,
  }) =>
      _RecommendCard(
        tokens: tokens,
        icon: _templateIcon(key),
        label: label,
        tint: tokens.brand,
        hasBg: false,
        onTap: onTap,
      );

  factory _RecommendCard.scene({
    required ThemeTokens tokens,
    required String label,
    required VoidCallback onTap,
  }) =>
      _RecommendCard(
        tokens: tokens,
        icon: Icons.camera_roll_outlined,
        label: label,
        tint: tokens.brand,
        hasBg: false,
        onTap: onTap,
      );

  factory _RecommendCard.academyTopic({
    required ThemeTokens tokens,
    required String label,
    required VoidCallback onTap,
  }) =>
      _RecommendCard(
        tokens: tokens,
        icon: Icons.menu_book_outlined,
        label: label,
        tint: tokens.brand,
        hasBg: true,
        onTap: onTap,
      );

  factory _RecommendCard.academyLevel({
    required ThemeTokens tokens,
    required String label,
    required VoidCallback onTap,
  }) =>
      _RecommendCard(
        tokens: tokens,
        icon: Icons.school_outlined,
        label: label,
        tint: tokens.brand,
        hasBg: false,
        onTap: onTap,
      );

  static IconData _templateIcon(String key) {
    switch (key) {
      case 'portrait':
        return Icons.face_outlined;
      case 'landscape':
        return Icons.landscape_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'street':
        return Icons.location_city_outlined;
      case 'night':
        return Icons.nightlight_outlined;
      case 'macro':
        return Icons.center_focus_strong_outlined;
      case 'still-life':
        return Icons.emoji_food_beverage_outlined;
      default:
        return Icons.photo_camera_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: hasBg ? tint.withAlpha(18) : tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint, tint.withAlpha(160)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
    return GestureDetector(onTap: onTap, child: card);
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
