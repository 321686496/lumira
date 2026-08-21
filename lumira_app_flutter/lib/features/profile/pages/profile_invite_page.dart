import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saver_gallery/saver_gallery.dart';

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
  final GlobalKey _posterKey = GlobalKey();

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
      // 打开全屏邀请海报
      await _showInvitePoster(code.code);
      if (!mounted) return;
      ref.invalidate(inviteStatsProvider); // 刷新 myInviteCode
    } on ApiException catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成失败：${e.message}', duration: const Duration(milliseconds: 1500));
    } catch (_) {
      // 离线/未注册环境兜底：保留原占位 SnackBar 行为
      if (!mounted) return;
      LumiraToast.show(toastContext, '生成邀请卡片', duration: const Duration(milliseconds: 1000));
    }
  }

  Future<void> _showInvitePoster(String code) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvitePosterSheet(code: code, posterKey: _posterKey),
    );
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
                  delay: const Duration(milliseconds: 60),
                  child: _MyInviteCodeCard(tokens: tokens),
                ),
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
    final tiers = stats?.tiers ?? const <InviteTierEntry>[];
    final List<RewardEntry> rewards;
    if (tiers.isEmpty) {
      // 兜底：后端未返回 tiers 时用静态阶梯
      rewards = _buildRewardLadder(stats);
    } else {
      rewards = tiers.map((t) {
        final done = t.done;
        final locked = t.locked;
        final labelList = t.rewards.map((r) => r.label).join('、');
        return RewardEntry(
          icon: Icons.card_giftcard,
          countLabel: '${t.requiredInvites} 分享',
          name: labelList.isEmpty ? '第 ${t.tier} 档奖励' : labelList,
          done: done,
          locked: locked,
          status: done ? '已达成' : (locked ? '' : '进行中'),
        );
      }).toList();
    }
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
    final keepList = stats?.invitees ?? const <Invitee>[];
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
          if (keepList.isEmpty)
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
                for (var i = 0; i < keepList.length; i++)
                  _InviteeRow(
                    invitee: keepList[i],
                    isLast: i == keepList.length - 1,
                    tokens: tokens,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 被邀请人单行（真实设备 ID）
class _InviteeRow extends StatelessWidget {
  const _InviteeRow({required this.invitee, required this.isLast, required this.tokens});
  final Invitee invitee;
  final bool isLast;
  final ThemeTokens tokens;

  static const _channelLabels = <String, String>{
    'direct': '直接邀请',
    'share_card': '分享卡片',
    'qrcode': '二维码',
  };
  static const _channelIcons = <String, IconData>{
    'direct': Icons.person_add_alt_1,
    'share_card': Icons.share,
    'qrcode': Icons.qr_code_2,
  };

  @override
  Widget build(BuildContext context) {
    final id = invitee.inviteeDeviceId;
    final short = id.length > 12 ? '${id.substring(0, 6)}…${id.substring(id.length - 4)}' : id;
    final channel = invitee.channel;
    final label = _channelLabels[channel] ?? channel;
    final date = _formatTimestamp(invitee.activatedAt);
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
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _channelIcons[channel] ?? Icons.person_add_alt_1,
              size: 20,
              color: tokens.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  short,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier New',
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.success,
              borderRadius: BorderRadius.circular(1000),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(int sec) {
  final d = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 「我的邀请码」展示卡（Hero 之后）
class _MyInviteCodeCard extends ConsumerWidget {
  const _MyInviteCodeCard({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(inviteStatsProvider).valueOrNull?.myInviteCode;
    return NeuCard(
      child: Row(
        children: [
          Icon(Icons.tag, size: 20, color: tokens.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code == null ? '尚未生成邀请码' : '我的邀请码：$code',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            ),
          ),
          if (code != null)
            GestureDetector(
              onTap: () async {
                final overlay = Overlay.of(context, rootOverlay: true);
                await Clipboard.setData(ClipboardData(text: code));
                LumiraToast.showWithOverlay(overlay, '邀请码已复制', duration: const Duration(milliseconds: 1200));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text('复制', style: TextStyle(fontSize: 12, color: tokens.brandText)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 全屏邀请海报弹层（可保存到相册）
class _InvitePosterSheet extends ConsumerWidget {
  const _InvitePosterSheet({required this.code, required this.posterKey});
  final String code;
  final GlobalKey posterKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    // 复制邀请码
    void copyCode() async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: code));
      messenger.showSnackBar(
        SnackBar(content: Text('邀请码已复制：$code'), duration: const Duration(seconds: 1)),
      );
    }

    // 保存海报：捕获 RepaintBoundary 为 PNG 存入相册
    Future<void> savePoster() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final boundary = posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        await SaverGallery.saveImage(
          Uint8List.fromList(byteData.buffer.asUint8List()),
          name: 'lumira_invite_${DateTime.now().millisecondsSinceEpoch}',
          quality: 95,
          androidExistNotSave: false,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('海报已保存到相册'), duration: Duration(seconds: 1)),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('保存失败，请长按截图保存'), duration: Duration(seconds: 2)),
        );
      }
    }

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('邀请卡片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  IconButton(
                    icon: Icon(Icons.close, color: tokens.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: posterKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [tokens.brandSubtle, tokens.surface],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('邀请好友，获得奖励',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                        const SizedBox(height: 8),
                        Text('输入我的邀请码，一起记录美好时光',
                            style: TextStyle(fontSize: 13, color: tokens.textSecondary)),
                        const SizedBox(height: 24),
                        QrImageView(
                          data: code,
                          version: QrVersions.auto,
                          size: 160,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: tokens.textPrimary),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: tokens.canvas,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(code,
                              style: TextStyle(
                                  fontFamily: 'Courier New',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: tokens.textPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: LumiraButton(variant: ButtonVariant.secondary, onPressed: copyCode, child: const Text('复制邀请码')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LumiraButton(variant: ButtonVariant.primary, onPressed: savePoster, child: const Text('保存海报')),
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
