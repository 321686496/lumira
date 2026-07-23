import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/gallery_models.dart';

/// 相册主页 3 列网格单元
///
/// 视觉规格来源：lumira-app/src/pages/gallery/index.vue line 60-70
/// - 1:1 aspect ratio
/// - 12rpx→6dp 圆角
/// - aspectFill 图片填充
class PhotoCell extends ConsumerWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    required this.onTap,
  });

  final GalleryPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6), // 12rpx → 6dp
        child: AspectRatio(
          aspectRatio: 1 / 1,
          child: _buildImage(tokens),
        ),
      ),
    );
  }

  Widget _buildImage(ThemeTokens tokens) {
    final url = photo.displayUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: tokens.surfaceAlt,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: tokens.textTertiary,
        ),
      );
    }
    // 兼容 dataUrl (http) 和 filePath (本地路径)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: tokens.surfaceAlt,
          child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
        ),
      );
    }
    // 本地文件路径（filePath）— 修复：原代码用 Image.asset，应使用 Image.file
    return Image.file(
      File(url),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
      ),
    );
  }
}
