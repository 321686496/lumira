import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/ohos_image_processor.dart';
import '../domain/photo_template.dart';
import '../services/preview_beauty_shader.dart'
    show loadFragmentProgramFromCandidates;

/// 编辑页细节效果（锐化/磨皮/暗角/颗粒/拉腿）实时预览的参数包。
///
/// 语义为【增量】：底层照片已烘焙 baked 基线效果，本层叠加 local − baked 的差值
/// （与 [PostProcess] 增量模型的 smoothStrength/sharpen/vignette/grain/legStretch
/// 字段一致）。负增量由 shader 以可逆近似处理（负锐化=软化、负暗角=提亮四角、
/// 负拉腿=压缩回去、负颗粒=反相噪声）；负磨皮无效果（烘焙磨皮无法撤销）。
class DetailEffectsParams {
  const DetailEffectsParams({
    this.sharpen = 0,
    this.smoothStrength = 0,
    this.vignette = 0,
    this.grain = 0,
    this.legStretch = 0,
  });

  final int sharpen;
  final int smoothStrength;
  final int vignette;
  final int grain;
  final int legStretch;

  factory DetailEffectsParams.fromPostProcess(PostProcess p) =>
      DetailEffectsParams(
        sharpen: p.sharpen,
        smoothStrength: p.smoothStrength,
        vignette: p.vignette,
        grain: p.grain,
        legStretch: p.legStretch,
      );

  /// 是否有任一非零增量（全零时上层可直接走原图片路径，不进 shader）。
  bool get hasAnyEffect =>
      sharpen != 0 ||
      smoothStrength != 0 ||
      vignette != 0 ||
      grain != 0 ||
      legStretch != 0;

  /// 输出画布宽高比：拉腿改变高度（满档 ±20%），其余效果不改变几何。
  double outputAspect(double srcW, double srcH) {
    final s = (legStretch / 100.0).clamp(-1.0, 1.0).toDouble();
    final outH = srcH * (1.0 + s * 0.20);
    return srcW / outH;
  }
}

/// 进程级单例：128×128 噪声 tile（LCG 0x85EBCA6B，与成片管线
/// dart_photo_pipeline._ensureGrainTile / OHOS C++ / iOS 同分布）。
Future<ui.Image>? _noiseTileFuture;
ui.Image? _noiseTileCache;

Future<ui.Image> loadGrainNoiseTile() async {
  final cached = _noiseTileCache;
  if (cached != null) return cached;
  return _noiseTileFuture ??= () async {
      const size = 128;
      final data = Uint8List(size * size * 4);
      var seed = 0x85EBCA6B;
      var i = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
          final rnd = ((seed >> 8) & 0xFFFF) / 65535.0; // 0..1
          final b = (rnd * 255.0).round().clamp(0, 255);
          data[i++] = b; // R：shader 内 g*2-1
          data[i++] = b;
          data[i++] = b;
          data[i++] = 255;
        }
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(data);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: size,
        height: size,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      _noiseTileCache = image;
      return image;
    }();
}

/// 进程级单例：编辑页细节效果 shader 程序。
Future<ui.FragmentProgram?>? _programFuture;

/// 预热解码缓存：url → 已解码 ui.Image。由 [DetailEffectsLayer.prewarm] 写入、
/// 层首次 _decode「采用即取走」（remove）——同一 ui.Image 实例只归一个层所有，
/// 避免双重 dispose。上限 [_kMaxPrewarmedImages]，淘汰即 dispose。
final Map<String, ui.Image> _prewarmedImages = <String, ui.Image>{};
const int _kMaxPrewarmedImages = 3;

/// OHOS 原生预览源缓存：url → cacheId 获取 future（进程级共享）。
///
/// prewarm 与层 _decode 共用同一 future：同一 url 只触发一次原生解码；
/// 层释放时同步移除该条目（配合原生 releaseDetailSource），后续同 url
/// 重新进缓存。原生侧另有 LRU 上限兜底。
final Map<String, Future<String?>> _ohosCacheFutures = <String, Future<String?>>{};

