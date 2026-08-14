import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../academy/data/academy_models.dart';
import '../data/inspiration_providers.dart';

class BetterShootSection extends ConsumerWidget {
  const BetterShootSection({
    super.key,
    required this.onCourseTap,
    required this.onMoreCourses,
  });

  final void Function(AcademyCourse) onCourseTap;
  final VoidCallback onMoreCourses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(coursePicksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '拍得更好',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onMoreCourses,
              behavior: HitTestBehavior.opaque,
              child: Text(
                '全部课程',
                style: TextStyle(fontSize: 13, color: tokens.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: async.when(
            loading: () => _placeholder(tokens),
            error: (_, __) => _placeholder(tokens),
            data: (courses) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _CourseCard(
                course: courses[index],
                onTap: () => onCourseTap(courses[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ThemeTokens tokens) {
    return Center(
      child: Text(
        '精选课程加载中',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.onTap});
  final AcademyCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: tokens.shadowConvex,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: Image.asset(
                  course.coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.menu_book_outlined,
                        size: 24, color: tokens.textTertiary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
