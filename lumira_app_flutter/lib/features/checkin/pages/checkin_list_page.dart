import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹列表页
class CheckinListPage extends ConsumerWidget {
  const CheckinListPage({super.key});

  void _goAdd(BuildContext context) {
    GoRouter.of(context).push(RouteNames.checkinEdit);
  }

  void _goDetail(BuildContext context, String id) {
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinDetail,
      {RouteNames.paramCheckinId: id},
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final listAsync = ref.watch(checkinsProvider);
    final countAsync = ref.watch(checkinTotalCountProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '探店足迹',
              actions: [
                GestureDetector(
                  onTap: () => _goAdd(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.add, size: 22, color: tokens.brand),
                  ),
                ),
              ],
            ),
            Expanded(
              child: listAsync.when(
                loading: () => Center(child: LumiraProgress.circular()),
                error: (e, _) => Center(
                  child: Text(
                    '加载失败：$e',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyState(tokens: tokens, onAdd: () => _goAdd(context));
                  }
                  final count = countAsync.valueOrNull ?? items.length;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _StatsCard(count: count, tokens: tokens),
                      const SizedBox(height: 16),
                      for (final item in items) ...[
                        FadeUp(
                          child: _CheckinListTile(
                            item: item,
                            tokens: tokens,
                            onTap: () => _goDetail(context, item.record.id),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.count, required this.tokens});

  final int count;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '个探店足迹',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CheckinListTile extends StatelessWidget {
  const _CheckinListTile({
    required this.item,
    required this.tokens,
    required this.onTap,
  });

  final CheckinListItem item;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final category = checkinCategoryOf(record.category);
    return NeuCard(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: _cover(item, tokens),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (record.rating > 0) ...[
                      const SizedBox(width: 8),
                      CheckinRatingStars(rating: record.rating, tokens: tokens),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CheckinCategoryTag(category: category, tokens: tokens),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                      ),
                    ),
                    Text(
                      formatCheckinDate(record.visitedAt),
                      style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
        ],
      ),
    );
  }

  /// 封面：有照片显示照片，无照片显示分类彩色图标占位
  Widget _cover(CheckinListItem item, ThemeTokens tokens) {
    final category = checkinCategoryOf(item.record.category);
    final url = item.coverPhotoUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: category.iconBgColor,
        child: Icon(category.icon, size: 24, color: category.iconColor),
      );
    }
    return CheckinPhotoImage(url: url, tokens: tokens, width: 56, height: 56);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens, required this.onAdd});

  final ThemeTokens tokens;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '还没有探店足迹',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: onAdd,
            child: const Text('记录第一笔'),
          ),
        ],
      ),
    );
  }
}
