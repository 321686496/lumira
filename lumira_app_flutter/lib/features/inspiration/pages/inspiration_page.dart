import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../home/widgets/scene_reco_card.dart';
import '../data/inspiration_mock_data.dart';
import '../widgets/mood_card.dart';
import '../widgets/outfit_diary_card.dart';

/// 灵感页
///
/// 视觉规格来源：lumira-app/src/pages/inspiration/index.vue（549 行）
/// - 4 个 section：今日心情 / 穿搭日记 / 推荐场景 / 加载更多
/// - 所有 section 用 FadeUp 错峰入场（d0/d1/d2/d3）
/// - 路由跳转：goSceneDetail(id) → captureSceneDetail?sceneId=xxx；goSceneManage → captureSceneManage
class InspirationPage extends ConsumerWidget {
  const InspirationPage({super.key});

  void _goSceneDetail(BuildContext context, String sceneId) {
    GoRouter.of(context).push(
      '${RouteNames.captureSceneDetail}?${RouteNames.paramSceneId}=$sceneId',
    );
  }

  void _goSceneManage(BuildContext context) {
    GoRouter.of(context).push(RouteNames.captureSceneManage);
  }

  void _goViewDiary(BuildContext context) {
    // uni-app 跳 gallery/diary（查看日记）
    GoRouter.of(context).push(RouteNames.galleryDiary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '灵感', transparent: true),
      body: Container(
        // 径向渐变背景装饰（glass 风格可见性）
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6), // 左上
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), // 48rpx/40rpx → 24dp/16dp
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 今日心情卡片
                const FadeUp(
                  child: MoodCard(),
                ),
                const SizedBox(height: 20), // 40rpx → 20dp
                // 2. 穿搭日记卡片
                FadeUp(
                  delay: const Duration(milliseconds: 100), // fade-up-d1
                  child: OutfitDiaryCard(onViewDiary: () => _goViewDiary(context)),
                ),
                const SizedBox(height: 20),
                // 3. 推荐场景卡片
                FadeUp(
                  delay: const Duration(milliseconds: 200), // fade-up-d2
                  child: _RecommendScenesCard(
                    onSceneTap: (id) => _goSceneDetail(context, id),
                    onMore: () => _goSceneManage(context),
                  ),
                ),
                const SizedBox(height: 20),
                // 4. 加载更多按钮
                const FadeUp(
                  delay: Duration(milliseconds: 300), // fade-up-d3
                  child: _LoadMoreButton(),
                ),
                const SizedBox(height: 16), // 32rpx → 16dp 底部间距
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 推荐场景卡片
class _RecommendScenesCard extends ConsumerWidget {
  const _RecommendScenesCard({required this.onSceneTap, required this.onMore});
  final void Function(String sceneId) onSceneTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 + 副标题
          Row(
            children: [
              Icon(
                Icons.explore_outlined, // ph-compass 替代
                size: 18, // 36rpx → 18dp
                color: tokens.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '根据你的喜好推荐',
                      style: TextStyle(
                        fontSize: 17, // 34rpx → 17dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        fontFamily: 'Noto Serif SC',
                      ),
                    ),
                    const SizedBox(height: 4), // 8rpx → 4dp
                    Text(
                      InspirationMockData.recommendSubtitle,
                      style: TextStyle(
                        fontSize: 12, // 24rpx → 12dp
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // 2x2 场景网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10, // 20rpx → 10dp
            crossAxisSpacing: 10,
            // Forced fix: SceneRecoCard with footer 需要更大文字区
            // 文字区 = 12+14+4+33+6+~28(footer)+14 = ~111dp
            // 图 3:4 占 0.75w，w≈140dp → 图 105dp，文字 111dp，total 216dp
            // childAspectRatio = 140/216 ≈ 0.65... 但实际报错，留 0.46 缓冲
            childAspectRatio: 0.46,
            children: InspirationMockData.scenes.map((inspirationScene) {
              return SceneRecoCard(
                scene: inspirationScene.scene,
                onTap: () => onSceneTap(inspirationScene.scene.id),
                showPhotoCount: false, // 用 footer 替代
                footer: _SceneTagFooter(tagInfo: inspirationScene.tagInfo, photoCount: inspirationScene.scene.photoCount),
              );
            }).toList(),
          ),
          const SizedBox(height: 16), // 40rpx → 16dp
          // 发现更多场景链接
          Center(
            child: GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '发现更多场景',
                    style: TextStyle(
                      fontSize: 13, // 26rpx → 13dp
                      color: tokens.brand,
                    ),
                  ),
                  Icon(Icons.arrow_right_alt, size: 14, color: tokens.brand), // ph-arrow-right 替代
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 场景标签 footer（替代 ScenePresetView #footer slot）
class _SceneTagFooter extends ConsumerWidget {
  const _SceneTagFooter({required this.tagInfo, required this.photoCount});
  final SceneTagInfo tagInfo;
  final int photoCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    // Forced fix（决策 1）: brief 使用 Dart 3 switch 表达式 + 模式匹配（违反 Dart 2.19.6 约束）。
    // 改为传统 if/else 给 tagBg / tagFg 赋值。
    final Color tagBg;
    final Color tagFg;
    if (tagInfo.tagCls == SceneTagType.gold) {
      tagBg = tokens.brandSubtle;
      tagFg = tokens.brandText;
    } else if (tagInfo.tagCls == SceneTagType.red) {
      tagBg = tokens.dangerSubtle;
      tagFg = tokens.danger;
    } else {
      tagBg = tokens.successSubtle;
      tagFg = tokens.success;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), // 20rpx/6rpx → 10dp/3dp
          decoration: BoxDecoration(
            color: tagBg,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: Text(
            tagInfo.tag,
            style: TextStyle(
              fontSize: 11, // 22rpx → 11dp
              fontWeight: FontWeight.w600,
              color: tagFg,
            ),
          ),
        ),
        const SizedBox(width: 8), // 16rpx → 8dp
        // 照片数
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined, // ph-images-square 替代
              size: 12, // 24rpx → 12dp
              color: tokens.brand,
            ),
            const SizedBox(width: 4), // 8rpx → 4dp
            Text(
              '$photoCount',
              style: TextStyle(
                fontSize: 11, // 22rpx → 11dp
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 加载更多灵感按钮
class _LoadMoreButton extends ConsumerWidget {
  const _LoadMoreButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 32rpx/20rpx → 16dp/10dp
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 14, color: tokens.textSecondary), // ph-sparkle 替代
            const SizedBox(width: 6), // 12rpx → 6dp
            Text(
              '加载更多灵感',
              style: TextStyle(
                fontSize: 13, // 26rpx → 13dp
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
