import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../data/inspiration_content.dart';
import '../data/inspiration_providers.dart';

class TodayShootSection extends ConsumerWidget {
  const TodayShootSection({
    super.key,
    required this.onItemTap,
    required this.onMoreScenes,
  });

  final void Function(TodayShootItem) onItemTap;
  final VoidCallback onMoreScenes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final async = ref.watch(todayShootProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(tokens: tokens),
        const SizedBox(height: 12),
        async.when(
          loading: () => _Grid(
              items: InspirationContent.todayShootPool.take(4).toList(),
              onItemTap: onItemTap),
          error: (_, __) => _Grid(
              items: InspirationContent.pickTodayShoot(null, DateTime.now()),
              onItemTap: onItemTap),
          data: (items) => _Grid(items: items, onItemTap: onItemTap),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: onMoreScenes,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '查看全部场景',
                  style: TextStyle(fontSize: 13, color: tokens.brand),
                ),
                Icon(Icons.arrow_right_alt, size: 14, color: tokens.brand),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.explore_outlined, size: 18, color: tokens.brand),
        const SizedBox(width: 8),
        Text(
          '今日可拍',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontFamily: 'Noto Serif SC',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: Text(
            '为你而选',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.brandText,
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onItemTap});
  final List<TodayShootItem> items;
  final void Function(TodayShootItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.62,
      children:
          items.map((item) => _Card(item: item, onTap: () => onItemTap(item))).toList(),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.item, required this.onTap});
  final TodayShootItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LumiraSurface(
        radius: 14,
        emphasize: true,
        clip: true,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    item.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                          Icons.image_outlined,
                          size: 28,
                          color: tokens.textTertiary),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.vibe,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
