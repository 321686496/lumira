import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/growth_providers.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/shooting_calendar_heatmap.dart';

/// 「全部记录」页：展示从最早有记录的一天到今天的完整拍摄日历热力图。
/// 复用 [ShootingCalendarHeatmap]，格子可点击查看单日详情。
class GrowthCalendarPage extends ConsumerWidget {
  const GrowthCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final heatmapAsync = ref.watch(growthHeatmapProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '全部记录',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: heatmapAsync.when(
            loading: () => SizedBox(
              height: 200,
              child: Center(child: LumiraProgress.circular()),
            ),
            error: (e, _) => Center(
              child: Text(
                '加载失败，请稍后重试',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            data: (heatmap) {
              final total = heatmap.values.fold<int>(0, (a, b) => a + b);
              final activeDays = heatmap.values.where((v) => v > 0).length;
              final hasData = activeDays > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 汇总
                  NeuCard(
                    child: Row(
                      children: [
                        _SummaryItem(
                          value: '$total',
                          label: '累计记录',
                          tokens: tokens,
                        ),
                        _divider(tokens),
                        _SummaryItem(
                          value: '$activeDays',
                          label: '活跃天数',
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '拍摄日历',
                          style: TextStyle(
                            fontFamily: 'Noto Serif SC',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!hasData)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: Text(
                                '暂无拍摄记录',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ShootingCalendarHeatmap(
                            heatmap: heatmap,
                            tokens: tokens,
                            onCellTap: (date, count, level) {
                              showDayDetailSheet(context, date: date);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _divider(ThemeTokens tokens) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: tokens.divider,
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.tokens,
  });
  final String value;
  final String label;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier New',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: tokens.brand,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
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
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileGrowth);
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