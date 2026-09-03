import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../data/gallery_models.dart';

/// 场景筛选 pills（横向滚动）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/index.vue line 37-51
class SceneFilterPills extends ConsumerWidget {
  const SceneFilterPills({
    super.key,
    required this.pills,
    required this.activeKey,
    required this.onTap,
  });

  final List<SceneFilterPill> pills;
  final String activeKey;
  final void Function(String key) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    return SizedBox(
      height: 36, // 72rpx → 36dp
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8), // 16rpx → 8dp
        itemBuilder: (_, i) {
          final pill = pills[i];
          final isActive = pill.key == activeKey;
          // 方案 B：新拟态选中态与未选中同为表面色，仅将凸起翻转为凹陷内阴影，
          // 品牌色只体现在文字/图标上，不用品牌实底（避免"发光"感）。
          final fg = isNeu
              ? (isActive ? tokens.brandText : tokens.textSecondary)
              : (isActive ? Colors.white : tokens.textSecondary);
          final rowContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pill.icon != null) ...[
                Icon(
                  pill.icon,
                  size: 12, // 24rpx → 12dp
                  color: fg,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                pill.label,
                style: TextStyle(
                  fontSize: 12, // 24rpx → 12dp
                  fontWeight: FontWeight.w500,
                  color: fg,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 4),
              Text(
                '${pill.count}',
                style: TextStyle(
                  fontSize: 11, // 22rpx → 11dp
                  color: isActive
                      ? (isNeu
                          ? tokens.brand.withOpacity(0.75)
                          : Colors.white.withOpacity(0.7))
                      : tokens.textTertiary,
                  height: 1.2,
                ),
              ),
            ],
          );

          final Widget pillContent = isNeu && isActive
              ? RecessedSurface(
                  tokens: tokens,
                  borderRadius: 1000,
                  depth: 0.7,
                  rimFraction: 0.32,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: rowContent,
                  ),
                )
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isNeu
                        ? (isActive ? null : tokens.surface)
                        : (isActive ? tokens.brand : tokens.surface),
                    borderRadius: BorderRadius.circular(1000),
                    border: isNeu
                        ? null
                        : Border.all(
                            color: isActive ? tokens.brand : tokens.divider,
                            width: 1,
                          ),
                    boxShadow: isNeu
                        ? (isActive ? null : tokens.shadowConvexSubtle)
                        : null,
                  ),
                  child: rowContent,
                );

          return GestureDetector(
            onTap: () => onTap(pill.key),
            behavior: HitTestBehavior.opaque,
            child: pillContent,
          );
        },
      ),
    );
  }
}
