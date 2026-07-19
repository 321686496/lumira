import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/inspiration_mock_data.dart';

/// 探店打卡卡片
///
/// 视觉规格来源：lumira-app/src/pages/inspiration/index.vue line 102-126
/// - 标题行：「探店打卡」
/// - stat 行：大数字「23」+「个探店足迹」
/// - 3 个 checkin item：彩色图标 + 标题 + 描述 + 箭头
class CheckinCard extends ConsumerWidget {
  const CheckinCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                Icons.place_outlined, // ph-map-pin 替代
                size: 18, // 36rpx → 18dp
                color: tokens.brand,
              ),
              const SizedBox(width: 8),
              Text(
                '探店打卡',
                style: TextStyle(
                  fontSize: 17, // 34rpx → 17dp
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // stat 行
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${InspirationMockData.checkinTotalCount}',
                style: TextStyle(
                  fontSize: 24, // lumira-stat-num 48rpx → 24dp（checkin-stat-num 比 streak 小）
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
              const SizedBox(width: 6), // 12rpx → 6dp
              Text(
                '个探店足迹',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary), // 26rpx → 13dp
              ),
            ],
          ),
          const SizedBox(height: 16), // 32rpx → 16dp
          // checkin list
          Column(
            children: InspirationMockData.checkins.asMap().entries.map((entry) {
              final index = entry.key;
              final checkin = entry.value;
              return _CheckinItem(
                checkin: checkin,
                showTopBorder: index > 0, // 非第一个显示顶部分隔线
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Forced fix（决策 2）: brief 中 _CheckinItem 是 StatelessWidget，无法 ref.watch(appThemeProvider)。
// 改为 ConsumerWidget，与 _OutfitPhotoView 一致，给 title Text 加 color: tokens.textPrimary，
// 给 desc Text 加 color: tokens.textTertiary。
class _CheckinItem extends ConsumerWidget {
  const _CheckinItem({required this.checkin, required this.showTopBorder});
  final CheckinEntry checkin;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12), // 24rpx → 12dp
      decoration: showTopBorder
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEAE5DC), width: 1)), // 2rpx → 1dp，divider 硬编码
            )
          : null,
      child: Row(
        children: [
          // 彩色图标
          Container(
            width: 40, // 80rpx → 40dp
            height: 40,
            decoration: BoxDecoration(
              color: checkin.iconBgColor,
              borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
            ),
            child: Icon(checkin.icon, size: 20, color: checkin.iconColor), // 40rpx → 20dp
          ),
          const SizedBox(width: 12), // 24rpx → 12dp
          // 标题 + 描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkin.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14, // 28rpx → 14dp
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2), // 4rpx → 2dp
                Text(
                  checkin.desc,
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary), // 24rpx → 12dp
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9C9690)), // ph-caret-right 32rpx → 16dp
        ],
      ),
    );
  }
}
