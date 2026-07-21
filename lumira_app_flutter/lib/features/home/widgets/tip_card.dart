import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/home_mock_data.dart';

/// 今日拍摄小贴士卡片
///
/// 视觉规格来源：lumira-app/src/pages/home/index.vue line 93-116 + style line 572-664
/// - 28rpx→14dp 圆角
/// - 40rpx→20dp padding
/// - border 2rpx rgba(brand,0.15) → 1dp
/// - 背景 linear-gradient(135deg, #FFFBF5 0%, #FDF6EC 100%)
/// - shadow-convex（这里简化为不带 shadow，用 border 替代避免与背景冲突）
/// - 72rpx→36dp 圆角 20rpx→10dp 图标背景方块
class TipCard extends ConsumerStatefulWidget {
  const TipCard({super.key, required this.onTry});

  final VoidCallback onTry;

  @override
  ConsumerState<TipCard> createState() => _TipCardState();
}

class _TipCardState extends ConsumerState<TipCard> {
  int _tipIndex = 0;

  void _refreshTip() {
    setState(() {
      _tipIndex = (_tipIndex + 1) % HomeMockData.tips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;
    final tip = HomeMockData.tips[_tipIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), // 40rpx → 20dp
      child: Container(
        padding: const EdgeInsets.all(20), // 40rpx → 20dp
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
          // neumorphic 风格：surface 纯色 + 双向阴影，移除渐变和边框
          // 其他风格：保留原渐变 + brand 15% 边框
          color: isNeumorphic ? tokens.surface : null,
          gradient: isNeumorphic
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFBF5),
                    Color(0xFFFDF6EC),
                  ],
                ),
          border: isNeumorphic
              ? null
              : Border.all(
                  color: tokens.brand.withOpacity(0.15),
                  width: 1, // 2rpx → 1dp
                ),
          boxShadow: isNeumorphic ? tokens.shadowConvex : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // tip-head
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标背景方块
                Container(
                  width: 36, // 72rpx → 36dp
                  height: 36,
                  decoration: BoxDecoration(
                    // neumorphic 风格：canvasDeep 内凹阴影方块
                    // 其他风格：brand 12% 半透明背景
                    color: isNeumorphic
                        ? tokens.canvasDeep
                        : tokens.brand.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
                    boxShadow: isNeumorphic
                        ? tokens.shadowConcaveSubtle
                        : null,
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 18, // 36rpx → 18dp
                    color: tokens.brand,
                  ),
                ),
                const SizedBox(width: 12), // 24rpx → 12dp
                // 文字内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日拍摄小贴士',
                        style: TextStyle(
                          fontSize: 15, // 30rpx → 15dp
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6), // 12rpx → 6dp
                      Text(
                        tip.text,
                        style: TextStyle(
                          fontSize: 13, // 26rpx → 13dp
                          color: tokens.textSecondary,
                          height: 1.7,
                        ),
                      ),
                      if (tip.sub.isNotEmpty) ...[
                        const SizedBox(height: 4), // 8rpx → 4dp
                        Text(
                          tip.sub,
                          style: TextStyle(
                            fontSize: 12, // 24rpx → 12dp
                            color: tokens.textTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14), // 28rpx → 14dp
            // tip-btns
            Row(
              children: [
                Expanded(
                  child: _TipButton(
                    icon: Icons.camera_alt_outlined,
                    label: '试试',
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tokens.brand, tokens.brandDeep],
                    ),
                    foregroundColor: Colors.white,
                    onTap: widget.onTry,
                    isNeumorphic: isNeumorphic,
                    tokens: tokens,
                  ),
                ),
                const SizedBox(width: 8), // 16rpx → 8dp
                Expanded(
                  child: _TipButton(
                    icon: Icons.refresh,
                    label: '换一批',
                    backgroundColor: tokens.surfaceAlt,
                    foregroundColor: tokens.textSecondary,
                    onTap: _refreshTip,
                    isNeumorphic: isNeumorphic,
                    tokens: tokens,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TipButton extends StatelessWidget {
  const _TipButton({
    required this.icon,
    required this.label,
    this.gradient,
    this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.isNeumorphic = false,
    this.tokens,
  });

  final IconData icon;
  final String label;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  /// 是否为 neumorphic 风格（影响装饰渲染）
  final bool isNeumorphic;

  /// 主题 tokens（neumorphic 风格下用于读取阴影/颜色）
  final ThemeTokens? tokens;

  @override
  Widget build(BuildContext context) {
    // neumorphic 风格分支：主按钮（gradient != null）用 brand 纯色 + shadowConvex；
    // 次按钮（backgroundColor != null）用 surfaceAlt + shadowConvexSubtle。
    // 其他风格：保持原 gradient/backgroundColor 渲染不变。
    BoxDecoration decoration;
    if (isNeumorphic && tokens != null) {
      if (gradient != null) {
        // 主按钮
        decoration = BoxDecoration(
          color: tokens!.brand,
          borderRadius: BorderRadius.circular(8),
          boxShadow: tokens!.shadowConvex,
        );
      } else {
        // 次按钮
        decoration = BoxDecoration(
          color: tokens!.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          boxShadow: tokens!.shadowConvexSubtle,
        );
      }
    } else {
      decoration = BoxDecoration(
        color: backgroundColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10), // 20rpx → 10dp
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor), // 32rpx → 16dp
            const SizedBox(width: 6), // 12rpx → 6dp
            Text(
              label,
              style: TextStyle(
                fontSize: 13, // 26rpx → 13dp
                fontWeight: FontWeight.w500,
                color: foregroundColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
