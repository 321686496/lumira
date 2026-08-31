import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
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

    // OHOS 滚动优化：把整格照片（含裁切圆角 + 可选遮罩）隔离成独立图层，
    // 滚动时复用缓存层，避免每帧重新合成，降低相册/flutter 网格滚动掉帧。
    return RepaintBoundary(
      child: GestureDetector(
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
    // 走统一加载组件：磁盘缓存 + 按实际渲染尺寸×DPR 降采样（自动识别网络/本地文件）
    return LumiraImage(
      url,
      fit: BoxFit.cover,
      errorWidget: placeholder,
    );
  }
}
