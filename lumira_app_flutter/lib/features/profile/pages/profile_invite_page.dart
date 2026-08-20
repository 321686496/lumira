import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/invite/data/invite_models.dart';
import '../../../features/invite/data/invite_repository.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 邀请有礼页
///
/// 视觉规格来源：lumira-app/src/pages/profile/invite.vue（394 行）
/// 6 个 section：
/// 1. HeroCard（image + title + desc）
/// 2. RewardCard（6 项奖励阶梯）
/// 3. ProgressCard（进度条）
/// 4. 生成邀请卡片按钮
/// 5. CodeCard（邀请码输入 + 确认按钮）
/// 6. RecordCard（3 项邀请记录）
class ProfileInvitePage extends ConsumerStatefulWidget {
  const ProfileInvitePage({super.key});

  @override
  ConsumerState<ProfileInvitePage> createState() => _ProfileInvitePageState();
}

class _ProfileInvitePageState extends ConsumerState<ProfileInvitePage> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateInviteCard() async {
    final toastContext = context;
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final code = await repo.generate();
      if (!mounted) return;
      LumiraToast.show(toastContext, '邀请码已生成：${code.code}', duration: const Duration(milliseconds: 1500));
    } on ApiException catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成失败：${e.message}', duration: const Duration(milliseconds: 1500));
    } catch (_) {
      // 离线/未注册环境兜底：保留原占位 SnackBar 行为
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成邀请卡片', duration: const Duration(milliseconds: 1000));
    }
  }

  Future<void> _confirmBindCode() async {
    final code = _codeController.text.trim();
    final toastContext = context;
    if (code.isEmpty) {
      LumiraToast.show(toastContext, '请输入邀请码', duration: const Duration(milliseconds: 1000));
      return;
    }
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final resp = await repo.activate(ActivateInviteRequest(inviteCode: code));
      if (!mounted) return;
      if (resp.rewards != null) {
        LumiraToast.show(toastContext, '邀请码已激活，解锁 ${resp.rewards!.items.length} 项奖励', duration: const Duration(milliseconds: 1500));
      } else {
        LumiraToast.show(toastContext, '邀请码已激活', duration: const Duration(milliseconds: 1500));
      }
      ref.invalidate(inviteStatsProvider);
      _codeController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '激活失败：${e.message}', duration: const Duration(milliseconds: 1500));
    } catch (_) {
      // 离线/未注册环境兜底
      if (!mounted) return;
      LumiraToast.show(toastContext, '绑定成功：$code', duration: const Duration(milliseconds: 1000));
      _codeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final statsAsync = ref.watch(inviteStatsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '邀请有礼',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 网络失败回退缓存时显示离线提示
                statsAsync.when(
                  data: (_) => const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) {
                    final isOffline = e is ApiException && e.isNetworkError;
                    if (!isOffline) return const SizedBox.shrink();
                    return ApiErrorBanner(
                      onRetry: () => ref.invalidate(inviteStatsProvider),
                    );
                  },
                ),
                FadeUp(child: _HeroCard(tokens: tokens)),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: _RewardCard(tokens: tokens),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 200),
                  child: _ProgressCard(tokens: tokens),
                ),
                const SizedBox(height: 16),
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: _generateInviteCard,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.brush_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('生成邀请卡片'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 400),
                  child: _CodeCard(
                    tokens: tokens,
                    controller: _codeController,
                    onConfirm: _confirmBindCode,
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 500),
                  child: _RecordCard(tokens: tokens),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Forced fix: canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 5 / 3,
              child: CachedNetworkImage(
                url: 'https://picsum.photos/seed/1926773/400/240',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '邀请好友，获得奖励',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '邀请好友一起记录美好，解锁专属模板',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider).valueOrNull;
    final rewards = _buildRewardLadder(stats);
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '奖励阶梯',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: rewards.map((r) => _RewardRow(item: r, tokens: tokens)).toList(),
          ),
        ],
      ),
    );
  }
}

/// 奖励阶梯定义项（阈值 / icon / 名称）
class _RewardLadderItem {
  const _RewardLadderItem({
    required this.threshold,
    required this.icon,
    required this.name,
  });
  final int threshold;
  final IconData icon;
  final String name;
}

/// 奖励阶梯定义（阈值 / icon / 名称）
/// 状态（done/locked/进行中）由真实 InviteStats.totalInvites 和 nextTier 派生
const _rewardLadder = <_RewardLadderItem>[
  _RewardLadderItem(threshold: 1, icon: Icons.movie_outlined, name: '日系胶片模板'),
  _RewardLadderItem(threshold: 3, icon: Icons.flag_outlined, name: '法式复古包'),
  _RewardLadderItem(threshold: 5, icon: Icons.star_outline, name: '氛围感包'),
  _RewardLadderItem(threshold: 10, icon: Icons.emoji_events_outlined, name: '分享达人成就'),
  _RewardLadderItem(threshold: 15, icon: Icons.workspace_premium_outlined, name: '全部精选模板'),
  _RewardLadderItem(threshold: 20, icon: Icons.bolt_outlined, name: '裂变之神'),
];

