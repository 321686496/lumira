import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/home_mock_data.dart';

/// 今日灵感卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 17-37 + style line 326-425
/// - 40rpx→20dp 边距
/// - 40rpx→20dp 圆角（hero-card border-radius 40rpx）
/// - padding 56rpx×48rpx → 28dp×24dp
/// - 背景：linear-gradient(135deg, #FDF6EC 0%, #F5E6CC 100%)
/// - hero-deco：280rpx→140dp 圆形 brand 10% 透明度装饰
class HeroCard extends ConsumerWidget {
  const HeroCard({super.key, required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 20, // 40rpx → 20dp
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24, // 48rpx → 24dp
          vertical: 28, // 56rpx → 28dp
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // 40rpx → 20dp
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDF6EC),
              Color(0xFFF5E6CC),
            ],
          ),
        ),
        child: Stack(
          children: [
            // hero-deco 装饰圆
            Positioned(
              top: -30, // -60rpx → -30dp
              right: -30,
              child: Container(
                width: 140, // 280rpx → 140dp
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.brand.withOpacity(0.10),
                ),
              ),
            ),
            // 内容层
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日期
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14, // 28rpx → 14dp
                      color: tokens.brand,
                    ),
                    const SizedBox(width: 6), // 12rpx → 6dp
                    Text(
                      HomeMockData.heroDateText,
                      style: TextStyle(
                        fontSize: 12, // 24rpx → 12dp
                        color: tokens.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // 20rpx → 10dp
                // 标题
                Text(
                  HomeMockData.heroTitle,
                  style: TextStyle(
                    fontSize: 22, // 44rpx → 22dp
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.01 * 22,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8), // 16rpx → 8dp
                // 描述
                Text(
                  HomeMockData.heroDesc,
                  style: TextStyle(
                    fontSize: 13, // 26rpx → 13dp
                    color: tokens.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20), // 40rpx → 20dp
                // CTA 按钮
                GestureDetector(
                  onTap: onCapture,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24, // 48rpx → 24dp
                      vertical: 12, // 24rpx → 12dp
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tokens.brand,
                          tokens.brandDeep,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 16, // 32rpx → 16dp
                          color: Colors.white,
                        ),
                        SizedBox(width: 8), // 16rpx → 8dp
                        Text(
                          '开始拍摄',
                          style: TextStyle(
                            fontSize: 15, // 30rpx → 15dp
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16), // 32rpx → 16dp
                // 天气
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14, // 28rpx → 14dp
                      color: tokens.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      HomeMockData.heroWeatherText,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
