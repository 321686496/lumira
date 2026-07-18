import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/templates_mock_data.dart';

/// 推荐模板卡片（Hero 推荐区横向滚动项）
///
/// 视觉规格来源：lumira-app/src/pages/templates/index.vue line 17-37
/// - 宽度: 260rpx → 130dp
/// - 图片宽高比: 133.33% (3:4)
/// - 圆角: 24rpx → 12dp
/// - source badge: 左上角，圆角胶囊
/// - name: 26rpx → 13dp，单行 ellipsis
/// - reason: 22rpx → 11dp，最多 2 行
class RecommendationCard extends ConsumerWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.onTap,
  });

  final TemplateRecommendation recommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final rec = recommendation;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130, // 260rpx → 130dp
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecImage(rec: rec, tokens: tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4), // 20rpx 16rpx 20rpx 4rpx → 10 8 10 2
              child: Text(
                rec.name,
                style: TextStyle(
                  fontSize: 13, // 26rpx → 13dp
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), // 20rpx 0 20rpx 20rpx → 10 0 10 10
              child: Text(
                rec.reason,
                style: TextStyle(
                  fontSize: 11, // 22rpx → 11dp
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecImage extends StatelessWidget {
  const _RecImage({required this.rec, required this.tokens});

  final TemplateRecommendation rec;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4, // padding-bottom: 133.33% → 3:4
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
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
          Positioned(
            top: 6, // 12rpx → 6dp
            left: 6,
            child: _SourceBadge(source: rec.source),
          ),
        ],
      ),
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
