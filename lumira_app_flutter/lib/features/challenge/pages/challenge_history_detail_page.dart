import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/challenge_models.dart';
import '../data/challenge_pool.dart';
import '../data/challenge_providers.dart';
import '../widgets/challenge_tag.dart';

/// 挑战历史记录详情页
///
/// 与挑战详情页（challenge_detail_page.dart）分离：
/// - 只读展示某一天的挑战历史记录，数据来自 allHistoryProvider（全量历史，不限周）
/// - 已完成记录显示正确的进度 1/1 与当时的作品照片
/// - **不展示"去拍照 / 再拍一张"按钮**，底部仅"返回"
class ChallengeHistoryDetailPage extends ConsumerStatefulWidget {
  const ChallengeHistoryDetailPage({
    super.key,
    this.challengeId,
    this.date,
  });

  final String? challengeId;

  /// 指定日期（YYYY-MM-DD）
  final String? date;

  @override
  ConsumerState<ChallengeHistoryDetailPage> createState() =>
      _ChallengeHistoryDetailPageState();
}

class _ChallengeHistoryDetailPageState
    extends ConsumerState<ChallengeHistoryDetailPage> {
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.challengeHistory);
    }
  }

  /// 根据历史记录 + 题库构建只读挑战详情
  ChallengeDetail? _buildDetail(ChallengeHistoryRecord? record) {
    final challengeId = widget.challengeId;
    if (challengeId == null) return null;
    final item = ChallengePool.byId(challengeId);
    if (item == null) return null;

    final isDone = record != null && record.status == ChallengeStatus.done;
    final progressCurrent = isDone ? 1 : 0;
    // 已完成以历史入账值为准（附加挑战按 60% 入账），否则展示题库奖励
    int rewardXP;
    if (isDone && record.rewardXP > 0) {
      rewardXP = record.rewardXP;
    } else {
      rewardXP = item.rewardXP;
    }

    return ChallengeDetail(
      id: item.id,
      badge: ChallengeCategory.label(item.category),
      title: item.title,
      description: item.description,
      rewardXP: rewardXP,
      progressCurrent: progressCurrent,
      progressTotal: 1,
      status: isDone ? ChallengeStatus.done : ChallengeStatus.pending,
      requirements: [
        Requirement(
          index: 1,
          title: '完成主题拍摄',
          description: '根据挑战标题完成一张符合主题的照片',
          done: isDone,
        ),
        Requirement(
          index: 2,
          title: '应用拍摄技巧',
          description: item.tip,
          done: isDone,
        ),
        Requirement(
          index: 3,
          title: '保存到画廊',
          description: '将作品保存到画廊完成挑战',
          done: isDone,
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
          description: '完成可获得 $rewardXP XP 经验值',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    final historyAsync = ref.watch(allHistoryProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('加载失败',
                style: TextStyle(color: tokens.textSecondary)),
          ),
          data: (history) {
            // 从全量历史中查找匹配 challengeId + date 的记录（以其为准，显示完成状态）
            ChallengeHistoryRecord? record;
            if (widget.challengeId != null && widget.date != null) {
              final matches = history.where((r) =>
                  r.challengeId == widget.challengeId &&
                  r.date == widget.date);
              if (matches.isNotEmpty) {
                record = matches.first;
              }
            }
            final detail = _buildDetail(record);

            if (detail == null) {
              return Center(
                child: Text('记录不存在',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            }

            final photoIds = record != null ? record.photoIds : const <String>[];
            final isDone = detail.status == ChallengeStatus.done;

            return Stack(
              children: [
                Column(
                  children: [
                    LumiraNav(
                      title: '挑战记录详情',
                      scrolled: _scrolled,
                      transparent: true,
                      leading: _BackButton(tokens: tokens, onBack: _back),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        children: [
                          FadeUp(
                            child: _HeroCard(
                                detail: detail, tokens: tokens, style: style),
                          ),
                          const SizedBox(height: 24),
                          // 完成的作品（仅已完成且有照片时显示）
                          if (isDone && photoIds.isNotEmpty) ...[
                            const _SectionTitle(text: '完成的作品'),
                            const SizedBox(height: 12),
                            FadeUp(
                              delay: const Duration(milliseconds: 80),
                              child: _WorkCard(
                                photoIds: photoIds,
                                date: record!.date,
                                title: detail.title,
                                rewardXP: detail.rewardXP,
                                tokens: tokens,
                                style: style,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // 挑战要求
                          const _SectionTitle(text: '挑战要求'),
                          const SizedBox(height: 12),
                          FadeUp(
                            delay: const Duration(milliseconds: 160),
                            child: NeuCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: Column(
                                children: detail.requirements
                                    .map((r) => _RequirementItem(
                                        requirement: r, tokens: tokens))
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              child: Column(
                                children: detail.tips
                                    .map((t) => _TipRow(tip: t, tokens: tokens))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // 底部：历史记录详情只读，仅"返回"（无去拍照）
                          FadeUp(
                            delay: const Duration(milliseconds: 320),
                            child: LumiraButton(
                              variant: ButtonVariant.primary,
                              onPressed: _back,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.arrow_back),
                                  SizedBox(width: 8),
                                  Text('返回'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onBack});
  final ThemeTokens tokens;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
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
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.2),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.detail, required this.tokens, required this.style});

  final ChallengeDetail detail;
  final ThemeTokens tokens;
  final UIStyle style;

  @override
  Widget build(BuildContext context) {
    final progressPercent = detail.progressTotal == 0
        ? 0.0
        : detail.progressCurrent / detail.progressTotal;
    final isNeumorphic = style == UIStyle.neumorphic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isNeumorphic ? tokens.surface : null,
        gradient: isNeumorphic
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFDF6EC), Color(0xFFF5E6CC)],
              ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isNeumorphic ? tokens.shadowConvex : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          Text(
            detail.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              height: 1.3,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
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
          Row(
            children: [
              Expanded(
                child: LumiraProgress.linear(
                  value: progressPercent,
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${detail.progressCurrent}/${detail.progressTotal} 已完成',
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 完成的作品：以横滑列表展示所有照片（支持多张），单张时也居中展示
class _WorkCard extends ConsumerWidget {
  const _WorkCard({
    required this.photoIds,
    required this.date,
    required this.title,
    required this.rewardXP,
    required this.tokens,
    required this.style,
  });

  final List<String> photoIds;
  final String date;
  final String title;
  final int rewardXP;
  final ThemeTokens tokens;
  final UIStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = style == UIStyle.neumorphic;

    Widget card() {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: _WorkImage(photoId: photoIds.first, tokens: tokens),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: tokens.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChallengeTagWidget(
                      tag: ChallengeTag(
                        label: '+$rewardXP XP',
                        color: ChallengeTagColor.gold,
                        showCheckIcon: false,
                      ),
                    ),
                    const ChallengeTagWidget(
                      tag: ChallengeTag(
                        label: '已完成',
                        color: ChallengeTagColor.green,
                        showCheckIcon: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

      return Container(
        decoration: BoxDecoration(
          color: isNeumorphic ? tokens.surface : tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border:
              isNeumorphic ? null : Border.all(color: tokens.divider, width: 1),
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
          child: SizedBox(
            width: double.infinity,
            child: content,
          ),
        ),
      );
    }

    if (photoIds.length <= 1) {
      return card();
    }

    // 多张照片：横滑列表
    return SizedBox(
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: isNeumorphic ? tokens.surface : tokens.canvas,
                borderRadius: BorderRadius.circular(14),
                border: isNeumorphic
                    ? null
                    : Border.all(color: tokens.divider, width: 1),
                boxShadow: isNeumorphic ? tokens.shadowConvexSubtle : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _WorkImage(
                          photoId: photoIds[index], tokens: tokens),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const ChallengeTagWidget(
                            tag: ChallengeTag(
                              label: '已完成',
                              color: ChallengeTagColor.green,
                              showCheckIcon: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 单张作品图，从 gallery_items 加载真实图片
class _WorkImage extends ConsumerWidget {
  const _WorkImage({required this.photoId, required this.tokens});

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
            color: tokens.divider,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return _placeholder();
        }
        final filePath = item.filePath ?? item.originalPath;
        if (filePath != null && filePath.isNotEmpty) {
          return Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }
        final dataUrl = item.dataUrl;
        if (dataUrl != null && dataUrl.isNotEmpty) {
          try {
            final idx = dataUrl.indexOf('base64,');
            if (idx != -1) {
              final b64 = dataUrl.substring(idx + 7);
              final bytes = Uri.parse('data:;base64,$b64').data!.contentAsBytes();
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              );
            }
          } catch (_) {}
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: tokens.divider,
      child: Icon(Icons.image, color: tokens.textTertiary),
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
          Container(
            width: 24,
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(tip.icon, size: 16, color: colors.icon),
          ),
          const SizedBox(width: 12),
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