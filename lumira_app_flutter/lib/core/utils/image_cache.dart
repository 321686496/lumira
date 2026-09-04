import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    while (_memoryTotalBytes > _maxMemoryTotalBytes && _memoryOrder.isNotEmpty) {
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

  /// 主 URL 加载失败时的回退地址（如缩略图失败回退原图）。
  /// 与 [url] 相同或为空时忽略。
  final String? fallbackUrl;

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

  /// 实际承载滚动的 ScrollPosition（见 [_findEffectivePosition]）。
  ScrollPosition? _pos;

  /// 是否已开始拉取，避免重复触发下载。
  bool _started = false;

  /// 是否已登记过 post-frame 回调，防止重复登记。
  bool _pendingFrameEval = false;

  @override
  void initState() {
    super.initState();
    // 不再在 initState 立即下载。若无有效滚动容器（图片直接展示在屏上），
    // 会在 didChangeDependencies 里 fail-open 直接拉取；否则等进入视口再拉取。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPosition();
  }

  @override
  void dispose() {
    _pos?.removeListener(_onScrollChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // URL 变化视为进入新图：重新走可见性判定（已在屏上则立即拉取新图）。
      _started = false;
      _bytes = null;
      _failed = false;
      _pendingFrameEval = false;
      _evaluateVisibility();
    }
  }

  /// 绑定「实际生效」的滚动位置，并在首次布局后评估一次可见性。
  void _syncPosition() {
    final p = _findEffectivePosition();
    if (!identical(p, _pos)) {
      _pos?.removeListener(_onScrollChanged);
      _pos = p;
      p?.addListener(_onScrollChanged);
    }
    _scheduleFrameEval();
  }

  void _scheduleFrameEval() {
    if (_pendingFrameEval) return;
    _pendingFrameEval = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingFrameEval = false;
      if (mounted) _evaluateVisibility();
    });
  }

  void _onScrollChanged() => _evaluateVisibility();

  /// 从内到外找「真实可滚动」的滚动容器位置。
  ///
  /// 许多页面用 `SingleChildScrollView + Column / shrinkWrap GridView` 包裹，
  /// 这类容器会把整体一次性 build（非懒加载）。这里取第一个实际可滚动的位置，
  /// 用于按滚动偏移判定本组件是否接近视口。固定尺寸（shrinkWrap）的内层
  /// GridView 不参与，直接穿透到外层真正滚动的容器，从而让内层图片也跟随
  /// 外层滚动懒加载。没有可滚动祖先时返回 null（视为直接展示，立即拉取）。
  ScrollPosition? _findEffectivePosition() {
    ScrollPosition? nearest;
    ScrollableState? s = context.findAncestorStateOfType<ScrollableState>();
    while (s != null) {
      final p = s.position;
      nearest ??= p;
      final hasScrollableContent =
          p.hasContentDimensions && p.maxScrollExtent > p.minScrollExtent;
      if (hasScrollableContent) return p;
      s = s.context.findAncestorStateOfType<ScrollableState>();
    }
    return nearest;
  }

  /// 依据滚动偏移判断本组件是否进入「视口 + 预加载余量」，是则开始拉取。
  /// 任何不确定/计算失败都 fail-open（立即拉取），保证图片一定能显示。
  void _evaluateVisibility() {
    if (_started || !mounted) return;

    final pos = _pos;
    if (pos == null) {
      // 不在任何滚动容器内 → 就在屏上，直接拉取。
      _startFetch();
      return;
    }

    final box = context.findRenderObject();
    if (box == null || box is! RenderBox) {
      // 尚未布局，等下一帧再判定。
      _scheduleFrameEval();
      return;
    }

    try {
      final viewport = _viewportFor(pos);
      if (viewport == null) {
        _startFetch();
        return;
      }
      // getOffsetToReveal 会自行累加嵌套滚动层的偏移，得到外层滚动坐标。
      final revealed = viewport.getOffsetToReveal(box, 0.0);
      final top = revealed.offset;
      final bottom = top + box.size.height;
      final vp = pos.pixels;
      final viewportH = pos.viewportDimension;
      // 性能(OHOS): 预加载余量 0.5 屏 → 1.2 屏。ln 引擎 dart:ui 图片解码慢，
      // 若只在"刚好滚进视口"才拉取，解码会直接占用滚动帧导致掉帧；
      // 提前约 1.2 屏拉取，让下载/解码发生在离屏期间，滚到可见时已就绪。
      final margin = viewportH * 1.2;
      final inView = bottom >= vp - margin && top <= vp + viewportH + margin;
      if (inView) _startFetch();
    } catch (_) {
      // 几何计算异常：安全回退为立即拉取。
      _startFetch();
    }
  }

  /// 从滚动位置的 storageContext 向上找其所属的 RenderAbstractViewport，
  /// 保证用「与滚动位置一致的视口」来计算，正确处理嵌套（shrinkWrap 内层）场景。
  /// 找不到时返回 null，由调用方 fail-open 立即拉取。
  RenderAbstractViewport? _viewportFor(ScrollPosition pos) {
    return pos.context.storageContext
        .findAncestorRenderObjectOfType<RenderAbstractViewport>();
  }

  void _startFetch() {
    if (_started) return;
    _started = true;
    _load();
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

    var bytes = await ImageCacheUtil.getImageBytes(widget.url);

    // 主 URL 失败且存在回退地址时，尝试回退原图。
    final fb = widget.fallbackUrl;
    if (bytes == null && fb != null && fb != widget.url && fb.isNotEmpty) {
      bytes = await ImageCacheUtil.getImageBytes(fb);
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
        final wPx = (mw.isFinite && mw > 0)
            ? (mw * dpr).round().clamp(1, 4096)
            : null;
        final hPx = (mh.isFinite && mh > 0)
            ? (mh * dpr).round().clamp(1, 4096)
            : null;

        int? cw = widget.cacheWidth;
        int? ch = widget.cacheHeight;
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
        } else if (cw == null) {
          cw ??= wPx;
        } else {
          ch ??= hPx;
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