import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/templates_providers.dart';
import '../widgets/template_grid.dart';

/// 「我的收藏」页：全部来源（内置/自定义/远程）已收藏模板，按收藏时间倒序。
///
/// 数据源：`favoriteTemplatesProvider`（复用 `template_favorites` + 全池记录）。
/// 复用共享 `TemplateGrid`（瀑布流双列 + 卡片点击进详情）。
class TemplatesFavoritesPage extends ConsumerWidget {
  const TemplatesFavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final favoritesAsync = ref.watch(favoriteTemplatesProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的收藏',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Container(
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
              child: favoritesAsync.when(
                loading: () => Center(
                  child: LumiraProgress.circular(),
                ),
                error: (_, __) => const _EmptyState(),
                data: (items) => items.isEmpty
                    ? const _EmptyState()
                    : SingleChildScrollView(
                        child: TemplateGrid(
                          tokens: tokens,
                          templates: items,
                          usageCounts: const <String, int>{},
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.templates);
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

/// 空态：暂无收藏（含 error 静默降级）。
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: NeuCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 48, color: tokens.textTertiary),
              const SizedBox(height: 12),
              Text(
                '暂无收藏',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '在模板详情页点亮红心，收藏喜欢的模板',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}