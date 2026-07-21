import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/templates_mock_data.dart';

/// 用户拍摄偏好卡片
///
/// 视觉规格来源：lumira-app/src/pages/templates/index.vue line 41-53
/// - 仅当 userPreference.totalPhotos > 0 时显示
/// - 卡片: surface 背景，24rpx 圆角，28rpx×32rpx padding
/// - 累计作品行: 左 label 右 val（brand 色 + tabular-nums）
/// - 最常用分类行: 左 label 右 val（brand 色 + 百分比）
class UserPreferenceCard extends ConsumerWidget {
  const UserPreferenceCard({super.key, required this.preference});

  final UserPreference preference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // 32rpx 28rpx → 16 14
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
        boxShadow:
            appTheme.style == UIStyle.neumorphic ? tokens.shadowConvex : null,
      ),
      child: Column(
        children: [
          _PrefRow(
            label: '累计作品',
            value: '${preference.totalPhotos} 张',
            tokens: tokens,
          ),
          const SizedBox(height: 8), // gap: 16rpx → 8dp
          _PrefRow(
            label: '最常用分类',
            value:
                '${TemplatesMockData.categoryLabel(preference.topCategory)} · ${preference.topCategoryPercentage}%',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.label,
    required this.value,
    required this.tokens,
  });

  final String label;
  final String value;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13, // 26rpx → 13dp
            color: tokens.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14, // 28rpx → 14dp
            fontWeight: FontWeight.w600,
            color: tokens.brand,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
