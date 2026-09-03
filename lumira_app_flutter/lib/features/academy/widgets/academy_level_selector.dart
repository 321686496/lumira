import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../data/academy_models.dart';

/// 难度等级横向选择器（pill 样式）
class AcademyLevelSelector extends ConsumerWidget {
  const AcademyLevelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AcademyLevel? selected; // null = 全部
  final ValueChanged<AcademyLevel?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    final items = <_LevelItem>[
      const _LevelItem(level: null, label: '全部'),
      _LevelItem(level: AcademyLevel.beginner, label: AcademyLevel.beginner.label),
      _LevelItem(level: AcademyLevel.intermediate, label: AcademyLevel.intermediate.label),
      _LevelItem(level: AcademyLevel.advanced, label: AcademyLevel.advanced.label),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item.level == selected;
          // 方案 B：新拟态选中与未选中同为表面色，仅凸起↔凹陷翻转，品牌色只在文字上
          final fg = isNeu
              ? (isSelected ? tokens.brandText : tokens.textSecondary)
              : (isSelected ? tokens.textInverse : tokens.textSecondary);
          return GestureDetector(
            onTap: () => onChanged(item.level),
            child: isNeu && isSelected
                ? RecessedSurface(
                    tokens: tokens,
                    borderRadius: 9999,
                    depth: 0.7,
                    rimFraction: 0.32,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isNeu
                          ? tokens.surface
                          : (isSelected ? tokens.brand : tokens.surface),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
                    ),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _LevelItem {
  final AcademyLevel? level;
  final String label;
  const _LevelItem({required this.level, required this.label});
}
