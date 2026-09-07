import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

Future<ui.FragmentProgram?> _loadDetailProgram() =>
    _programFuture ??= loadFragmentProgramFromCandidates(
      Platform.operatingSystem == 'ohos'
          ? const [
              'assets/shaders/edit_detail_effects.frag',
              'shaders/edit_detail_effects.frag',
            ]
          : const ['shaders/edit_detail_effects.frag'],
    );

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

  @override
  State<DetailEffectsLayer> createState() => _DetailEffectsLayerState();
}

class _DetailEffectsLayerState extends State<DetailEffectsLayer> {
  ui.Image? _image;
  String? _decodingUrl;
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _decode();
    _loadProgram();
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
      _decode();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final targetUrl = widget.url;
    _decodingUrl = targetUrl;
    final next = await _decodeToUiImage(targetUrl);
    if (!mounted || _decodingUrl != targetUrl) {
      next?.dispose();
      return;
    }
    setState(() => _image = next);
  }

  /// 从来源字节解码出 GPU-backed [ui.Image]（data:/本地文件）。
  /// 失败或来源类型不受支持时返回 null（由 [build] 走 [fallback] 降级）。
  Future<ui.Image?> _decodeToUiImage(String url) async {
    if (url.isEmpty) return null;
    final maxEdge = widget.maxEdge;
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

  Future<void> _loadProgram() async {
    ui.FragmentProgram? prog;
    try {
      prog = await _loadDetailProgram();
    } catch (_) {
      prog = null;
    }
    if (!mounted) return;
    setState(() => _program = prog);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final prog = _program;
    if (img == null || prog == null) {
      // 未就绪 / 解码失败 / shader 加载失败 → 原图片路径。
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
              return widget.fallback();
            }
            return CustomPaint(
              painter: DetailEffectsPainter(
                image: img,
                noise: noise,
                effects: widget.effects,
                program: prog,
              ),
              child: widget.fallback(),
            );
          },
        ),
      ),
    );
  }
}

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
    } catch (_) {
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
