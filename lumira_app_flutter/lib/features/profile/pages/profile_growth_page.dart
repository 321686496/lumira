import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../features/points/data/points_repository.dart';
import '../../../shared/services/poster_generator.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/growth_models.dart';
import '../providers/growth_providers.dart';
import '../services/growth_xp_service.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/shooting_calendar_heatmap.dart';

/// 成长中心页
///
/// 视觉规格来源：lumira-app/src/pages/profile/growth.vue（375 行）
/// 4 个 section：
/// 1. LevelCard（等级 + 经验进度 + 三列 meta）
/// 2. AchievementCard（6 项成就墙）
/// 3. TrajectoryCard（4 项成长轨迹时间线）
/// 4. CalendarCard（112 格热力图 + 图例）
///
/// 数据来源：GrowthDao 聚合 user_progress / challenge_history / gallery_items 表。
/// 4 个 FutureProvider 通过 maybeWhen 提供加载兜底，避免 UI 闪烁。
class ProfileGrowthPage extends ConsumerWidget {
  const ProfileGrowthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    // 进入成长中心触发一次升级奖励补发（离线失败静默，联网后下次再补）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _claimPendingRewards(ref, context);
    });

    final levelAsync = ref.watch(growthLevelProvider);
    final breakdownAsync = ref.watch(growthXpBreakdownProvider);
    final achievementsAsync = ref.watch(growthAchievementsProvider);
    final trajectoryAsync = ref.watch(growthTrajectoryProvider);
    final heatmapAsync = ref.watch(growthHeatmapProvider);

    // 所有 provider 都在加载中时显示空状态（防御性，实际各 section 已有 orElse 兜底）
    final allLoading = levelAsync.isLoading &&
        achievementsAsync.isLoading &&
        trajectoryAsync.isLoading &&
        heatmapAsync.isLoading;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '成长中心',
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
          child: allLoading
              ? const _EmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeUp(
                        child: _LevelCard(
                          tokens: tokens,
                          summary: levelAsync.maybeWhen(
                            data: (s) => s,
                            orElse: () => GrowthSummary.empty,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeUp(
                        delay: const Duration(milliseconds: 50),
                        child: _XpBreakdownCard(
                          tokens: tokens,
                          entries: breakdownAsync.maybeWhen(
                            data: (e) => e,
                            orElse: () => const [],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeUp(
                        delay: const Duration(milliseconds: 100),
                        child: _AchievementCard(
                          tokens: tokens,
                          achievements: achievementsAsync.maybeWhen(
                            data: (a) => a,
                            orElse: () => kPlaceholderAchievements,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeUp(
                        delay: const Duration(milliseconds: 200),
                        child: _TrajectoryCard(
                          tokens: tokens,
                          trajectory: trajectoryAsync.maybeWhen(
                            data: (t) => t,
                            orElse: () => const [],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeUp(
                        delay: const Duration(milliseconds: 300),
                        child: _CalendarCard(
                          tokens: tokens,
                          heatmap: heatmapAsync.maybeWhen(
                            data: (h) => h,
                            orElse: () => const {},
                          ),
                        ),
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

/// 进入成长中心时补发升级积分奖励（离线失败静默，联网后下次再补）。
Future<void> _claimPendingRewards(WidgetRef ref, BuildContext context) async {
  try {
    final db = await ref.read(databaseProvider.future);
    final repo = await ref.read(pointsRepositoryProvider.future);
    final svc = GrowthXpService(
      db,
      earnLevelReward: (level) =>
          repo.earn(type: 'level_reward', refId: level),
    );
    final newCount = await svc.claimLevelRewards();
    if (newCount > 0 && context.mounted) {
      LumiraToast.show(context, '升级奖励 +$newCount 笔积分已到账');
    }
  } catch (e) {
    debugPrint('[growth] claim level rewards failed: $e');
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary, required this.tokens});
  final GrowthSummary summary;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    // 当前等级下界与下一级上界（阈值表）
    final cur = LEVEL_THRESHOLDS.where((t) => t.level == summary.level).toList();
    final curFloor = cur.isEmpty ? 0 : cur.first.xp;
    final nxt = LEVEL_THRESHOLDS.where((t) => t.level == summary.level + 1).toList();
    final nxtCeil = nxt.isEmpty ? summary.currentXp : nxt.first.xp;
    final span = nxtCeil - curFloor;
    final xpIntoLevel = summary.currentXp - curFloor;
    final xpPercent = (span <= 0 ? 0.0 : (xpIntoLevel / span) * 100).round().clamp(0, 100);

    return NeuCard(
      child: Column(
        children: [
          Text(
            'LEVEL',
            style: TextStyle(
              fontFamily: 'Courier New',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.brandText,
              letterSpacing: 0.08 * 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.level}',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary.levelName,
            style: TextStyle(
              fontSize: 15,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: tokens.brand.withOpacity(0.18)),
                  FractionallySizedBox(
                    widthFactor: xpPercent / 100.0,
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
          const SizedBox(height: 12),
          // 三列 meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${formatThousands(summary.currentXp)} XP',
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '还差 ${formatThousands(summary.xpToNextLevel)} XP 升级',
                    style: TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 11,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  nxt.isEmpty
                      ? '已达最高等级'
                      : '${formatThousands(nxtCeil)} XP',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: nxt.isEmpty
                        ? tokens.textTertiary
                        : tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpBreakdownCard extends StatelessWidget {
  const _XpBreakdownCard({required this.tokens, required this.entries});
  final ThemeTokens tokens;
  final List<XpBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '经验来源',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          for (final e in entries) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${e.amount} XP',
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: tokens.brand.withOpacity(0.15)),
                    FractionallySizedBox(
                      widthFactor: e.ratio < 0 ? 0 : e.ratio,
                      child: Container(color: tokens.brand),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AchievementCard extends ConsumerWidget {
  const _AchievementCard({required this.tokens, required this.achievements});
  final ThemeTokens tokens;
  final List<AchievementRecord> achievements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedCount = achievements.where((a) => a.unlocked).length;
    final levelAsync = ref.watch(growthLevelProvider);
    final style = ref.watch(appThemeProvider).style;
    final levelName = levelAsync.maybeWhen(
      data: (s) => s.levelName,
      orElse: () => '',
    );
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '成就',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$unlockedCount / ${achievements.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: achievements
                .map((a) => _AchievementCell(
                      item: a,
                      tokens: tokens,
                      style: style,
                      levelName: levelName,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AchievementCell extends StatelessWidget {
  const _AchievementCell({
    required this.item,
    required this.tokens,
    this.style = UIStyle.neumorphic,
    this.levelName = '',
  });

  final AchievementRecord item;
  final ThemeTokens tokens;
  final UIStyle style;
  final String levelName;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt;
      case 'flame':
        return Icons.local_fire_department;
      case 'layers':
        return Icons.layers;
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: style == UIStyle.glass
            ? ThemeTokens.glassFill(tokens)
            : tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: style == UIStyle.glass
            ? Border.all(color: ThemeTokens.glassBorder(tokens), width: 1)
            : null,
        boxShadow: style == UIStyle.glass
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 6),
                  blurRadius: 20,
                ),
              ]
            : tokens.shadowConvexSubtle,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _iconForKey(item.iconKey),
                size: 36,
                color: item.unlocked ? tokens.textPrimary : tokens.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: item.unlocked
                      ? tokens.textPrimary
                      : tokens.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          // 已解锁成就右上角分享按钮
          if (item.unlocked)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  final posterKey = GlobalKey();
                  PosterGenerator.showPoster(
                    context: context,
                    tokens: tokens,
                    title: '成就海报预览',
                    content: _AchievementPosterContent(
                      tokens: tokens,
                      achievement: item,
                      levelName: levelName,
                    ),
                    posterKey: posterKey,
                    shareSubject: '如画 · 成就解锁：${item.name}',
                    shareText: '我在如画解锁了「${item.name}」成就！快来一起挑战吧！',
                    fileNamePrefix: 'lumira_achievement_${item.id}',
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.ios_share_outlined,
                    size: 14,
                    color: tokens.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // 整卡可点击查看成就详情与完成情况
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(context, item, tokens),
      child: cell,
    );

    if (item.unlocked) return tappable;
    return Opacity(opacity: 0.5, child: tappable);
  }

  /// 点击成就弹出详情，展示描述、解锁状态与解锁时间
  void _showDetail(
      BuildContext context, AchievementRecord item, ThemeTokens tokens) {
    final timeStr = item.unlockedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(item.unlockedAt!)
            .toString()
            .substring(0, 10)
        : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 成就图标
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: item.unlocked
                        ? LinearGradient(
                            colors: [tokens.brand, tokens.brandDeep],
                          )
                        : null,
                    color: item.unlocked ? null : tokens.canvasDeep,
                  ),
                  child: Icon(
                    _iconForKey(item.iconKey),
                    size: 32,
                    color: item.unlocked ? Colors.white : tokens.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 名称
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // 描述
              Text(
                item.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              // 解锁状态
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.unlocked
                        ? tokens.successSubtle
                        : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    item.unlocked ? '已解锁' : '未解锁',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.unlocked
                          ? tokens.success
                          : tokens.textTertiary,
                    ),
                  ),
                ),
              ),
              if (item.unlocked && timeStr != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '解锁于 $timeStr',
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TrajectoryCard extends StatelessWidget {
  const _TrajectoryCard({required this.tokens, required this.trajectory});
  final ThemeTokens tokens;
  final List<GrowthTrajectoryRecord> trajectory;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '成长轨迹',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < trajectory.length; i++)
                _TrajectoryRow(
                  entry: trajectory[i],
                  isLast: i == trajectory.length - 1,
                  tokens: tokens,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrajectoryRow extends StatelessWidget {
  const _TrajectoryRow({required this.entry, required this.isLast, required this.tokens});
  final GrowthTrajectoryRecord entry;
  final bool isLast;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateTime.fromMillisecondsSinceEpoch(entry.timestamp)
        .toString()
        .substring(0, 10);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间线左侧：圆点 + 连接线
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.canvas, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brand.withOpacity(0.4),
                      blurRadius: 0,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 36, // ~48dp height
                  color: tokens.divider,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier New',
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.tokens, required this.heatmap});
  final ThemeTokens tokens;
  final Map<String, int> heatmap;

  /// 热力图色块颜色，跟随主题品牌色（原先写死 #C9A96E）
  Color _heatColor(int level) {
    switch (level) {
      case 0:
        return tokens.divider;
      case 1:
        return tokens.brand.withOpacity(0.2);
      case 2:
        return tokens.brand.withOpacity(0.4);
      case 3:
        return tokens.brand.withOpacity(0.6);
      default:
        return tokens.brand;
    }
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    // 用 UTC 以与 DAO 中 SQLite date(ts/1000,'unixepoch') 的 UTC 日期对齐。
    final today = DateTime.now().toUtc();

    // 本月拍摄数：当前 YYYY-MM 内所有日期的活动数之和
    final currentMonth = _formatDate(today).substring(0, 7);
    var monthlyPhotos = 0;
    heatmap.forEach((dateStr, count) {
      if (dateStr.startsWith(currentMonth)) {
        monthlyPhotos += count;
      }
    });

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '拍摄日历',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '本月 $monthlyPhotos 张',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () =>
                    GoRouter.of(context)
                        .push(RouteNames.profileGrowthCalendar),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '全部记录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tokens.brand,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: tokens.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShootingCalendarHeatmap(
            heatmap: heatmap,
            tokens: tokens,
            daysBack: 112,
            onCellTap: (date, count, level) {
              showDayDetailSheet(context, date: date);
            },
          ),
          const SizedBox(height: 12),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '少',
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
              const SizedBox(width: 4),
              for (final level in const [0, 1, 2, 3, 4]) ...[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: _heatColor(level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Text(
                '多',
                style: TextStyle(fontSize: 11, color: tokens.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('暂无数据，去完成第一次拍摄解锁成长记录'),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () => GoRouter.of(context).push(RouteNames.capture),
            child: const Text('去拍摄'),
          ),
        ],
      ),
    );
  }
}

/// 成就海报内容 Widget
class _AchievementPosterContent extends StatelessWidget {
  const _AchievementPosterContent({
    required this.tokens,
    required this.achievement,
    required this.levelName,
  });

  final ThemeTokens tokens;
  final AchievementRecord achievement;
  final String levelName;

  IconData _iconForKey(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt;
      case 'flame':
        return Icons.local_fire_department;
      case 'layers':
        return Icons.layers;
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.canvas],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: t.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.brand, t.brandDeep]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForKey(achievement.iconKey),
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '成就解锁',
              style: TextStyle(
                fontSize: 12,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              achievement.name,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Noto Serif SC',
                color: t.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              achievement.description,
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: t.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, size: 16, color: t.brand),
                const SizedBox(width: 8),
                Text(
                  levelName.isNotEmpty
                      ? '当前等级：$levelName'
                      : '继续探索更多成就',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
