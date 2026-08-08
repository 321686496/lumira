import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_content.dart';
import '../data/academy_trajectory_models.dart';
import '../providers/academy_providers.dart';

/// 学习轨迹页
///
/// 时间线竖向布局，展示用户已完全完成的课程列表。
/// 每节点：圆形序号 + 课程封面 + 课程名 + 完成时间 + "第 N 个完成"标签
/// 节点间用虚线连接。
class AcademyTrajectoryPage extends ConsumerWidget {
  const AcademyTrajectoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final trajectoryAsync = ref.watch(academyTrajectoryProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '学习轨迹',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: trajectoryAsync.when(
          loading: () => Center(child: LumiraProgress.circular(strokeWidth: 2)),
          error: (_, __) => Center(
            child: Text('加载失败', style: TextStyle(color: tokens.textTertiary)),
          ),
          data: (trajectory) {
            if (trajectory.isEmpty) {
              return _EmptyState(tokens: tokens);
            }
            // 估算总学习时长：每段 paragraphs 折算 30 秒
            int totalDurationSeconds = 0;
            for (final record in trajectory) {
              final detail = AcademyContent.getCourseDetail(record.courseId);
              if (detail != null) {
                final paragraphCount = detail.sections.fold<int>(
                    0, (sum, s) => sum + s.paragraphs.length);
                totalDurationSeconds += paragraphCount * 30;
              }
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeUp(
                    child: _StatsCard(
                      tokens: tokens,
                      completedCount: trajectory.length,
                      totalCount: AcademyContent.courses.length,
                      totalDurationSeconds: totalDurationSeconds,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeUp(
                    delay: const Duration(milliseconds: 80),
                    child: _Timeline(
                      tokens: tokens,
                      trajectory: trajectory,
                    ),
                  ),
                ],
              ),
            );
          },
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
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileAcademy);
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

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.tokens,
    required this.completedCount,
    required this.totalCount,
    required this.totalDurationSeconds,
  });

  final ThemeTokens tokens;
  final int completedCount;
  final int totalCount;
  final int totalDurationSeconds;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 分钟';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return remMinutes > 0 ? '$hours 小时 $remMinutes 分钟' : '$hours 小时';
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 22, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '学习轨迹',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '已完成 $completedCount / $totalCount 课',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: totalCount > 0
                        ? completedCount / totalCount
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: tokens.textTertiary),
              const SizedBox(width: 6),
              Text(
                '总学习时长约 ${_formatDuration(totalDurationSeconds)}',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.tokens, required this.trajectory});

  final ThemeTokens tokens;
  final List<AcademyTrajectoryRecord> trajectory;

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < trajectory.length; i++)
          _TimelineNode(
            tokens: tokens,
            record: trajectory[i],
            isLast: i == trajectory.length - 1,
            formatDate: _formatDate,
          ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.tokens,
    required this.record,
    required this.isLast,
    required this.formatDate,
  });

  final ThemeTokens tokens;
  final AcademyTrajectoryRecord record;
  final bool isLast;
  final String Function(int) formatDate;

  @override
  Widget build(BuildContext context) {
    final course = AcademyContent.getCourse(record.courseId);
    final courseTitle = course?.title ?? '未知课程';
    final coverImage = course?.coverImage ?? '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：圆形序号 + 虚线
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tokens.brand, tokens.brandDeep],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${record.sequence}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                          color: tokens.divider,
                          dashWidth: 2,
                          dashHeight: 3,
                          gapHeight: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：课程卡片
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: NeuCard(
                child: Row(
                  children: [
                    // 课程封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: coverImage.isNotEmpty
                            ? Image.asset(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: tokens.surfaceAlt,
                                  child: Icon(Icons.image_outlined,
                                      size: 20, color: tokens.textTertiary),
                                ),
                              )
                            : Container(
                                color: tokens.surfaceAlt,
                                child: Icon(Icons.school,
                                    size: 20, color: tokens.brand),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 课程信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseTitle,
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
                            formatDate(record.completedAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier New',
                              color: tokens.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tokens.successSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '第 ${record.sequence} 个完成',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: tokens.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: tokens.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '开始你的第一节课程吧',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成课程并提交作业后，\n你的学习轨迹将出现在这里',
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  GoRouter.of(context).go(RouteNames.profileAcademy);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.menu_book_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('去学习'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间线节点间虚线绘制器
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashHeight,
    required this.gapHeight,
  });

  final Color color;
  final double dashWidth;
  final double dashHeight;
  final double gapHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final step = dashHeight + gapHeight;
    final count = (size.height / step).floor();
    final xOffset = (size.width - dashWidth) / 2;
    for (var i = 0; i < count; i++) {
      final y = i * step;
      canvas.drawRect(
        Rect.fromLTWH(xOffset, y, dashWidth, dashHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color ||
      dashWidth != oldDelegate.dashWidth ||
      dashHeight != oldDelegate.dashHeight ||
      gapHeight != oldDelegate.gapHeight;
}