Future<String?> obtainOhosDetailCache(String url, int maxEdge) {
  if (!OhosImageProcessor.isSupported) return Future.value(null);
  return _ohosCacheFutures.putIfAbsent(url, () {
    // catchError 兜底：任何异常都归 null（层侧自然回退 shader/原图路径）
    return OhosImageProcessor.instance
        .cacheDetailSource(path: url, maxEdge: maxEdge)
        .then((r) => r?.cacheId)
        .catchError((Object _) => null);
  });
}

/// 释放 url 对应的原生预览源缓存（层销毁/换图时调用）。
void releaseOhosDetailCache(String url) {
  final future = _ohosCacheFutures.remove(url);
  if (future == null) return;
  future.then((cacheId) {
    if (cacheId != null) {
      OhosImageProcessor.instance.releaseDetailSource(cacheId);
    }
  }).catchError((Object _) {});
}

Future<ui.FragmentProgram?> _loadDetailProgram() =>
    // 首选带 assets/ 前缀的 asset key：pubspec.yaml shaders 段声明的路径
    // 原样保留为编译产物的 asset key（AssetManifest 中为
    // assets/shaders/edit_detail_effects.frag，iOS/Android/OHOS 一致）。
    // 无前缀路径仅作工具链行为变化时的兜底。
    // 失败（null）不进缓存，避免首载偶发失败后本进程永久回退原图。
    _programFuture ??= loadFragmentProgramFromCandidates(
      const [
        'assets/shaders/edit_detail_effects.frag',
        'shaders/edit_detail_effects.frag',
      ],
    ).then((prog) {
      if (prog == null) _programFuture = null;
      return prog;
    });

Future<ui.FragmentProgram?>? _coreProgramFuture;

Future<ui.FragmentProgram?> _loadCoreDetailProgram() =>
    _coreProgramFuture ??= loadFragmentProgramFromCandidates(
      const [
        'assets/shaders/edit_smooth_sharpen.frag',
        'shaders/edit_smooth_sharpen.frag',
      ],
    ).then((prog) {
      if (prog == null) _coreProgramFuture = null;
      return prog;
    });

/// 从来源字节解码出 GPU-backed [ui.Image]（data:/本地文件）。
/// 失败或来源类型不受支持时返回 null（调用方走原图降级）。
/// 模块级函数：[DetailEffectsLayer.prewarm] 与层 State 共用同一实现。
Future<ui.Image?> decodeDetailEffectsSource(String url, int maxEdge) async {
  if (url.isEmpty) return null;

  // OHOS：dart:ui 的 JPEG 软件解码极慢（实测 1200x1600 约 6s），解码期间
  // 每帧都走 fallback 原图，表现为"拖动磨皮/锐化滑块无实时变化"。优先走
  // 系统硬解（DCT 降采样，一次解码到 maxEdge），失败回退 dart:ui。
  // 同 watermark_animation_overlay._decodeSource 的已验证模式。
  if (OhosImageProcessor.isSupported &&
      !url.startsWith('data:') &&
      !url.startsWith('assets/') &&
      !url.startsWith('http://') &&
      !url.startsWith('https://')) {
    final decoded = await _decodeViaOhosNative(url, maxEdge);
    if (decoded != null) return decoded;
    debugPrint('[detail-effects] OHOS native decode failed, fallback dart:ui');
  }

  Uint8List bytes;
  try {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      bytes = base64Decode(comma >= 0 ? url.substring(comma + 1) : url);
    } else if (url.startsWith('assets/') ||
        url.startsWith('http://') ||
        url.startsWith('https://')) {
      return null;
    } else {
      bytes = File(url).readAsBytesSync();
    }
  } catch (_) {
    return null;
  }

  late ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final longest = math.max(img.width, img.height);
    if (longest <= maxEdge) {
      codec.dispose();
      return img;
    }
    final scale = maxEdge / longest;
    codec.dispose();
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: (img.width * scale).round(),
      targetHeight: (img.height * scale).round(),
    );
    final frame2 = await codec.getNextFrame();
    final resized = frame2.image;
    codec.dispose();
    img.dispose();
    return resized;
  } catch (_) {
    try {
      codec.dispose();
    } catch (_) {}
    return null;
  }
}

