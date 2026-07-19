import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_content_mock_data.dart';

/// 摄影学院课程详情页
///
/// 视觉规格来源：lumira-app/src/pages/profile/academy-detail.vue（468 行）
/// 6 个 section：
/// 1. LessonHead（标题 + meta）
/// 2. HeroImage
/// 3. ContentBody（首段 + TipCard + 对比网格 + 实战练习 + 小贴士 + 推荐模板）
/// 4. CompleteWrap（标记完成按钮）
class ProfileAcademyDetailPage extends ConsumerStatefulWidget {
  const ProfileAcademyDetailPage({super.key, this.academyId});

  final String? academyId;

  @override
  ConsumerState<ProfileAcademyDetailPage> createState() =>
      _ProfileAcademyDetailPageState();
}

class _ProfileAcademyDetailPageState
    extends ConsumerState<ProfileAcademyDetailPage> {
  bool _bookmarked = false;
  bool _completed = false;

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarked ? '已收藏' : '已取消收藏'),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _markComplete() {
    if (_completed) return;
    setState(() => _completed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已标记为已学完'),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '教程',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          GestureDetector(
            onTap: _toggleBookmark,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 22,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LessonHead(tokens: tokens),
                _HeroImage(tokens: tokens),
                _ContentBody(
                  tokens: tokens,
                  completed: _completed,
                  onMarkComplete: _markComplete,
                ),
              ],
            ),
          ),
        ),
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
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _LessonHead extends StatelessWidget {
  const _LessonHead({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), // 48rpx/32rpx/0 → 24/16/0
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProfileContentMockData.lessonTitle,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 22, // 44rpx → 22dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            ProfileContentMockData.lessonMeta,
            style: TextStyle(
              fontSize: 13, // 26rpx → 13dp
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            ProfileContentMockData.lessonHeroImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: tokens.surfaceAlt,
              child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({
    required this.tokens,
    required this.completed,
    required this.onMarkComplete,
  });

  final ThemeTokens tokens;
  final bool completed;
  final VoidCallback onMarkComplete;

  @override
  Widget build(BuildContext context) {
    const sections = ProfileContentMockData.lessonSections;
    return Padding(
      padding: const EdgeInsets.all(24), // 48rpx → 24dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: 为什么角度很重要
          if (sections.isNotEmpty) ...[
            _SectionTitle(text: sections[0].title, tokens: tokens),
            const SizedBox(height: 8),
            for (var i = 0; i < sections[0].paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(
                sections[0].paragraphs[i],
                style: TextStyle(
                  fontSize: 14, // 28rpx → 14dp
                  color: tokens.textSecondary,
                  height: 1.8,
                ),
              ),
            ],
            const SizedBox(height: 28), // 56rpx → 28dp
          ],
          // TipCard
          _TipCard(tokens: tokens),
          const SizedBox(height: 28),
          // Section 2: 俯拍 vs 平拍
          if (sections.length >= 2) ...[
            _SectionTitle(text: sections[1].title, tokens: tokens),
            const SizedBox(height: 8),
            if (sections[1].paragraphs.isNotEmpty)
              Text(
                sections[1].paragraphs[0],
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                  height: 1.8,
                ),
              ),
            const SizedBox(height: 12),
            _CompareGrid(tokens: tokens),
            const SizedBox(height: 28),
          ],
          // PracticeCard
          _PracticeCard(tokens: tokens),
          const SizedBox(height: 28),
          // Section 3: 小贴士
          if (sections.length >= 3) ...[
            _SectionTitle(text: sections[2].title, tokens: tokens),
            const SizedBox(height: 12),
            _TipsCard(tokens: tokens),
            const SizedBox(height: 28),
          ],
          // RecommendSection
          _SectionTitle(text: '推荐模板', tokens: tokens),
          const SizedBox(height: 12),
          _RecommendCard(tokens: tokens),
          const SizedBox(height: 32), // 64rpx → 32dp
          // CompleteWrap
          LumiraButton(
            label: '标记为已学完',
            icon: Icons.check,
            onPressed: completed ? null : onMarkComplete,
            enabled: !completed,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Noto Serif SC',
        fontSize: 17, // 34rpx → 17dp
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16), // 32rpx → 16dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag row: gold tag '技巧' with sparkle icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // 16rpx/6rpx → 8/3dp
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: tokens.brandText),
                const SizedBox(width: 4),
                Text(
                  '技巧',
                  style: TextStyle(
                    fontSize: 11, // 22rpx → 11dp
                    fontWeight: FontWeight.w500,
                    color: tokens.brandText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ProfileContentMockData.tipCardTitle,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16, // 32rpx → 16dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ProfileContentMockData.tipCardParagraph,
            style: TextStyle(
              fontSize: 13, // 26rpx → 13dp
              color: tokens.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                ProfileContentMockData.tipCardImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: tokens.surfaceAlt,
                  child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareGrid extends StatelessWidget {
  const _CompareGrid({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const cells = ProfileContentMockData.compareCells;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 12), // 24rpx → 12dp
            Expanded(
              child: _CompareCellView(cell: cells[i], tokens: tokens),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareCellView extends StatelessWidget {
  const _CompareCellView({required this.cell, required this.tokens});
  final CompareCell cell;
  final ThemeTokens tokens;

  Color get _tagBg {
    switch (cell.tagColor) {
      case 'green':
        return tokens.successSubtle;
      case 'gold':
      default:
        return tokens.brandSubtle;
    }
  }

  Color get _tagText {
    switch (cell.tagColor) {
      case 'green':
        return tokens.success;
      case 'gold':
      default:
        return tokens.brandText;
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'arrow_down':
        return Icons.arrow_downward;
      case 'arrows_left_right':
        return Icons.swap_horiz;
      default:
        return Icons.compare_arrows;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // 24rpx → 12dp
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(cell.iconName), size: 32, color: tokens.brand),
          const SizedBox(height: 8),
          Text(
            cell.name,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 14, // 28rpx → 14dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cell.desc,
            style: TextStyle(
              fontSize: 11, // 22rpx → 11dp
              color: tokens.textTertiary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _tagBg,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              cell.tagText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _tagText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.tokens});
  final ThemeTokens tokens;

  Color _tagBg(PracticeTag t) {
    switch (t.color) {
      case 'gold':
        return tokens.brandSubtle;
      case 'green':
        return tokens.successSubtle;
      case 'red':
      default:
        return tokens.dangerSubtle;
    }
  }

  Color _tagText(PracticeTag t) {
    switch (t.color) {
      case 'gold':
        return tokens.brandText;
      case 'green':
        return tokens.success;
      case 'red':
      default:
        return tokens.danger;
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'sun':
        return Icons.wb_sunny_outlined;
      case 'arrow_down':
        return Icons.arrow_downward;
      default:
        return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.brand, width: 1.5), // brand 1.5dp
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge: brand bg '实战练习'
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.brand,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '实战练习',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textInverse,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ProfileContentMockData.practiceTitle,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ProfileContentMockData.practiceParagraph,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProfileContentMockData.practiceTags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _tagBg(t),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconFor(t.iconName), size: 12, color: _tagText(t)),
                          const SizedBox(width: 4),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _tagText(t),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), // 40rpx/32rpx → 20/16dp
      decoration: BoxDecoration(
        color: tokens.canvas, // 与外层 canvas 相同，靠圆角区分
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < ProfileContentMockData.tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ProfileContentMockData.tips[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 2.0, // line-height 2
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  const _RecommendCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const r = ProfileContentMockData.recommendTemplate;
    return NeuCard(
      padding: const EdgeInsets.all(12), // 24rpx → 12dp
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RecommendImage: aspectRatio 3:4
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80, // 固定宽度，避免溢出
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  r.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // RecommendRow: info + 免费 badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.name,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  r.desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    r.badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: tokens.brandText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
