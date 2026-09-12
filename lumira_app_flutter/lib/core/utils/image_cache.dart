import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// 由分类图标原图 URL + 分类 key 构造缩略图请求地址。
///
/// 网格/卡片只需要小尺寸封面，让后端按需生成缩略图，可显著减少首次加载
/// 的下载字节量（避免把后台上传的全尺寸原图整张拉下来）。
/// 若 [iconUrl] 为空则原样返回，由上层走内置 Material Icon 兜底。
String categoryThumbUrl(String iconUrl, String key, {int w = 600}) {
  if (iconUrl.isEmpty || key.isEmpty) return iconUrl;
  return '${AppConfig.baseUrl}/thumbs/categories/$key?w=$w';
}

/// Rewrite stored template image URLs to a backend WebP variant.
String templateThumbUrl(
  String url, {
  String? baseUrl,
  int w = 800,
}) {
  if (url.isEmpty ||
      url.contains('/api/v1/thumbs/templates/') ||
      !url.contains('/uploads/templates/')) {
    return url;
  }

  const marker = '/uploads/templates/';
  final relative = url.substring(url.indexOf(marker) + marker.length);
  final cleanPath = relative.split('?').first.split('#').first;
  final parts = cleanPath.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length != 2) return url;
  final templateId = parts[0];
  final filename = parts[1];
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$', caseSensitive: false)
      .hasMatch(templateId)) {
    return url;
  }
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$', caseSensitive: false)
      .hasMatch(filename)) {
    return url;
  }

  final base = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');
  return '$base/thumbs/templates/$templateId/$filename?w=$w';
}