/// OHOS 系统硬解路径：JPEG → RGBA 由原生 image.ImageSource 完成
/// （desiredSize 为 DCT 域降采样，锐度优于事后像素缩放）。
Future<ui.Image?> _decodeViaOhosNative(String path, int maxEdge) async {
  final result = await OhosImageProcessor.instance.decodeJpegToRgba(
    path: path,
    targetWidth: maxEdge,
    targetHeight: maxEdge,
  );
  if (result == null) return null;
  try {
    return await _rgbaBytesToUiImage(result.rgba, result.width, result.height);
  } catch (e) {
    debugPrint('[detail-effects] rgba→image failed: $e');
    return null;
  }
}

/// RGBA 字节直建 [ui.Image]（ImmutableBuffer + ImageDescriptor.raw）。
Future<ui.Image> _rgbaBytesToUiImage(
  Uint8List rgba,
  int width,
  int height,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  buffer.dispose();
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final image = frame.image;
  descriptor.dispose();
  codec.dispose();
  return image;
}

/// 编辑页细节效果实时预览层：单 pass fragment shader 完成
/// 拉腿(几何) → 锐化 → 颗粒 → 磨皮 → 暗角，数值语义与四端成片管线统一
///（见 edit_detail_effects.frag 头注释）。
///
/// 结构与 [SmoothImageLayer] 同源：
/// - 来源字节解码为 GPU-backed [ui.Image]（最长边封顶 [maxEdge]），滑块拖动
///   仅更新 [effects]，复用已解码图像不重复解码；
/// - 解码未就绪/失败/来源为 http → 回退 [fallback]，不白屏不阻塞；
/// - shader 加载失败 → 回退 [fallback]（画原图）。
class DetailEffectsLayer extends StatefulWidget {
  const DetailEffectsLayer({
    super.key,
    required this.url,
    required this.effects,
    required this.fallback,
    this.maxEdge = 2048,
  });

  final String url;
  final DetailEffectsParams effects;

  /// 解码未就绪/失败时回退到的基础图片 widget。
  final Widget Function() fallback;

  /// 解码最长边封顶，减少内存与耗时（源字节解码，非 GPU 读回）。
  final int maxEdge;

  /// 预热：提前解码 [url] 并加载 shader 程序（编辑页进入时调用）。
  ///
  /// 动机：滑块首次拖动时 DetailEffectsLayer 才进入 widget 树，若此刻才开始
  /// 解码，拖动期间一直显示 fallback 原图，表现为「拖动磨皮/锐化滑块无实时
  /// 变化」。页面加载完成后调用本方法，首次拖动即命中 [url] 的预热缓存。
  static Future<void> prewarm(String url, {int maxEdge = 2048}) async {
    // shader 程序为进程级单例，预热即触发加载。
    _loadDetailProgram();
    _loadCoreDetailProgram();
    if (url.isEmpty || url.startsWith('http')) return;
    // OHOS：同时预热原生预览源缓存（原生实时预览渲染复用该缓存）
    if (OhosImageProcessor.isSupported) {
      obtainOhosDetailCache(url, maxEdge);
    }
    if (_prewarmedImages.containsKey(url)) return;
    try {
      final img = await decodeDetailEffectsSource(url, maxEdge);
      if (img == null) return;
      if (_prewarmedImages.containsKey(url)) {
        img.dispose();
        return;
      }
      _prewarmedImages[url] = img;
      while (_prewarmedImages.length > _kMaxPrewarmedImages) {
        final oldestKey = _prewarmedImages.keys.first;
        _prewarmedImages.remove(oldestKey)?.dispose();
      }
      debugPrint('[edit-diag] prewarmed detail effects image: $url');
    } catch (e) {
      debugPrint('[detail-effects] prewarm failed (ignored): $e');
    }
  }

