import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../checkin/data/checkin_categories.dart';
import '../../checkin/data/checkin_models.dart';
import '../../checkin/data/checkin_providers.dart';
import '../../checkin/widgets/checkin_common.dart';

/// 灵感页「探店打卡」卡片 — 真实本地数据（sqflite）
///
/// - 统计行：总数 → 列表页
/// - 条目：最近 3 条（彩色分类图标 + 店名 + 相对日期）→ 详情页
/// - 空态：「还没有探店足迹」+「记录第一笔」→ 新增页
class CheckinCard extends ConsumerWidget {
  const CheckinCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final listAsync = ref.watch(checkinsProvider);
    final countAsync = ref.watch(checkinTotalCountProvider);

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                '探店打卡',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          listAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: LumiraProgress.circular()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '足迹加载失败',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.invalidate(checkinsProvider);
                      ref.invalidate(checkinTotalCountProvider);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '重试',
                        style: TextStyle(fontSize: 12, color: tokens.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            data: (items) {
              final count = countAsync.valueOrNull ?? items.length;
              if (items.isEmpty) return _EmptyHint(tokens: tokens);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 总数统计 → 列表页
                  GestureDetector(
                    onTap: () => _goList(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '个探店足迹',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              size: 18, color: tokens.textTertiary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < items.length && i < 3; i++) ...[
                    _CheckinItem(
                      item: items[i],
                      tokens: tokens,
                      showDivider: i > 0,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CheckinItem extends StatelessWidget {
  const _CheckinItem({
    required this.item,
    required this.tokens,
    this.showDivider = false,
  });

  final CheckinListItem item;
  final ThemeTokens tokens;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final category = checkinCategoryOf(record.category);
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.build(
        RouteNames.checkinDetail,
        {RouteNames.paramCheckinId: record.id},
      )),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            top: showDivider
                ? BorderSide(color: tokens.divider, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: category.iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.icon, size: 18, color: category.iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCheckinDate(record.visitedAt),
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(Icons.place_outlined, size: 28, color: tokens.textTertiary),
              const SizedBox(height: 8),
              Text(
                '还没有探店足迹',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '记录你喜欢的店铺，打造专属地图',
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => GoRouter.of(context).push(RouteNames.checkinEdit),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_location_alt_outlined,
                    size: 16, color: tokens.brand),
                const SizedBox(width: 6),
                Text(
                  '记录第一笔',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _goList(BuildContext context) {
  GoRouter.of(context).push(RouteNames.checkinList);
}
