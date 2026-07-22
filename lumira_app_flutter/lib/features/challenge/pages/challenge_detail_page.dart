import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/challenge_models.dart';
import '../data/challenge_pool.dart';
import '../widgets/challenge_tag.dart';

/// Challenge 详情页
///
/// 视觉规格来源：lumira-app/src/pages/challenge/detail.vue
/// 5 个 section:
/// 1. LumiraNav（标题"挑战详情" + 左侧返回箭头）
/// 2. HeroCard（金色渐变背景 + badge + status + 标题 + 描述 + 奖励 + 进度条）
/// 3. 完成的作品（3:4 作品图 + 日期 + 标题 + tags）
/// 4. 挑战要求（3 个 req-item）
/// 5. 拍摄建议（3 个 tip-row，gold/green/red 三色）
/// 6. 底部操作（"返回挑战" outline + "再拍一张" brand）
class ChallengeDetailPage extends ConsumerStatefulWidget {
  const ChallengeDetailPage({super.key, this.challengeId});

  final String? challengeId;

  @override
  ConsumerState<ChallengeDetailPage> createState() =>
      _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends ConsumerState<ChallengeDetailPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  static const double _scrollThreshold = 10.0;

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

  void _back() {
    // Forced fix: canPop 保护，避免 pop 到空栈退出应用
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.challenge);
    }
  }

  void _goCapture() => GoRouter.of(context).push(RouteNames.capture);

  /// 从题库构建挑战详情
  ChallengeDetail? _buildDetailFromPool(String? challengeId) {
    if (challengeId == null) return null;
    final item = ChallengePool.byId(challengeId);
    if (item == null) return null;

    return ChallengeDetail(
      id: item.id,
      badge: ChallengeCategory.label(item.category),
      title: item.title,
      description: item.description,
      rewardXP: item.rewardXP,
      progressCurrent: 0,
      progressTotal: 1,
      status: ChallengeStatus.pending,
      requirements: [
        Requirement(
          index: 1,
          title: '完成主题拍摄',
          description: '根据挑战标题完成一张符合主题的照片',
          done: false,
        ),
        Requirement(
          index: 2,
          title: '应用拍摄技巧',
          description: item.tip,
          done: false,
        ),
        Requirement(
          index: 3,
          title: '保存到画廊',
          description: '将作品保存到画廊完成挑战',
          done: false,
        ),
      ],
      tips: [
        Tip(
          icon: Icons.tips_and_updates_outlined,
          iconColor: ChallengeTagColor.gold,
          title: '技巧提示',
          description: item.tip,
        ),
        Tip(
          icon: Icons.category_outlined,
          iconColor: ChallengeTagColor.green,
          title: '分类标签',
          description: '本挑战属于「${ChallengeCategory.label(item.category)}」分类',
        ),
        Tip(
          icon: Icons.emoji_events_outlined,
          iconColor: ChallengeTagColor.red,
          title: '奖励',
          description: '完成可获得 ${item.rewardXP} XP 经验值',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    final detail = _buildDetailFromPool(widget.challengeId);

    if (detail == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        body: SafeArea(
          child: Center(
            child: Text('挑战不存在', style: TextStyle(color: tokens.textSecondary)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                LumiraNav(
                  title: '挑战详情',
                  scrolled: _scrolled,
                  transparent: true,
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    children: [
                      FadeUp(
                        child: _HeroCard(detail: detail, tokens: tokens, style: style),
                      ),
                      const SizedBox(height: 24),
                      // 完成的作品
                      if (detail.completedWork != null) ...[
                        const _SectionTitle(text: '完成的作品'),
                        const SizedBox(height: 12),
                        FadeUp(
                          delay: const Duration(milliseconds: 80),
                          child: _WorkCard(work: detail.completedWork!, tokens: tokens, style: style),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // 挑战要求
                      const _SectionTitle(text: '挑战要求'),
                      const SizedBox(height: 12),
                      FadeUp(
                        delay: const Duration(milliseconds: 160),
                        child: NeuCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Column(
                            children: detail.requirements
                                .map((r) => _RequirementItem(
                                      requirement: r,
                                      tokens: tokens,
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 拍摄建议
                      const _SectionTitle(text: '拍摄建议'),
                      const SizedBox(height: 12),
                      FadeUp(
                        delay: const Duration(milliseconds: 240),
                        child: NeuCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Column(
                            children: detail.tips
                                .map((t) => _TipRow(tip: t, tokens: tokens))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // 底部操作
                      FadeUp(
                        delay: const Duration(milliseconds: 320),
                        child: Row(
                          children: [
                            Expanded(
                              child: LumiraButton(
                                label: '返回挑战',
                                onPressed: _back,
                                variant: LumiraButtonVariant.outline,
                                icon: Icons.arrow_back,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LumiraButton(
                                label: '再拍一张',
                                onPressed: _goCapture,
                                variant: LumiraButtonVariant.brand,
                                icon: Icons.camera_alt_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail, required this.tokens, required this.style});

  final ChallengeDetail detail;
  final ThemeTokens tokens;
  final UIStyle style;

  @override
  Widget build(BuildContext context) {
    final progressPercent = detail.progressTotal == 0
        ? 0.0
        : detail.progressCurrent / detail.progressTotal;
    // Forced fix: neumorphic 风格下移除硬编码金色渐变，改用 surface 纯色 + shadowConvex 双向阴影
    final isNeumorphic = style == UIStyle.neumorphic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), // 40rpx 48rpx → 20 24
      decoration: BoxDecoration(
        color: isNeumorphic ? tokens.surface : null,
        gradient: isNeumorphic
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFDF6EC), Color(0xFFF5E6CC)],
              ),
        borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
        boxShadow: isNeumorphic ? tokens.shadowConvex : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // badge 行：左 badge + 右 status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.my_location, size: 14, color: tokens.brandText),
                  const SizedBox(width: 4),
                  ChallengeTagWidget(
                    tag: ChallengeTag(
                      label: detail.badge,
                      color: ChallengeTagColor.gold,
                    ),
                  ),
                ],
              ),
              if (detail.status == ChallengeStatus.done)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.successSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '已完成',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.success,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 标题
          Text(
            detail.title,
            style: TextStyle(
              fontSize: 20, // 40rpx → 20dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.3,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // 描述
          Text(
            detail.description,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              height: 1.7,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // 奖励
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 16, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                '奖励 +${detail.rewardXP} XP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.brandText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 进度条
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 8,
                    backgroundColor: tokens.brand.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${detail.progressCurrent}/${detail.progressTotal} 已完成',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, required this.tokens, required this.style});

  final Work work;
  final ThemeTokens tokens;
  final UIStyle style;

  @override
  Widget build(BuildContext context) {
    // Forced fix: neumorphic 风格下移除 border，canvas→surface，boxShadow→shadowConvexSubtle
    final isNeumorphic = style == UIStyle.neumorphic;
    return Container(
      decoration: BoxDecoration(
        color: isNeumorphic ? tokens.surface : tokens.canvas,
        borderRadius: BorderRadius.circular(14),
        border: isNeumorphic ? null : Border.all(color: tokens.divider, width: 1),
        boxShadow: isNeumorphic
            ? tokens.shadowConvexSubtle
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3:4 作品图
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                work.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: tokens.divider,
                  child: Icon(Icons.image, color: tokens.textTertiary),
                ),
              ),
            ),
            // 信息区
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: tokens.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        work.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 标题
                  Text(
                    work.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: work.tags.map((t) => ChallengeTagWidget(tag: t)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  const _RequirementItem({required this.requirement, required this.tokens});

  final Requirement requirement;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圆形序号
          Container(
            width: 24, // 48rpx → 24dp
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.brandSubtle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${requirement.index}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.brandText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 标题 + 描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  requirement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                    height: 1.6,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (requirement.done)
            Icon(Icons.check, size: 16, color: tokens.brand),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip, required this.tokens});

  final Tip tip;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final colors = _TipColors.from(tokens, tip.iconColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 64×64 圆角图标盒
          Container(
            width: 32, // 64rpx → 32dp
            height: 32,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
            ),
            child: Icon(tip.icon, size: 16, color: colors.icon),
          ),
          const SizedBox(width: 12),
          // 标题 + 描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tip.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipColors {
  const _TipColors({required this.background, required this.icon});

  final Color background;
  final Color icon;

  static _TipColors from(ThemeTokens tokens, ChallengeTagColor color) {
    switch (color) {
      case ChallengeTagColor.gold:
        return _TipColors(
          background: tokens.brand.withOpacity(0.12),
          icon: tokens.brand,
        );
      case ChallengeTagColor.green:
        return _TipColors(
          background: tokens.success.withOpacity(0.10),
          icon: tokens.success,
        );
      case ChallengeTagColor.red:
        return _TipColors(
          background: tokens.danger.withOpacity(0.10),
          icon: tokens.danger,
        );
    }
  }
}