  @override
  State<DetailEffectsLayer> createState() => _DetailEffectsLayerState();
}

class _DetailEffectsLayerState extends State<DetailEffectsLayer> {
  ui.Image? _image;
  String? _decodingUrl;
  ui.FragmentProgram? _program;
  ui.FragmentProgram? _coreProgram;

  // ── OHOS 原生实时预览（与成片同一 C++ 管线）──
  // flutter_ohos 上 Dart FragmentShader 在部分真机静默渲染为原图，拖动滑块
  // 照片无变化；该路径用原生 processRgba 增量渲染保证实时效果可见。
  String? _ohosCacheId;
  ui.Image? _previewImage;
  int _previewSig = -1;
  bool _rendering = false;
  DetailEffectsParams? _pending;

  /// 当前效果参数指纹（用于跳过重复渲染；各字段钳到 0-255 后按 8 位错开，
  /// 负增量与 0 同签 —— 原生渲染本就把负增量钳为无效果，视觉等价）。
  static int _sigOf(DetailEffectsParams e) =>
      (e.sharpen.clamp(0, 255) << 24) |
      (e.smoothStrength.clamp(0, 255) << 16) |
      (e.vignette.clamp(0, 255) << 8) |
      e.grain.clamp(0, 255);

  @override
  void initState() {
    super.initState();
    _decode();
    _loadProgram();
    _loadCoreProgram();
  }

  @override
  void didUpdateWidget(DetailEffectsLayer old) {
    super.didUpdateWidget(old);
    // 仅来源变化才重新解码；effects 变化复用已解码 _image，
    // build 自动以新参数触发 shader 重绘。
    if (old.url != widget.url) {
      final oldImg = _image;
      _image = null;
      oldImg?.dispose();
      _resetOhosPreview(oldUrl: old.url);
      _decode();
    } else if (_sigOf(old.effects) != _sigOf(widget.effects)) {
      _scheduleOhosRender();
    }
  }

  @override
  void dispose() {
    _resetOhosPreview(oldUrl: widget.url);
    _image?.dispose();
    super.dispose();
  }

  /// 释放 OHOS 原生预览状态（换图/销毁时调用）。
  /// [oldUrl] 为缓存所属的来源 url（换图时是旧 url，dispose 时是当前 url）。
  void _resetOhosPreview({required String oldUrl}) {
    final cacheId = _ohosCacheId;
    _ohosCacheId = null;
    _previewImage?.dispose();
    _previewImage = null;
    _previewSig = -1;
    _pending = null;
    _rendering = false;
    if (cacheId != null) {
      releaseOhosDetailCache(oldUrl);
    }
  }

  /// 调度一次原生渲染：渲染中则合并（保留最新参数），空闲则立即执行。
  void _scheduleOhosRender() {
    if (!OhosImageProcessor.isSupported || _ohosCacheId == null) return;
    final params = widget.effects;
    if (!params.hasAnyEffect) return;
    if (_sigOf(params) == _previewSig && !_rendering) return;
    if (_rendering) {
      _pending = params;
      return;
    }
    _startOhosRender(params);
  }

