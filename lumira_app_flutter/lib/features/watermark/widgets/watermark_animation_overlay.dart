import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';
import '../services/watermark_renderer.dart';

/// 拍摄后水印定格动画 overlay。
///
/// 拍照完成且水印 + 动画开关均开启时，由拍摄页挂到 Stack 顶层播放：
/// - Phase 1 (0–28%)：带水印的照片从很小状态放大到满（最大宽 = 页面宽 * 0.9）并淡入
/// - Phase 2 (28–78%)：居中停顿，展示最终效果
/// - Phase 3 (78–100%)：整体淡出
/// - 动画结束后通过 [onAnimationComplete] 通知拍摄页直接跳转到拍摄预览页
///
/// 展示内容与最终落库成片视觉一致：
/// - 依据 [isPortrait] / [isFront] 对原始照片做方向对齐（旋转 + 前置镜像），
///   与后处理管线的 `_alignOrientation` 逻辑一致；
/// - 复用 [WatermarkRenderer] 把水印元素与拍立得白边合成到照片上，
///   因此动画与成片（含拍立得白边）外观一致。
///
/// 性能 / 可见性：
/// - **快速路径**先解码原片并方向对齐，第一帧即可显示动画内容（不空白）；
/// - **后台路径**再降采样 + 水印合成，完成后替换显示，避免等待完整后处理管线
///   （GPU + isolate + 落库，约数百 ms，会拖慢出片），实现近乎零延迟。
///
/// 使用 [IgnorePointer] 不拦截手势，[ui.Image] 与 [AnimationController]
/// 在 dispose 中释放，[ui.Codec] 在取帧后立即释放。
class WatermarkAnimationOverlay extends StatefulWidget {
  final String photoPath;
  final WatermarkTemplate watermarkTemplate;
  final bool isFront;
  final bool isPortrait;
  final VoidCallback onAnimationComplete;

  const WatermarkAnimationOverlay({
    super.key,
    required this.photoPath,
    required this.watermarkTemplate,
    required this.isFront,
    required this.isPortrait,
    required this.onAnimationComplete,
  });

  @override
  State<WatermarkAnimationOverlay> createState() =>
      _WatermarkAnimationOverlayState();
}

