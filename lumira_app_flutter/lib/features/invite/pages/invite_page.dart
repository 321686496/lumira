import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show ButtonVariant, LumiraButton;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/invite_repository.dart';

/// 邀请码页
///
/// 3 个 section：
/// 1. InviteCodeCard（邀请码大字号 + 复制按钮，调 POST /invite/generate）
/// 2. StatsCard（总邀请数 / 每次奖励积分 / 累计获得 / 当前余额）
/// 3. RulesCard（邀请规则说明）
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  String? _inviteCode;
  bool _loadingCode = false;

  static const double _scrollThreshold = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInviteCode();
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

  Future<void> _loadInviteCode() async {
    if (_loadingCode) return;
    setState(() => _loadingCode = true);
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final result = await repo.generate();
      if (!mounted) return;
      setState(() => _inviteCode = result.code);
    } on ApiException catch (_) {
      // 静默失败，UI 显示重试按钮
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _onCopy() async {
    final code = _inviteCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    final tokens = ref.read(themeTokensProvider);
    _showSnack(tokens, '邀请码已复制', isSuccess: true);
  }

  void _showSnack(
    ThemeTokens tokens,
    String message, {
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.info_outline,
              size: 18,
              color: isSuccess ? tokens.success : tokens.danger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: tokens.surface,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final statsAsync = ref.watch(invitePointsRepositoryProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '邀请有礼',
        transparent: true,
        scrolled: _scrolled,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.standard),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeUp(
                    child: _InviteCodeCard(
                      tokens: tokens,
                      code: _inviteCode,
                      loading: _loadingCode,
                      onCopy: _onCopy,
                      onRetry: _loadInviteCode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeUp(
                    delay: const Duration(milliseconds: 80),
                    child: _StatsCard(
                      tokens: tokens,
                      asyncValue: statsAsync,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeUp(
                    delay: const Duration(milliseconds: 160),
                    child: _RulesCard(tokens: tokens),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 邀请码卡
class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.tokens,
    required this.code,
    required this.loading,
    required this.onCopy,
    required this.onRetry,
  });
  final ThemeTokens tokens;
  final String? code;
  final bool loading;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '我的邀请码',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: tokens.brandSubtle.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.brand.withOpacity(0.3)),
            ),
            child: _CodeContent(
              tokens: tokens,
              code: code,
              loading: loading,
              onRetry: onRetry,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '将邀请码分享给好友，好友首次激活后双方均可获得积分奖励',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: (code == null || code!.isEmpty) ? null : onCopy,
              child: const Text('复制邀请码'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeContent extends StatelessWidget {
  const _CodeContent({
    required this.tokens,
    required this.code,
    required this.loading,
    required this.onRetry,
  });
  final ThemeTokens tokens;
  final String? code;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.brand,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '生成中...',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
        ],
      );
    }
    final c = code;
    if (c == null || c.isEmpty) {
      return GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh, size: 14, color: tokens.brand),
            const SizedBox(width: 6),
            Text(
              '获取失败，点击重试',
              style: TextStyle(fontSize: 14, color: tokens.brand),
            ),
          ],
        ),
      );
    }
    return Text(
      c,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: tokens.brandDeep,
      ),
    );
  }
}

/// 邀请统计卡
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.tokens, required this.asyncValue});
  final ThemeTokens tokens;
  final AsyncValue<InvitePointsRepository> asyncValue;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: asyncValue.when(
        loading: () => _StatsSkeleton(tokens: tokens),
        error: (e, _) => _StatsError(
          tokens: tokens,
          msg: e is ApiException ? e.message : '加载失败',
        ),
        data: (repo) {
          return FutureBuilder<InvitePointsStats>(
            future: repo.pointsStats(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return _StatsSkeleton(tokens: tokens);
              }
              if (snap.hasError) {
                return _StatsError(
                  tokens: tokens,
                  msg: snap.error is ApiException
                      ? (snap.error as ApiException).message
                      : '加载失败',
                );
              }
              final stats = snap.data!;
              return _StatsBody(tokens: tokens, stats: stats);
            },
          );
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.tokens, required this.stats});
  final ThemeTokens tokens;
  final InvitePointsStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Text(
              '邀请统计',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                tokens: tokens,
                label: '已邀请',
                value: '${stats.totalInvites}',
                unit: '人',
              ),
            ),
            Container(width: 1, height: 40, color: tokens.divider),
            Expanded(
              child: _StatCell(
                tokens: tokens,
                label: '每次奖励',
                value: '${stats.rewardPointsPerInvite}',
                unit: '积分',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: tokens.divider),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCell(
                tokens: tokens,
                label: '累计获得',
                value: '${stats.totalEarnedFromInvite}',
                unit: '积分',
              ),
            ),
            Container(width: 1, height: 40, color: tokens.divider),
            Expanded(
              child: _StatCell(
                tokens: tokens,
                label: '当前余额',
                value: '${stats.currentBalance}',
                unit: '积分',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.tokens,
    required this.label,
    required this.value,
    required this.unit,
  });
  final ThemeTokens tokens;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.brand,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(fontSize: 11, color: tokens.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 80, height: 16, color: tokens.surfaceAlt),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(height: 50, color: tokens.surfaceAlt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 50, color: tokens.surfaceAlt),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.tokens, required this.msg});
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
            '统计加载失败：$msg',
            style: TextStyle(fontSize: 13, color: tokens.danger),
          ),
        ),
      ],
    );
  }
}

/// 规则说明卡
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final rules = <String>[
      '好友通过你的邀请码首次激活，双方各得积分奖励',
      '仅新设备首次使用时可绑定邀请码，激活后即绑定邀请关系',
      '邀请奖励积分将自动计入积分余额，可在「我的积分」查看',
      '禁止恶意刷邀请行为，一经发现将回收奖励并封禁账号',
    ];
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '活动规则',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rules.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rules[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (i < rules.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
