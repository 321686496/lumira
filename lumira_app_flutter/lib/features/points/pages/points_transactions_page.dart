import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/points_models.dart';
import '../data/points_repository.dart';
import '../widgets/point_transaction_tile.dart';

/// 积分明细页：展示当前设备全部积分流水，支持按获取/花费筛选、时间/额度排序、来源搜索。
///
/// 顶部汇总卡（当前余额 / 累计获取 / 累计消耗）+ 流水的筛选/搜索控制栏，下方全量流水。
/// 数据一次性全量拉取后在前端筛选/排序/搜索，保证与分页无关、中文来源可搜。
class PointsTransactionsPage extends ConsumerStatefulWidget {
  const PointsTransactionsPage({super.key});

  @override
  ConsumerState<PointsTransactionsPage> createState() =>
      _PointsTransactionsPageState();
}

class _PointsTransactionsPageState
    extends ConsumerState<PointsTransactionsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  /// 搜索输入控制器（用于重置时清空输入框内容）
  final TextEditingController _searchController = TextEditingController();

  List<PointTransaction> _all = [];
  bool _loading = false;
  String? _error;
  bool _loaded = false;

  /// 类型筛选：all（全部）/ earn（获取）/ spend（花费）
  String _typeFilter = 'all';

  /// 排序：time（时间最新在前）/ amount（额度从高到低）
  String _sort = 'time';

  /// 来源搜索（中文/源码均可匹配）
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > 12.0;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  Future<void> _loadAll() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = await ref.read(pointsRepositoryProvider.future);
      const pageSize = 200;
      final all = <PointTransaction>[];
      var offset = 0;
      while (true) {
        final data =
            await repo.listTransactions(limit: pageSize, offset: offset);
        all.addAll(data.transactions);
        if (all.length >= data.total || data.transactions.isEmpty) break;
        offset += pageSize;
      }
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(pointsBalanceProvider);
    await _loadAll();
  }

  /// 全量流水经过筛选 + 搜索 + 排序后的可见列表
  List<PointTransaction> get _visible {
    var list = _all;
    final query = _query.trim().toLowerCase();
    if (_typeFilter == 'earn') {
      list = list.where((t) => t.delta > 0).toList();
    } else if (_typeFilter == 'spend') {
      list = list.where((t) => t.delta < 0).toList();
    }
    if (query.isNotEmpty) {
      list = list
          .where((t) =>
              pointSourceLabel(t.source).toLowerCase().contains(query) ||
              t.source.toLowerCase().contains(query))
          .toList();
    }
    final sorted = [...list];
    if (_sort == 'amount') {
      sorted.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final balanceAsync = ref.watch(pointsBalanceProvider);
    final visible = _visible;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '积分明细',
        transparent: true,
        scrolled: _scrolled,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.standard),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: visible.length + 1,
                itemBuilder: (context, index) {
                  // 第 0 项：汇总卡 + 控制栏 + 列表标题
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(
                          tokens: tokens,
                          balanceAsync: balanceAsync,
                          totalCount: _all.isEmpty ? null : _all.length,
                        ),
                        const SizedBox(height: 12),
                        _FilterBar(
                          controller: _searchController,
                          typeFilter: _typeFilter,
                          sort: _sort,
                          query: _query,
                          onTypeChanged: (v) =>
                              setState(() => _typeFilter = v),
                          onSortChanged: (v) => setState(() => _sort = v),
                          onQueryChanged: (v) => setState(() => _query = v),
                          onClear: () {
                            setState(() {
                              _typeFilter = 'all';
                              _sort = 'time';
                              _query = '';
                              _searchController.clear();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _ListHeader(
                          tokens: tokens,
                          shownCount: visible.length,
                          totalCount: _all.length,
                        ),
                        const SizedBox(height: 4),
                        if (!_loaded && _error == null)
                          _BuildLoading(tokens: tokens)
                        else if (_error != null)
                          _BuildError(tokens: tokens, state: this)
                        else if (visible.isEmpty)
                          _BuildEmpty(tokens: tokens, state: this),
                      ],
                    );
                  }
                  final i = index - 1;
                  final tx = visible[i];
                  return Column(
                    children: [
                      if (i > 0) Divider(height: 1, color: tokens.divider),
                      PointTransactionTile(tokens: tokens, tx: tx),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 汇总卡：当前余额 + 累计获取 / 累计消耗
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tokens,
    required this.balanceAsync,
    this.totalCount,
  });

  final ThemeTokens tokens;
  final AsyncValue<PointsBalance> balanceAsync;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '当前余额',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              const Spacer(),
              if (totalCount != null)
                Text(
                  '共 $totalCount 笔',
                  style: TextStyle(
                      fontSize: 12, color: tokens.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          balanceAsync.when(
            loading: () => Text(
              '--',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: tokens.brand,
                height: 1,
              ),
            ),
            error: (_, __) => Text(
              '--',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: tokens.brand,
                height: 1,
              ),
            ),
            data: (balance) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${balance.balance}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: tokens.brand,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatColumn(
                            tokens: tokens,
                            label: '累计获取',
                            value: balance.totalEarned,
                            color: tokens.success,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: tokens.divider,
                        ),
                        Expanded(
                          child: _StatColumn(
                            tokens: tokens,
                            label: '累计消耗',
                            value: balance.totalSpent,
                            color: tokens.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.tokens,
    required this.label,
    required this.value,
    required this.color,
  });
  final ThemeTokens tokens;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 筛选 + 搜索 + 排序控制栏
///
/// 复用 [LumiraTextField] 与 [LumiraFilterChip]，自动跟随 4 风格 × 8 主题，
/// 避免手工写死颜色/边框导致新拟态等内容下样式错乱。
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.typeFilter,
    required this.sort,
    required this.query,
    required this.onTypeChanged,
    required this.onSortChanged,
    required this.onQueryChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String typeFilter;
  final String sort;
  final String query;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

  bool get _hasFilter =>
      typeFilter != 'all' || sort != 'time' || query.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 搜索框（LumiraTextField 自带各风格容器/凹陷阴影/聚焦态）
        LumiraTextField(
          controller: controller,
          hintText: '搜索来源，如“签到 / 解锁”',
          prefixIcon: Consumer(
            builder: (context, ref, _) {
              final t = ref.watch(themeTokensProvider);
              return Icon(Icons.search, size: 18, color: t.textTertiary);
            },
          ),
          onChanged: onQueryChanged,
          suffixIcon: query.isNotEmpty
              ? Consumer(
                  builder: (context, ref, _) {
                    final t = ref.watch(themeTokensProvider);
                    return GestureDetector(
                      onTap: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      child: Icon(Icons.close,
                          size: 16, color: t.textTertiary),
                    );
                  },
                )
              : null,
        ),
        const SizedBox(height: 12),
        // 类型筛选（全部 / 获取 / 花费）
        Row(
          children: [
            _chip(typeFilter == 'all', '全部', () => onTypeChanged('all')),
            const SizedBox(width: 8),
            _chip(typeFilter == 'earn', '获取', () => onTypeChanged('earn')),
            const SizedBox(width: 8),
            _chip(typeFilter == 'spend', '花费',
                () => onTypeChanged('spend')),
          ],
        ),
        const SizedBox(height: 10),
        // 排序 + 重置
        Row(
          children: [
            _chip(sort == 'time', '时间排序', () => onSortChanged('time')),
            const SizedBox(width: 8),
            _chip(sort == 'amount', '额度排序', () => onSortChanged('amount')),
            const Spacer(),
            if (_hasFilter) _chip(false, '重置', onClear),
          ],
        ),
      ],
    );
  }

  Widget _chip(bool active, String label, VoidCallback onTap) {
    return LumiraFilterChip(
      label: label,
      active: active,
      onTap: onTap,
    );
  }
}

