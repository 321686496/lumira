import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show ButtonVariant, LumiraButton, LumiraTextField;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/redeem_models.dart';
import '../data/redeem_repository.dart';

/// 兑换码页
///
/// UI 重写：接入 ThemeTokens + LumiraNav + GlassBackground + NeuCard + LumiraButton + FadeUp。
/// 数据层（redeemRepositoryProvider / RedeemCodeRequest）保持不变。
class RedeemPage extends ConsumerStatefulWidget {
  const RedeemPage({super.key});

  @override
  ConsumerState<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends ConsumerState<RedeemPage> {
  final _codeCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
    _codeCtrl.dispose();
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

  Future<void> _onSubmit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    final tokens = ref.read(themeTokensProvider);
    setState(() => _submitting = true);
    try {
      final repo = await ref.read(redeemRepositoryProvider.future);
      final resp = await repo.redeem(RedeemCodeRequest(code: code));
      if (mounted) {
        _showThemedSnackBar(
          tokens,
          '已兑换：${resp.campaignName}（${resp.rewardItems.length} 项奖励）',
          isSuccess: true,
        );
        _codeCtrl.clear();
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showThemedSnackBar(tokens, '兑换失败：${e.message}');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                  FadeUp(
                    child: _CodeCard(
                      tokens: tokens,
                      controller: _codeCtrl,
                      submitting: _submitting,
                      onSubmit: _onSubmit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeUp(
                    delay: const Duration(milliseconds: 100),
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

/// 输入兑换码卡：NeuCard + TextField + 全宽 LumiraButton.brand
class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.tokens,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });
  final ThemeTokens tokens;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

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
          ),
          const SizedBox(height: 14),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: submitting ? null : onSubmit,
            child: Text(submitting ? '兑换中...' : '立即兑换'),
          ),
        ],
      ),
    );
  }
}

/// 兑换说明卡：列出规则
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.tokens});
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