/// 轻量级网络图片缓存
///
/// 使用 dio 下载 + 本地文件缓存，解决 Image.network 重复下载、加载慢的问题。
/// 缓存目录：`<app_cache_dir>/image_cache/`，以 URL 的 hashCode 作为文件名。
///
/// 流程：内存缓存 → 磁盘缓存 → 网络下载。磁盘缓存可跨启动复用，避免每次冷启动重新下载。
///
/// 2026-08 优化：加大下载超时 + 失败重试（修复"大图加载不出来"）；同一 URL
/// 并发只下载一次（去重）；新增 [prefetch] 供网格可见时提前暖缓存；内存缓存带
/// 大小上限与 FIFO 淘汰，避免全尺寸大图常驻内存导致 OOM。
class ImageCacheUtil {
  ImageCacheUtil._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: 8000,
    receiveTimeout: 30000,
  ));

  static Directory? _cacheDir;
  static final Map<String, Uint8List> _memoryCache = {};

  /// 正在下载中的 URL → Future，避免同一 URL 被并发重复下载。
  static final Map<String, Future<Uint8List?>> _inflight = {};

  /// 内存缓存 FIFO 淘汰顺序（记录 URL 插入顺序）。
  static final List<String> _memoryOrder = [];

  /// 单文件超过该字节数时不进内存缓存（仅磁盘），避免大图常驻内存。
  static const int _maxMemoryEntryBytes = 1024 * 1024;

  /// 内存缓存总字节上限，超出后按 FIFO 淘汰最旧条目。
  static const int _maxMemoryTotalBytes = 64 * 1024 * 1024;
  static int _memoryTotalBytes = 0;

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

  /// 下载并缓存图片（失败自动重试，最多 3 次）。
  static Future<Uint8List?> _downloadAndCache(String url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _dio.get<Uint8List>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Accept': 'image/*, */*;q=0.8'},
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          final bytes = response.data!;
          try {
            final dir = await _getCacheDir();
            await File('${dir.path}/${_urlToHash(url)}').writeAsBytes(
              bytes,
              flush: true,
            );
          } catch (_) {
            // 写磁盘缓存失败不影响本次展示
          }
          _storeMemory(url, bytes);
          return bytes;
        }
      } catch (_) {
        // 下载失败，等待后重试
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return null;
  }

  /// 写入内存缓存（带大小上限 + FIFO 淘汰）。
  static void _storeMemory(String url, Uint8List bytes) {
    final size = bytes.length;
    if (size > _maxMemoryEntryBytes) return; // 大图只走磁盘缓存
    if (_memoryCache.containsKey(url)) return;
    _memoryCache[url] = bytes;
    _memoryOrder.add(url);
    _memoryTotalBytes += size;
    while (
        _memoryTotalBytes > _maxMemoryTotalBytes && _memoryOrder.isNotEmpty) {
      final oldest = _memoryOrder.removeAt(0);
      final removed = _memoryCache.remove(oldest);
      if (removed != null) _memoryTotalBytes -= removed.length;
    }
  }

  /// 获取图片字节数据（内存缓存 → 磁盘缓存 → 下载，下载去重）
  static Future<Uint8List?> getImageBytes(String url) async {
    if (url.isEmpty) return null;

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
        _storeMemory(url, bytes);
        return bytes;
      }
    } catch (_) {
      // 读取磁盘缓存失败则走下载
    }

    // 3. 下载（同一 URL 并发共享同一次下载）
    return _inflight[url] ??= _downloadAndCache(url).whenComplete(() {
      _inflight.remove(url);
    });
  }

  /// 预取一组图片 URL（限并发），用于网格/列表可见时提前暖缓存。
  ///
  /// [concurrency] 默认 3：避免一次性开太多连接把弱网打爆，导致全部超时。
  /// 已缓存/已下载的 URL 会命中缓存直接返回，重复调用是幂等的。
  static Future<void> prefetch(
    List<String> urls, {
    int concurrency = 3,
  }) async {
    final pending = urls.where((u) => u.isNotEmpty).toList();
    if (pending.isEmpty) return;
    final workers = concurrency.clamp(1, 6);
    var index = 0;
    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= pending.length) return;
        await getImageBytes(pending[i]);
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
  }

  /// 定向失效单个 URL 的缓存（内存 + 磁盘）。
  ///
  /// 用于线上资源变更/删除时精准清除旧字节缓存，避免已失效的图片继续被展示。
  /// 在途下载（_inflight）也会被取消，下次请求会真正回源。
  static Future<void> invalidate(String url) async {
    if (url.isEmpty) return;
    _removeMemoryEntry(url);
    if (_memoryTotalBytes < 0) _memoryTotalBytes = 0;
    _inflight.remove(url);
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/${_urlToHash(url)}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 磁盘缓存删除失败不影响后续（内存已清，下次会重新下载覆盖）
    }
  }

  /// 定向失效一组 URL 的缓存（内存 + 磁盘）。
  ///
  /// 用于模板同步后一次性清理该模板的封面/效果图/剪影等所有图片资源缓存。
  static Future<void> invalidateMany(Iterable<String> urls) async {
    final unique = urls.where((u) => u.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return;
    for (final u in unique) {
      _removeMemoryEntry(u);
      _inflight.remove(u);
    }
    _recomputeMemoryBytes();
    try {
      final dir = await _getCacheDir();
      for (final u in unique) {
        final file = File('${dir.path}/${_urlToHash(u)}');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// 从内存缓存中移除单个 URL（并同步维护总量/顺序）。
  static void _removeMemoryEntry(String url) {
    final removed = _memoryCache.remove(url);
    if (removed != null) _memoryTotalBytes -= removed.length;
    _memoryOrder.remove(url);
  }

  /// 重新计算内存缓存总量，防止增量维护产生漂移。
  static void _recomputeMemoryBytes() {
    var total = 0;
    for (final b in _memoryCache.values) {
      total += b.length;
    }
    _memoryTotalBytes = total;
  }

  /// 清除所有缓存
  static Future<void> clearCache() async {
    _memoryCache.clear();
    _memoryOrder.clear();
    _memoryTotalBytes = 0;
    _inflight.clear();
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// 当前内存缓存占用字节数（供设置页/缓存页展示）。
  static int get memoryCacheBytes => _memoryTotalBytes;

  /// 计算磁盘图片缓存目录总大小（字节）。
  /// 用于缓存详情页展示"图片缓存（磁盘）"占用。
  static Future<int> calculateDiskCacheBytes() async {
    try {
      final dir = await _getCacheDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 仅清空内存缓存（不动磁盘文件），供缓存页「内存缓存」单项清理。
  static void clearMemoryOnly() {
    _memoryCache.clear();
    _memoryOrder.clear();
    _memoryTotalBytes = 0;
    _inflight.clear();
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
    this.fallbackUrl,
    this.loader,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
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

  /// 主 URL 加载失败时的回退地址（如缩略图失败回退原图）。
  /// 与 [url] 相同或为空时忽略。
  final String? fallbackUrl;

  final Future<Uint8List?> Function(String url)? loader;

  final BoxFit fit;
  final AlignmentGeometry alignment;

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
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // URL changed: discard the previous bytes and start a fresh request.
      _bytes = null;
      _failed = false;
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

    final requestId = ++_requestId;
    final loadBytes = widget.loader ?? ImageCacheUtil.getImageBytes;
    var bytes = await loadBytes(widget.url);
    if (!mounted || requestId != _requestId) return;

    // 主 URL 失败且存在回退地址时，尝试回退原图。
    final fb = widget.fallbackUrl;
    if (bytes == null && fb != null && fb != widget.url && fb.isNotEmpty) {
      bytes = await loadBytes(fb);
      if (!mounted || requestId != _requestId) return;
    }

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
        final mw = constraints.maxWidth;
        final mh = constraints.maxHeight;
        final wPx =
            (mw.isFinite && mw > 0) ? (mw * dpr).round().clamp(1, 4096) : null;
        final hPx =
            (mh.isFinite && mh > 0) ? (mh * dpr).round().clamp(1, 4096) : null;

        int? cw = widget.cacheWidth;
        int? ch = widget.cacheHeight;
        // 性能(Forced fix): 父级约束为「无限」时对应边长算不出，若不兜底会按
        // 原图全尺寸解码（后端封面可达 4000px），OHOS 软件解码下是解码突刺来源。
        // 以「屏幕宽度×DPR」为目标上限兜底：图片不可能显示超过一屏宽，
        // 既避免全尺寸解码，也不会低于实际渲染尺寸导致发虚。
        final cappedScreen =
            (MediaQuery.of(context).size.width * dpr).round().clamp(1, 4096);
        if (cw == null && ch == null) {
          // 只传「较大物理边长」一个维度做解码降采样，另一维度由引擎按原图宽高比推导。
          // 若同时传 cacheWidth+cacheHeight，Flutter 会把解码图强制拉伸成容器比例——
          // 当容器比例与图片原始比例不一致（如模板宽高比 16:9、封面实拍 4:3）时，
          // 图片会被拉伸变形（模板详情封面"被拉伸"的根因）。
          if (wPx != null && hPx != null) {
            if (wPx >= hPx) {
              cw = wPx;
            } else {
              ch = hPx;
            }
          } else if (wPx != null) {
            cw = wPx;
          } else {
            ch = hPx;
          }
          if (cw == null && ch == null) cw = cappedScreen;
        } else if (cw != null && ch != null) {
          if (cw >= ch) {
            ch = null;
          } else {
            cw = null;
          }
        }

        Widget image = Image.memory(
          _bytes!,
          fit: widget.fit,
          alignment: widget.alignment,
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
        // 栅格化隔离：把图片独立成一层。滚动/外层动画时，合成器只平移/变换
        // 这一层，而不必每帧重新光栅化整张照片（OHOS 上多图滚动卡顿的主因）。
        return RepaintBoundary(child: image);
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
