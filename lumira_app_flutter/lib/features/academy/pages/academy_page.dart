import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';
import '../widgets/academy_course_card.dart';
import '../widgets/academy_knowledge_card.dart';
import '../widgets/academy_level_selector.dart';
import '../widgets/academy_overview_card.dart';

/// 摄影美学院首页
class AcademyPage extends ConsumerStatefulWidget {
  const AcademyPage({super.key});

  @override
  ConsumerState<AcademyPage> createState() => _AcademyPageState();
}

class _AcademyPageState extends ConsumerState<AcademyPage> {
  AcademyLevel? _selectedLevel;

  void _goDetail(String courseId) {
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.profileAcademyDetail,
          {RouteNames.paramAcademyId: courseId}),
    );
  }

  void _goKnowledge(String cardId) {
    GoRouter.of(context).push(
      RouteNames.profileAcademyKnowledge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final actionState = ref.watch(academyActionsProvider);
    final overviewAsync = ref.watch(academyOverviewProvider);
    final favoriteIdsAsync = ref.watch(favoriteCardIdsProvider);
    final knowledgeCards = ref.watch(knowledgeCardsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '摄影美学院', transparent: true),
      body: Stack(
        children: [
          const Positioned.fill(
              child: GlassBackground(variant: GlassBackgroundVariant.profile)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 140),
              children: [
                // Section 1: 学习概览卡
                FadeUp(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: overviewAsync.when(
                      data: (overview) =>
                          AcademyOverviewCard(overview: overview),
                      loading: () => const SizedBox(
                          height: 72,
                          child: Center(
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                      error: (_, __) => const SizedBox(height: 72),
                    ),
                  ),
                ),
                // Section 2: 难度等级选择器
                FadeUp(
                  delay: const Duration(milliseconds: 60),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AcademyLevelSelector(
                      selected: _selectedLevel,
                      onChanged: (level) =>
                          setState(() => _selectedLevel = level),
                    ),
                  ),
                ),
                // Section 3: 课程网格（2 列）
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _CourseGrid(
                      level: _selectedLevel,
                      actionVersion: actionState.version,
                      onTap: _goDetail,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Section 4: 知识卡片
                FadeUp(
                  delay: const Duration(milliseconds: 140),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 0, 12),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 20, color: tokens.brand),
                        const SizedBox(width: 6),
                        Text(
                          '美学知识',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: knowledgeCards.length,
                    itemBuilder: (context, index) {
                      final kc = knowledgeCards[index];
                      final isFav = favoriteIdsAsync.maybeWhen(
                        data: (ids) => ids.contains(kc.id),
                        orElse: () => false,
                      );
                      return AcademyKnowledgeCard(
                        card: kc,
                        isFavorited: isFav,
                        onTap: () => _goKnowledge(kc.id),
                        onFavorite: () {
                          ref
                              .read(academyActionsProvider.notifier)
                              .toggleFavorite(kc.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const FloatingTabBar(active: 'profile'),
    );
  }
}

/// 课程网格（2 列）
class _CourseGrid extends ConsumerWidget {
  const _CourseGrid(
      {required this.level, required this.actionVersion, required this.onTap});

  final AcademyLevel? level;
  final int actionVersion;
  final void Function(String courseId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch actionVersion to trigger rebuild after status changes
    ref.watch(academyActionsProvider);
    final courses = ref.watch(coursesProvider(level));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemBuilder: (context, index) {
        final course = courses[index];
        final progressAsync = ref.watch(courseProgressProvider(course.id));
        final status = progressAsync.maybeWhen(
          data: (p) => p?.status ?? CourseStatus.notStarted,
          orElse: () => CourseStatus.notStarted,
        );
        return AcademyCourseCard(
          course: course,
          status: status,
          onTap: () => onTap(course.id),
        );
      },
    );
  }
}
