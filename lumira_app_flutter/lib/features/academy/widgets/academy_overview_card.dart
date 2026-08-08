import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/academy_models.dart';
import 'academy_progress_ring.dart';

/// 学习概览卡：进度环 + 连续天数 + XP + 推荐下一课
class AcademyOverviewCard extends ConsumerWidget {
  const AcademyOverviewCard({super.key, required this.overview});

  final AcademyOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 左侧：进度环
          AcademyProgressRing(
            progress: overview.completionRate,
            size: 72,
            ringColor: tokens.brand,
            backgroundColor: tokens.divider,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(overview.completionRate * 100).round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  '完成',
                  style: TextStyle(fontSize: 10, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 右侧：统计信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_outlined, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('${overview.streakDays} 天', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                    const SizedBox(width: 12),
                    Icon(Icons.bolt_outlined, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('${overview.totalXP} XP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${overview.completedCourses}/${overview.totalCourses} 课已完成',
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
                if (overview.nextCourseTitle != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      final id = overview.nextCourseId;
                      if (id != null) {
                        GoRouter.of(context).push(
                          RouteNames.build(RouteNames.profileAcademyDetail, {RouteNames.paramAcademyId: id}),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outlined, size: 16, color: tokens.brandText),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              overview.nextCourseStatus == CourseStatus.inProgress
                                  ? '继续：${overview.nextCourseTitle}'
                                  : '推荐：${overview.nextCourseTitle}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.brandText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    GoRouter.of(context).push(RouteNames.academyTrajectory);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline, size: 16, color: tokens.brandText),
                        const SizedBox(width: 6),
                        Text(
                          '我的学习轨迹',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tokens.brandText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: tokens.brandText),
                      ],
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
