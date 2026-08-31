import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 模板卡片共享徽标组件
///
/// 模板库 / 发现页 / 搜索页的模板卡片统一复用，保证免费/付费/已拍角标视觉完全一致。
/// 叠在封面图上，黑/白半透明遮罩属跨风格通用的「叠加视觉」，不视为主题色。

/// 免费徽标（绿色胶囊，左上角）。
class FreeBadge extends StatelessWidget {
  const FreeBadge({super.key, required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.success.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        '免费',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 付费徽标（品牌渐变 + 积分文案，左上角）。
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.tokens, required this.price});

  final ThemeTokens tokens;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 与 uni-app 一致的渐变品牌徽标
        gradient: LinearGradient(colors: [tokens.brand, tokens.brandDeep]),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        '$price 积分',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 已拍照片数徽标（半透明深色 pill，叠在封面右下角）。
class UsageCountBadge extends StatelessWidget {
  const UsageCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '已拍 $count 张',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
