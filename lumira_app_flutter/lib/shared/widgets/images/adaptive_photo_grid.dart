import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';

/// 自适应九宫格图片展示
///
/// 渲染规则：
/// - count == 0: 空 SizedBox.shrink
/// - count <= 4: 2 列网格，全部显示
/// - count == 6 / 9: 3 列满网格，无占位
/// - count == 5 / 7 / 8: 3 列网格，最后一行不满时显示 "+1" 占位卡
/// - count > 9: 仅显示前 8 张 + 第 9 格替换为 "+N" 卡片（N = count - 9）
class AdaptivePhotoGrid extends StatelessWidget {
  const AdaptivePhotoGrid({
    super.key,
    required this.urls,
    this.maxDisplay = 9,
    this.onTapOverflow,
    this.spacing = 4.0,
  });

  final List<String> urls;
  final int maxDisplay;
  final VoidCallback? onTapOverflow;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    if (count == 0) return const SizedBox.shrink();

    final crossCount = count <= 4 ? 2 : 3;

    // Corrected displayCount and overflowCount logic:
    // - count > maxDisplay: show (maxDisplay-1) images, last cell is "+(count-maxDisplay)" overflow
    // - count > 4 && count % 3 != 0: show (count-1) images, last cell is "+1" overflow
    // - otherwise: show all images, no overflow
    final int displayCount;
    final int overflowCount;
    if (count > maxDisplay) {
      displayCount = maxDisplay - 1;
      overflowCount = count - maxDisplay;
    } else if (count > 4 && count % 3 != 0) {
      displayCount = count - 1;
      overflowCount = 1;
    } else {
      displayCount = count;
      overflowCount = 0;
    }

    final cells = <Widget>[];
    for (var i = 0; i < displayCount; i++) {
      cells.add(_ImageCell(url: urls[i]));
    }
    if (overflowCount > 0) {
      cells.add(_OverflowCell(count: overflowCount, onTap: onTapOverflow));
    }

    // Cap cell height so very wide grids (e.g. full-width in tests) still fit
    // in a typical viewport; narrow grids (real app inside a card) stay 1:1.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - (crossCount - 1) * spacing) / crossCount;
        const maxCellHeight = 150.0;
        final cellHeight =
            cellWidth > maxCellHeight ? maxCellHeight : cellWidth;
        final aspectRatio = cellWidth / cellHeight;
        return GridView.count(
          crossAxisCount: crossCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: cells,
        );
      },
    );
  }
}

class _ImageCell extends ConsumerWidget {
  const _ImageCell({required this.url});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: _buildImage(tokens),
    );
  }

  Widget _buildImage(ThemeTokens tokens) {
    final fallback = Container(
      color: tokens.divider,
      child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
    );
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        url: url,
        fit: BoxFit.cover,
        errorWidget: fallback,
      );
    }
    // 本地文件路径
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _OverflowCell extends ConsumerWidget {
  const _OverflowCell({required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, color: tokens.textInverse, size: 20),
            const SizedBox(height: 4),
            Text(
              '+$count',
              style: TextStyle(
                color: tokens.textInverse,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
