import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';

/// 水印预览组件：在深色（仿照片）背景上以 [CustomPaint] + [TextPainter]
/// 渲染 [WatermarkTemplate] 的元素，供水印管理页与编辑页共用。
///
/// 绘制约定与 [WatermarkRenderer] 一致：
/// - 锚点 = `element.x * size.width`, `element.y * size.height`
/// - 绝对字号 = `element.fontSize * size.width`（fontSize 为相对值 0.0~1.0），
///   并施加最小字号 7px 的下限，保证小尺寸预览中文字仍可读
/// - letterSpacing 按 `size.width / 400` 缩放（参考宽度 400）
/// - textAlign 决定相对锚点的水平偏移（left=0 / right=-w / center=-w/2）
/// - 旋转 / 透明度 / bold / italic / shadow 均按元素属性应用
class WatermarkPreview extends StatelessWidget {
  const WatermarkPreview({
    super.key,
    required this.template,
    this.width = 100,
    this.height = 130,
    this.background,
    this.borderRadius = 8,
  });

  final WatermarkTemplate template;
  final double width;
  final double height;
  final Color? background;
  final double borderRadius;

  /// 深色仿照片背景：浅灰文字在深色背景上清晰可辨
  static const Color _defaultBackground = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ?? _defaultBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: CustomPaint(
        painter: _WatermarkPreviewPainter(template),
      ),
    );
  }
}

class _WatermarkPreviewPainter extends CustomPainter {
  _WatermarkPreviewPainter(this.template);

  static const double _referenceWidth = 400.0;

  final WatermarkTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _referenceWidth;

    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) {
        // 图片元素预览暂不支持（与渲染器当前行为一致）
        continue;
      }
      _drawTextElement(canvas, element, size, scale);
    }
  }

  void _drawTextElement(
    Canvas canvas,
    WatermarkElement element,
    Size size,
    double scale,
  ) {
    // 预览场景施加最小字号 7px，保证小尺寸预览（如 100x130）中文字仍可读；
    // 最大字号限制为预览宽度的 18%，防止过大元素溢出预览框
    final absoluteFontSize =
        (element.fontSize * size.width).clamp(7.0, size.width * 0.18);
    final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);

    final textStyle = TextStyle(
      color: _withOpacity(element.color, element.opacity),
      fontSize: absoluteFontSize,
      fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
      letterSpacing: element.letterSpacing * scale,
      shadows: [
        ui.Shadow(
          color: _withOpacity(element.shadowColor, element.opacity),
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

  /// 将 [color] 的 alpha 通道乘以 [opacity]（0.0~1.0），返回带透明度的颜色。
  ui.Color _withOpacity(ui.Color color, double opacity) {
    if (opacity >= 1.0) return color;
    final clamped = opacity.clamp(0.0, 1.0);
    final alpha = (color.alpha * clamped).round();
    return ui.Color.fromARGB(alpha, color.red, color.green, color.blue);
  }

  @override
  bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) {
    // 编辑页元素属性为可变对象就地修改，无法靠引用相等判断；
    // 始终重绘以保证滑块/文本变化即时反映（预览尺寸小，开销可忽略）。
    return true;
  }
}
