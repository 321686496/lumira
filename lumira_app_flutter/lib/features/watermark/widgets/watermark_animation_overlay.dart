import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';

/// 水印相框入场动画 overlay。
///
/// 拍照完成且水印 + 动画开关均开启时，由拍摄页挂到 Stack 顶层播放：
/// - Phase 1 (0–14%)：照片淡入（冻结在屏幕中央）
/// - Phase 2 (14–45%)：水印元素淡入 + 轻微放大 (0.8→1.0)
/// - Phase 3 (45–68%)：保持显示
/// - Phase 4 (68–86%)：照片 + 水印向角标缩略图目标矩形缩小并平移
/// - Phase 5 (86–100%)：在目标位置最终淡出
///
/// 使用 [IgnorePointer] 不拦截手势，[ui.Image] 与 [AnimationController]
/// 在 dispose 中释放，[ui.Codec] 在抽帧后立即释放。
class WatermarkAnimationOverlay extends StatefulWidget {
  final String photoPath;
  final WatermarkTemplate watermarkTemplate;
  final Rect targetRect;
  final VoidCallback onAnimationComplete;

  const WatermarkAnimationOverlay({
    super.key,
    required this.photoPath,
    required this.watermarkTemplate,
    required this.targetRect,
    required this.onAnimationComplete,
  });

  @override
  State<WatermarkAnimationOverlay> createState() =>
      _WatermarkAnimationOverlayState();
}

class _WatermarkAnimationOverlayState extends State<WatermarkAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _photoFade;
  late Animation<double> _watermarkFade;
  late Animation<double> _shrink;
  ui.Image? _photoImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _photoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
    );
    _watermarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.14, 0.45, curve: Curves.easeOut),
    );
    _shrink = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.68, 0.86, curve: Curves.easeInCubic),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_photoImage == null) return const SizedBox.shrink();

        final photoOpacity = _photoFade.value;
        final watermarkOpacity = _watermarkFade.value;
        final shrinkValue = _shrink.value;

        // Phase 4：向目标缩略图位置缩小 + 平移
        final scale = 1.0 - (shrinkValue * 0.85);
        final photoOpacityFinal = shrinkValue > 0
            ? photoOpacity * (1.0 - shrinkValue * 0.3)
            : photoOpacity;

        // 平移：屏幕中心 → 目标矩形中心
        final screenCenter =
            Offset(screenSize.width / 2, screenSize.height / 2);
        final targetCenter = widget.targetRect.center;
        final dx = (targetCenter.dx - screenCenter.dx) * shrinkValue;
        final dy = (targetCenter.dy - screenCenter.dy) * shrinkValue;

        return IgnorePointer(
          child: Stack(
            children: [
              // Phase 1~4：黑色半透明遮罩（随 shrink 一起淡出）
              if (_controller.value < 0.86)
                Container(
                    color:
                        Colors.black.withOpacity(0.4 * (1 - shrinkValue))),

              // 照片
              Center(
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: photoOpacityFinal,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8 * shrinkValue),
                        child: SizedBox(
                          width: screenSize.width,
                          height: screenSize.height,
                          child: RawImage(
                            image: _photoImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 水印文本元素（Phase 2 淡入，与照片同步缩放/平移）
              // 使用 CustomPaint + 自定义 Painter 复刻 WatermarkRenderer 的
              // 绘制逻辑（textAlign X 偏移 / Y 偏移 / 旋转 / letterSpacing /
              // shadow），确保动画 overlay 与最终渲染水印视觉一致。
              if (watermarkOpacity > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WatermarkOverlayPainter(
                      template: widget.watermarkTemplate,
                      screenSize: screenSize,
                      opacity: watermarkOpacity,
                      scale: scale * (0.8 + 0.2 * watermarkOpacity),
                      translate: Offset(dx, dy),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 水印动画 overlay 专用 Painter：复刻 [WatermarkRenderer._drawTextElement]
/// 的绘制约定，使动画中显示的水印与最终渲染到照片上的水印视觉一致。
///
/// 关键约定（与渲染器对齐）：
/// - absoluteFontSize = element.fontSize * screenSize.width
/// - anchorX = element.x * screenSize.width, anchorY = element.y * screenSize.height
/// - textAlign 偏移：left=0 / center=-width/2 / right=-width
/// - Y 偏移：-textHeight * 0.85
/// - letterSpacing: element.letterSpacing * (screenSize.width / 400)
/// - shadow: blurRadius=(absFontSize*0.08).clamp(0.5,8.0),
///           offset=(blurRadius*0.4, blurRadius*0.4)
///
/// overlay 自身应用 opacity / scale / translate 变换（与照片同步缩放平移）。
class _WatermarkOverlayPainter extends CustomPainter {
  _WatermarkOverlayPainter({
    required this.template,
    required this.screenSize,
    required this.opacity,
    required this.scale,
    required this.translate,
  });

  static const double _referenceWidth = 400.0;

  final WatermarkTemplate template;
  final Size screenSize;
  final double opacity;
  final double scale;
  final Offset translate;

  @override
  void paint(Canvas canvas, Size size) {
    // overlay 画布尺寸 = screenSize，元素坐标基于 screenSize 缩放
    final scaleRef = screenSize.width / _referenceWidth;

    canvas.save();
    // 应用与照片同步的平移 + 缩放变换
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);

    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) continue;
      if (element.text.isEmpty) continue;
      _drawTextElement(canvas, element, scaleRef);
    }

    canvas.restore();
  }

  void _drawTextElement(
    Canvas canvas,
    WatermarkElement element,
    double scaleRef,
  ) {
    final absoluteFontSize = element.fontSize * screenSize.width;
    final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);

    final textStyle = TextStyle(
      color: _withOpacity(element.color, element.opacity * opacity),
      fontSize: absoluteFontSize,
      fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
      letterSpacing: element.letterSpacing * scaleRef,
      shadows: [
        ui.Shadow(
          color: _withOpacity(element.shadowColor, element.opacity * opacity),
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

    final anchorX = element.x * screenSize.width;
    final anchorY = element.y * screenSize.height;

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

  /// 将 [color] 的 alpha 通道乘以 [opacity]（0.0~1.0），返回带透明度的颜色。
  ui.Color _withOpacity(ui.Color color, double opacity) {
    if (opacity >= 1.0) return color;
    final clamped = opacity.clamp(0.0, 1.0);
    final alpha = (color.alpha * clamped).round();
    return ui.Color.fromARGB(alpha, color.red, color.green, color.blue);
  }

  @override
  bool shouldRepaint(covariant _WatermarkOverlayPainter oldDelegate) {
    // 与预览 painter 一致：元素属性为可变对象就地修改，无法靠引用相等判断；
    // 始终重绘以保证动画过程中元素变化即时反映。
    return true;
  }
}
