import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../sign_in/data/sign_in_repository.dart';
import '../data/points_models.dart';
import '../data/points_repository.dart';
import '../widgets/point_transaction_tile.dart';
import '../widgets/points_earn_ways.dart';

/// 积分钱包页
///
/// 4 个 section：
/// 1. BalanceCard（当前积分余额大字号 + 累计获得 / 累计消耗）
/// 2. SignInCard（自动签到状态 + 连签天数）
/// 3. InviteEntry（邀请有礼入口卡片）
/// 4. TransactionsList（积分流水列表，按时间倒序）
class PointsWalletPage extends ConsumerStatefulWidget {
  const PointsWalletPage({super.key});

  @override
  ConsumerState<PointsWalletPage> createState() => _PointsWalletPageState();
}

class _PointsWalletPageState extends ConsumerState<PointsWalletPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  static const double _scrollThreshold = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > _scrollThreshold;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(pointsRepositoryProvider);
    ref.invalidate(signInRepositoryProvider);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final balanceAsync = ref.watch(pointsBalanceProvider);
    final signInAsync = ref.watch(signInStatusProvider);
    final txAsync = ref.watch(pointsRecentTransactionsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的积分',
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
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeUp(
                      child: _BalanceCard(
                        tokens: tokens,
                        balanceAsync: balanceAsync,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeUp(
                      delay: const Duration(milliseconds: 80),
                      child: _SignInCard(
                        tokens: tokens,
                        statusAsync: signInAsync,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeUp(
                      delay: const Duration(milliseconds: 160),
                      child: _InviteEntryCard(
                        tokens: tokens,
                        onTap: () =>
                            GoRouter.of(context).push(RouteNames.invite),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeUp(
                      delay: const Duration(milliseconds: 200),
                      child: _EarnWaysCard(tokens: tokens),
                    ),
                    const SizedBox(height: 16),
                    FadeUp(
                      delay: const Duration(milliseconds: 240),
                      child: _TransactionsCard(
                        tokens: tokens,
                        txAsync: txAsync,
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

/// 余额卡：大字号显示当前余额 + 累计获得 / 累计消耗
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.tokens, required this.balanceAsync});
  final ThemeTokens tokens;
  final AsyncValue<PointsBalance> balanceAsync;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: balanceAsync.when(
        loading: () => _BalanceSkeleton(tokens: tokens),
        error: (e, _) => _BalanceError(
          tokens: tokens,
          msg: e is ApiException ? e.message : '加载失败',
        ),
        data: (balance) => _BalanceBody(tokens: tokens, balance: balance),
      ),
    );
  }
}

class _BalanceBody extends StatelessWidget {
  const _BalanceBody({required this.tokens, required this.balance});
  final ThemeTokens tokens;
  final PointsBalance balance;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${balance.balance}',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: tokens.brand,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '积分',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatColumn(
                  tokens: tokens,
                  label: '累计获得',
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
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: balance.freeUnlockCount > 0
                ? tokens.brandSubtle
                : tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_open_outlined,
                size: 16,
                color:
                    balance.freeUnlockCount > 0 ? tokens.brand : tokens.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  balance.freeUnlockCount > 0
                      ? '免费解锁 ×${balance.freeUnlockCount}：可在解锁页任选付费模板，不消耗积分'
                      : '免费解锁 ×0：邀请好友可获取免费解锁次数',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: balance.freeUnlockCount > 0
                        ? tokens.textPrimary
                        : tokens.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 14,
          color: tokens.surfaceAlt,
        ),
        const SizedBox(height: 14),
        Container(
          width: 120,
          height: 40,
          color: tokens.surfaceAlt,
        ),
        const SizedBox(height: 24),
        Container(
          height: 56,
          color: tokens.surfaceAlt,
        ),
      ],
    );
  }
}

