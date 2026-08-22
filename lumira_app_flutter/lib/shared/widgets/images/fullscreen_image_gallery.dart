import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/theme/theme_controller.dart';

/// 全屏多图查看器（基于 photo_view，手势对齐主流相册/看图 App）
///
/// - 黑底全屏模态（图片查看场景的通用视觉，非主题表面）
/// - 双指捏合缩放（contained ~ 6x）；双击在适配/放大 1:1 间切换
/// - 放大后单指拖动预览图，**不会**误切下一张
/// - 缩回原比例后左右滑动切换照片（带动画）
/// - 单击关闭、右上角关闭按钮、底部计数器「x / n」
///
/// 手势冲突由 [PhotoViewGallery] 内置的复合手势识别器统一仲裁：
/// 缩放阶段（缩放值 >= contained）优先给 pan，未缩放时把横向滑动交给
/// PageView 分页，彻底规避「缩小后拖动立即切图」的误触。
///
/// 数据源同时兼容：http 图片、`data:`（base64）字符串、本地文件路径。
class FullscreenImageGallery extends ConsumerStatefulWidget {
  const FullscreenImageGallery({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  ConsumerState<FullscreenImageGallery> createState() =>
      _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends ConsumerState<FullscreenImageGallery> {
  late final int _clamped =
      widget.urls.isEmpty ? 0 : widget.initialIndex.clamp(0, widget.urls.length - 1);
  late final PageController _controller = PageController(initialPage: _clamped);
  late int _index = _clamped;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  ImageProvider _providerFor(String url) {
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma >= 0 ? url.substring(comma + 1) : url;
      try {
        return MemoryImage(base64Decode(b64));
      } catch (_) {
        // 损坏的 base64：退化为纯黑占位（黑底上几近不可见，仅兜底避免崩溃）
        return MemoryImage(_kTransparentImage);
      }
    }
    return FileImage(File(url));
  }

  static final Uint8List _kTransparentImage = Uint8List(4);

  Widget _broken(BuildContext context, Object error, StackTrace? st) => Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 40, color: Colors.white54),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final n = widget.urls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片主体：黑底居中查看，物理缩放/拖动 + 条件分页（photo_view 统一仲裁手势）
          Positioned.fill(
            child: PhotoViewGallery.builder(
              itemCount: n,
              builder: (_, i) => PhotoViewGalleryPageOptions(
                imageProvider: _providerFor(widget.urls[i]),
                // contained 等价于之前的 1.0 —— 图片适配容器为基准
                minScale: PhotoViewComputedScale.contained,
                maxScale: 6.0,
                filterQuality: FilterQuality.high,
                // 单击关闭（双击缩放不会触发此回调）
                onTapUp: (_, __, ___) => _close(),
                errorBuilder: _broken,
              ),
              pageController: _controller,
              onPageChanged: (i) {
                if (mounted) setState(() => _index = i);
              },
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              scrollPhysics: const PageScrollPhysics(),
            ),
          ),
          // 右上角关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: tokens.textInverse.withOpacity(0.95),
                  size: 20,
                ),
              ),
            ),
          ),
          // 底部计数器
          if (n > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 28,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: Text(
                    '${_index + 1} / $n',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}