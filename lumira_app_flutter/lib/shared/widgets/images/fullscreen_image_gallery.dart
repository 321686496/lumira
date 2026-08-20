import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';

/// 全屏多图查看器
///
/// - 黑底全屏模态（图片查看场景的通用视觉，非主题表面）
/// - `PageView` 左右滑动切换所有照片
/// - 每页 `InteractiveViewer` 双指缩放 / 拖拽
/// - 底部计数器「x / n」、右上角关闭按钮
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
  late final PageController _controller =
      PageController(initialPage: _clamped)..addListener(_onPageChanged);
  late int _index = _clamped;

  void _onPageChanged() {
    final p = _controller.page?.round();
    if (p != null && p != _index) setState(() => _index = p);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final n = widget.urls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片主体：黑底居中，左右滑动 + 缩放拖拽
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: PageView.builder(
                controller: _controller,
                itemCount: n,
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: _buildPhoto(widget.urls[i]),
                ),
              ),
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

  /// 照片渲染：http / data(base64) / 本地文件
  Widget _buildPhoto(String url) {
    final Widget? image = _resolveImage(url);
    final fallback = Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, size: 40, color: Colors.white54),
    );
    return ClipRect(
      child: Center(
        child: (image ?? fallback),
      ),
    );
  }

  Widget? _resolveImage(String url) {
    Widget wrap(ImageProvider provider) => Image(
          image: provider,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined, size: 40, color: Colors.white54),
        );
    if (url.startsWith('http')) {
      return wrap(NetworkImage(url));
    }
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma >= 0 ? url.substring(comma + 1) : url;
      try {
        return wrap(MemoryImage(base64Decode(b64)));
      } catch (_) {
        return null;
      }
    }
    return wrap(FileImage(File(url)));
  }
}