import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';
import '../widgets/checkin_poster_generator.dart';

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

  /// 弹出探店足迹海报（生成 / 导出 / 分享）
  Future<void> _showSharePoster(BuildContext context, CheckinListItem item) async {
    final tokens = ref.read(appThemeProvider).tokens;
    await showCheckinPoster(
      context: context,
      tokens: tokens,
      item: item,
      ref: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final statsAsync = ref.watch(checkinStatsProvider);
    final categoriesAsync = ref.watch(checkinCategoriesProvider);
    final listAsync = ref.watch(checkinsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          // 渐变背景叠层（手帐风淡入氛围）
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.8),
                    radius: 1.3,
                    colors: [
                      tokens.brandSubtle.withOpacity(0.5),
                      tokens.canvas.withOpacity(0),
                    ],
                    stops: const [0.0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
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
                      ),
                      const SizedBox(height: 12),
                      _SortToggle(
                        sortBy: _sortBy,
                        onToggle: (s) => setState(() => _sortBy = s),
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
                            onShare: () => _showSharePoster(context, item),
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
          ],
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
            _statCell('${stats?.total ?? 0}', '足迹总数', Icons.place_outlined),
            _statCell('${stats?.highRated ?? 0}', '好评店铺', Icons.thumb_up_alt_outlined),
            _statCell(avg > 0 ? avg.toStringAsFixed(1) : '-', '平均评分', Icons.star_outline),
            _statCell('${stats?.thisYear ?? 0}', '今年新增', Icons.local_fire_department_outlined),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String num, String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: tokens.brand),
        ),
        const SizedBox(height: 6),
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
  });

  final List<String> categories;
  final String? selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // 外层 ListView 已提供 24px 水平内边距，此处不再叠加，
        // 保证分类 tab 与下方排序 tab 左缘对齐
        padding: EdgeInsets.zero,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isAll = i == 0;
          final active =
              isAll ? selected == null : selected == categories[i - 1];
          final label =
              isAll ? '全部' : checkinCategoryOf(categories[i - 1]).label;
          // 复用 LumiraFilterChip：选中态在中（新拟态下呈凹陷内阴影），全风格一致
          return Center(
            child: LumiraFilterChip(
              label: label,
              active: active,
              onTap: () => onSelect(isAll ? 'all' : categories[i - 1]),
            ),
          );
        },
      ),
    );
  }
}

class _SortToggle extends ConsumerWidget {
  const _SortToggle({
    required this.sortBy,
    required this.onToggle,
  });

  final String sortBy;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    return Row(
      children: [
        _sortChip('按时间', 'time', sortBy == 'time', tokens, isNeu),
        const SizedBox(width: 8),
        _sortChip('按评分', 'rating', sortBy == 'rating', tokens, isNeu),
      ],
    );
  }

  Widget _sortChip(
      String label, String key, bool active, ThemeTokens tokens, bool isNeu) {
    // 尺寸规格与 LumiraFilterChip 对齐（horizontal 14 / vertical 8 / 图标 14），
    // 保证排序 tab 与分类 tab 高度一致
    final rowContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          key == 'time' ? Icons.access_time : Icons.star,
          size: 14,
          color: active ? tokens.brandText : tokens.textTertiary,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? tokens.brandText : tokens.textTertiary,
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => onToggle(key),
      child: isNeu && active
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: 1000,
              depth: 0.7,
              rimFraction: 0.32,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: rowContent,
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                // neumorphic：方案 B 选中/未选中同为 surface，仅凸起↔凹陷翻转；
                // 非新拟态保持品牌淡底选中态
                color: isNeu
                    ? tokens.surface
                    : (active ? tokens.brandSubtle : Colors.transparent),
                borderRadius: BorderRadius.circular(1000),
                boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
              ),
              child: rowContent,
            ),
    );
  }
}

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.item,
    required this.tokens,
    required this.onTap,
    required this.onShare,
  });

  final CheckinListItem item;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final category = checkinCategoryOf(record.category);
    final isHighRated = record.rating >= 4;

    return NeuCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 92,
              height: 92,
              child: _cover(item, tokens),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 店名 + 分享（生成海报）
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onShare,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.ios_share_rounded,
                          size: 18,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // 评分 + 值得一去
                Row(
                  children: [
                    CheckinRatingStars(
                      rating: record.rating,
                      tokens: tokens,
                      size: 13,
                    ),
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
                const SizedBox(height: 7),
                // 分类 + 地点（地点独占剩余空间，不再与日期挤压）
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
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // 到访时间（轻量行，避免底部徽章拥挤）
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: tokens.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      formatCheckinDate(record.visitedAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        child: Icon(category.icon, size: 34, color: category.iconColor),
      );
    }
    return CheckinPhotoImage(url: url, tokens: tokens, width: 92, height: 92);
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


