import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_mock_data.dart';
import '../data/gallery_models.dart';

/// 月度摄影手帐页（mock 数据）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/monthly-digest.vue（480 行）
/// - LumiraNav + 封面 + 照片墙 + 本月精选 + 总结卡 + 场景足迹 + CTA + Footer
class GalleryMonthlyDigestPage extends ConsumerWidget {
  const GalleryMonthlyDigestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '7月摄影手帐',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [_ExportAction(tokens: tokens)],
      ),
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
              children: [
                // 封面
                FadeUp(child: _CoverSection(tokens: tokens)),
                const SizedBox(height: 24),
                // 照片墙
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: _PhotoGridSection(tokens: tokens),
                ),
                const SizedBox(height: 24),
                // 本月精选
                FadeUp(
                  delay: const Duration(milliseconds: 200),
                  child: _SelectedSection(tokens: tokens),
                ),
                const SizedBox(height: 24),
                // 总结卡
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: _SummarySection(tokens: tokens),
                ),
                const SizedBox(height: 24),
                // 场景足迹
                FadeUp(
                  delay: const Duration(milliseconds: 400),
                  child: _SceneTagsSection(tokens: tokens),
                ),
                const SizedBox(height: 24),
                // CTA
                FadeUp(
                  delay: const Duration(milliseconds: 500),
                  child: _CtaSection(tokens: tokens),
                ),
                const SizedBox(height: 24),
                // Footer
                _FooterBranding(tokens: tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _ExportAction extends ConsumerWidget {
  const _ExportAction({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isNeu ? tokens.surface : null,
          border: isNeu ? null : Border.all(color: tokens.divider, width: 1),
          borderRadius: BorderRadius.circular(1000),
          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
        ),
        child: Text(
          '导出',
          style: TextStyle(fontSize: 13, color: tokens.textSecondary),
        ),
      ),
    );
  }
}

class _CoverSection extends StatelessWidget {
  const _CoverSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(Icons.menu_book_outlined, size: 36, color: tokens.brand),
        const SizedBox(height: 12),
        Text(
          '我的 7 月摄影手帐',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'serif',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lumira · Monthly Digest',
          style: TextStyle(
            fontSize: 12,
            color: tokens.textTertiary,
            fontFamily: 'Courier New',
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(GalleryMockData.coverStats.length, (i) {
            final s = GalleryMockData.coverStats[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: 1,
                    height: 28,
                    color: tokens.divider,
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.num,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.label,
                      style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PhotoGridSection extends StatelessWidget {
  const _PhotoGridSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '月份照片墙',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'serif',
              ),
            ),
            Text(
              '共 32 张',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                fontFamily: 'Courier New',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0, // 取最低公倍数（实际不同 cell 用 AspectRatio 覆盖）
          children: GalleryMockData.digestGalleryPhotos.map((p) {
            final ratio = _ratioOf(p.ratio);
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: ratio,
                child: CachedNetworkImage(
                  url: p.img,
                  fit: BoxFit.cover,
                  errorWidget: Container(color: tokens.surfaceAlt),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  double _ratioOf(DigestPhotoRatio r) {
    switch (r) {
      case DigestPhotoRatio.ratio11:
        return 1.0;
      case DigestPhotoRatio.ratio34:
        return 3.0 / 4.0;
      case DigestPhotoRatio.ratio45:
        return 4.0 / 5.0;
    }
  }
}

class _SelectedSection extends StatelessWidget {
  const _SelectedSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '本月精选',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'serif',
              ),
            ),
            Text(
              '3 张',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                fontFamily: 'Courier New',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...GalleryMockData.digestSelectedPhotos.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CachedNetworkImage(
                        url: s.img,
                        fit: BoxFit.cover,
                        errorWidget: Container(color: tokens.surfaceAlt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.date,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textTertiary,
                                fontFamily: 'Courier New',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.brandSubtle,
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Text(
                            s.tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: tokens.brand,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: tokens.shadowConvex,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '7月拍摄总结',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: GalleryMockData.summaryStats
                .map((s) => Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.num,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: tokens.brand,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.label,
                            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              GalleryMockData.monthQuote,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTagsSection extends StatelessWidget {
  const _SceneTagsSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '场景足迹',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GalleryMockData.sceneTags.map((t) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 14, color: tokens.brand),
                  const SizedBox(width: 4),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${t.count}',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CtaSection extends ConsumerWidget {
  const _CtaSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;

    return Column(
      children: [
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.brand,
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_outlined, size: 16, color: tokens.canvas),
                const SizedBox(width: 8),
                Text(
                  '生成手帐长图',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.canvas,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isNeu ? tokens.surface : null,
              border: isNeu ? null : Border.all(color: tokens.divider, width: 1),
              borderRadius: BorderRadius.circular(1000),
              boxShadow: isNeu ? tokens.shadowConvexBrand : null,
            ),
            child: Text(
              '分享手帐',
              style: TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterBranding extends StatelessWidget {
  const _FooterBranding({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '如你所见，皆成画卷 · 如画 Lumira',
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.8),
              radius: 1.2,
              colors: [
                tokens.brandSubtle.withOpacity(0.35),
                tokens.canvas.withOpacity(0),
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}
