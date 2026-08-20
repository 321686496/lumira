import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

class PhotoCell extends ConsumerWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isMultiSelectMode = false,
  });

  final GalleryPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isMultiSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1 / 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(context, tokens),
              if (isMultiSelectMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.brand
                          : Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              if (isSelected)
                Container(
                  color: tokens.brand.withOpacity(0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, ThemeTokens tokens) {
    final url = photo.displayUrl;
    final placeholder = Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
    );
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    // 性能优化：相册为 3 列网格，格子仅约 1/3 屏宽。
    // 只传 cacheWidth（不传 cacheHeight）按「格子实际像素 × DPR」降采样解码，
    // 引擎会按原图宽高比自动计算高度，避免拉伸变形；既省解码量又保比例。
    final mq = MediaQuery.of(context);
    final cellLogical =
        (((mq.size.width - 48 - 12) / 3).clamp(64.0, 300.0)).toDouble();
    final cachePx = (cellLogical * mq.devicePixelRatio).round();
    // frameBuilder：解码完成前先显示占位底色，避免白块闪烁
    Widget buildFrame(BuildContext context, Widget child, int? frame, bool wasSync) {
      return frame == null ? placeholder : child;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: cachePx,
        frameBuilder: buildFrame,
        errorBuilder: (context, error, stack) => placeholder,
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      cacheWidth: cachePx,
      frameBuilder: buildFrame,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
