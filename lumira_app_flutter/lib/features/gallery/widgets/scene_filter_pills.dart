import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
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
    final tokens = ref.watch(appThemeProvider).tokens;

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
          return GestureDetector(
            onTap: () => onTap(pill.key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(
                  color: isActive ? tokens.brand : tokens.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pill.icon != null) ...[
                    Icon(
                      pill.icon,
                      size: 12, // 24rpx → 12dp
                      color: isActive ? Colors.white : tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    pill.label,
                    style: TextStyle(
                      fontSize: 12, // 24rpx → 12dp
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : tokens.textSecondary,
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
                      color: isActive ? Colors.white.withOpacity(0.7) : tokens.textTertiary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
