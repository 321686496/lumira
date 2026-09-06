import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/ohos_image_processor.dart';
import '../models/watermark_template.dart';
import '../services/watermark_renderer.dart';
import '../../capture/services/dart_photo_pipeline.dart'
    show applyP3ToSrgbRgba, isDisplayP3Jpeg;

/// 拍摄后水印定格动画 overlay。
///
/// 拍照完成且水印 + 动画开关均开启时，由拍摄页挂到 Stack 顶层播放：
/// - Phase 1 (0–35%)：带水印的照片从很小状态放大到满（最大宽 = 页面宽 * 0.9）并淡入
/// - Phase 2 (35–85%)：居中停顿，展示最终效果
/// - Phase 3 (85–100%)：整体淡出
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

  /// 动画源是否已是屏幕空间 WYSIWYG 帧（iOS/OHOS 快门冻结取景器截图，
  /// 已物理竖屏 + 已前置镜像 + 已含色彩滤镜）。
  /// true：跳过 [_alignOrientation]，避免对已对齐帧二次旋转/镜像
  /// （前置双重镜像 bug 的根因）；
  /// false：成片回退源（原始照片），按设备方向 + 前置镜像对齐。
  final bool sourceAligned;
  final VoidCallback onAnimationComplete;

  const WatermarkAnimationOverlay({
    super.key,
    required this.photoPath,
    required this.watermarkTemplate,
    required this.isFront,
    required this.isPortrait,
    this.sourceAligned = false,
    required this.onAnimationComplete,
  });

  @override
  State<WatermarkAnimationOverlay> createState() =>
      _WatermarkAnimationOverlayState();
}

