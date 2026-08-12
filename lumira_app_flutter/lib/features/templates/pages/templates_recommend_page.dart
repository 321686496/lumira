import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../recommend/recommendation_models.dart';
import '../recommend/recommendation_providers.dart';

/// 为你推荐页
///
/// 纯本地算法推荐（spec 2026-08-12）：
/// 1. 风格分析卡：真实场景风格统计
/// 2. 猜你喜欢：匹配打分 Top（排除已拥有+已用过），支持换一换
/// 3. 旧爱回归：很久前用过 + 近期类型匹配的模板召回
/// 4. 根据最近拍摄：最近照片关联模板推荐
class TemplatesRecommendPage extends ConsumerStatefulWidget {
  const TemplatesRecommendPage({super.key});

  @override
  ConsumerState<TemplatesRecommendPage> createState() =>
      _TemplatesRecommendPageState();
}

class _TemplatesRecommendPageState extends ConsumerState<TemplatesRecommendPage> {
  // 猜你喜欢 / 旧爱回归 的轮换偏移（换一换 = 窗口滑动）
  int _guessOffset = 0;
  int _recallOffset = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final resultAsync = ref.watch(recommendationProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                LumiraNav(
                  title: '为你推荐',
                  transparent: true,
                  leading: _BackButton(
                    tokens: tokens,
                    onTap: () => _back(context),
                  ),
                ),
                Expanded(
                  child: resultAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => _ErrorView(
                      tokens: tokens,
                      message: '推荐数据加载失败',
                      onRetry: () => ref.invalidate(recommendationProvider),
                    ),
                    data: (result) => _buildContent(tokens, result),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeTokens tokens, RecommendationResult result) {
    // 窗口切片（换一换用）：guessLikes 每屏 6，recall 每屏 4
    final guessPage = _slice(result.guessLikes, _guessOffset, 6);
    final recallPage = _slice(result.recall, _recallOffset, 4);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StyleAnalysisCard(
            tokens: tokens,
            scores: result.styleScores,
            coldStart: result.coldStart,
          ),
          _GuessLikesSection(
            tokens: tokens,
            items: guessPage,
            onShuffle: () => setState(() => _guessOffset += 6),
            hasMore: result.guessLikes.length > _guessOffset + 6,
          ),
          if (recallPage.isNotEmpty)
            _RecallSection(
              tokens: tokens,
              items: recallPage,
              onShuffle: () => setState(() => _recallOffset += 4),
              hasMore: result.recall.length > _recallOffset + 4,
            ),
          if (result.recentInfo != null || result.recentRelated.isNotEmpty)
            _RecentShotSection(
              tokens: tokens,
              info: result.recentInfo,
              items: result.recentRelated,
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 从完整候选按偏移取窗口（换一换轮转）
  List<RecommendItem> _slice(List<RecommendItem> all, int offset, int page) {
    if (all.isEmpty) return const [];
    final start = offset % all.length;
    final result = <RecommendItem>[];
    for (var i = 0; i < page && result.length < page; i++) {
      result.add(all[(start + i) % all.length]);
    }
    return result;
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

/// 共享 section 标题（icon + title + 可选 link）
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.tokens,
    this.linkText,
    this.onLinkTap,
  });

  final IconData icon;
  final String title;
  final ThemeTokens tokens;
  final String? linkText;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: tokens.brand, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (linkText != null)
            GestureDetector(
              onTap: onLinkTap ?? () {},
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    linkText!,
                    style: TextStyle(fontSize: 12, color: tokens.brand),
                    maxLines: 1,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: tokens.brand),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Section 1: 风格分析卡（真实风格统计 / 冷启动引导）
class _StyleAnalysisCard extends StatelessWidget {
  const _StyleAnalysisCard({
    required this.tokens,
    required this.scores,
    required this.coldStart,
  });

  final ThemeTokens tokens;
  final List<StyleScore> scores;
  final bool coldStart;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: NeuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette, color: tokens.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '根据你的拍摄风格',
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                coldStart || scores.isEmpty
                    ? '完成 3 张拍摄后生成你的风格分析'
                    : '分析你的真实拍摄记录，我们发现你偏爱以下风格',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              if (scores.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...scores.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                color: tokens.brand, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${s.percent.round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LumiraProgress.linear(
                          value: (s.percent / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section 2: 猜你喜欢（真实推荐 + 换一换）
class _GuessLikesSection extends StatelessWidget {
  const _GuessLikesSection({
    required this.tokens,
    required this.items,
    required this.onShuffle,
    required this.hasMore,
  });

  final ThemeTokens tokens;
  final List<RecommendItem> items;
  final VoidCallback onShuffle;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.favorite_outline,
            title: '猜你喜欢',
            tokens: tokens,
            linkText: '换一换',
            onLinkTap: () {
              if (hasMore) {
                onShuffle();
              } else {
                LumiraToast.show(context, '已展示全部推荐',
                    duration: const Duration(milliseconds: 1000));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => _RecommendCard(
                tokens: tokens,
                item: items[index],
                showMatch: true,
                showUsedCount: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 3: 旧爱回归（很久前用过 + 近期类型匹配）
class _RecallSection extends StatelessWidget {
  const _RecallSection({
    required this.tokens,
    required this.items,
    required this.onShuffle,
    required this.hasMore,
  });

  final ThemeTokens tokens;
  final List<RecommendItem> items;
  final VoidCallback onShuffle;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.restore,
            title: '旧爱回归',
            tokens: tokens,
            linkText: '换一换',
            onLinkTap: () {
              if (hasMore) {
                onShuffle();
              } else {
                LumiraToast.show(context, '已展示全部推荐',
                    duration: const Duration(milliseconds: 1000));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => _RecommendCard(
                tokens: tokens,
                item: items[index],
                showMatch: true,
                showUsedCount: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 推荐模板卡片（猜你喜欢 / 旧爱回归 共用）
class _RecommendCard extends StatelessWidget {
  const _RecommendCard({
    required this.tokens,
    required this.item,
    this.showMatch = false,
    this.showUsedCount = false,
  });

  final ThemeTokens tokens;
  final RecommendItem item;
  final bool showMatch;
  final bool showUsedCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        RouteNames.withTemplateId(RouteNames.templatesDetail, item.templateId),
      ),
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.expand(
                  child: _TemplateCover(item: item),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.price > 0) ...[
                  Text(
                    '${item.price} 积分',
                    style: TextStyle(fontSize: 11, color: tokens.brand),
                  ),
                ] else ...[
                  Text(
                    '免费',
                    style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                  ),
                ],
                const Spacer(),
                if (showMatch)
                  Text(
                    '匹配 ${(item.matchScore * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11, color: tokens.textSecondary),
                  ),
                if (showUsedCount && item.usedCount > 0)
                  Text(
                    '用过 ${item.usedCount} 次',
                    style: TextStyle(
                        fontSize: 11, color: tokens.textSecondary),
                  ),
              ],
            ),
            if (item.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.reason,
                style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 模板封面（支持本地 coverData 与网络 cover）
class _TemplateCover extends StatelessWidget {
  const _TemplateCover({required this.item});
  final RecommendItem item;

  @override
  Widget build(BuildContext context) {
    if (item.coverData != null && item.coverData!.isNotEmpty) {
      return Image.memory(
        base64Decode(item.coverData!),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (item.cover.isNotEmpty) {
      return Image.network(
        item.cover,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(color: const Color(0xFFF0EDE8));
        },
        errorBuilder: (_, __, ___) =>
            Container(color: const Color(0xFFF0EDE8)),
      );
    }
    return Container(color: const Color(0xFFF0EDE8));
  }
}

/// Section 4: 根据最近拍摄
class _RecentShotSection extends StatelessWidget {
  const _RecentShotSection({
    required this.tokens,
    required this.info,
    required this.items,
  });

  final ThemeTokens tokens;
  final RecentInfo? info;
  final List<RecommendItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && info == null) return const SizedBox.shrink();
    return FadeUp(
      delay: const Duration(milliseconds: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.photo_camera,
            title: '根据最近拍摄',
            tokens: tokens,
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                info!.text,
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => _RecommendCard(
                tokens: tokens,
                item: items[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.tokens,
    required this.message,
    required this.onRetry,
  });

  final ThemeTokens tokens;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: tokens.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(fontSize: 14, color: tokens.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
