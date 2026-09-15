import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 首页导航栏右侧操作按钮
///
/// 从 `features/home/pages/home_page.dart` 的 `_NavAction` 提取为公共组件，
/// 目的是让「首页标题样式」选择页的预览能复用**完全同一个**按钮实现——
/// 之前预览里手写了一份图标，图标数量（少了"奖励"入口）和颜色都和首页对不上，
/// 导致预览"不像首页"。提取成公共组件后，首页改了这里就跟着改，不会再次漂移。
///
/// 视觉规格（与首页保持一致，勿随意调整）：
/// - 图标 20dp、颜色 `tokens.textSecondary`
/// - 外圈 8dp 点击热区
/// - [badgeCount] > 0 时在通知图标右上角显示品牌色角标（>99 显示 99+）
class HomeNavAction extends StatelessWidget {
  const HomeNavAction({
    super.key,
    required this.icon,
    required this.tokens,
    this.badgeCount,
    this.onTap,
    this.iconSize = 20,
  });

  final IconData icon;
  final ThemeTokens tokens;

  /// 未读角标数量；<=0 或 null 时不显示角标。
  final int? badgeCount;

  final VoidCallback? onTap;

  /// 图标尺寸。首页固定 20dp；预览场景（卡片内缩略）可传更小值，
  /// 但仅改尺寸、不改配色，保证与首页同源。
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(
      icon,
      size: iconSize, // 40rpx → 20dp
      color: tokens.textSecondary,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: (badgeCount != null && badgeCount! > 0)
            ? Badge(
                label: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    fontSize: 9,
                    color: tokens.textInverse,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: tokens.brand,
                smallSize: 8,
                child: iconWidget,
              )
            : iconWidget,
      ),
    );
  }
}