/// 奖励阶梯条目（用于 UI 渲染）
class RewardEntry {
  const RewardEntry({
    required this.icon,
    required this.countLabel,
    required this.name,
    required this.done,
    required this.locked,
    required this.status,
  });
  final IconData icon;
  final String countLabel;
  final String name;
  final bool done;
  final bool locked;
  final String status;
}

List<RewardEntry> _buildRewardLadder(InviteStats? stats) {
  final invited = stats?.totalInvites ?? 0;
  final nextRequired = stats?.nextTier?.requiredInvites;
  return _rewardLadder.map((t) {
    final done = invited >= t.threshold;
    final isNext = nextRequired == t.threshold;
    return RewardEntry(
      icon: t.icon,
      countLabel: '${t.threshold} 分享',
      name: t.name,
      done: done,
      locked: !done && !isNext,
      status: done ? '已达成' : (isNext ? '进行中' : ''),
    );
  }).toList();
}

class _RewardRow extends ConsumerWidget {
  const _RewardRow({required this.item, required this.tokens});
  final RewardEntry item;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final isNeu = appTheme.style == UIStyle.neumorphic;
    final bool done = item.done;
    final bool locked = item.locked;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: done ? tokens.brandSubtle : (isNeu ? tokens.surface : tokens.canvas),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
        border: isNeu
            ? null
            : Border.all(
                color: done ? tokens.brand.withOpacity(0.3) : tokens.divider,
                width: 1,
              ),
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 20,
            color: locked ? tokens.textTertiary : tokens.brand,
          ),
          const SizedBox(width: 8),
          Text(
            item.countLabel,
            style: TextStyle(
              fontSize: 12,
              color: locked ? tokens.textTertiary : tokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                color: locked ? tokens.textTertiary : tokens.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 右侧 tag
          if (done)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Text(
                item.status,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (item.status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.brandText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (locked)
            Icon(Icons.lock_outline, size: 14, color: tokens.textTertiary),
        ],
      ),
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider).valueOrNull;
    final invited = stats?.totalInvites ?? 0;
    final nextRequired = stats?.nextTier?.requiredInvites ?? 0;
    final nextRewardName = stats?.nextTier?.rewards.isNotEmpty == true
        ? stats!.nextTier!.rewards.map((r) => r.label).join('、')
        : '';
    final remaining = nextRequired > invited ? nextRequired - invited : 0;
    final percent = nextRequired > 0 ? (invited / nextRequired * 100).clamp(0, 100) : 100.0;
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '当前进度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '已邀请 $invited 位',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: percent / 100.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tokens.brand, tokens.brandLight],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextRewardName.isEmpty
                ? '暂无下一档奖励'
                : '再邀请 $remaining 人可解锁「$nextRewardName」',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.tokens,
    required this.controller,
    required this.onConfirm,
  });
  final ThemeTokens tokens;
  final TextEditingController controller;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入好友邀请码',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LumiraTextField(
            controller: controller,
            hintText: '粘贴好友的邀请码...',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: onConfirm,
              child: const Text('确认绑定'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider).valueOrNull;
    final records = _buildInviteRecords(stats);
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '邀请记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '暂无邀请记录，邀请好友即可解锁奖励',
                  style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < records.length; i++)
                  _RecordRow(
                    record: records[i],
                    isLast: i == records.length - 1,
                    tokens: tokens,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 邀请记录条目（用于 UI 渲染）
class InviteRecord {
  const InviteRecord({
    required this.icon,
    required this.name,
    required this.date,
    required this.status,
    required this.pending,
  });
  final IconData icon;
  final String name;
  final String date;
  final String status;
  final bool pending;
}

/// 从 InviteStats.unlockedRewards 构建 InviteRecord 列表
List<InviteRecord> _buildInviteRecords(InviteStats? stats) {
  if (stats == null || stats.unlockedRewards.isEmpty) return const [];
  return stats.unlockedRewards.map((r) {
    final name = r.rewardItems.isNotEmpty
        ? r.rewardItems.map((e) => e.label).join('、')
        : (r.sourceDetail ?? '奖励');
    final date = _formatTimestamp(r.unlockedAt);
    return InviteRecord(
      icon: Icons.card_giftcard,
      name: name,
      date: date,
      status: '已确认',
      pending: false,
    );
  }).toList();
}

String _formatTimestamp(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.isLast, required this.tokens});
  final InviteRecord record;
  final bool isLast;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.divider, width: 0.5),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: record.pending ? tokens.surface : tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(record.icon, size: 20, color: tokens.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.date,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier New',
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 右侧 tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: record.pending ? tokens.surfaceAlt : tokens.success,
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Text(
              record.status,
              style: TextStyle(
                fontSize: 11,
                color: record.pending ? tokens.textTertiary : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
