import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';
import '../services/watermark_layout.dart';

/// 水印预览组件：在深色（无底图）或真实照片底图上渲染 [WatermarkTemplate]
/// 的画框 + 元素，供水印管理页缩略图使用。
///
/// 几何与换算完全交给 [WatermarkPreviewGeometry] / [WatermarkElementMetrics] /
/// [WatermarkTextPlacement]（与成片渲染器同源），因此缩略图与成片一致：
/// - 画框按 [WatermarkLayout] 绘制：拍立得白卡（纯色 / 渐变 + 圆角）铺满卡片，
///   照片绘进 `photoRect`，内描边沿 `photoRect` 内缩半个线宽
/// - 元素坐标按其 [WatermarkElement.space] 取基准矩形（`frame` → 白板）
/// - 字号夹取在**显示像素**上做：`clamp(显示字号, 5, 卡片显示宽 × 0.16)`
class WatermarkPreview extends StatelessWidget {
  const WatermarkPreview({
    super.key,
    required this.template,
    this.width = 100,
    this.height = 130,
    this.background,
    this.borderRadius = 8,
    this.date,
  });

  final WatermarkTemplate template;
  final double width;
  final double height;

  /// 可选照片底图。提供时以 [BoxFit.cover] 绘进画框的照片区域；
  /// 未提供时保持深色仿照片底（此时拍立得仍会画出白卡）。
  final ImageProvider? background;
  final double borderRadius;

  /// `dateTime` 元素所用日期；为空时用当天（缩略图无照片 EXIF）。
  final DateTime? date;

  /// 深色仿照片背景
  static const Color _defaultBackground = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    final dateText = formatWatermarkDate(date ?? DateTime.now());
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _defaultBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = WatermarkPreviewGeometry.fit(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            frame: template.frame,
          );
          final cardRect = geometry.displayRect(geometry.layout.cardRect);
          final photoRect = geometry.displayRect(geometry.layout.photoRect);
          return Stack(
            children: [
              // 卡片底色：仅画框模板需要（none 时画布底色被照片完全覆盖）。
              if (template.frame.type != WatermarkFrameType.none)
                Positioned.fromRect(
                  rect: cardRect,
                  child: CustomPaint(
                    painter: _CardBasePainter(
                      template.frame,
                      photoWidth: photoRect.width,
                    ),
                  ),
                ),
              if (background != null)
                Positioned.fromRect(
                  rect: photoRect,
                  child: Image(image: background!, fit: BoxFit.cover),
                ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _WatermarkPreviewPainter(
                    template: template,
                    geometry: geometry,
                    dateText: dateText,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 卡片底色：拍立得白卡（纯色 / 渐变 + 圆角），铺满整张卡片。
class _CardBasePainter extends CustomPainter {
  _CardBasePainter(this.frame, {required this.photoWidth});

  final WatermarkFrame frame;

  /// 照片显示宽度，用于按「相对照片宽」的比例换算圆角。
  final double photoWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    if (frame.borderFill == WatermarkBorderFill.gradient) {
      paint.shader = watermarkFrameGradientShader(frame, rect);
    } else {
      paint.color = frame.color;
    }
    final radius = frame.borderRadius * photoWidth;
    if (radius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardBasePainter oldDelegate) => true;
}

class _WatermarkPreviewPainter extends CustomPainter {
  _WatermarkPreviewPainter({
    required this.template,
    required this.geometry,
    required this.dateText,
  });

  final WatermarkTemplate template;
  final WatermarkPreviewGeometry geometry;
  final String dateText;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = template.frame;
    if (frame.type == WatermarkFrameType.innerBorder) {
      final photoRect = geometry.displayRect(geometry.layout.photoRect);
      final stroke = frame.borderRatio * photoRect.width;
      final paint = Paint()
        ..color = frame.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      final inner = photoRect.deflate(stroke / 2);
      if (frame.borderRadius > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              inner, Radius.circular(frame.borderRadius * photoRect.width)),
          paint,
        );
      } else {
        canvas.drawRect(inner, paint);
      }
    }

    final cardDisplayWidth =
        geometry.displayRect(geometry.layout.cardRect).width;
    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) {
        // 图片元素预览暂不支持（与渲染器当前行为一致）
        continue;
      }
      _drawTextElement(canvas, element, cardDisplayWidth);
    }
  }

  void _drawTextElement(
    Canvas canvas,
    WatermarkElement element,
    double cardDisplayWidth,
  ) {
    final base = geometry.baseFor(element.space);

    // 字号夹取在显示像素上做，并回推等效基准宽度，使阴影 / 字距随之等比缩放，
    // 避免小缩略图中文字互相重叠、大元素溢出画框。
    const minFontSize = 5.0;
    final maxFontSize = math.max(minFontSize, cardDisplayWidth * 0.16);
    var baseWidth = base.width;
    if (element.fontSize > 0) {
      final displayFontSize = element.fontSize * base.width;
      final clamped =
          displayFontSize.clamp(minFontSize, maxFontSize).toDouble();
      if (clamped != displayFontSize) {
        baseWidth = clamped / element.fontSize;
      }
    }
    final metrics = WatermarkElementMetrics.of(element, baseWidth);

    final painter = TextPainter(
      text: TextSpan(
        text: element.type == WatermarkElementType.dateTime
            ? dateText
            : element.text,
        style: TextStyle(
          color: metrics.color,
          fontSize: metrics.fontSize,
          fontWeight: metrics.fontWeight,
          fontStyle: metrics.fontStyle,
          fontFamily: metrics.fontFamily,
          letterSpacing: metrics.letterSpacing,
          shadows: metrics.shadows,
        ),
      ),
      textAlign: element.textAlign,
      textDirection: TextDirection.ltr,
    )..layout();

    final placement = WatermarkTextPlacement.compute(
      element: element,
      base: base,
      textWidth: painter.width,
      textHeight: painter.height,
    );

    canvas.save();
    canvas.translate(placement.anchorX, placement.anchorY);
    if (element.rotation != 0.0) {
      canvas.rotate(element.rotation);
    }
    canvas.translate(placement.offsetX, placement.offsetY);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) {
    // 编辑页元素属性为可变对象就地修改，无法靠引用相等判断；
    // 始终重绘以保证滑块/文本变化即时反映（预览尺寸小，开销可忽略）。
    return true;
  }
}