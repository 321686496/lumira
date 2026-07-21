import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/templates_browse_mock_data.dart';

/// 为你推荐页
///
/// 视觉规格来源：lumira-app/src/pages/templates/recommend.vue
/// 4 个 section：
/// 1. StyleAnalysisCard（palette 图标 + 根据你的拍摄风格 + 3 个 LinearProgressIndicator）
/// 2. GuessLikesSection（猜你喜欢 + 换一换 link + 2 列网格 6 项）
/// 3. SimilarUsersSection（相似用户也在拍 + 查看全部 link + 2 列网格 4 项，usageCount 用 formatThousands）
/// 4. RecentShotSection（根据最近拍摄 + recent-info-card + 2 列网格 4 项）
///
/// 接收参数：无
class TemplatesRecommendPage extends ConsumerWidget {
  const TemplatesRecommendPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StyleAnalysisCard(tokens: tokens),
                        _GuessLikesSection(tokens: tokens),
                        _SimilarUsersSection(tokens: tokens),
                        _RecentShotSection(tokens: tokens),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.brand,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: tokens.brand,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Section 1: 风格分析卡
class _StyleAnalysisCard extends StatelessWidget {
  const _StyleAnalysisCard({required this.tokens});
  final ThemeTokens tokens;

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
                '分析你过往的 128 张作品，我们发现你偏爱以下风格',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...TemplatesBrowseMockData.styleAnalysis.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(s.icon, color: tokens.brand, size: 16),
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
                            '${s.percent}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.percent / 100,
                          backgroundColor: tokens.surfaceAlt,
                          color: tokens.brand,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section 2: 猜你喜欢
class _GuessLikesSection extends StatelessWidget {
  const _GuessLikesSection({required this.tokens});
  final ThemeTokens tokens;

  void _showSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('换一换功能即将上线'),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            onLinkTap: () => _showSnack(context),
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
                // Forced fix: 0.72 在 360dp 小屏溢出 ~14dp
                // cellWidth=154 → cellHeight(0.66)=233dp，内容=154(图 1:1)+20(padding)+54(3 行文字)=228dp ✓
                childAspectRatio: 0.66,
              ),
              itemCount: TemplatesBrowseMockData.guessLikes.length,
              itemBuilder: (_, index) => _GuessLikeCard(
                tokens: tokens,
                item: TemplatesBrowseMockData.guessLikes[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 3: 相似用户也在拍
class _SimilarUsersSection extends StatelessWidget {
  const _SimilarUsersSection({required this.tokens});
  final ThemeTokens tokens;

  void _showSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('查看全部功能即将上线'),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.group_outlined,
            title: '相似用户也在拍',
            tokens: tokens,
            linkText: '查看全部',
            onLinkTap: () => _showSnack(context),
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
                // Forced fix: 0.72 在 360dp 小屏溢出（_SimilarUserCard 仅 2 行文字但接近边界）
                childAspectRatio: 0.66,
              ),
              itemCount: TemplatesBrowseMockData.similarUsers.length,
              itemBuilder: (_, index) => _SimilarUserCard(
                tokens: tokens,
                item: TemplatesBrowseMockData.similarUsers[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section 4: 根据最近拍摄
class _RecentShotSection extends StatelessWidget {
  const _RecentShotSection({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const recent = TemplatesBrowseMockData.recentShot;
    return FadeUp(
      delay: const Duration(milliseconds: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.history,
            title: '根据最近拍摄',
            tokens: tokens,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _RecentInfoCard(tokens: tokens, info: recent),
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
                // Forced fix: 0.72 在 360dp 小屏溢出 ~14dp（_RecentTemplateCard 3 行文字）
                childAspectRatio: 0.66,
              ),
              itemCount: TemplatesBrowseMockData.recentTemplates.length,
              itemBuilder: (_, index) => _RecentTemplateCard(
                tokens: tokens,
                item: TemplatesBrowseMockData.recentTemplates[index],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// recent-info-card：最近拍摄信息提示
class _RecentInfoCard extends StatelessWidget {
  const _RecentInfoCard({required this.tokens, required this.info});
  final ThemeTokens tokens;
  final RecentShotInfo info;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://picsum.photos/seed/${info.imgSeed}/100/100',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: tokens.surfaceAlt,
                child: Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: tokens.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  info.sub,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                  maxLines: 1,
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

/// 猜你喜欢卡片
class _GuessLikeCard extends StatelessWidget {
  const _GuessLikeCard({required this.tokens, required this.item});
  final ThemeTokens tokens;
  final GuessLikeItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/templates/detail'),
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://picsum.photos/seed/${item.imgSeed}/400/400',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _LevelBadge(
                      tokens: tokens,
                      level: item.level,
                      isGold: item.isGold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.match,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.reason,
                    style: TextStyle(
                      fontSize: 10,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// 相似用户卡片
class _SimilarUserCard extends StatelessWidget {
  const _SimilarUserCard({required this.tokens, required this.item});
  final ThemeTokens tokens;
  final SimilarUserItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/templates/detail'),
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Image.network(
                'https://picsum.photos/seed/${item.imgSeed}/400/400',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: tokens.surfaceAlt,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatThousands(item.usageCount)}+ 用户使用',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.brand,
                    ),
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

/// 最近模板卡片
class _RecentTemplateCard extends StatelessWidget {
  const _RecentTemplateCard({required this.tokens, required this.item});
  final ThemeTokens tokens;
  final RecentTemplateItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/templates/detail'),
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://picsum.photos/seed/${item.imgSeed}/400/400',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _ThemeBadge(tokens: tokens, theme: item.theme),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.match,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.count,
                    style: TextStyle(
                      fontSize: 10,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// 难度 badge（猜你喜欢卡片）
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.tokens,
    required this.level,
    required this.isGold,
  });

  final ThemeTokens tokens;
  final String level; // '易 新手' / '中 进阶' / '中 构图' / '难 大师'
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (lumira-tag-gold / lumira-tag-green)
        color: isGold
            ? const Color(0xFFC9A96E).withOpacity(0.92)
            : const Color(0xFF5A7A48).withOpacity(0.92),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 主题 badge（最近模板卡片）
class _ThemeBadge extends StatelessWidget {
  const _ThemeBadge({required this.tokens, required this.theme});
  final ThemeTokens tokens;
  final String theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.55))
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        theme,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
