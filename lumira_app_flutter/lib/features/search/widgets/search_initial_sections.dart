import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../templates/widgets/template_cover_image.dart';

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

/// 推荐卡片数据：展示名 + 搜索关键词 + 封面 + 目标 scope + 兜底图标。
class SearchRecommendItem {
  const SearchRecommendItem({
    required this.keyword,
    required this.label,
    required this.scope,
    this.cover,
    this.coverData,
    this.fallbackIcon = Icons.photo_camera_outlined,
  });

  /// 点击后提交搜索的关键词。
  final String keyword;

  /// 卡片展示名称。
  final String label;

  /// 点击后应切换到的搜索范围。
  final SearchScope scope;

  /// 封面（assets 路径 / http URL / data URL）。
  final String? cover;

  /// 封面 base64 data（自定义模板 coverData）。
  final String? coverData;

  /// 无封面时的兜底图标。
  final IconData fallbackIcon;
}

/// 为你推荐区块：模板（横向卡片，封面 + 标签）。
class SearchRecommendTemplateSection extends ConsumerWidget {
  const SearchRecommendTemplateSection({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<SearchRecommendItem> items;
  final ValueChanged<SearchRecommendItem> onTap;

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
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecommendCard(
                item: items[i],
                tokens: tokens,
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 场景（封面卡片，名称取该风格下最新场景）。
class SearchRecommendSceneSection extends ConsumerWidget {
  const SearchRecommendSceneSection({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<SearchRecommendItem> items;
  final ValueChanged<SearchRecommendItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (items.isEmpty) return const SizedBox.shrink();
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
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecommendCard(
                item: items[i],
                tokens: tokens,
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 为你推荐 · 美学院（主题/等级封面卡片）。
class SearchRecommendAcademySection extends ConsumerWidget {
  const SearchRecommendAcademySection({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<SearchRecommendItem> items;
  final ValueChanged<SearchRecommendItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    if (items.isEmpty) return const SizedBox.shrink();
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
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecommendCard(
                item: items[i],
                tokens: tokens,
                onTap: () => onTap(items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 统一的推荐封面卡片：上方封面（无封面时用品牌图标占位），下方单行标签。
class _RecommendCard extends StatelessWidget {
  const _RecommendCard({
    required this.item,
    required this.tokens,
    required this.onTap,
  });

  final SearchRecommendItem item;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasCover = (item.cover != null && item.cover!.isNotEmpty) ||
        (item.coverData != null && item.coverData!.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 92,
        // Forced fix: 推荐封面卡改用共享 LumiraSurface，按当前 4 种 UI 风格渲染
        // （neumorphic/glass/female/…），不再固定 surface + divider 细边。
        child: LumiraSurface(
          radius: 16,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: hasCover
                    ? TemplateCoverImage(
                        cover: item.cover,
                        coverData: item.coverData,
                        fit: BoxFit.cover,
                        fallback: _placeholder(item, tokens),
                        errorFallback: _placeholder(item, tokens),
                      )
                    : _placeholder(item, tokens),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(SearchRecommendItem it, ThemeTokens tokens) {
    return Container(
      color: tokens.surfaceAlt,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tokens.brand, tokens.brand.withAlpha(160)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(it.fallbackIcon, size: 20, color: Colors.white),
        ),
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
