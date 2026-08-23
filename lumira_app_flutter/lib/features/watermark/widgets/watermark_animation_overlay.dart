import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';

/// 拍摄后水印定格动画 overlay。
///
/// 拍照完成且水印 + 动画开关均开启时，由拍摄页挂到 Stack 顶层播放：
/// - Phase 1 (0–28%)：带水印的照片从很小状态放大到满（最大宽 = 页面宽 * 0.9）并淡入
/// - Phase 2 (28–78%)：居中停顿，展示最终效果
/// - Phase 3 (78–100%)：整体淡出
/// - 动画结束后通过 [onAnimationComplete] 通知拍摄页直接跳转到拍摄预览页
///
/// 展示区域固定为「最大宽 = 页面宽 * 0.9」并居中，按照片原始比例（[AspectRatio]）
/// 定高，因此照片与水印使用同一尺寸坐标系，水印位置 / 字号与最终渲染到照片上的一致。
///
/// 使用 [IgnorePointer] 不拦截手势，[ui.Image] 与 [AnimationController]
/// 在 dispose 中释放，[ui.Codec] 在抽帧后立即释放。
class WatermarkAnimationOverlay extends StatefulWidget {
  final String photoPath;
  final WatermarkTemplate watermarkTemplate;
  final VoidCallback onAnimationComplete;

  const WatermarkAnimationOverlay({
    super.key,
    required this.photoPath,
    required this.watermarkTemplate,
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

  late AnimationController _controller;
  late Animation<double> _grow;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;
  ui.Image? _photoImage;

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
    _loadImage();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _photoImage = frame.image);
      } else {
        frame.image.dispose();
      }
      codec.dispose();
    } catch (e) {
      debugPrint('[watermark-anim] image load failed: $e');
    }
  }

  @override
  void dispose() {
    _photoImage?.dispose();
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
          if (_photoImage == null) return const SizedBox.shrink();

          final image = _photoImage!;
          final aspect = image.width / image.height;

          // 缩放：0.15（极小）→ 1.0，配合 easeOutBack 产生「从小变大」的定格效果
          final scale = 0.15 + 0.85 * _grow.value;
          // 透明度：淡入 × (1 - 淡出)
          final opacity = _fadeIn.value * (1.0 - _fadeOut.value);

          return Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: SizedBox(
                      width: maxWidth,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(image: image, fit: BoxFit.cover),
                          CustomPaint(
                            painter: _WatermarkOverlayPainter(
                              template: widget.watermarkTemplate,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// 水印动画 overlay 专用 Painter：复刻 [WatermarkRenderer._drawTextElement]
/// 的绘制约定，使动画中显示的水印与最终渲染到照片上的水印视觉一致。
///
/// 关键约定（与渲染器对齐）：
/// - absoluteFontSize = element.fontSize * size.width
/// - anchorX = element.x * size.width, anchorY = element.y * size.height
/// - textAlign 偏移：left=0 / center=-width/2 / right=-width
/// - Y 偏移：-textHeight * 0.85
/// - letterSpacing: element.letterSpacing * (size.width / 400)
/// - shadow: blurRadius=(absFontSize*0.08).clamp(0.5,8.0),
///           offset=(blurRadius*0.4, blurRadius*0.4)
///
/// 尺寸 [size] 即为照片展示盒的尺寸（照片 + 水印共用），因此元素相对坐标
/// 映射到实际照片区域是准确的；整体淡入淡出 / 缩放由外层 Opacity / Transform 负责。
class _WatermarkOverlayPainter extends CustomPainter {
  _WatermarkOverlayPainter({required this.template});

  static const double _referenceWidth = 400.0;

  final WatermarkTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleRef = size.width / _referenceWidth;

    canvas.save();
    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) continue;
      if (element.text.isEmpty) continue;
      _drawTextElement(canvas, element, size, scaleRef);
    }
    canvas.restore();
  }

  void _drawTextElement(
    Canvas canvas,
    WatermarkElement element,
    Size size,
    double scaleRef,
  ) {
    final absoluteFontSize = element.fontSize * size.width;
    final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);

    final textStyle = TextStyle(
      color: element.color,
      fontSize: absoluteFontSize,
      fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
      letterSpacing: element.letterSpacing * scaleRef,
      shadows: [
        ui.Shadow(
          color: element.shadowColor,
          blurRadius: blurRadius,
          offset: ui.Offset(blurRadius * 0.4, blurRadius * 0.4),
        ),
      ],
    );

    final painter = TextPainter(
      text: TextSpan(text: element.text, style: textStyle),
      textAlign: element.textAlign,
      textDirection: TextDirection.ltr,
    )..layout();

    final anchorX = element.x * size.width;
    final anchorY = element.y * size.height;

    double offsetX;
    switch (element.textAlign) {
      case TextAlign.right:
        offsetX = -painter.width;
        break;
      case TextAlign.center:
        offsetX = -painter.width / 2;
        break;
      case TextAlign.left:
      case TextAlign.justify:
      case TextAlign.start:
      case TextAlign.end:
      default:
        offsetX = 0.0;
    }
    // 与渲染器一致：y 锚点视为文本基线顶部偏上，使视觉位置贴合
    final offsetY = -painter.height * 0.85;

    canvas.save();
    canvas.translate(anchorX, anchorY);
    if (element.rotation != 0.0) {
      canvas.rotate(element.rotation);
    }
    canvas.translate(offsetX, offsetY);
    painter.paint(canvas, ui.Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkOverlayPainter oldDelegate) {
    // 与预览 painter 一致：元素属性为可变对象就地修改，无法靠引用相等判断；
    // 始终重绘以保证元素变化即时反映。
    return true;
  }
}