import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show FontStyle, FontWeight, TextAlign;

import '../models/watermark_template.dart';

/// 水印渲染结果：合成后的 RGBA 原始字节 + 输出画布尺寸。
///
/// 画框（拍立得）会使输出画布向外扩展，超出原图尺寸，因此必须显式返回
/// [width]/[height] 供调用方构造编码图像。
class WatermarkRenderResult {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  const WatermarkRenderResult({
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });
}

/// 水印渲染器：将 [WatermarkTemplate]（含画框 + 元素）绘制到源图像上，
/// 返回 [WatermarkRenderResult]。
///
/// 渲染流程：
/// 1. 依据模板画框（[WatermarkFrame]）计算输出画布尺寸与照片在画布上的位置
/// 2. 以 [ui.PictureRecorder] + [ui.Canvas] 录制绘制指令
/// 3. 绘制投影 / 白卡（拍立得）/ 照片 / 内描边
/// 4. 每个元素按其 [WatermarkElement.space]（photo/frame）选择坐标基准矩形
/// 5. 通过 [ui.Picture.toImage] 转为 [ui.Image] 并取 rawRgba 字节
class WatermarkRenderer {
  /// 参考设计宽度（元素 fontSize 为相对值，按此宽度换算绝对像素）。
  static const double _referenceWidth = 400.0;

