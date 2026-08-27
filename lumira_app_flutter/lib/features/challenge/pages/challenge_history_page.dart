import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';

import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/challenge_models.dart';
import '../data/challenge_providers.dart';

/// 挑战记录页（挑战墙）
///
/// 按日期倒序展示用户的挑战历史记录，每条记录可溯源到当日拍摄的图片。
/// 数据源：allHistoryProvider（全部挑战历史，不限日期范围）
class ChallengeHistoryPage extends ConsumerWidget {
  const ChallengeHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final historyAsync = ref.watch(allHistoryProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: '挑战记录',
              transparent: true,
              leading: _BackButton(tokens: tokens),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Text('加载失败',
                      style: TextStyle(color: tokens.textTertiary)),
                ),
                data: (records) {
                  // 过滤今日未完成的 pending 记录：只有到第二天才显示为跳过
                  final now = DateTime.now();
                  final todayStr =
                      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final filtered = List<ChallengeHistoryRecord>.from(records)
                    ..removeWhere((r) =>
                        r.date == todayStr &&
                        r.status == ChallengeStatus.pending);
                  // 按日期倒序排列
                  final sorted = List<ChallengeHistoryRecord>.from(filtered)
                    ..sort((a, b) => b.date.compareTo(a.date));

                  // 统计数据
                  final doneCount = sorted
                      .where((r) => r.status == ChallengeStatus.done)
                      .length;
                  final skippedCount = sorted
                      .where((r) => r.status == ChallengeStatus.skipped)
                      .length;
                  final totalXP = sorted
                      .where((r) => r.status == ChallengeStatus.done)
                      .fold(0, (sum, r) => sum + r.rewardXP);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      // 顶部统计卡
                      FadeUp(
                        child: _SummaryHeader(
                          tokens: tokens,
                          totalDays: sorted.length,
                          doneCount: doneCount,
                          skippedCount: skippedCount,
                          totalXP: totalXP,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeUp(
                        delay: const Duration(milliseconds: 80),
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 18, color: tokens.brand),
                            const SizedBox(width: 6),
                            Text(
                              '历史记录',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '共 ${sorted.length} 条',
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (sorted.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              '还没有挑战记录',
                              style: TextStyle(
                                  fontSize: 13, color: tokens.textTertiary),
                            ),
                          ),
                        )
                      else
                        // 时间线列表
                        for (var i = 0; i < sorted.length; i++) ...[
                          FadeUp(
                            delay: Duration(milliseconds: 160 + i * 60),
                            child: _HistoryTimelineTile(
                              tokens: tokens,
                              record: sorted[i],
                              isLast: i == sorted.length - 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
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
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.challenge);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.tokens,
    required this.totalDays,
    required this.doneCount,
    required this.skippedCount,
    required this.totalXP,
  });

  final ThemeTokens tokens;
  final int totalDays;
  final int doneCount;
  final int skippedCount;
  final int totalXP;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '挑战历程',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '过去 $totalDays 天你完成了 $doneCount 次挑战',
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 完成率环
          _CompletionRing(
            tokens: tokens,
            doneCount: doneCount,
            totalCount: totalDays,
          ),
        ],
      ),
    );
  }
}

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({
    required this.tokens,
    required this.doneCount,
    required this.totalCount,
  });

  final ThemeTokens tokens;
  final int doneCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: tokens.brandSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.brand),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 时间线单条记录
class _HistoryTimelineTile extends ConsumerWidget {
  const _HistoryTimelineTile({
    required this.tokens,
    required this.record,
    required this.isLast,
  });

  final ThemeTokens tokens;
  final ChallengeHistoryRecord record;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = record.status == ChallengeStatus.done;
    final dotColor = isDone ? tokens.brand : tokens.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线轴
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(color: tokens.canvas, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: tokens.surfaceAlt,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 内容卡
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              // 整卡可点击跳转历史挑战记录详情页（不再仅照片可点）
              child: GestureDetector(
                onTap: () => _viewDetail(context, ref),
                behavior: HitTestBehavior.opaque,
                child: NeuCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日期 + 状态
                      Row(
                        children: [
                          Text(
                            _formatDate(record.date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tokens.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          _StatusChip(
                            tokens: tokens,
                            status: record.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 标题
                      Text(
                        record.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 分类 + XP
                      Row(
                        children: [
                          _CategoryChip(
                              tokens: tokens, category: record.category),
                          const SizedBox(width: 8),
                          if (isDone) ...[
                            Icon(Icons.stars_outlined,
                                size: 14, color: tokens.brand),
                            const SizedBox(width: 2),
                            Text(
                              '+${record.rewardXP} XP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.brand,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 照片缩略图横滑（真实数据 photoIds 可能为空，则不渲染）
                      if (record.photoIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: record.photoIds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final photoId = record.photoIds[index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _PhotoThumb(
                                  photoId: photoId,
                                  tokens: tokens,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) {
        return '${parts[1]}月${parts[2]}日';
      }
    } catch (_) {}
    return isoDate;
  }

  void _viewDetail(BuildContext context, WidgetRef ref) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.challengeHistoryDetail,
        {
          RouteNames.paramChallengeId: record.challengeId,
          RouteNames.paramDate: record.date,
        },
      ),
    );
  }
}

/// 照片缩略图组件，从 gallery_items 加载真实图片
class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.photoId, required this.tokens});

  final String photoId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GalleryItemRecord?>(
      future: ref
          .read(galleryDaoProvider.future)
          .then((dao) => dao.getById(photoId)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: 72,
            height: 72,
            color: tokens.divider,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Container(
            width: 72,
            height: 72,
            color: tokens.brandSubtle,
            child: Icon(Icons.image_outlined, size: 24, color: tokens.brand),
          );
        }
        final filePath = item.filePath ?? item.originalPath;
        if (filePath != null && filePath.isNotEmpty) {
          return LumiraImage(
            filePath,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorWidget: _placeholder(),
          );
        }
        final dataUrl = item.dataUrl;
        if (dataUrl != null && dataUrl.isNotEmpty) {
          return LumiraImage(
            dataUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorWidget: _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      color: tokens.brandSubtle,
      child: Icon(Icons.image_outlined, size: 24, color: tokens.brand),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tokens, required this.status});
  final ThemeTokens tokens;
  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final isDone = status == ChallengeStatus.done;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDone ? tokens.successSubtle : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        isDone ? '已完成' : '已跳过',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDone ? tokens.success : tokens.textTertiary,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.tokens, required this.category});
  final ThemeTokens tokens;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        ChallengeCategory.label(category),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: tokens.brandText,
        ),
      ),
    );
  }
}