class _BalanceError extends StatelessWidget {
  const _BalanceError({required this.tokens, required this.msg});
  final ThemeTokens tokens;
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: tokens.danger),
        const SizedBox(width: 6),
        Text(msg, style: TextStyle(fontSize: 13, color: tokens.danger)),
      ],
    );
  }
}

/// 签到卡：连签天数 + 自动签到状态
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.tokens, required this.statusAsync});
  final ThemeTokens tokens;
  final AsyncValue<SignInStatus> statusAsync;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: statusAsync.when(
        loading: () => _RowSkeleton(tokens: tokens),
        error: (e, _) => _SignInError(
          tokens: tokens,
          msg: e is ApiException ? e.message : '加载失败',
        ),
        data: (status) => _SignInRow(tokens: tokens, status: status),
      ),
    );
  }
}

class _SignInRow extends StatelessWidget {
  const _SignInRow({required this.tokens, required this.status});
  final ThemeTokens tokens;
  final SignInStatus status;

  @override
  Widget build(BuildContext context) {
    final signedToday = status.signedToday;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.calendar_today_outlined,
              size: 20, color: tokens.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '每日签到',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                signedToday
                    ? '今日已自动签到（当日首拍）'
                    : '今日未拍摄，拍摄后自动签到',
                style: TextStyle(
                  fontSize: 12,
                  color: signedToday ? tokens.success : tokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '连签 ${status.consecutiveDays} 天',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tokens.brand,
          ),
        ),
      ],
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          color: tokens.surfaceAlt,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 80, height: 14, color: tokens.surfaceAlt),
              const SizedBox(height: 6),
              Container(width: 140, height: 11, color: tokens.surfaceAlt),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignInError extends StatelessWidget {
  const _SignInError({required this.tokens, required this.msg});
  final ThemeTokens tokens;
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: tokens.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '签到状态加载失败：$msg',
            style: TextStyle(fontSize: 13, color: tokens.danger),
          ),
        ),
      ],
    );
  }
}

/// 邀请有礼入口卡
class _InviteEntryCard extends StatelessWidget {
  const _InviteEntryCard({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.card_giftcard,
                  size: 20, color: tokens.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '邀请有礼',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '邀请好友注册，双方各得积分',
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// 获取积分途径提示卡：展示签到/每日首拍/完成挑战等积分来源
class _EarnWaysCard extends StatelessWidget {
  const _EarnWaysCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '获取积分',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // stacked：标题 + 说明上下排布，避免「每日签到」等长文案在右侧被挤压换行/变形
          PointsEarnWaysList(tokens: tokens, stacked: true),
        ],
      ),
    );
  }
}

/// 积分流水卡
class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.tokens, required this.txAsync});
  final ThemeTokens tokens;
  final AsyncValue<PointsTransactions> txAsync;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: tokens.brand),
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
              GestureDetector(
                onTap: () => GoRouter.of(context)
                    .push(RouteNames.pointsTransactions),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: tokens.textTertiary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          txAsync.when(
            loading: () => _TxSkeleton(tokens: tokens),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '加载失败：${e is ApiException ? e.message : '未知错误'}',
                style: TextStyle(fontSize: 13, color: tokens.danger),
              ),
            ),
            data: (data) {
              final list = data.transactions;
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '暂无积分流水',
                      style: TextStyle(
                          fontSize: 13, color: tokens.textTertiary),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: tokens.divider),
                    PointTransactionTile(
                      tokens: tokens,
                      tx: list[i],
                    ),
                    if (i < list.length - 1) const SizedBox(height: 4),
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

class _TxSkeleton extends StatelessWidget {
  const _TxSkeleton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                color: tokens.surfaceAlt,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 12, color: tokens.surfaceAlt),
                    const SizedBox(height: 6),
                    Container(width: 140, height: 10, color: tokens.surfaceAlt),
                  ],
                ),
              ),
              Container(width: 40, height: 14, color: tokens.surfaceAlt),
            ],
          ),
        );
      }),
    );
  }
}