  /// 将 [template] 渲染到 [sourceImage] 上，返回合成结果（RGBA 字节 + 尺寸）。
  Future<WatermarkRenderResult> render({
    required ui.Image sourceImage,
    required WatermarkTemplate template,
  }) async {
    final photoW = sourceImage.width.toDouble();
    final photoH = sourceImage.height.toDouble();
    final frame = template.frame;
    final type = frame.type;
    final scale = photoW / _referenceWidth;

    // —— 画布尺寸 ——
    // 拍立得：四边白边独立向外扩展（照片区域保持不变，四周补白），
    // 底部可再叠加白板；其余类型画布与照片同尺寸。
    double padLeft = 0, padRight = 0, padTop = 0, padBottom = 0;
    if (type == WatermarkFrameType.polaroid) {
      padLeft = frame.borderLeft * photoW;
      padRight = frame.borderRight * photoW;
      padTop = frame.borderTop * photoW;
      padBottom = frame.borderBottom * photoW +
          (frame.bottomPlate ? frame.bottomRatio * photoH : 0);
    }
    final shadow = (type == WatermarkFrameType.polaroid && frame.shadowOpacity > 0)
        ? (frame.shadowBlur * photoW).clamp(2.0, 60.0)
        : 0.0;
    final outputW = (photoW + padLeft + padRight).round();
    final outputH = (photoH + padTop + padBottom + shadow).round();

    final cardRect = ui.Rect.fromLTWH(
        0, 0, photoW + padLeft + padRight, photoH + padTop + padBottom);
    final photoOrigin = ui.Offset(padLeft, padTop);
    final photoRect = ui.Rect.fromLTWH(padLeft, padTop, photoW, photoH);
    final plateRect = (type == WatermarkFrameType.polaroid && frame.bottomPlate)
        ? ui.Rect.fromLTWH(
            padLeft, photoRect.bottom, photoW + padLeft + padRight, padBottom)
        : photoRect;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 投影（拍立得，仅底部）
    if (shadow > 0) {
      final paint = ui.Paint()
        ..color = _withOpacity(frame.shadowColor, frame.shadowOpacity)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, cardRect.bottom, outputW.toDouble(), shadow * 1.4),
        paint,
      );
    }

    if (type == WatermarkFrameType.polaroid) {
      final paint = ui.Paint();
      if (frame.borderFill == WatermarkBorderFill.gradient) {
        paint.shader = _frameGradientShader(frame, cardRect);
      } else {
        paint.color = frame.color;
      }
      if (frame.borderRadius > 0) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(cardRect, ui.Radius.circular(frame.borderRadius * photoW)),
          paint,
        );
      } else {
        canvas.drawRect(cardRect, paint);
      }
    }

    // 照片
    canvas.drawImage(sourceImage, photoOrigin, ui.Paint());

    // 内描边
    if (type == WatermarkFrameType.innerBorder) {
      final stroke = frame.borderRatio * photoW;
      final paint = ui.Paint()
        ..color = frame.color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke;
      final inner = photoRect.deflate(stroke / 2);
      if (frame.borderRadius > 0) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(inner, ui.Radius.circular(frame.borderRadius * photoW)),
          paint,
        );
      } else {
        canvas.drawRect(inner, paint);
      }
    }

    // 元素
    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) continue;
      final base = element.space == WatermarkElementSpace.frame ? plateRect : photoRect;
      _drawTextElement(canvas, element, base, scale);
    }

    // 画布圆角裁剪（拍立得/内描边且 borderRadius>0）
    if (type != WatermarkFrameType.none && frame.borderRadius > 0) {
      final clipRect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, outputW.toDouble(), outputH.toDouble()),
        ui.Radius.circular(frame.borderRadius * photoW),
      );
      canvas.clipRRect(clipRect);
    }

    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(outputW, outputH);
    final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    outputImage.dispose();
    if (byteData == null) throw StateError('WatermarkRenderer: failed to encode output image');
    return WatermarkRenderResult(
      rgbaBytes: byteData.buffer.asUint8List(),
      width: outputW,
      height: outputH,
    );
  }

  void _drawTextElement(
    ui.Canvas canvas,
    WatermarkElement element,
    ui.Rect base, // 坐标空间基准矩形
    double scale,
  ) {
    final absoluteFontSize = element.fontSize * base.width;
    final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);

    // 构建段落
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: element.textAlign,
      fontSize: absoluteFontSize,
      fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
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
        ),
      )
      ..addText(element.text);

    // 约束宽度使用基准矩形宽度
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: base.width));

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    // 锚点：相对基准矩形换算绝对像素
    final anchorX = element.x * base.width + base.left;
    final anchorY = element.y * base.height + base.top;

    double offsetX;
    switch (element.textAlign) {
      case TextAlign.right:
        offsetX = -textWidth;
        break;
      case TextAlign.center:
        offsetX = -textWidth / 2;
        break;
      case TextAlign.left:
      case TextAlign.justify:
      default:
        offsetX = 0.0;
    }
    final offsetY = -textHeight * 0.85;

    canvas.save();
    canvas.translate(anchorX, anchorY);
    if (element.rotation != 0.0) {
      canvas.rotate(element.rotation);
    }
    canvas.translate(offsetX, offsetY);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    canvas.restore();
  }

  /// 将 [color] 的 alpha 通道乘以 [opacity]（0.0~1.0），返回带透明度的颜色。
  ui.Color _withOpacity(ui.Color color, double opacity) {
    if (opacity >= 1.0) return color;
    final clamped = opacity.clamp(0.0, 1.0);
    final alpha = (color.alpha * clamped).round();
    return ui.Color.fromARGB(
      alpha,
      color.red,
      color.green,
      color.blue,
    );
  }

  /// 拍立得卡片底渐变 shader：基于 [WatermarkFrame.color] →
  /// [WatermarkFrame.gradientEndColor] 与 [WatermarkFrame.gradientDirection]。
  ui.Shader? _frameGradientShader(WatermarkFrame frame, ui.Rect rect) {
    return ui.Gradient.linear(
      _gradientFrom(frame.gradientDirection, rect),
      _gradientTo(frame.gradientDirection, rect),
      [frame.color, frame.gradientEndColor],
    );
  }

  /// 渐变起点。
  ui.Offset _gradientFrom(WatermarkGradientDirection dir, ui.Rect rect) {
    final c = rect.center;
    switch (dir) {
      case WatermarkGradientDirection.bottomToTop:
        return ui.Offset(c.dx, rect.bottom);
      case WatermarkGradientDirection.leftToRight:
        return ui.Offset(rect.left, c.dy);
      case WatermarkGradientDirection.rightToLeft:
        return ui.Offset(rect.right, c.dy);
      case WatermarkGradientDirection.topLeftToBottomRight:
        return rect.topLeft;
      case WatermarkGradientDirection.bottomLeftToTopRight:
        return rect.bottomLeft;
      case WatermarkGradientDirection.topToBottom:
      default:
        return ui.Offset(c.dx, rect.top);
    }
  }

  /// 渐变终点。
  ui.Offset _gradientTo(WatermarkGradientDirection dir, ui.Rect rect) {
    final c = rect.center;
    switch (dir) {
      case WatermarkGradientDirection.bottomToTop:
        return ui.Offset(c.dx, rect.top);
      case WatermarkGradientDirection.leftToRight:
        return ui.Offset(rect.right, c.dy);
      case WatermarkGradientDirection.rightToLeft:
        return ui.Offset(rect.left, c.dy);
      case WatermarkGradientDirection.topLeftToBottomRight:
        return rect.bottomRight;
      case WatermarkGradientDirection.bottomLeftToTopRight:
        return rect.topRight;
      case WatermarkGradientDirection.topToBottom:
      default:
        return ui.Offset(c.dx, rect.bottom);
    }
  }
}