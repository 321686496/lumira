import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/templates/widgets/template_import_sheet.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 分享码 / 邀请码 兑换入口页
///
/// 视觉规格来源：superpowers/specs/2026-07-29-flutter-app-polish-design.md 第 3 块
/// 4 个 section：
/// 1. 输入区（TextField + 导入按钮 + 打开模板导入二级按钮）
/// 2. 能获得的奖励说明（4 项列表）
/// 3. 使用规则（4 项列表）
/// 4. 获取更多分享码（文案 + 邀请好友按钮）
///
/// Section 4（最近兑换记录）按设计文档可选：redeem_repository 当前仅提供 redeem
/// 提交接口、无历史查询方法，故跳过。
class ProfileShareCodePage extends ConsumerStatefulWidget {
  const ProfileShareCodePage({super.key});

  @override
  ConsumerState<ProfileShareCodePage> createState() =>
      _ProfileShareCodePageState();
}

class _ProfileShareCodePageState extends ConsumerState<ProfileShareCodePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _codeController = TextEditingController();
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
    final offset = _scrollController.offset;
    final newScrolled = offset > _scrollThreshold;
    if (newScrolled != _scrolled) {
      setState(() => _scrolled = newScrolled);
    }
  }

  /// 校验分享码格式：必须以 LUMIRA- 开头，至少 3 段（LUMIRA / 分类 / 名称），
  /// 分类与名称非空。
  ///
  /// 与 template_import_sheet.dart 中 _parseTemplateCode 的格式约束保持一致
  /// （该方法为 ConsumerWidget 私有方法，不便直接提取，按 spec fallback 在此复制校验）。
  bool _isValidShareCode(String code) {
    if (!code.startsWith('LUMIRA-')) return false;
    final parts = code.split('-');
    if (parts.length < 3) return false;
    if (parts[1].isEmpty || parts[2].isEmpty) return false;
    return true;
  }

  void _handleImport() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      LumiraToast.show(context, '请输入分享码', duration: const Duration(milliseconds: 1200));
      return;
    }
    if (_isValidShareCode(code)) {
      LumiraToast.show(context, '分享码已识别：$code，请前往模板导入页完成导入', duration: const Duration(milliseconds: 1800));
    } else {
      LumiraToast.show(context, '分享码格式无效', duration: const Duration(milliseconds: 1200));
    }
  }

  void _openTemplateImport() {
    TemplateImportSheet.show(context, onImported: (_) {});
  }

  void _goInvite() {
    GoRouter.of(context).push(RouteNames.profileInvite);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '分享码',
        transparent: true,
        scrolled: _scrolled,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          // glass 风格彩色斑点背景（其他风格 SizedBox.shrink）
          const Positioned.fill(child: GlassBackground()),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: 输入区
                  FadeUp(
                    child: _InputSection(
                      tokens: tokens,
                      controller: _codeController,
                      onImport: _handleImport,
                      onOpenTemplateImport: _openTemplateImport,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Section 2: 能获得的奖励说明
                  FadeUp(
                    delay: const Duration(milliseconds: 100),
                    child: _RewardSection(tokens: tokens),
                  ),
                  const SizedBox(height: 20),
                  // Section 3: 使用规则
                  FadeUp(
                    delay: const Duration(milliseconds: 200),
                    child: _RulesSection(tokens: tokens),
                  ),
                  const SizedBox(height: 20),
                  // Section 4: 获取更多分享码
                  FadeUp(
                    delay: const Duration(milliseconds: 300),
                    child: _MoreCodesSection(
                      tokens: tokens,
                      onInvite: _goInvite,
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

/// Section 1：输入分享码 / 邀请码
class _InputSection extends StatelessWidget {
  const _InputSection({
    required this.tokens,
    required this.controller,
    required this.onImport,
    required this.onOpenTemplateImport,
  });

  final ThemeTokens tokens;
  final TextEditingController controller;
  final VoidCallback onImport;
  final VoidCallback onOpenTemplateImport;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入分享码 / 邀请码',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LumiraTextField(
            controller: controller,
            hintText: 'LUMIRA-{category}-{name}',
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: onImport,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.download_outlined, size: 18),
                SizedBox(width: 8),
                Text('导入'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 二级入口：跳转到模板导入面板（保留原 sheet 流程）
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onOpenTemplateImport,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '打开模板导入',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.brand,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: tokens.brand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 2：能获得的奖励说明
class _RewardSection extends StatelessWidget {
  const _RewardSection({required this.tokens});

  final ThemeTokens tokens;

  static const _items = <_RewardItem>[
    _RewardItem(
      icon: Icons.collections_bookmark_outlined,
      text: '解锁对应分类的精选模板（限免 7 天）',
    ),
    _RewardItem(
      icon: Icons.stars_outlined,
      text: '获得 50 积分（可兑换其他模板）',
    ),
    _RewardItem(
      icon: Icons.school_outlined,
      text: '解锁场景拍摄指导',
    ),
    _RewardItem(
      icon: Icons.flash_on_outlined,
      text: '优先体验新功能',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入分享码能获得什么',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < _items.length; i++)
                _RewardRow(
                  item: _items[i],
                  isLast: i == _items.length - 1,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardItem {
  const _RewardItem({required this.icon, required this.text});
  final IconData icon;
  final String text;
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.item,
    required this.isLast,
    required this.tokens,
  });

  final _RewardItem item;
  final bool isLast;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: tokens.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.text,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 3：使用规则
class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.tokens});

  final ThemeTokens tokens;

  static const _rules = <String>[
    '每个分享码只能使用一次',
    '分享码有效期 30 天',
    '同一分类分享码不能重复使用',
    '奖励将在导入后自动入账',
  ];

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用规则',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < _rules.length; i++)
                _RuleRow(
                  text: _rules[i],
                  isLast: i == _rules.length - 1,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.text,
    required this.isLast,
    required this.tokens,
  });

  final String text;
  final bool isLast;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: 0.5),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.check_circle_outline,
              size: 14,
              color: tokens.brand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 4：获取更多分享码
class _MoreCodesSection extends StatelessWidget {
  const _MoreCodesSection({required this.tokens, required this.onInvite});

  final ThemeTokens tokens;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '获取更多分享码',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '关注官方账号 / 邀请好友 / 完成挑战任务可获得更多分享码',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: onInvite,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.person_add_outlined, size: 18),
                SizedBox(width: 8),
                Text('邀请好友'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
