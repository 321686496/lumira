import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';

/// 模板编辑页顶部的横向滚动 Tab 条。
///
/// 一行风格自适应的 chip，随当前 UI 风格 × 主题切换而变化，高亮当前选中 tab。
/// 所有颜色、边框、阴影、圆角一律从 `themeTokensProvider` / `uiStyleProvider`
/// 派生，不硬编码任何皮肤色、不写死阴影。
///
/// Tab 条位于纯色画布上，按「画布取向」渲染：
/// - neumorphic：未选中用 `shadowConvexSubtle` 轻凸起，选中使用**内凹 `shadowConcave`**
///   表达"被按压下去"的激活态（方案 B：与未选中同为表面色，品牌色只在文字）。
/// - flat / glass / female：不使用外阴影，改用「surface + 细边」表达表面。
class EditorTabBar extends ConsumerWidget {
  const EditorTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TabChip(
                label: tabs[i],
                selected: i == index,
                tokens: tokens,
                style: style,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个 Tab chip。选中态用品牌强调色高亮，未选中态用画布表面色。
class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.tokens,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final UIStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final radius = BorderRadius.circular(9999);
    final textColor = _textColor();

    final labelText = Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: textColor,
      ),
    );

    // 新拟态方案 B：未选中轻凸起，选中用凹陷表面（RecessedSurface 沿四边叠加
    // 明暗、中心平底，比单条对角渐变更贴合内凹），品牌色只在文字
    if (style == UIStyle.neumorphic) {
      final Widget chipContent = selected
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: 9999,
              depth: 0.7,
              rimFraction: 0.32,
              child: Padding(padding: pad, child: labelText),
            )
          : Container(
              padding: pad,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: radius,
              ),
              child: labelText,
            );
      return Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: selected ? null : tokens.shadowConvexSubtle,
        ),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: chipContent,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: pad,
        decoration: _decoration(radius),
        child: labelText,
      ),
    );
  }

  Color _textColor() {
    if (!selected) return tokens.textSecondary;
    // 选中态：brandSubtle 底上使用品牌深色文字，保证可读且区别于未选中。
    if (style == UIStyle.female) return tokens.brandDeep;
    return tokens.brandText;
  }

  BoxDecoration _decoration(BorderRadius radius) {
    switch (style) {
      case UIStyle.neumorphic:
        // neumorphic 已在 build 中提前处理（选中用 RecessedSurface 凹陷表面），
        // 此分支不会被调用，仅保留一个等效表面装饰以维持 switch 穷尽性。
        return BoxDecoration(
          color: tokens.surface,
          borderRadius: radius,
          border: null,
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: selected ? tokens.brandSubtle : tokens.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? tokens.brand : tokens.divider,
            width: 1,
          ),
        );
      case UIStyle.glass:
        // 玻璃风格画布上的 chip：半透明表面 + 细边（不做毛玻璃外阴影）。
        return BoxDecoration(
          color: (selected ? tokens.brandSubtle : tokens.surface)
              .withOpacity(0.6),
          borderRadius: radius,
          border: Border.all(
            color: selected ? tokens.brand : tokens.divider,
            width: 1,
          ),
        );
      case UIStyle.female:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [tokens.brandSubtle, Color.lerp(tokens.brandLight, tokens.surface, 0.3)!]
                : [tokens.surface, Color.lerp(tokens.brandSubtle, tokens.surface, 0.7)!],
          ),
          border: Border.all(
            color: selected ? tokens.brand : tokens.divider,
            width: 1,
          ),
        );
    }
  }
}