/// 列表标题行
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.tokens,
    required this.shownCount,
    required this.totalCount,
  });

  final ThemeTokens tokens;
  final int shownCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final hasFilter = shownCount != totalCount;
    return Row(
      children: [
        Icon(Icons.receipt_long_outlined, size: 18, color: tokens.brand),
        const SizedBox(width: 8),
        Text(
          '积分流水',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          hasFilter ? '筛选出 $shownCount 条 / 共 $totalCount 条' : '全部流水',
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _BuildLoading extends StatelessWidget {
  const _BuildLoading({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: LumiraProgress.circular(strokeWidth: 2),
      ),
    );
  }
}

class _BuildError extends StatelessWidget {
  const _BuildError({required this.tokens, required this.state});
  final ThemeTokens tokens;
  final _PointsTransactionsPageState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 28, color: tokens.danger),
            const SizedBox(height: 8),
            Text(
              '加载失败：${state._error}',
              style: TextStyle(fontSize: 13, color: tokens.textTertiary),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: state._loadAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '重新加载',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: tokens.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildEmpty extends StatelessWidget {
  const _BuildEmpty({required this.tokens, required this.state});
  final ThemeTokens tokens;
  final _PointsTransactionsPageState state;

  @override
  Widget build(BuildContext context) {
    final msg = state._all.isEmpty ? '暂无积分流水' : '没有符合筛选条件的流水';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(fontSize: 13, color: tokens.textTertiary),
        ),
      ),
    );
  }
}