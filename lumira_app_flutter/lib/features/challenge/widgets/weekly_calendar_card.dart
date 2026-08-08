import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/challenge_providers.dart';
import '../data/challenge_models.dart';

class WeeklyCalendarCard extends ConsumerWidget {
  const WeeklyCalendarCard({super.key, this.onDateTap});

  /// 点击已完成或已跳过的日期回调，传递 challengeId 和 date（YYYY-MM-DD）
  final void Function(String challengeId, String date)? onDateTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final asyncHistory = ref.watch(weeklyHistoryProvider);

    // 计算本周一到今天
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: asyncHistory.when(
        loading: () => SizedBox(height: 80, child: Center(child: LumiraProgress.circular())),
        error: (e, _) => SizedBox(height: 80, child: Center(child: Text('加载失败', style: TextStyle(color: tokens.textSecondary)))),
        data: (history) {
          // 构建日期到状态的映射
          final dateStatus = <String, ChallengeStatus>{};
          // 按日期索引历史记录，用于回调
          final dateRecords = <String, ChallengeHistoryRecord>{};
          for (final record in history) {
            if (record.status == ChallengeStatus.done) {
              dateStatus[record.date] = ChallengeStatus.done;
            }
            // 取每个日期最晚的一条记录作为代表
            dateRecords[record.date] = record;
          }

          final todayStr = _formatDate(now);
          final completedCount = dateStatus.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本周挑战', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.map((day) {
                  final dayStr = _formatDate(day);
                  final isToday = dayStr == todayStr;
                  final isFuture = day.isAfter(now);
                  final isCompleted = dateStatus[dayStr] == ChallengeStatus.done;

                  // 是否可点击：已完成或已跳过的历史日期
                  final isPastWithRecord = !isFuture && dateRecords.containsKey(dayStr);
                  final canTap = isPastWithRecord && onDateTap != null;

                  Color iconColor;
                  IconData iconData;
                  if (isCompleted) {
                    iconColor = tokens.success;
                    iconData = Icons.check_circle;
                  } else if (isToday) {
                    iconColor = tokens.brand;
                    iconData = Icons.radio_button_checked;
                  } else if (isFuture) {
                    iconColor = tokens.textTertiary;
                    iconData = Icons.radio_button_unchecked;
                  } else {
                    iconColor = tokens.textTertiary;
                    iconData = Icons.remove_circle_outline;
                  }

                  return GestureDetector(
                    onTap: canTap
                        ? () {
                            final record = dateRecords[dayStr]!;
                            onDateTap!(record.challengeId, dayStr);
                          }
                        : null,
                    child: Column(
                      children: [
                        Text(
                          ['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1],
                          style: TextStyle(fontSize: 11, color: isToday ? tokens.brand : tokens.textTertiary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isToday ? tokens.brandSubtle : tokens.canvasDeep,
                            borderRadius: BorderRadius.circular(10),
                            border: isToday ? Border.all(color: tokens.brand, width: 1.5) : null,
                          ),
                          child: Icon(iconData, size: 20, color: iconColor),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 进度条
              Row(
                children: [
                  Expanded(
                    child: LumiraProgress.linear(
                      value: completedCount / 7,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$completedCount/7', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brand)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
