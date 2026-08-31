import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/templates_mock_data.dart';
import 'adaptive_cover_image.dart';
import 'template_badges.dart';

/// 推荐模板卡片（Hero 推荐区横向滚动项）
///
/// 内容排版与「全部模板页」卡片对齐：
/// - 封面：真实比例自适应（宽度 100%，9:16 温和削减），叠 来源角标(左上) + 价格徽标(右上) + 已拍徽标(右下)
/// - 信息区：名称 + 推荐理由(短简介)。卡片较窄（130dp），标签行会被挤压，故推荐卡片不带分类/氛围标签
/// - 保留来源角标与推荐理由（Hero 专属信息）
class RecommendationCard extends ConsumerWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.usageCount,
    required this.onTap,
  });

  final TemplateRecommendation recommendation;
  final int usageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final rec = recommendation;

    return SizedBox(
      width: 130, // 260rpx → 130dp
      child: NeuCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面固定宽高（高 172 ≈ 宽 130 的 3:4 竖版），
            // 卡片高度稳定、布局整齐；真实比例由 BoxFit.cover 在固定框内轻微裁切，
            // 底部信息区固定贴底，不留白。
            SizedBox(
              width: double.infinity,
              height: 172,
              child: _RecImage(
                rec: rec,
                tokens: tokens,
                usageCount: usageCount,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 封面固定高 172 + 信息区 ~76 = 卡片高约 248，列表高度贴合，底部紧凑无大量留白。
                  if (rec.reason.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      rec.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecImage extends StatelessWidget {
  const _RecImage({
    required this.rec,
    required this.tokens,
    required this.usageCount,
  });

  final TemplateRecommendation rec;
  final ThemeTokens tokens;
  final int usageCount;

  @override
  Widget build(BuildContext context) {
    return AdaptiveCoverImage(
      cover: rec.cover,
      coverData: rec.coverData,
      fallback: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brand.withOpacity(0.6),
              tokens.brandDeep.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: tokens.textInverse.withOpacity(0.6),
          ),
        ),
      ),
      errorFallback: Container(
        color: tokens.surfaceAlt,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: tokens.textTertiary,
          ),
        ),
      ),
      overlay: [
        // 来源角标（Hero 专属）：左上
        Positioned(
          top: 8,
          left: 8,
          child: _SourceBadge(source: rec.source),
        ),
        // 价格/免费徽标：右上（与来源角标同行，避免重叠）
        if (rec.price == 0)
          Positioned(
            top: 8,
            right: 8,
            child: FreeBadge(tokens: tokens),
          )
        else
          Positioned(
            top: 8,
            right: 8,
            child: PremiumBadge(tokens: tokens, price: rec.price),
          ),
        // 已拍照片数：右下（与模板库卡片一致）
        if (usageCount > 0)
          Positioned(
            bottom: 8,
            right: 8,
            child: UsageCountBadge(count: usageCount),
          ),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final TemplateSource source;

  @override
  Widget build(BuildContext context) {
    final colors = _badgeColors(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // 16rpx 4rpx → 8 2
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        TemplatesMockData.sourceLabel(source),
        style: TextStyle(
          fontSize: 10, // 20rpx → 10dp
          color: colors.text,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  /// 来源色板
  /// 来源：lumira-app/src/pages/templates/index.vue line 230-233
  _BadgeColors _badgeColors(TemplateSource source) {
    switch (source) {
      case TemplateSource.recentUsed:
        // rgba(0, 0, 0, 0.55) bg + #F5E6CC text
        return _BadgeColors(Colors.black.withOpacity(0.55), const Color(0xFFF5E6CC));
      case TemplateSource.sceneMatch:
        // rgba(90, 122, 72, 0.85) bg + #fff text
        return _BadgeColors(const Color(0xFF5A7A48).withOpacity(0.85), Colors.white);
      case TemplateSource.categoryMatch:
        // rgba(201, 169, 110, 0.85) bg + #fff text
        return _BadgeColors(const Color(0xFFC9A96E).withOpacity(0.85), Colors.white);
      case TemplateSource.systemPick:
        // rgba(0, 0, 0, 0.65) bg + #fff text
        return _BadgeColors(Colors.black.withOpacity(0.65), Colors.white);
    }
  }
}

/// 来源 badge 颜色对（替代 Dart 3 records，Dart 2.19.6 兼容）
class _BadgeColors {
  const _BadgeColors(this.bg, this.text);

  final Color bg;
  final Color text;
}
