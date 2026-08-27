import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraProgress, LumiraButton, ButtonVariant;
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 我的收藏：单页双分区展示已收藏课程 + 已收藏知识卡
class AcademyFavoritesPage extends ConsumerWidget {
  const AcademyFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final courseFavAsync = ref.watch(favoriteCourseIdsProvider);
    final cardFavAsync = ref.watch(favoriteCardIdsProvider);
    final allCourses = ref.watch(coursesProvider(null));
    final allCards = ref.watch(knowledgeCardsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '我的收藏',
        transparent: true,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
              child: GlassBackground(variant: GlassBackgroundVariant.profile)),
          SafeArea(
            top: false,
            child: courseFavAsync.when(
              loading: () => Center(child: LumiraProgress.circular()),
              error: (_, __) => Center(
                child: Text('加载失败', style: TextStyle(color: tokens.textTertiary)),
              ),
              data: (courseIds) => _buildContent(
                context,
                ref,
                tokens,
                courseIds: courseIds,
                cardIds: cardFavAsync.maybeWhen(
                    data: (s) => s, orElse: () => <String>{}),
                allCourses: allCourses,
                allCards: allCards,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ThemeTokens tokens, {
    required Set<String> courseIds,
    required Set<String> cardIds,
    required List<AcademyCourse> allCourses,
    required List<KnowledgeCard> allCards,
  }) {
    final favCourses =
        allCourses.where((c) => courseIds.contains(c.id)).toList();
    final favCards =
        allCards.where((c) => cardIds.contains(c.id)).toList();

    if (favCourses.isEmpty && favCards.isEmpty) {
      return _EmptyState(tokens: tokens);
    }

    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return ListView(
      padding: EdgeInsets.only(top: topPadding, bottom: 24),
      children: [
        if (favCourses.isNotEmpty) ...[
          _SectionTitle(title: '已收藏课程', tokens: tokens),
          for (final c in favCourses) _CourseRow(course: c, tokens: tokens),
        ],
        if (favCards.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionTitle(title: '已收藏知识卡', tokens: tokens),
          for (final kc in favCards) _KnowledgeRow(card: kc, tokens: tokens),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.tokens});
  final String title;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Noto Serif SC',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.tokens});
  final AcademyCourse course;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: _FavoriteRow(
        cover: course.coverImage,
        title: '第${course.lessonNumber}课 · ${course.title}',
        subtitle: course.meta,
        tokens: tokens,
        onTap: () => GoRouter.of(context).push(
          RouteNames.build(
            RouteNames.profileAcademyDetail,
            {RouteNames.paramAcademyId: course.id},
          ),
        ),
      ),
    );
  }
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({required this.card, required this.tokens});
  final KnowledgeCard card;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: _FavoriteRow(
        cover: card.coverImage,
        title: card.title,
        subtitle: card.subtitle,
        tokens: tokens,
        onTap: () => GoRouter.of(context).push(
          RouteNames.build(
            RouteNames.profileAcademyKnowledge,
            {RouteNames.paramAcademyId: card.id},
          ),
        ),
      ),
    );
  }
}

/// 总览页统一行卡片：封面 + 标题 + 副标题 + 取消收藏爱心
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.tokens,
    required this.onTap,
  });
  final String cover;
  final String title;
  final String subtitle;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 54,
                child: LumiraImage(
                  cover,
                  fit: BoxFit.cover,
                  errorWidget:  Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text('还没有收藏内容',
              style: TextStyle(fontSize: 14, color: tokens.textTertiary)),
          const SizedBox(height: 4),
          Text('进入课程或知识卡片点心形图标即可收藏',
              style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('返回摄影美学院'),
          ),
        ],
      ),
    );
  }
}