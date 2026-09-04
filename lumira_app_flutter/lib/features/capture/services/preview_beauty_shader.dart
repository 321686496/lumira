import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../domain/photo_template.dart';

/// 取景器实时美颜 shader 封装（OHOS 真视图层逐帧处理）。
///
/// - [noiseTileFuture]：进程一次构建 128×128 颗粒 tile（固定 LCG，与成片 C++/iOS 预览/
///   Dart bake 同分布），消除旧实现逐帧随机导致的取景器卡顿。
/// - [programFuture]：延迟加载 `preview_beauty.frag`；引擎不支持时返回 null，
///   调用方据此安全回退到纯 ColorFiltered（不伪造预览、不拖帧）。
/// - [render]：把一帧捕获帧经统一单 pass shader 渲染成新 ui.Image，全 GPU、零 CPU 读回。
///
/// 硬约束：取景器不得卡顿/掉帧 —— 渲染在 raster 线程异步执行，调用方按帧忙丢弃 + 自适应降采样。
class PreviewBeautyShader {
  PreviewBeautyShader._();

  static const int noiseTexSize = 128;

  static ui.Image? _noiseTile;
  static ui.FragmentProgram? _program;
  static Future<void>? _initFuture;

  /// 初始化（程序 + 颗粒 tile），幂等；失败时 [_program] 保持 null，调用方回退。
  static Future<void> ensureInit() {
    return _initFuture ??= _doInit();
  }

  static Future<void> _doInit() async {
    try {
      _program =
          await ui.FragmentProgram.fromAsset('shaders/preview_beauty.frag');
    } catch (_) {
      debugPrint('[preview-beauty] shader 加载失败，回退 ColorFiltered');
      _program = null;
    }
    await _buildNoiseTile();
  }

  static Future<void> _buildNoiseTile() async {
    if (_noiseTile != null) return;
    final bytes = Uint8List(noiseTexSize * noiseTexSize * 4);
    var seed = 0x85EBCA6B; // 固定种子（与成片/C++/iOS 同种子族，可复现）
    for (var i = 0; i < noiseTexSize * noiseTexSize; ++i) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      final rnd = ((seed >> 8) & 0xFFFF) / 65535.0; // 0..1
      final g = (rnd * 255.0).round().clamp(0, 255);
      final o = i * 4;
      bytes[o] = g;
      bytes[o + 1] = g;
      bytes[o + 2] = g;
      bytes[o + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: noiseTexSize,
      height: noiseTexSize,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    buffer.dispose();
    descriptor.dispose();
    codec.dispose();
    _noiseTile = frame.image;
  }

  /// 程序是否可用（null = 引擎不支持，应回退）。
  static ui.FragmentProgram? get program => _program;

  /// 颗粒 tile 是否就绪（供外部判断启动 Ticker 条件）。
  static ui.Image? get noiseTile => _noiseTile;

  /// 是否应启用逐帧美颜（任一空间效果 > 0）。仅色彩矩阵时走廉价 ColorFiltered。
  static bool hasSpatialEffects(PostProcess p) =>
      p.sharpen > 0 || p.grain > 0 || p.vignette > 0 || p.smoothStrength > 0;

  /// 单 pass 渲染 [frame] → 新 ui.Image（与成片同规格）。
  ///
  /// 调用方负责在不用时 dispose 入参 [frame] 与返回值。程序不可用或渲染失败时返回 null。
  static Future<ui.Image?> render(
    ui.Image frame, {
    required PostProcess post,
  }) async {
    final program = _program;
    if (program == null) return null;
    final w = frame.width, h = frame.height;
    if (w <= 0 || h <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final shader = program
        .fragmentShader()
      // uniform 顺序必须与 preview_beauty.frag 声明一致：
      // uSize(vec2)=0,1; uFrameSize(vec2)=2,3; uSharpen=4; uVignette=5; uSmooth=6; uGrain=7
      ..setFloat(0, w.toDouble())
      ..setFloat(1, h.toDouble())
      ..setFloat(2, w.toDouble())
      ..setFloat(3, h.toDouble())
      ..setFloat(4, (post.sharpen / 100.0).clamp(0.0, 1.2).toDouble())
      ..setFloat(5, (post.vignette / 100.0).clamp(0.0, 1.0).toDouble())
      ..setFloat(6, (post.smoothStrength / 100.0).clamp(0.0, 1.0).toDouble())
      ..setFloat(7, (post.grain / 100.0).clamp(0.0, 1.0).toDouble())
      ..setImageSampler(0, frame)
      ..setImageSampler(1, _noiseTile!);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(w, h);
    } catch (_) {
      return null;
    } finally {
      picture.dispose();
    }
  }
}