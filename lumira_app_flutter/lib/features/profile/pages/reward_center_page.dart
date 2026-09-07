import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/redeem/data/redeem_models.dart';
import '../../../features/redeem/data/redeem_repository.dart';
import '../../home/widgets/scan_qr_page.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show ButtonVariant, LumiraButton, LumiraTextField, LumiraToast;
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 兑换码聚合页
///
/// 首页右上角礼盒入口。取代原「分享码」页（内容过期且与扫一扫重叠），
/// 收敛为三块能力：
/// 1. 兑换码：输入/扫码后真正调用后台兑换，兑现积分与模板
/// 2. 我的奖励：跳转 [RewardsPage]（profileRewards）
/// 3. 邀请有礼：跳转 [ProfileInvitePage]（profileInvite）
class RewardCenterPage extends ConsumerStatefulWidget {
  const RewardCenterPage({super.key});

  @override
  ConsumerState<RewardCenterPage> createState() => _RewardCenterPageState();
}

class _RewardCenterPageState extends ConsumerState<RewardCenterPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;
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
    _codeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final newScrolled = _scrollController.offset > _scrollThreshold;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  /// 立即兑换：调用后台兑换接口，兑现积分/模板并提示余额。
  Future<void> _onRedeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      LumiraToast.show(context, '请输入兑换码', duration: const Duration(milliseconds: 1200));
      return;
    }
    final tokens = ref.read(themeTokensProvider);
    setState(() => _submitting = true);
    try {
      final repo = await ref.read(redeemRepositoryProvider.future);
      final resp = await repo.redeem(RedeemCodeRequest(code: code));
      if (!mounted) return;
      final parts = <String>[resp.campaignName];
      if (resp.rewardPoints > 0) {
        parts.add('获得 ${resp.rewardPoints} 积分');
      }
      if (resp.rewardTemplates.isNotEmpty) {
        final names = resp.rewardTemplates.map((t) => t.templateName).join('、');
        parts.add('解锁模板：$names');
      }
      parts.add('当前余额 ${resp.balance} 积分');
      _showThemedSnackBar(tokens, '已兑换：${parts.join('，')}', isSuccess: true);
      _codeController.clear();
    } on ApiException catch (e) {
      if (mounted) {
        _showThemedSnackBar(tokens, '兑换失败：${e.message}');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 扫码填入兑换码（不自动兑换，由用户点击「立即兑换」确认）
  Future<void> _onScanCode() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanQrPage()),
    );
    if (text != null && text.trim().isNotEmpty) {
      _codeController.text = text.trim();
    }
  }

  /// 主题化 SnackBar：tokens.surface 背景 + tokens.textPrimary 文字
  void _showThemedSnackBar(
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
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: tokens.surface,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _goRewards() => GoRouter.of(context).push(RouteNames.profileRewards);
  void _goInvite() => GoRouter.of(context).push(RouteNames.profileInvite);

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '兑换码',
        transparent: true,
        scrolled: _scrolled,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.standard),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: 兑换码
                  FadeUp(
                    child: _RedeemCard(
                      tokens: tokens,
                      controller: _codeController,
                      submitting: _submitting,
                      onRedeem: _onRedeem,
                      onScan: _onScanCode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Section 2: 兑换说明
                  FadeUp(
                    delay: const Duration(milliseconds: 100),
                    child: _RedeemRuleCard(tokens: tokens),
                  ),
                  const SizedBox(height: 16),
                  // Section 3: 我的奖励
                  FadeUp(
                    delay: const Duration(milliseconds: 200),
                    child: _EntryCard(
                      tokens: tokens,
                      icon: Icons.card_giftcard_outlined,
                      title: '我的奖励',
                      subtitle: '查看已获得的积分与模板奖励',
                      onTap: _goRewards,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Section 4: 邀请有礼
                  FadeUp(
                    delay: const Duration(milliseconds: 300),
                    child: _EntryCard(
                      tokens: tokens,
                      icon: Icons.person_add_outlined,
                      title: '邀请有礼',
                      subtitle: '邀请好友，双方获得积分奖励',
                      onTap: _goInvite,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 兑换码输入卡：NeuCard + TextField(带扫码) + 全宽 LumiraButton.brand
class _RedeemCard extends StatelessWidget {
  const _RedeemCard({
    required this.tokens,
    required this.controller,
    required this.submitting,
    required this.onRedeem,
    required this.onScan,
  });

  final ThemeTokens tokens;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onRedeem;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入兑换码',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '输入兑换码以领取专属奖励',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          LumiraTextField(
            controller: controller,
            hintText: '请输入兑换码...',
            suffixIcon: IconButton(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          LumiraButton(
            variant: ButtonVariant.primary,
            // 品牌 CTA：按压保持主色背景（新拟态下不切换为凹陷表面）
            keepBrandOnPress: true,
            onPressed: submitting ? null : onRedeem,
            child: Text(submitting ? '兑换中...' : '立即兑换'),
          ),
        ],
      ),
    );
  }
}

/// 兑换说明卡：列出规则
class _RedeemRuleCard extends StatelessWidget {
  const _RedeemRuleCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final rules = <String>[
      '每个兑换码只能使用一次，兑换后即作废',
      '兑换成功后奖励将自动入账，可在「我的奖励」查看',
      '部分兑换码设有有效期，请在有效期内使用',
      '若兑换码无效或已过期，请联系发放方重新获取',
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
                '兑换说明',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
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

/// 通用快捷入口卡：图标 + 标题 + 副标题 + 右箭头
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: tokens.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: tokens.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}