class _WatermarkAnimationOverlayState extends State<WatermarkAnimationOverlay>
    with SingleTickerProviderStateMixin {
  /// 展示最大宽度占页面宽度的比例。
  static const double _maxWidthRatio = 0.8;

  /// 展示最大高度占页面高度的比例（避免竖片溢出屏幕）。
  static const double _maxHeightRatio = 0.85;

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
  bool _animationStarted = false;

  /// 启动动画（只启动一次）。
  ///
  /// 必须等首帧解码完成后才 forward，
  /// 否则动画时长会被解码耗时压缩：iOS 解码快 -> 动画看起来太快；
  /// OHOS 解码慢 -> 首帧出现时 grow 已结束，甚至动画已整体结束，看起来没有动画。
  /// 统一为「首帧就绪才从头播，各平台时长一致」。
  void _startAnimation() {
    if (_animationStarted) return;
    _animationStarted = true;
    _controller.forward();
  }

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
      duration: const Duration(milliseconds: 2000),
    );
    // Phase 1：从小放大到 1.0（easeOutBack 带轻微回弹），同步淡入
    _grow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    // Phase 2：保持显示；Phase 3：淡出
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 1.0, curve: Curves.easeIn),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
    // 快速路径：解码 + 方向对齐原片，立即显示，保证动画不空白。
    _prepBase();
    // 后台路径：水印（含拍立得白边）合成后替换显示。
    _buildComposite();
    // 动画启动延后到首帧解码完成，保证各平台时长一致（见 _startAnimation）。
  }

  /// 解码源照片为 [ui.Image]。
  ///
  /// OHOS：走系统级硬件解码 [OhosImageProcessor.decodeJpegToRgba]，
  /// 直接按 [targetDim] 降采样，绕过 flutter_ohos 引擎 dart:ui 慢速 JPEG 软件解码
  /// （实测 1200x1600 约 6s）；失败自动回退 dart:ui 解码。
  /// 其他平台：dart:ui 解码完整分辨率。
  /// 返回 null 表示解码失败（调用方统一异常处理）。
  Future<ui.Image?> _decodeSource({int targetDim = _decodeTargetDim}) async {
    if (OhosImageProcessor.isSupported) {
      final result = await OhosImageProcessor.instance.decodeJpegToRgba(
        path: widget.photoPath,
        targetWidth: targetDim,
        targetHeight: targetDim,
      );
      if (result != null) {
        return _rgbaToImage(result.rgba, result.width, result.height);
      }
      debugPrint('[watermark-anim] OHOS 原生解码失败，回退 dart:ui');
    }
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();
      return image;
    } catch (e) {
      debugPrint('[watermark-anim] dart:ui 解码失败: $e');
      return null;
    }
  }

  /// 快速路径：解码原片 → 方向对齐（仅原始成片源）→ 立即显示。
  Future<void> _prepBase() async {
    ui.Image? decoded;
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      decoded = await _decodeSource();
      if (decoded == null) throw Exception('decode failed');

      final aligned = await _alignIfNeeded(decoded);
      if (aligned != decoded) {
        decoded.dispose();
        decoded = aligned;
      }
      // 宽色域原片做正确的 P3→sRGB 换算，使动画画面与最终成片（已校色）色彩一致，
      // 避免 iOS 相机 P3 原片被按 sRGB 解释导致的偏黄。
      decoded = await _p3CorrectIfNeeded(decoded, bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      final ui.Image img = decoded;
      setState(() {
        _applyPlaceholder(img, img.width, img.height);
      });
      // 首帧就绪：此刻才开始播放动画，保证 iOS/OHOS 动画时长一致（不因解码耗时被压缩）。
      _startAnimation();
    } catch (e) {
      // 解码失败：无法展示画面，仍启动控制器以触发 onAnimationComplete，避免卡死拍摄流程。
      debugPrint('[watermark-anim] base prep failed: $e');
      _startAnimation();
    }
  }

  /// 后台路径：把水印（含拍立得白边）合成到降采样后的照片上，完成后替换显示。
  Future<void> _buildComposite() async {
    ui.Image? source;
    ui.Image? downscaled;
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      source = await _decodeSource();
      if (source == null) throw Exception('decode failed');

      final aligned = await _alignIfNeeded(source);
      if (aligned != source) {
        source.dispose();
        source = aligned;
      }

      if (OhosImageProcessor.isSupported) {
        // OHOS：原生解码已按 _decodeTargetDim 降采样，无需再次缩放。
        downscaled = source;
        source = null;
      } else {
        // 其他平台：降采样到展示目标尺寸，避免全尺寸合成耗时（仅两次瞬时对齐用图）。
        downscaled = await _downscale(source, _decodeTargetDim);
        source.dispose();
        source = null;
      }

      // 宽色域原片在降采样后做正确的 P3→sRGB 换算，与成片色彩一致（避免动画偏黄）。
      downscaled = await _p3CorrectIfNeeded(downscaled, bytes);

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

  /// 按 [WatermarkAnimationOverlay.sourceAligned] 决定是否做方向对齐。
  /// 取景器来源帧（快门冻结帧/video 帧直出）已是屏幕空间 WYSIWYG，
  /// 跳过对齐；原始成片源才走 [_alignOrientation]。
  Future<ui.Image> _alignIfNeeded(ui.Image src) async {
    if (widget.sourceAligned) return src;
    return _alignOrientation(src);
  }

  /// 与后处理管线 `PhotoPostProcessor._alignOrientation` 一致的方向对齐。
  Future<ui.Image> _alignOrientation(ui.Image src) async {
    final jpegIsLandscape = src.width > src.height;
    final deviceIsPortrait = widget.isPortrait;
    final needRotate = (deviceIsPortrait && jpegIsLandscape) ||
        (!deviceIsPortrait && !jpegIsLandscape);
    // 前置镜像仅在「sensor-native 横屏像素」时补做：竖屏像素的前置 JPEG
    // （iOS WYSIWYG video 帧直出 / OHOS 相册增强成品）已是镜像结果，
    // 再镜像会双重水平翻转。与 capture_page._applyColorMatrixOnGpu 同规则。
    final needMirror = widget.isFront && jpegIsLandscape;
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

  /// 若源 JPEG 为 Display P3 宽色域，对其解码图像做正确的 P3→sRGB 换算并返回新图；
  /// 否则原样返回。原图在成功换算后会被 dispose，调用方沿用返回值即可。
  Future<ui.Image> _p3CorrectIfNeeded(
    ui.Image image,
    Uint8List jpegBytes,
  ) async {
    if (isDisplayP3Jpeg(jpegBytes) == false) return image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return image;
      final rgba =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      applyP3ToSrgbRgba(rgba);
      final corrected = await _rgbaToImage(rgba, image.width, image.height);
      image.dispose();
      return corrected;
    } catch (e) {
      debugPrint('[watermark-anim] P3→sRGB 换算失败（保留原图）: $e');
      return image;
    }
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

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final image = _displayImage;
          if (image == null || _displayW == 0 || _displayH == 0) {
            return const SizedBox.shrink();
          }
          final aspect = _displayW / _displayH;

          // 按「限宽 80% / 限高 85%」手算实际显示宽高（等比缩放）。
          // 不能依赖 Center + AspectRatio + SizedBox 来限宽：Center 给宽松约束后，
          // AspectRatio 会按“比例 + 全屏约束”自行撑到满宽，SizedBox 的宽度请求被无视。
          final maxW = screenSize.width * _maxWidthRatio;
          final maxH = screenSize.height * _maxHeightRatio;
          double w;
          double h;
          if (aspect >= 1) {
            w = maxW;
            h = w / aspect;
            if (h > maxH) {
              h = maxH;
              w = h * aspect;
            }
          } else {
            h = maxH;
            w = h * aspect;
            if (w > maxW) {
              w = maxW;
              h = w / aspect;
            }
          }

          // 缩放：0.15（极小）→ 1.0，配合 easeOutBack 产生「从小变大」的定格效果
          final scale = 0.15 + 0.85 * _grow.value;
          // 透明度：淡入 × (1 - 淡出)
          final opacity = _fadeIn.value * (1.0 - _fadeOut.value);

          return Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: RawImage(image: image, fit: BoxFit.fill),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}