import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 轻量级网络图片缓存
///
/// 使用 dio 下载 + 本地文件缓存，解决 Image.network 重复下载、加载慢的问题。
/// 缓存目录：`<app_cache_dir>/image_cache/`，以 URL 的 hashCode 作为文件名。
///
/// 流程：内存缓存 → 磁盘缓存 → 网络下载。磁盘缓存可跨启动复用，避免每次冷启动重新下载。
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
    // 以完整 URL 的 hashCode 作为缓存文件名（含查询参数，避免同 path 不同参数冲突）。
    // Dart 的 String.hashCode 在同一字符串下是确定的，可作为稳定文件名。
    final hash = url.hashCode.toRadixString(36);
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final ext = path.toLowerCase().contains('.png')
        ? '.png'
        : path.toLowerCase().contains('.webp')
            ? '.webp'
            : path.toLowerCase().contains('.gif')
                ? '.gif'
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
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'image/*, */*;q=0.8'},
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        try {
          final dir = await _getCacheDir();
          await File('${dir.path}/${_urlToHash(url)}').writeAsBytes(
            response.data!,
            flush: true,
          );
        } catch (_) {
          // 写磁盘缓存失败不影响本次展示
        }
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
    final mem = _memoryCache[url];
    if (mem != null) {
      return mem;
    }

    // 2. 磁盘缓存
    try {
      final cachedFile = await _getCachedFile(url);
      if (cachedFile != null) {
        final bytes = await cachedFile.readAsBytes();
        _memoryCache[url] = bytes;
        return bytes;
      }
    } catch (_) {
      // 读取磁盘缓存失败则走下载
    }

    // 3. 下载
    return _downloadAndCache(url);
  }

  /// 清除所有缓存
  static Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// 带缓存 + 自适应降采样的网络图片组件
///
/// 相对 [Image.network] 的改进：
/// - **磁盘缓存**：首次下载后写入本地，后续冷启动直接读磁盘，避免重复下载。
/// - **自动降采样**：内部用 [LayoutBuilder] 按「实际渲染尺寸 × DPR」计算目标解码尺寸并传入
///   [Image.memory] 的 cacheWidth/cacheHeight，网格/缩略图不再按原图全尺寸解码，
///   显著降低解码耗时与内存占用（成片 4000px 在最常见场景下不必全量解码）。
/// - **占位/错误态**：加载中显示占位，失败显示错误占位。
class CachedNetworkImage extends StatefulWidget {
  const CachedNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
  });

  final String url;
  final BoxFit fit;

  /// 展示尺寸（非必填，未传时由父布局约束决定）
  final double? width;
  final double? height;

  /// 强制目标解码尺寸（物理像素）。为 null 时自动按「渲染尺寸 × DPR」计算。
  final int? cacheWidth;
  final int? cacheHeight;

  final BorderRadius? borderRadius;

  /// 加载/解码中的占位 widget（默认是底色块）
  final Widget? placeholder;

  /// 加载失败的占位 widget（默认是图片缺省图标）
  final Widget? errorWidget;

  /// 加载中的底色（placeholder 未提供时使用）
  final Color? backgroundColor;

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _bytes = null;
    });

    if (widget.url.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    final bytes = await ImageCacheUtil.getImageBytes(widget.url);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _failed = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _placeholder();
    if (_failed || _bytes == null) return _error();

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        int? cw = widget.cacheWidth;
        final mw = constraints.maxWidth;
        if (cw == null && mw.isFinite && mw > 0) {
          cw = (mw * dpr).round().clamp(1, 4096);
        }
        int? ch = widget.cacheHeight;
        final mh = constraints.maxHeight;
        if (ch == null && mh.isFinite && mh > 0) {
          ch = (mh * dpr).round().clamp(1, 4096);
        }

        Widget image = Image.memory(
          _bytes!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          cacheWidth: cw,
          cacheHeight: ch,
          gaplessPlayback: true,
          // 解码完成前保留占位，避免白块闪烁
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync || frame != null) return child;
            return _placeholder();
          },
          errorBuilder: (context, error, stack) => _error(),
        );

        if (widget.borderRadius != null) {
          image = ClipRRect(
            borderRadius: widget.borderRadius!,
            child: image,
          );
        }
        return image;
      },
    );
  }

  Widget _placeholder() {
    if (widget.placeholder != null) return widget.placeholder!;
    return ColoredBox(
      color: widget.backgroundColor ?? Colors.white.withOpacity(0.08),
    );
  }

  Widget _error() {
    if (widget.errorWidget != null) return widget.errorWidget!;
    return ColoredBox(
      color: widget.backgroundColor ?? Colors.white.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 16),
      ),
    );
  }
}