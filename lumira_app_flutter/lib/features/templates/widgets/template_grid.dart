import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../data/templates_browse_mock_data.dart';
import '../services/template_mapper.dart';
import 'ambience_badges.dart';
import 'template_cover_image.dart';

/// TemplateRecord → AllTemplateItem 适配
/// DAO 模板数据 → 模板网格（TemplateGrid）所需类型
///
/// `isCustom` 由调用方根据 `r.isBuiltin` 决定：builtin=false 表示用户自定义模板。
AllTemplateItem templateGridItemFromRecord(
  TemplateRecord r, {
  required bool isCustom,
}) {
  return AllTemplateItem(
    id: r.id,
    name: r.name,
    category: r.category,
    style: (r.classification['style'] as String?),
    method: (r.classification['method'] as String?),
    // v4level：四级分类扩展字段（spec 2026-08-17-template-category-4level-design.md §4.1）
    majorStyle: (r.classification['majorStyle'] as String?),
    subStyle: (r.classification['subStyle'] as String?),
    coverSeed: r.id,
    cover: r.cover.isEmpty
        ? null
        : TemplateMapper.normalizeAssetUrl(r.cover),
    coverData: r.coverData,
    price: r.price,
    isCustom: isCustom,
    shortDesc: r.shortDesc,
    description: r.description,
    ambience: TemplateMapper.ambienceFromJson(r.ambienceJson),
  );
}

/// 截断长描述到约 [maxLen] 字符并追加省略号（卡片短简介兜底用）。
String truncate(String s, {int maxLen = 24}) {
  if (s.characters.length <= maxLen) return s;
  return '${s.characters.take(maxLen)}…';
}

/// 共享模板网格：瀑布流双列网格 + 单张模板卡片渲染
///
/// 视觉规格来源：lumira-app/src/pages/templates/all.vue
/// 提供给「全部模板」页与「我的收藏」页复用。
class TemplateGrid extends StatelessWidget {
  const TemplateGrid({
    super.key,
    required this.tokens,
    required this.templates,
    required this.usageCounts,
  });

  final ThemeTokens tokens;
  final List<AllTemplateItem> templates;
  final Map<String, int> usageCounts;

  /// 估算单张模板卡片总高度，用于瀑布流双列按高度配平（仅分配用，非精确值）。
  ///
  /// 结构：图(宽×4/3) + 文字区(内边距 24 + 名称 20 + [短描述 3+30] + 间距 6 + 徽标行 22)。
  double _estimateCardHeight(AllTemplateItem t, double cardWidth) {
    final imageH = cardWidth * 4 / 3;
    final hasDesc = t.shortDesc.isNotEmpty || t.description.isNotEmpty;
    final textH = 20 + (hasDesc ? 33 : 0) + 6 + 22 + 24;
    return imageH + textH;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40 - 12) / 2; // 页面左右 padding 20 + 列间距 12

    // 瀑布流双列：按估算高度累加，把下一张卡放到当前更矮的一列，视觉上近似等高收尾。
    final left = <Widget>[];
    final right = <Widget>[];
    var leftH = 0.0;
    var rightH = 0.0;
    for (final t in templates) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TemplateCard(
          tokens: tokens,
          template: t,
          usageCount: usageCounts[t.id] ?? 0,
        ),
      );
      final h = _estimateCardHeight(t, cardWidth);
      if (leftH <= rightH) {
        left.add(card);
        leftH += h;
      } else {
        right.add(card);
        rightH += h;
      }
    }

    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
          ],
        ),
      ),
    );
  }
}

/// 单张模板卡片（3:4 封面 + 免费/付费徽标 + 已拍 N 张 + 名称 + 短描述 + 氛围徽标 + 自定义标签）。
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.tokens,
    required this.template,
    required this.usageCount,
  });

  final ThemeTokens tokens;
  final AllTemplateItem template;
  final int usageCount;

  @override
  Widget build(BuildContext context) {
    final shortDesc = template.shortDesc.isNotEmpty
        ? template.shortDesc
        : truncate(template.description);
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(
        '/templates/detail?templateId=${template.id}',
      ),
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3:4 aspect ratio image
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateCoverImage(
                    cover: template.cover,
                    coverData: template.coverData,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.photo_outlined,
                        color: tokens.textTertiary,
                        size: 28,
                      ),
                    ),
                    errorFallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
                  if (template.price == 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _FreeBadge(tokens: tokens),
                    )
                  else
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _PremiumBadge(
                          tokens: tokens, price: template.price),
                    ),
                  // 已拍照片数：叠在封面右下角（半透明深色 pill），
                  // 避免占用下方信息行横向空间，导致季节/天气等氛围标签换行变纵向。
                  if (usageCount > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
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
                              '已拍 $usageCount 张',
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
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shortDesc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              TemplatesBrowseMockData.categoryLabel(
                                  template.category),
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.brand,
                              ),
                            ),
                            if (template.isCustom)
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
                              ambience: template.ambience,
                              tokens: tokens,
                              maxItems: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 免费徽标绿（色值跟随主题 success 色）
        color: tokens.success.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        '免费',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.tokens, required this.price});
  final ThemeTokens tokens;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (gradient brand → brandDeep)
        gradient: LinearGradient(colors: [tokens.brand, tokens.brandDeep]),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        '$price 积分',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}