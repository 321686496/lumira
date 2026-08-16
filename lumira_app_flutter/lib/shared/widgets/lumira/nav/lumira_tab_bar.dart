import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';
import '../_internal/lumira_theme_resolver.dart';

/// 如画应用内嵌 TabBar
///
/// 区别于主导航 FloatingTabBar，本组件用于页面内的 Tab 切换。
/// 视觉规格来源：spec §3.5 LumiraTabBar
///
/// - 选中 tab：tokens.brand 文字 + brand 2dp 下划线
/// - 未选中：tokens.textTertiary 文字，无下划线
/// - tab 文字默认 fontSize 14，选中加粗
/// - 4 风格：glass 风格白透明 0.3 背景 + backdrop blur 10；其他风格透明背景
/// - 下划线位置由 controller.animation 驱动，平滑过渡
class LumiraTabBar extends ConsumerWidget {
  const LumiraTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.onTap,
  });

  final List<Widget> tabs;
  final TabController controller;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final style = appTheme.style;
    final isGlass = style == UIStyle.glass;
    final tabCount = tabs.length;

    Widget bar = LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabCount;
        return SizedBox(
          height: 44,
          child: Stack(
            children: [
              // Tab 项等宽分布
              Row(
                children: List.generate(tabCount, (index) {
                  return Expanded(
                    child: _TabItemView(
                      tab: tabs[index],
                      index: index,
                      controller: controller,
                      tokens: tokens,
                      onTap: () {
                        controller.animateTo(index);
                        onTap?.call(index);
                      },
                    ),
                  );
                }),
              ),
              // 选中下划线（由 controller.animation 驱动）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 2,
                  child: AnimatedBuilder(
                    animation: controller.animation ?? controller,
                    builder: (context, _) {
                      // animation 在 controller 未 attach 时为 null，回退到 index
                      final value =
                          controller.animation?.value ??
                          controller.index.toDouble();
                      // 下划线宽度取 tab 宽的一半，中心对齐到当前选中 tab 的中心。
                      // 直接计算 left，避免 Align 偏移公式未扣除子组件宽度导致的错位。
                      final underlineWidth = tabWidth * 0.5;
                      final left =
                          value * tabWidth + (tabWidth - underlineWidth) / 2;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: left),
                          child: Container(
                            width: underlineWidth,
                            height: 2,
                            decoration: BoxDecoration(
                              color: tokens.brand,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    // glass 风格：白透明 0.3 背景 + backdrop blur 10
    if (isGlass) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(
            color: Colors.white.withOpacity(0.3),
            child: bar,
          ),
        ),
      );
    }

    return bar;
  }
}

class _TabItemView extends StatelessWidget {
  const _TabItemView({
    required this.tab,
    required this.index,
    required this.controller,
    required this.tokens,
    required this.onTap,
  });

  final Widget tab;
  final int index;
  final TabController controller;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: controller.animation ?? controller,
          builder: (context, _) {
            // animation 在 controller 未 attach 时为 null，回退到 index
            final value =
                controller.animation?.value ??
                controller.index.toDouble();
            // 当前 tab 的选中权重：距离动画值越近权重越高
            final selectedness = 1.0 - (value - index).abs().clamp(0.0, 1.0);
            final isSelected = selectedness > 0.5;
            final color = isSelected
                ? LumiraThemeResolver.selectedColor(tokens)
                : LumiraThemeResolver.unselectedTextColor(tokens);
            return DefaultTextStyle.merge(
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: 18),
                child: tab,
              ),
            );
          },
        ),
      ),
    );
  }
}
