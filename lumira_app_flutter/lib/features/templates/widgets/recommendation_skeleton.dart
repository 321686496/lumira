// lib/features/templates/widgets/recommendation_skeleton.dart
//
// 「今日为你推荐」加载骨架屏
// 与 RecommendationCard 同构：卡宽 130、封面固定高 172、信息区标题 + 两行理由占位，
// 横向排布 3 张（一屏可见量），列表高度与数据态一致（256），数据到位后不产生跳动。

import 'package:flutter/material.dart';

import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/skeleton.dart';

/// 「今日为你推荐」骨架屏
///
/// 在 todayRecommendationItemsProvider 处于 loading 时替代横向推荐流。
/// 卡片外壳复用 NeuCard，保证四种 UI 风格下与真实卡片的底色/阴影一致；
/// 流光只作用在内部占位块上。
class RecommendationSkeleton extends StatelessWidget {
  const RecommendationSkeleton({
    super.key,
    this.itemCount = 3,
    this.height = 256,
  });

  /// 占位卡片数量
  final int itemCount;

  /// 列表高度（与真实推荐流一致，避免加载完成时布局跳动）
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // 骨架屏不可滑动（真实内容到位后可滑动）
        physics: const NeverScrollableScrollPhysics(),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => const _RecommendationSkeletonCard(),
      ),
    );
  }
}

/// 单张推荐卡骨架：封面块 + 标题条 + 两行理由条
class _RecommendationSkeletonCard extends StatelessWidget {
  const _RecommendationSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130, // 与 RecommendationCard 一致
      child: NeuCard(
        padding: EdgeInsets.zero,
        shadowVariant: NeuShadowVariant.convexSubtle,
        child: SkeletonShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面占位（NeuCard 会裁剪圆角，故此处不单独圆角）
              const SkeletonBox(height: 172, radius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SkeletonBox(width: 84, height: 13, radius: 4), // 模板名
                    SizedBox(height: 8),
                    // 理由行 1 撑满内容宽度（不传 width 时占位块宽度为 0，故显式 infinity）
                    SkeletonBox(width: double.infinity, height: 10, radius: 3),
                    SizedBox(height: 5),
                    SkeletonBox(width: 68, height: 10, radius: 3), // 推荐理由 行2
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
