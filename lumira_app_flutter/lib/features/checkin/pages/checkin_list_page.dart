import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_share.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹列表页
class CheckinListPage extends ConsumerStatefulWidget {
  const CheckinListPage({super.key});

  @override
  ConsumerState<CheckinListPage> createState() => _CheckinListPageState();
}

class _CheckinListPageState extends ConsumerState<CheckinListPage> {
  /// 排序方式：'time' 按时间 / 'rating' 按评分
  String _sortBy = 'time';

  /// 当前选中的分类（null 表示全部）
  String? _selectedCategory;

  void _goAdd() {
    GoRouter.of(context).push(RouteNames.checkinEdit);
  }

  void _goDetail(String id) {
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinDetail,
      {RouteNames.paramCheckinId: id},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final statsAsync = ref.watch(checkinStatsProvider);
    final categoriesAsync = ref.watch(checkinCategoriesProvider);
    final listAsync = ref.watch(checkinsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '探店足迹',
              actions: [
                GestureDetector(
                  onTap: _goAdd,
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
                    return _EmptyState(tokens: tokens, onAdd: _goAdd);
                  }
                  final filtered = _applyFilterAndSort(items);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      _StatsCard(stats: statsAsync.valueOrNull, tokens: tokens),
                      const SizedBox(height: 16),
                      _CategoryPills(
                        categories: categoriesAsync.valueOrNull ?? const [],
                        selected: _selectedCategory,
                        onSelect: _selectCategory,
                        tokens: tokens,
                      ),
                      const SizedBox(height: 12),
                      _SortToggle(
                        sortBy: _sortBy,
                        onToggle: (s) => setState(() => _sortBy = s),
                        tokens: tokens,
                      ),
                      const SizedBox(height: 4),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              '当前分类下还没有足迹',
                              style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                            ),
                          ),
                        ),
                      for (final item in filtered) ...[
                        FadeUp(
                          child: _CheckinCard(
                            item: item,
                            tokens: tokens,
                            onTap: () => _goDetail(item.record.id),
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

  List<CheckinListItem> _applyFilterAndSort(List<CheckinListItem> items) {
    var list = _selectedCategory == null
        ? items
        : items
            .where((i) => i.record.category == _selectedCategory)
            .toList();
    if (_sortBy == 'rating') {
      list = List.from(list)
        ..sort((a, b) => b.record.rating.compareTo(a.record.rating));
    }
    return list;
  }

  void _selectCategory(String cat) {
    setState(() {
      _selectedCategory =
          (cat == 'all' || _selectedCategory == cat) ? null : cat;
    });
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.tokens});

  final CheckinStats? stats;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final avg = stats != null ? stats!.avgRating : 0.0;
    return NeuCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCell('${stats?.total ?? 0}', '足迹总数'),
            _statCell('${stats?.highRated ?? 0}', '好评店铺'),
            _statCell(avg > 0 ? avg.toStringAsFixed(1) : '-', '平均评分'),
            _statCell('${stats?.thisYear ?? 0}', '今年新增'),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'Courier New',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.tokens,
  });

  final List<String> categories;
  final String? selected;
  final void Function(String) onSelect;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isAll = i == 0;
          final active =
              isAll ? selected == null : selected == categories[i - 1];
          final label =
              isAll ? '全部' : checkinCategoryOf(categories[i - 1]).label;
          return GestureDetector(
            onTap: () => onSelect(isAll ? 'all' : categories[i - 1]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(
                  color: active ? tokens.brand : tokens.divider,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active ? tokens.textInverse : tokens.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({
    required this.sortBy,
    required this.onToggle,
    required this.tokens,
  });

  final String sortBy;
  final void Function(String) onToggle;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _sortChip('按时间', 'time', sortBy == 'time'),
        const SizedBox(width: 8),
        _sortChip('按评分', 'rating', sortBy == 'rating'),
      ],
    );
  }

  Widget _sortChip(String label, String key, bool active) {
    return GestureDetector(
      onTap: () => onToggle(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              key == 'time' ? Icons.access_time : Icons.star,
              size: 12,
              color: active ? tokens.brandText : tokens.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? tokens.brandText : tokens.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
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
    final isHighRated = record.rating >= 4;

    return NeuCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面更大更圆润
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 80,
              child: _cover(item, tokens),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
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
                      // 分享按钮
                      GestureDetector(
                        onTap: () {
                          final stars =
                              '★' * record.rating + '☆' * (5 - record.rating);
                          final text = '探店：${record.name}\n'
                              '评分：$stars\n'
                              '地点：${record.place}'
                              '${record.note.isNotEmpty ? '\n备注：${record.note}' : ''}';
                          SafeShare.share(text, subject: '如画 LUMIRA · 探店足迹');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.share_outlined,
                            size: 16,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CheckinRatingStars(rating: record.rating, tokens: tokens),
                      if (isHighRated) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: tokens.successSubtle,
                            borderRadius: BorderRadius.circular(1000),
                          ),
                          child: Text(
                            '值得一去',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: tokens.success,
                            ),
                          ),
                        ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ),
                      Text(
                        formatCheckinDate(record.visitedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        child: Icon(category.icon, size: 32, color: category.iconColor),
      );
    }
    return CheckinPhotoImage(url: url, tokens: tokens, width: 80, height: 80);
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