  /// 原生 C++ 渲染一帧细节效果预览（磨皮/锐化/暗角/颗粒增量）。
  Future<void> _startOhosRender(DetailEffectsParams params) async {
    final cacheId = _ohosCacheId;
    if (cacheId == null || _rendering) return;
    _rendering = true;
    ui.Image? rendered;
    try {
      Future<OhosRgbaResult?> render() =>
          OhosImageProcessor.instance.renderDetailPreview(
            cacheId: _ohosCacheId ?? cacheId,
            sharpen: params.sharpen.clamp(0, 100),
            smooth: params.smoothStrength.clamp(0, 100),
            vignette: params.vignette.clamp(0, 100),
            grain: params.grain.clamp(0, 100),
          );
      var res = await render();
      if (res == null && mounted && cacheId == _ohosCacheId) {
        // 缓存被原生 LRU 淘汰：重建缓存并重试一次
        releaseOhosDetailCache(widget.url);
        final newId = await obtainOhosDetailCache(widget.url, widget.maxEdge);
        if (mounted && newId != null && newId != _ohosCacheId) {
          _ohosCacheId = newId;
        }
        if (mounted && _ohosCacheId != null) {
          res = await render();
        }
      }
      if (!mounted || res == null) return;
      rendered = await _rgbaBytesToUiImage(res.rgba, res.width, res.height);
      if (!mounted || _ohosCacheId != cacheId) {
        rendered.dispose();
        rendered = null;
        return;
      }
      final old = _previewImage;
      setState(() {
        _previewImage = rendered;
        _previewSig = _sigOf(params);
      });
      old?.dispose();
      debugPrint('[edit-diag] ohos native preview rendered '
          'smooth=${params.smoothStrength} sharpen=${params.sharpen}');
    } catch (e) {
      debugPrint('[detail-effects] ohos native preview failed: $e');
    } finally {
      _rendering = false;
    }
    // 渲染期间滑块又动了 → 用最新参数继续渲染
    final pending = _pending;
    _pending = null;
    if (pending != null && mounted && _sigOf(pending) != _previewSig) {
      await _startOhosRender(pending);
    }
  }

  Future<void> _decode() async {
    final targetUrl = widget.url;
    _decodingUrl = targetUrl;
    // OHOS：获取/预热原生预览源缓存（实时预览渲染复用；prewarm 已暖过则直接命中）
    if (OhosImageProcessor.isSupported &&
        !targetUrl.startsWith('http') &&
        targetUrl.isNotEmpty) {
      final cacheId = await obtainOhosDetailCache(targetUrl, widget.maxEdge);
      if (!mounted || _decodingUrl != targetUrl) return;
      if (cacheId != null) {
        _ohosCacheId = cacheId;
        _scheduleOhosRender();
      }
    }
    // 预热命中：直接采用已解码图像（首次拖动滑块即有实时效果，无解码空窗）。
    final prewarmed = _prewarmedImages.remove(targetUrl);
    if (prewarmed != null) {
      if (!mounted) {
        prewarmed.dispose();
        return;
      }
      debugPrint('[edit-diag] layer decode adopted prewarmed: $targetUrl');
      setState(() => _image = prewarmed);
      return;
    }
    debugPrint('[edit-diag] layer decode start: $targetUrl');
    final next = await _decodeUrlToUiImage(targetUrl, widget.maxEdge);
    if (!mounted || _decodingUrl != targetUrl) {
      next?.dispose();
      return;
    }
    if (next == null) {
      debugPrint('[detail-effects] source decode failed: $targetUrl');
    } else {
      debugPrint('[edit-diag] layer decode done: '
          '${next.width}x${next.height}');
    }
    setState(() => _image = next);
  }

  /// 从来源字节解码出 GPU-backed [ui.Image]（data:/本地文件）。
  /// 失败或来源类型不受支持时返回 null（由 [build] 走 [fallback] 降级）。
  Future<ui.Image?> _decodeUrlToUiImage(String url, int maxEdge) =>
      decodeDetailEffectsSource(url, maxEdge);

  Future<void> _loadProgram() async {
    ui.FragmentProgram? prog;
    try {
      prog = await _loadDetailProgram();
    } catch (_) {
      debugPrint('[detail-effects] detail shader load failed');
      prog = null;
    }
    if (prog == null) {
      debugPrint('[detail-effects] detail shader unavailable');
    }
    if (!mounted) return;
    setState(() => _program = prog);
  }

