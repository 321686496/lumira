import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 底部导航项数据
class LumiraBottomNavItem {
  const LumiraBottomNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final Widget icon;
  final String label;
  final Widget? activeIcon;
}

/// 如画应用统一底部导航栏
///
/// 视觉规格来源：spec §3.5 LumiraBottomNavigationBar
///
/// - 布局：Row 等宽分布，每项 Column(icon + label)
/// - 选中项：icon tokens.brand，label tokens.brandText
/// - 未选中：icon tokens.textTertiary，label tokens.textTertiary
/// - icon size 24，label fontSize 11
/// - 背景：tokens.surface + 顶部 1px tokens.divider 边框
/// - 高度 56 + 底部安全区
/// - 4 风格：glass 风格背景白透明 0.6 + backdrop blur 20
/// - 点击：InkWell，splashColor tokens.brandSubtle
class LumiraBottomNavigationBar extends ConsumerWidget {
  const LumiraBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<LumiraBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final isGlass = style == UIStyle.glass;
    final splashColor = tokens.brandSubtle;

    Widget nav = Container(
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.6) : tokens.surface,
        border: Border(
          top: BorderSide(color: tokens.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: _NavItemView(
                  item: item,
                  isSelected: isSelected,
                  tokens: tokens,
                  splashColor: splashColor,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );

    // glass 风格：backdrop blur 20（背景白透明已由 Container 提供）
    if (isGlass) {
      nav = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: nav,
        ),
      );
    }

    return nav;
  }
}

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.isSelected,
    required this.tokens,
    required this.splashColor,
    required this.onTap,
  });

  final LumiraBottomNavItem item;
  final bool isSelected;
  final ThemeTokens tokens;
  final Color splashColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected
        ? LumiraThemeResolver.selectedColor(tokens)
        : LumiraThemeResolver.unselectedTextColor(tokens);
    final labelColor = isSelected
        ? LumiraThemeResolver.selectedTextColor(tokens)
        : LumiraThemeResolver.unselectedTextColor(tokens);

    final iconWidget = isSelected && item.activeIcon != null
        ? item.activeIcon!
        : item.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: splashColor.withOpacity(0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: IconTheme.merge(
                data: IconThemeData(color: iconColor, size: 24),
                child: iconWidget,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
