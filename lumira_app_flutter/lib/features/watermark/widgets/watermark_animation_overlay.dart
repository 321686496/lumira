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
/// 性能：为避免等待完整后处理管线（GPU + isolate + 落库，约数百 ms，会拖慢出片），
/// 动画直接使用原始照片在本地降采样后做方向对齐 + 水印合成，几乎零延迟。
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

  /// 本地合成目标尺寸上限（动画展示区域较小，无需解码/合成全尺寸原图）。
  static const int _decodeTargetDim = 1200;

  late AnimationController _controller;
  late Animation<double> _grow;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  ui.Image? _compositeImage;
  int _compositeW = 0;
  int _compositeH = 0;

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
    _buildComposite();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  /// 本地合成成片视觉：方向对齐 → 水印（含拍立得白边）合成 → RGBA 转 [ui.Image]。
  Future<void> _buildComposite() async {
    ui.Image? decoded;
    ui.Image? aligned;
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _decodeTargetDim,
      );
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      codec.dispose();

      // 方向对齐：旋转 + 前置镜像（与成片管线 _alignOrientation 一致）
      aligned = await _alignOrientation(decoded);
      if (aligned != decoded) {
        decoded.dispose();
        decoded = aligned;
      }

      // 复用渲染器：把水印元素 + 拍立得白边合成到照片上，得到成片外观
      final renderer = WatermarkRenderer();
      final result = await renderer.render(
        sourceImage: decoded,
        template: widget.watermarkTemplate,
      );

      final composite = await _rgbaToImage(
        result.rgbaBytes,
        result.width,
        result.height,
      );
      if (!mounted) {
        composite.dispose();
        return;
      }
      setState(() {
        _compositeW = result.width;
        _compositeH = result.height;
        _compositeImage = composite;
      });
    } catch (e) {
      debugPrint('[watermark-anim] composite build failed: $e');
    } finally {
      decoded?.dispose();
    }
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
    _compositeImage?.dispose();
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
          final image = _compositeImage;
          if (image == null || _compositeW == 0 || _compositeH == 0) {
            return const SizedBox.shrink();
          }
          final aspect = _compositeW / _compositeH;

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