  Future<void> _loadCoreProgram() async {
    ui.FragmentProgram? prog;
    try {
      prog = await _loadCoreDetailProgram();
    } catch (e) {
      debugPrint('[detail-effects] core shader load failed: $e');
      prog = null;
    }
    if (prog == null) {
      debugPrint('[detail-effects] core shader unavailable');
    }
    if (!mounted) return;
    setState(() => _coreProgram = prog);
  }

  @override
  Widget build(BuildContext context) {
    // OHOS 原生实时预览帧优先：与成片同一 C++ 管线（flutter_ohos 上 Dart
    // FragmentShader 静默失效时，这是拖动滑块照片跟着变化的保障）。
    // 原生渲染不含拉腿几何（成片仍会应用），拉腿增量≠0 时回落 shader 展示路径。
    final preview = _previewImage;
    if (preview != null && widget.effects.legStretch == 0) {
      return Center(
        child: AspectRatio(
          aspectRatio: preview.width / preview.height,
          child: RawImage(
            image: preview,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      );
    }
    final img = _image;
    if (img == null) {
      // 未解码 / 解码失败 → 原图片路径。
      return widget.fallback();
    }
    final coreOnly = widget.effects.vignette == 0 &&
        widget.effects.grain == 0 &&
        widget.effects.legStretch == 0;
    // core 短路 shader 仅在真正加载成功时使用。绝不能把 CoreDetailEffectsPainter
    // 配到完整程序（edit_detail_effects.frag）上：两者 uniform 布局不同
    //（core：uSharpenA=4 / uSmooth=5；完整：uVignette=5 / uSmooth=6），错配会把
    // 磨皮值写进暗角槽位、uSmooth 落在默认 0 →「锐化有效果、磨皮无效果」。
    if (coreOnly && _coreProgram != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: widget.effects.outputAspect(
            img.width.toDouble(),
            img.height.toDouble(),
          ),
          child: CustomPaint(
            painter: CoreDetailEffectsPainter(
              image: img,
              effects: widget.effects,
              program: _coreProgram!,
            ),
          ),
        ),
      );
    }
    final prog = _program;
    if (prog == null) {
      // shader 加载失败 → 原图片路径。
      return widget.fallback();
    }
    return Center(
      child: AspectRatio(
        // 拉腿改变高度 → 画布比例随之变化，观感等价 BoxFit.contain。
        aspectRatio: widget.effects.outputAspect(
          img.width.toDouble(),
          img.height.toDouble(),
        ),
        child: FutureBuilder<ui.Image>(
          future: loadGrainNoiseTile(),
          builder: (context, snapshot) {
            final noise = snapshot.data;
            if (noise == null) {
              if (snapshot.hasError) {
                debugPrint(
                    '[detail-effects] noise tile failed: ${snapshot.error}');
              }
              return widget.fallback();
            }
            // 注意：CustomPaint 的 painter 绘制在 child **之下**（SDK
            // RenderCustomPaint.paint：painter → child → foregroundPainter）。
            // 此处绝不能挂 child（尤其不透明原图 fallback）——同比例画布下
            // 原图会完全遮盖 shader 输出（细节参数调整不可见）；拉腿比例变化
            // 时 child 上下留边，shader 以重影形式露出（2026-09-10 修复）。
            // 尺寸由 AspectRatio 的 tight 约束给定，无需 child 提供布局。
            return CustomPaint(
              painter: DetailEffectsPainter(
                image: img,
                noise: noise,
                effects: widget.effects,
                program: prog,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 诊断打点去重：painter 每次 build 都是新实例，需用文件级变量记录上次参数指纹。
String _lastFullPaintDiag = '';
String _lastCorePaintDiag = '';

/// 逐片元细节效果画家。paint 期异常一律降级画原图（不抛出、不白屏）。
class DetailEffectsPainter extends CustomPainter {
  DetailEffectsPainter({
    required this.image,
    required this.noise,
    required this.effects,
    required this.program,
  });

  final ui.Image image;
  final ui.Image noise;
  final DetailEffectsParams effects;
  final ui.FragmentProgram program;

  @override
  void paint(Canvas canvas, Size size) {
    final sig = '${effects.smoothStrength},${effects.sharpen},'
        '${effects.vignette},${effects.grain},${effects.legStretch}';
    if (sig != _lastFullPaintDiag) {
      _lastFullPaintDiag = sig;
      debugPrint('[edit-diag] full painter paint fx=[$sig] '
          'canvas=${size.width}x${size.height} img=${image.width}x${image.height}');
    }
    try {
      // float 与 sampler 两套独立索引空间（同 SkinSmoothPainter 约定）：
      // - float：uSize(vec2)→0,1；uFrameSize(vec2)→2,3；uSharpenA→4；
      //   uVignette→5；uSmooth→6；uGrain→7；uLegStretch→8。
      // - sampler：uTexture→0；uNoise→1。
      final e = effects;
      final shader = program.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, image.width.toDouble())
        ..setFloat(3, image.height.toDouble())
        ..setFloat(
            4, (e.sharpen / 100.0 * 6.0).clamp(-6.0, 6.0).toDouble())
        ..setFloat(5, (e.vignette / 100.0).clamp(-1.0, 1.0).toDouble())
        ..setFloat(6, (e.smoothStrength / 100.0).clamp(0.0, 1.0).toDouble())
        ..setFloat(7, (e.grain / 100.0).clamp(-1.0, 1.0).toDouble())
        ..setFloat(8, (e.legStretch / 100.0).clamp(-1.0, 1.0).toDouble())
        ..setImageSampler(0, image)
        ..setImageSampler(1, noise);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (e, st) {
      debugPrint('[detail-effects] detail shader paint failed: $e\n$st');
      _fallback(canvas, size);
    }
  }

  /// 渲染期异常时的兜底：不抛出不白屏，直接画原图。
  void _fallback(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant DetailEffectsPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.noise != noise ||
      oldDelegate.program != program ||
      oldDelegate.effects.sharpen != effects.sharpen ||
      oldDelegate.effects.smoothStrength != effects.smoothStrength ||
      oldDelegate.effects.vignette != effects.vignette ||
      oldDelegate.effects.grain != effects.grain ||
      oldDelegate.effects.legStretch != effects.legStretch;
}

class CoreDetailEffectsPainter extends CustomPainter {
  CoreDetailEffectsPainter({
    required this.image,
    required this.effects,
    required this.program,
  });

  final ui.Image image;
  final DetailEffectsParams effects;
  final ui.FragmentProgram program;

  @override
  void paint(Canvas canvas, Size size) {
    final sig = '${effects.smoothStrength},${effects.sharpen}';
    if (sig != _lastCorePaintDiag) {
      _lastCorePaintDiag = sig;
      debugPrint('[edit-diag] core painter paint fx=[$sig] '
          'canvas=${size.width}x${size.height} img=${image.width}x${image.height}');
    }
    try {
      final shader = program.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, image.width.toDouble())
        ..setFloat(3, image.height.toDouble())
        ..setFloat(
            4, (effects.sharpen / 100.0 * 6.0).clamp(-6.0, 6.0).toDouble())
        ..setFloat(
            5, (effects.smoothStrength / 100.0).clamp(0.0, 1.0).toDouble())
        ..setImageSampler(0, image);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (e, st) {
      debugPrint('[detail-effects] core shader paint failed: $e\n$st');
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CoreDetailEffectsPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.program != program ||
      oldDelegate.effects.sharpen != effects.sharpen ||
      oldDelegate.effects.smoothStrength != effects.smoothStrength;
}
