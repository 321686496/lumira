import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 轻量级网络图片缓存
///
/// 使用 dio 下载 + 本地文件缓存，解决 Image.network 重复下载、加载慢的问题。
/// 缓存目录：`<app_cache_dir>/image_cache/`，以 URL 的 MD5 哈希作为文件名。
class ImageCacheUtil {
  ImageCacheUtil._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: 5000,
    receiveTimeout: 10000,
  ));

  static Directory? _cacheDir;
  static final Map<String, Uint8List> _memoryCache = {};

  static Future<Directory> _getCacheDir() async {
    _cacheDir ??= await getTemporaryDirectory();
    final dir = Directory('${_cacheDir!.path}/image_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _urlToHash(String url) {
    // 简单哈希：取 URL 最后一段路径 + 查询参数
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final hash = path.hashCode.abs().toRadixString(16);
    final ext = path.contains('.png')
        ? '.png'
        : path.contains('.webp')
            ? '.webp'
            : '.jpg';
    return '$hash$ext';
  }

  /// 获取缓存文件路径
  static Future<File?> _getCachedFile(String url) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/${_urlToHash(url)}');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// 下载并缓存图片
  static Future<Uint8List?> _downloadAndCache(String url) async {
    try {
      final response = await _dio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        final dir = await _getCacheDir();
        final file = File('${dir.path}/${_urlToHash(url)}');
        await file.writeAsBytes(response.data!);
        _memoryCache[url] = response.data!;
        return response.data;
      }
    } catch (_) {
      // 下载失败，静默忽略
    }
    return null;
  }

  /// 获取图片字节数据（内存缓存 → 磁盘缓存 → 下载）
  static Future<Uint8List?> getImageBytes(String url) async {
    // 1. 内存缓存
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }

    // 2. 磁盘缓存
    final cachedFile = await _getCachedFile(url);
    if (cachedFile != null) {
      final bytes = await cachedFile.readAsBytes();
      _memoryCache[url] = bytes;
      return bytes;
    }

    // 3. 下载
    return _downloadAndCache(url);
  }

  /// 清除所有缓存
  static Future<void> clearCache() async {
    _memoryCache.clear();
    final dir = await _getCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

/// 带缓存的网络图片组件
///
/// 优先从缓存加载，加载失败显示占位符。
class CachedNetworkImage extends StatefulWidget {
  const CachedNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loading = true;
      _bytes = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.url.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final bytes = await ImageCacheUtil.getImageBytes(widget.url);
    if (!mounted) return;

    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: widget.borderRadius,
            ),
          );
    }

    if (_bytes == null) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: widget.borderRadius,
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, color: Colors.white24, size: 16),
            ),
          );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Image.memory(
        _bytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
      ),
    );
  }
}
