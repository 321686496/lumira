import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_models.dart';
import '../data/academy_mock_data.dart';
import '../providers/academy_providers.dart';

/// 课程详情页
class AcademyDetailPage extends ConsumerStatefulWidget {
  const AcademyDetailPage({super.key, this.academyId});

  final String? academyId;

  @override
  ConsumerState<AcademyDetailPage> createState() => _AcademyDetailPageState();
}

class _AcademyDetailPageState extends ConsumerState<AcademyDetailPage> {
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    // 标记为已开始学习
    if (widget.academyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(academyActionsProvider.notifier).markStarted(widget.academyId!);
      });
    }
  }

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
    if (widget.academyId == null) return;
    ref.read(academyActionsProvider.notifier).markCompleted(widget.academyId!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已标记为已学完'), duration: Duration(milliseconds: 1000)),
    );
  }

  void _goAssignment() {
    if (widget.academyId == null) return;
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.profileAcademyAssignment,
        {RouteNames.paramAcademyId: widget.academyId!},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final academyId = widget.academyId;
    final detail = academyId != null ? ref.watch(courseDetailProvider(academyId)) : null;
    final progressAsync = academyId != null ? ref.watch(courseProgressProvider(academyId)) : null;

    if (detail == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: const LumiraNav(title: '教程', transparent: true),
        body: Center(child: Text('课程不存在', style: TextStyle(color: tokens.textTertiary))),
      );
    }

    final isCompleted = progressAsync?.maybeWhen(
          data: (p) => p?.status == CourseStatus.completed,
          orElse: () => false,
        ) ?? false;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '教程',
        transparent: true,
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
            colors: [tokens.brandSubtle.withOpacity(0.35), tokens.canvas.withOpacity(0.0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LessonHead(detail: detail, tokens: tokens),
                _HeroImage(detail: detail, tokens: tokens),
                _ContentBody(
                  detail: detail,
                  tokens: tokens,
                  isCompleted: isCompleted,
                  onMarkComplete: _markComplete,
                  onGoAssignment: _goAssignment,
                  ref: ref,
                ),
                // 内嵌知识卡片 section
                if (detail.knowledgeCardIds.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('相关知识', style: TextStyle(
                      fontFamily: 'Noto Serif SC', fontSize: 17,
                      fontWeight: FontWeight.w600, color: tokens.textPrimary,
                    )),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 24),
                      itemCount: detail.knowledgeCardIds.length,
                      itemBuilder: (context, index) {
                        final cardId = detail.knowledgeCardIds[index];
                        final kc = AcademyMockData.getKnowledgeCard(cardId);
                        if (kc == null) return const SizedBox.shrink();
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: NeuCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kc.title, style: TextStyle(
                                  fontFamily: 'Noto Serif SC', fontSize: 14,
                                  fontWeight: FontWeight.w600, color: tokens.textPrimary,
                                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(kc.subtitle, style: TextStyle(
                                  fontSize: 11, color: tokens.textTertiary,
                                ), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === 迁移自 profile_academy_detail_page.dart 的私有 widget ===
// 以下 widget 与原文件基本一致，唯一变化：数据来源从 ProfileContentMockData 改为 AcademyCourseDetail

class _LessonHead extends StatelessWidget {
  const _LessonHead({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第${detail.course.lessonNumber}课 · ${detail.course.title}',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(detail.course.meta, style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(detail.heroImage, fit: BoxFit.cover,
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
    required this.detail,
    required this.tokens,
    required this.isCompleted,
    required this.onMarkComplete,
    required this.onGoAssignment,
    required this.ref,
  });

  final AcademyCourseDetail detail;
  final ThemeTokens tokens;
  final bool isCompleted;
  final VoidCallback onMarkComplete;
  final VoidCallback onGoAssignment;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final sections = detail.sections;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1
          if (sections.isNotEmpty) ...[
            _SectionTitle(text: sections[0].title, tokens: tokens),
            const SizedBox(height: 8),
            for (var i = 0; i < sections[0].paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(sections[0].paragraphs[i], style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
            ],
            const SizedBox(height: 28),
          ],
          // TipCard
          _TipCard(detail: detail, tokens: tokens),
          const SizedBox(height: 28),
          // Section 2 + CompareGrid
          if (sections.length >= 2) ...[
            _SectionTitle(text: sections[1].title, tokens: tokens),
            const SizedBox(height: 8),
            if (sections[1].paragraphs.isNotEmpty)
              Text(sections[1].paragraphs[0], style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
            const SizedBox(height: 12),
            _CompareGrid(detail: detail, tokens: tokens),
            const SizedBox(height: 28),
          ],
          // PracticeCard
          _PracticeCard(detail: detail, tokens: tokens),
          const SizedBox(height: 28),
          // Section 3 + Tips
          if (sections.length >= 3) ...[
            _SectionTitle(text: sections[2].title, tokens: tokens),
            const SizedBox(height: 12),
            _TipsCard(detail: detail, tokens: tokens),
            const SizedBox(height: 28),
          ],
          // RecommendTemplate
          if (detail.recommendTemplate != null) ...[
            _SectionTitle(text: '推荐模板', tokens: tokens),
            const SizedBox(height: 12),
            _RecommendCard(detail: detail, tokens: tokens),
            const SizedBox(height: 32),
          ],
          // 开始实战 CTA
          if (detail.assignment != null) ...[
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: onGoAssignment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.camera_alt_outlined),
                  SizedBox(width: 8),
                  Text('开始实战'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 标记完成
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: isCompleted ? null : onMarkComplete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check),
                SizedBox(width: 8),
                Text('标记为已学完'),
              ],
            ),
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
    return Text(text, style: TextStyle(
      fontFamily: 'Noto Serif SC', fontSize: 17,
      fontWeight: FontWeight.w600, color: tokens.textPrimary,
    ));
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(9999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 12, color: tokens.brandText),
              const SizedBox(width: 4),
              Text('技巧', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.brandText)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(detail.tipCardTitle, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 6),
          Text(detail.tipCardParagraph, style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(detail.tipCardImage, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareGrid extends StatelessWidget {
  const _CompareGrid({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cells = detail.compareCells;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _CompareCellView(cell: cells[i], tokens: tokens)),
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

  Color get _tagBg => cell.tagColor == 'green' ? tokens.successSubtle : tokens.brandSubtle;
  Color get _tagText => cell.tagColor == 'green' ? tokens.success : tokens.brandText;

  IconData _iconFor(String name) {
    switch (name) {
      case 'arrow_down': return Icons.arrow_downward;
      case 'arrows_left_right': return Icons.swap_horiz;
      case 'sun': return Icons.wb_sunny_outlined;
      case 'lightbulb': return Icons.lightbulb_outline;
      case 'face': return Icons.face_outlined;
      default: return Icons.compare_arrows;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(cell.iconName), size: 32, color: tokens.brand),
          const SizedBox(height: 8),
          Text(cell.name, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Text(cell.desc, style: TextStyle(fontSize: 11, color: tokens.textTertiary, height: 1.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _tagBg, borderRadius: BorderRadius.circular(9999)),
            child: Text(cell.tagText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _tagText)),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  Color _tagBg(String color) {
    switch (color) {
      case 'gold': return tokens.brandSubtle;
      case 'green': return tokens.successSubtle;
      default: return tokens.dangerSubtle;
    }
  }

  Color _tagText(String color) {
    switch (color) {
      case 'gold': return tokens.brandText;
      case 'green': return tokens.success;
      default: return tokens.danger;
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'camera': return Icons.camera_alt_outlined;
      case 'sun': return Icons.wb_sunny_outlined;
      case 'arrow_down': return Icons.arrow_downward;
      case 'face': return Icons.face_outlined;
      case 'lightbulb': return Icons.lightbulb_outline;
      default: return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.brand, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: tokens.brand, borderRadius: BorderRadius.circular(9999)),
            child: Text('实战练习', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textInverse)),
          ),
          const SizedBox(height: 10),
          Text(detail.practiceTitle, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 6),
          Text(detail.practiceParagraph, style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: detail.practiceTags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _tagBg(t.color), borderRadius: BorderRadius.circular(9999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_iconFor(t.iconName), size: 12, color: _tagText(t.color)),
                const SizedBox(width: 4),
                Text(t.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _tagText(t.color))),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < detail.tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle))),
              const SizedBox(width: 8),
              Expanded(child: Text(detail.tips[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 2.0))),
            ]),
          ],
        ],
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  const _RecommendCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final r = detail.recommendTemplate!;
    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(r.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.name, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(r.desc, style: TextStyle(fontSize: 12, color: tokens.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(9999)),
                child: Text(r.badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.brandText)),
              ),
            ],
          )),
        ],
      ),
    );
  }
}
