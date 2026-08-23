import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../academy/data/academy_models.dart'
    show AcademyLevelExt, AcademyTopicExt;
import '../../templates/widgets/ambience_badges.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../data/search_result.dart';

/// 搜索结果卡片（富内容，瀑布流竖卡）。
///
/// 模板卡片视觉完全对齐「全部模板页」卡片：
/// - 封面：模板/场景 3:4，美学院（课程/知识卡）4:3（与美学院知识卡一致）
/// - 左上角：类型角标（模板/场景/美学院）+ 模板价格/免费徽标
/// - [已拍 N 张] 叠在封面右下角（不占信息行空间）
/// - 信息区：名称 + 短描述 + 两级分类/自定义 + 季节/天气/时段氛围胶囊（Wrap 自动换行，不挤压）
class SearchResultCard extends ConsumerWidget {
  const SearchResultCard({
    super.key,
    required this.result,
    required this.showTypeBadge,
    required this.onTap,
  });

  final SearchResult result;
  final bool showTypeBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final r = result;

    return NeuCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imageStack(r, tokens),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _info(r, tokens),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageStack(SearchResult r, ThemeTokens tokens) {
    // 美学院 4:3（对齐美学院知识卡宽高比），模板/场景 3:4（瀑布流竖卡）
    final ratio = r.scope == SearchScope.academy ? 4 / 3 : 3 / 4;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(r, tokens),
          // 左上角类型角标（模板/场景/美学院）
          if (showTypeBadge)
            Positioned(top: 8, left: 8, child: _typeBadge(tokens, r.scope.label)),
          // 模板价格/免费徽标：类型角标在左时放右上，模板专属页放左上（对齐全部模板页）
          if (r.template != null)
            Positioned(
              top: 8,
              right: showTypeBadge ? 8 : null,
              left: showTypeBadge ? null : 8,
              child: r.price == 0
                  ? _priceBadge(tokens, '免费', true)
                  : _priceBadge(tokens, '${r.price}', false),
            ),
          // 已拍数：叠图角标（模板），不占用下方信息行空间，避免挤压季节/天气标签。
          if (r.template != null && r.usageCount > 0)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '已拍 ${r.usageCount} 张',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _info(SearchResult r, ThemeTokens tokens) {
    final hasShortDesc = r.template != null && r.shortDesc.isNotEmpty;
    return [
      Text(
        r.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Noto Serif SC',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: tokens.textPrimary,
        ),
      ),
      if (hasShortDesc) ...[
        const SizedBox(height: 3),
        Text(
          r.shortDesc,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: tokens.textSecondary,
          ),
        ),
      ],
      const SizedBox(height: 6),
      _tagRow(r, tokens),
    ];
  }

  Widget _tagRow(SearchResult r, ThemeTokens tokens) {
    if (r.template != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 两级分类：「大类 · 二级大风格」
                Text(
                  r.categoryTwoLevel,
                  style: TextStyle(fontSize: 11, color: tokens.brand),
                ),
                if (r.isCustom)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '自定义',
                      style: TextStyle(
                        fontSize: 10,
                        color: tokens.brandText,
                      ),
                    ),
                  ),
                AmbienceBadges(
                  ambience: r.ambience,
                  tokens: tokens,
                  maxItems: 2,
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (r.scene != null) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (r.scene!.style.isNotEmpty)
            _infoChip(tokens, r.scene!.style, bg: tokens.brandSubtle, fg: tokens.brand),
          if (r.scene!.category.isNotEmpty)
            _infoChip(tokens, r.scene!.category,
                bg: tokens.surfaceAlt, fg: tokens.textSecondary),
          Text(
            r.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: tokens.textSecondary,
            ),
          ),
        ],
      );
    }
    // 美学院
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _infoChip(tokens, r.course?.topic.label ?? r.knowledgeCard!.topic.label,
                  bg: tokens.brandSubtle, fg: tokens.brand),
              if (r.isCourse)
                _infoChip(tokens, r.course!.level.label,
                    bg: tokens.surfaceAlt, fg: tokens.textSecondary),
              if (!r.isCourse && r.subtitle.isNotEmpty)
                Text(
                  r.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _image(SearchResult r, ThemeTokens tokens) {
    final url = r.imageUrl;
    final data = r.coverData;
    if ((url == null || url.isEmpty) && (data == null || data.isEmpty)) {
      return _placeholder(tokens, r);
    }
    return TemplateCoverImage(
      cover: url,
      coverData: data,
      fit: BoxFit.cover,
      fallback: _placeholder(tokens, r),
      errorFallback: _placeholder(tokens, r),
    );
  }

  Widget _placeholder(ThemeTokens tokens, SearchResult r) => Container(
        color: tokens.surfaceAlt,
        child: Icon(
          r.scope == SearchScope.scene ? Icons.image_outlined : Icons.photo_outlined,
          color: tokens.textTertiary,
          size: 28,
        ),
      );

  Widget _priceBadge(ThemeTokens tokens, String text, bool free) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: free
            ? tokens.success.withOpacity(0.85)
            : Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _typeBadge(ThemeTokens tokens, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: tokens.textPrimary),
      ),
    );
  }

  Widget _infoChip(ThemeTokens tokens, String label,
      {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}

/// 搜索结果列表瓦片（单列列表布局，横向卡：左侧图 右侧文字）。
class SearchResultListTile extends ConsumerWidget {
  const SearchResultListTile({
    super.key,
    required this.result,
    required this.showTypeBadge,
    required this.onTap,
  });

  final SearchResult result;
  final bool showTypeBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final r = result;
    return NeuCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumb(r, tokens),
                  if (showTypeBadge)
                    Positioned(top: 6, left: 6, child: _liteBadge(tokens, r.scope.label)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.template != null
                                ? r.categoryTwoLevel
                                : r.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: r.template != null
                                  ? tokens.brand
                                  : tokens.textSecondary,
                            ),
                          ),
                        ),
                        if (r.template != null && r.usageCount > 0) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.camera_alt_outlined,
                              size: 12, color: tokens.textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            '${r.usageCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(SearchResult r, ThemeTokens tokens) {
    final url = r.imageUrl;
    final data = r.coverData;
    if ((url == null || url.isEmpty) && (data == null || data.isEmpty)) {
      return Container(
        color: tokens.surfaceAlt,
        child: Icon(
          r.scope == SearchScope.scene ? Icons.image_outlined : Icons.photo_outlined,
          color: tokens.textTertiary,
          size: 24,
        ),
      );
    }
    return TemplateCoverImage(
      cover: url,
      coverData: data,
      fit: BoxFit.cover,
      fallback: Container(color: tokens.surfaceAlt),
      errorFallback: Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.broken_image_outlined,
            size: 22, color: tokens.textTertiary),
      ),
    );
  }

  Widget _liteBadge(ThemeTokens tokens, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: tokens.textPrimary)),
    );
  }
}