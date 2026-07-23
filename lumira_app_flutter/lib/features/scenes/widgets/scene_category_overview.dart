import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../capture/data/capture_scene_mock_data.dart';

/// 场景分类概览 section（可在模板 tab 页 / 场景页复用）
///
/// 大卡片 + 瀑布流双列布局，展示 4 个一级场景分类。
class SceneCategoryOverview extends ConsumerWidget {
  const SceneCategoryOverview({super.key, this.compact = false});

  /// compact=true 用于嵌入其他页面（如模板 tab）：缩小高度、隐藏顶部摘要
  final bool compact;

  static const List<_SceneCategoryMeta> _categories = [
    _SceneCategoryMeta(
      id: 'light',
      name: '光线氛围',
      icon: Icons.wb_sunny_outlined,
      desc: '窗光、日落逆光、霓虹与烛光',
      gradient: [Color(0xFFE8B97A), Color(0xFFB8743D)],
      height: 180,
    ),
    _SceneCategoryMeta(
      id: 'outdoor',
      name: '室外环境',
      icon: Icons.landscape_outlined,
      desc: '海边、森林、城市街景',
      gradient: [Color(0xFF8FA06A), Color(0xFF5A7A48)],
      height: 160,
    ),
    _SceneCategoryMeta(
      id: 'indoor',
      name: '室内空间',
      icon: Icons.home_outlined,
      desc: '居家、咖啡馆、影棚',
      gradient: [Color(0xFFC9A96E), Color(0xFF8B7355)],
      height: 170,
    ),
    _SceneCategoryMeta(
      id: 'mood',
      name: '情绪氛围',
      icon: Icons.favorite_outline,
      desc: '治愈、孤独、内心风景',
      gradient: [Color(0xFFC9A0A8), Color(0xFF8C5A66)],
      height: 190,
    ),
  ];

  int _countForCategory(String categoryId) {
    final group = CaptureSceneMockData.categories.firstWhere(
      (g) => g.category.name == categoryId,
      orElse: () => CaptureSceneMockData.categories.first,
    );
    return CaptureSceneMockData.allScenes
        .where((s) => s.category == group.category)
        .length;
  }

  void _goScenesWithCategory(BuildContext context, String categoryId) {
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.scenes, {RouteNames.paramCategory: categoryId}),
    );
  }

  void _goScenesAll(BuildContext context) {
    GoRouter.of(context).push(RouteNames.scenes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    // 瀑布流双列分布
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final card = _SceneCategoryCard(
        meta: cat,
        count: _countForCategory(cat.id),
        tokens: tokens,
        onTap: () => _goScenesWithCategory(context, cat.id),
      );
      if (i % 2 == 0) {
        left.add(card);
      } else {
        right.add(card);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // section 标题
          Row(
            children: [
              Text(
                '场景分类',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _goScenesAll(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.brand,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: tokens.brand),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 瀑布流双列
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 12),
              Expanded(child: Column(children: right)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SceneCategoryMeta {
  const _SceneCategoryMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.gradient,
    required this.height,
  });
  final String id;
  final String name;
  final IconData icon;
  final String desc;
  final List<Color> gradient;
  final double height;
}

/// 分类大卡片
class _SceneCategoryCard extends StatelessWidget {
  const _SceneCategoryCard({
    required this.meta,
    required this.count,
    required this.tokens,
    required this.onTap,
  });

  final _SceneCategoryMeta meta;
  final int count;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: meta.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: meta.gradient.last.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meta.gradient,
                ),
              ),
            ),
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: -16,
              left: -16,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, size: 22, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    meta.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '$count 个场景',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
