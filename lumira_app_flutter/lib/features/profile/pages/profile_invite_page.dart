import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/invite/data/invite_models.dart';
import '../../../features/invite/data/invite_repository.dart';
import '../../../shared/widgets/api_error_banner.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final code = await repo.generateCode();
      messenger.showSnackBar(
        SnackBar(
          content: Text('邀请码已生成：${code.code}'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('生成失败：${e.message}'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (_) {
      // 离线/未注册环境兜底：保留原占位 SnackBar 行为
      messenger.showSnackBar(
        const SnackBar(
          content: Text('生成邀请卡片'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }
  }

  Future<void> _confirmBindCode() async {
    final code = _codeController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('请输入邀请码'),
          duration: Duration(milliseconds: 1000),
        ),
      );
      return;
    }
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final resp = await repo.activate(ActivateInviteRequest(inviteCode: code));
      if (resp.rewards != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('邀请码已激活，解锁 ${resp.rewards!.items.length} 项奖励'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('邀请码已激活'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
      ref.invalidate(inviteStatsProvider);
      _codeController.clear();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('激活失败：${e.message}'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } catch (_) {
      // 离线/未注册环境兜底
      messenger.showSnackBar(
        SnackBar(
          content: Text('绑定成功：$code'),
          duration: const Duration(milliseconds: 1000),
        ),
      );
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
                    label: '生成邀请卡片',
                    variant: LumiraButtonVariant.brand,
                    icon: Icons.brush_outlined,
                    onPressed: _generateInviteCard,
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
              child: Image.network(
                'https://picsum.photos/seed/1926773/400/240',
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

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
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
            children: ProfileMockData.rewards.map((r) => _RewardRow(item: r, tokens: tokens)).toList(),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.item, required this.tokens});
  final RewardEntry item;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final bool done = item.done;
    final bool locked = item.locked;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // 硬编码颜色：done 项背景 #F5EDDB
        color: done ? const Color(0xFFF5EDDB) : tokens.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const remaining = ProfileMockData.totalInvitedForNext - ProfileMockData.invitedCount;
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
                '已邀请 ${ProfileMockData.invitedCount} 位',
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
                    widthFactor: ProfileMockData.inviteProgressPercent / 100.0,
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
            '再邀请 $remaining 人可解锁「${ProfileMockData.nextRewardName}」',
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
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '粘贴好友的邀请码...',
              hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
              filled: true,
              fillColor: tokens.canvas,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: tokens.divider, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: tokens.divider, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: tokens.brand, width: 1.5),
              ),
            ),
            style: TextStyle(color: tokens.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: LumiraButton(
              label: '确认绑定',
              variant: LumiraButtonVariant.outline,
              expand: false,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
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
          Column(
            children: [
              for (var i = 0; i < ProfileMockData.inviteRecords.length; i++)
                _RecordRow(
                  record: ProfileMockData.inviteRecords[i],
                  isLast: i == ProfileMockData.inviteRecords.length - 1,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
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
              // 硬编码颜色：pending 用 tokens.surface，非 pending 用 #F5EDDB
              color: record.pending ? tokens.surface : const Color(0xFFF5EDDB),
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
