import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/feedback/lumira_toast.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/points_recharge.dart';

/// 积分充值页
///
/// 充值为人工客服流程（不接入支付 SDK）：
/// 1. 复制客服微信号 → 微信搜索添加
/// 2. 发送「账号ID + 想充的档位」，客服核实后手动发放积分
/// 3. 到账后可在「积分流水」中查看（来源：后台发放）
///
/// 视觉遵循 4 风格 × 8 主题：LumiraNav + GlassBackground + NeuCard，
/// 所有颜色从 appThemeProvider 派生，不硬编码。
class PointsRechargePage extends ConsumerStatefulWidget {
  const PointsRechargePage({super.key});

  @override
  ConsumerState<PointsRechargePage> createState() => _PointsRechargePageState();
}

class _PointsRechargePageState extends ConsumerState<PointsRechargePage> {
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

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) LumiraToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final deviceId = ref.watch(authControllerProvider).deviceId;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '积分充值',
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
                  _StepsCard(
                    tokens: tokens,
                    deviceId: deviceId,
                    onCopyWechat: () => _copy(kRechargeWechat, '微信号已复制'),
                    onCopyAccountId: () {
                      final id = deviceId ?? '';
                      if (id.isEmpty) {
                        LumiraToast.show(context, '账号ID暂不可用，请稍后再试');
                        return;
                      }
                      _copy(id, '账号ID已复制');
                    },
                  ),
                  const SizedBox(height: 16),
                  _TiersCard(tokens: tokens),
                  const SizedBox(height: 16),
                  _NotesCard(tokens: tokens),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片统一外壳：图标 + 标题 + 内容
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.children,
  });
  final ThemeTokens tokens;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// 充值步骤卡：复制微信号 → 微信添加客服 → 发送账号ID + 档位
class _StepsCard extends StatelessWidget {
  const _StepsCard({
    required this.tokens,
    required this.deviceId,
    required this.onCopyWechat,
    required this.onCopyAccountId,
  });
  final ThemeTokens tokens;
  final String? deviceId;
  final VoidCallback onCopyWechat;
  final VoidCallback onCopyAccountId;

  @override
  Widget build(BuildContext context) {
    // Dart 2.19.6 不支持 records，用轻量私有类承载步骤文案
    const steps = [
      _StepData('复制客服微信号', '微信搜索并添加客服，说明要充值积分'),
      _StepData('发送账号ID + 档位', '告诉客服你的账号ID和想充的档位'),
      _StepData('客服核实后到账', '充值成功，积分自动发放到你的账号'),
    ];
    return _SectionCard(
      tokens: tokens,
      icon: Icons.rocket_launch_outlined,
      title: '充值步骤',
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _StepRow(tokens: tokens, index: i + 1, text: steps[i].title),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              steps[i].desc,
              style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _CopyRow(
          tokens: tokens,
          label: '客服微信号',
          value: kRechargeWechat,
          onCopy: onCopyWechat,
        ),
        const SizedBox(height: 8),
        _CopyRow(
          tokens: tokens,
          label: '账号ID',
          value: deviceId == null || deviceId!.isEmpty ? '未获取到' : deviceId!,
          onCopy: onCopyAccountId,
        ),
      ],
    );
  }
}

/// 步骤文案数据（避免 Dart 2.19.6 不支持 records 语法）
class _StepData {
  final String title;
  final String desc;

  const _StepData(this.title, this.desc);
}

/// 带序号圆点的单行步骤
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.tokens,
    required this.index,
    required this.text,
  });
  final ThemeTokens tokens;
  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.brand,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 可复制的信息行（微信号 / 账号ID）
class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.tokens,
    required this.label,
    required this.value,
    required this.onCopy,
  });
  final ThemeTokens tokens;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(Icons.copy_outlined, size: 15, color: tokens.brand),
                  const SizedBox(width: 2),
                  Text(
                    '复制',
                    style: TextStyle(fontSize: 12, color: tokens.brand),
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

/// 充值档位卡：金额 → 积分（多充多送）
class _TiersCard extends StatelessWidget {
  const _TiersCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      tokens: tokens,
      icon: Icons.currency_yen,
      title: '充值档位',
      children: [
        Text(
          '1 元 = 100 积分，充得越多送得越多',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < kRechargeTiers.length; i++) ...[
          if (i > 0) Divider(height: 1, color: tokens.divider),
          _TierRow(tokens: tokens, tier: kRechargeTiers[i]),
        ],
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tokens, required this.tier});
  final ThemeTokens tokens;
  final RechargeTier tier;

  @override
  Widget build(BuildContext context) {
    final bonus = rechargeBonusLabel(tier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tier.bonusPoints > 0 ? tokens.brandSubtle : tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '¥${tier.amount}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tier.bonusPoints > 0 ? tokens.brand : tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tier.totalPoints} 积分',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier.bonusPoints > 0
                      ? '基础 ${tier.basePoints} + 赠送 ${tier.bonusPoints}'
                      : '标准 1:100',
                  style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          if (bonus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                bonus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.brand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 充值须知卡
class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final notes = [
      '充值为人工客服处理，核实后 1 个工作日内到账',
      '充值前请确认账号ID与所选档位，避免积分发错账号',
      '到账后可在「积分流水」中查看（来源：后台发放）',
      '如有疑问，可直接在微信中咨询充值客服',
    ];
    return _SectionCard(
      tokens: tokens,
      icon: Icons.info_outline,
      title: '充值须知',
      children: [
        for (var i = 0; i < notes.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
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
                  notes[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
