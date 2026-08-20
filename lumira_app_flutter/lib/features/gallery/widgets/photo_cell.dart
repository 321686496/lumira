import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
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
    // 走统一缓存组件：磁盘缓存 + 自动按格子尺寸×DPR 降采样，避免重新下载与全尺寸解码
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        url: url,
        fit: BoxFit.cover,
        placeholder: placeholder,
        errorWidget: placeholder,
      );
    }
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}