class _WatermarkAnimationOverlayState extends State<WatermarkAnimationOverlay>
    with SingleTickerProviderStateMixin {
  /// 展示最大宽度占页面宽度的比例。
  static const double _maxWidthRatio = 0.9;

  /// 后台合成目标尺寸上限（动画展示区域较小，无需解码/合成全尺寸原图）。
  static const int _decodeTargetDim = 1200;

  late AnimationController _controller;
  late Animation<double> _grow;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  /// 当前展示的图片：先以「方向对齐后的原片」立即显示（保证动画不空白），
  /// 成片（含水印 + 拍立得白边）合成完成后再替换为合成图。
  ui.Image? _displayImage;
  int _displayW = 0;
  int _displayH = 0;
  bool _compositeReady = false;
  bool _disposed = false;

  /// 应用展示图并释放上一张（避免泄漏）。
  void _applyDisplay(ui.Image image, int w, int h) {
    _displayImage?.dispose();
    _displayImage = image;
    _displayW = w;
    _displayH = h;
  }

  /// 应用占位原片；若成片合成已就绪则丢弃占位原片，避免回退。
  void _applyPlaceholder(ui.Image image, int w, int h) {
    if (_compositeReady) {
      image.dispose();
      return;
    }
    _displayImage?.dispose();
    _displayImage = image;
    _displayW = w;
    _displayH = h;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Phase 1：从小放大到 1.0（easeOutBack 带轻微回弹），同步淡入
    _grow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOutBack),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );
    // Phase 2：保持显示；Phase 3：淡出
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.78, 1.0, curve: Curves.easeIn),
    );
    // 快速路径：解码 + 方向对齐原片，立即显示，保证动画不空白。
    _prepBase();
    // 后台路径：水印（含拍立得白边）合成后替换显示。
    _buildComposite();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  /// 快速路径：解码原片 → 方向对齐 → 立即显示。
  Future<void> _prepBase() async {
    ui.Image? decoded;
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      codec.dispose();

      final aligned = await _alignOrientation(decoded);
      if (aligned != decoded) {
        decoded.dispose();
        decoded = aligned;
      }
      if (!mounted) {
        decoded.dispose();
        return;
      }
      final ui.Image img = decoded;
      setState(() {
        _applyPlaceholder(img, img.width, img.height);
      });
    } catch (e) {
      debugPrint('[watermark-anim] base prep failed: $e');
    }
  }

  /// 后台路径：把水印（含拍立得白边）合成到降采样后的照片上，完成后替换显示。
  Future<void> _buildComposite() async {
    ui.Image? source;
    ui.Image? downscaled;
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      source = frame.image;
      codec.dispose();

      final aligned = await _alignOrientation(source);
      if (aligned != source) {
        source.dispose();
        source = aligned;
      }

      // 降采样到展示目标尺寸，避免全尺寸合成耗时（仅两次瞬时对齐用图）。
      downscaled = await _downscale(source, _decodeTargetDim);
      source.dispose();
      source = null;

      final renderer = WatermarkRenderer();
      final result = await renderer.render(
        sourceImage: downscaled,
        template: widget.watermarkTemplate,
      );

      final composite = await _rgbaToImage(
        result.rgbaBytes,
        result.width,
        result.height,
      );
      if (!mounted || _disposed) {
        composite.dispose();
        return;
      }
      setState(() {
        _compositeReady = true;
        _applyDisplay(composite, result.width, result.height);
      });
    } catch (e) {
      debugPrint('[watermark-anim] composite build failed: $e');
    } finally {
      downscaled?.dispose();
      source?.dispose();
    }
  }

  /// 等比缩放到 [targetDim]（长边）以内，返回新图（调用方负责 dispose）。
  Future<ui.Image> _downscale(ui.Image src, int targetDim) async {
    final w = src.width.toDouble();
    final h = src.height.toDouble();
    final scale = (targetDim / (w > h ? w : h)).clamp(0.0, 1.0);
    final nw = (w * scale).round().clamp(1, src.width);
    final nh = (h * scale).round().clamp(1, src.height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    canvas.drawImage(
      src,
      ui.Offset.zero,
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(nw, nh);
    picture.dispose();
    return result;
  }

  /// 与后处理管线 `PhotoPostProcessor._alignOrientation` 一致的方向对齐。
  Future<ui.Image> _alignOrientation(ui.Image src) async {
    final jpegIsLandscape = src.width > src.height;
    final deviceIsPortrait = widget.isPortrait;
    final needRotate = (deviceIsPortrait && jpegIsLandscape) ||
        (!deviceIsPortrait && !jpegIsLandscape);
    final needMirror = widget.isFront;
    if (!needRotate && !needMirror) return src;

    final int rotation;
    final double outW;
    final double outH;
    if (needRotate) {
      rotation = deviceIsPortrait ? 90 : 270;
      outW = src.height.toDouble();
      outH = src.width.toDouble();
    } else {
      rotation = 0;
      outW = src.width.toDouble();
      outH = src.height.toDouble();
    }
    final radians = rotation * math.pi / 180.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(outW / 2.0, outH / 2.0);
    canvas.rotate(radians);
    canvas.scale(needMirror ? -1.0 : 1.0, 1.0);
    canvas.drawImage(
      src,
      ui.Offset(-src.width / 2.0, -src.height / 2.0),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final result = await picture.toImage(outW.round(), outH.round());
    picture.dispose();
    return result;
  }

  /// RGBA 原始字节 → [ui.Image]（避免 JPEG 编解码往返）。
  Future<ui.Image> _rgbaToImage(
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

  @override
  void dispose() {
    _disposed = true;
    _displayImage?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * _maxWidthRatio;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final image = _displayImage;
          if (image == null || _displayW == 0 || _displayH == 0) {
            return const SizedBox.shrink();
          }
          final aspect = _displayW / _displayH;

          // 缩放：0.15（极小）→ 1.0，配合 easeOutBack 产生「从小变大」的定格效果
          final scale = 0.15 + 0.85 * _grow.value;
          // 透明度：淡入 × (1 - 淡出)
          final opacity = _fadeIn.value * (1.0 - _fadeOut.value);

          return Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: SizedBox(
                    width: maxWidth,
                    child: RawImage(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}