import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show FontStyle, FontWeight, TextAlign;

import '../models/watermark_template.dart';

/// 水印渲染器：将 [WatermarkElement] 列表绘制到源图像上，返回 RGBA 原始字节。
///
/// 渲染流程：
/// 1. 以 [ui.PictureRecorder] + [ui.Canvas] 录制绘制指令
/// 2. 先绘制源图像作为底图
/// 3. 对每个文本元素，使用 [ui.ParagraphBuilder] 构建段落
/// 4. 字号按 `imageSize.width / 400` 缩放（参考分辨率 400px 设计）
/// 5. 通过 `canvas.save/translate/rotate/restore` 应用旋转
/// 6. 通过 [ui.Picture.toImage] 转换为 [ui.Image]
/// 7. 通过 [ui.Image.toByteData] 取 rawRgba 字节返回
class WatermarkRenderer {
  /// 参考设计宽度（元素 fontSize 为相对值，按此宽度换算绝对像素）。
  static const double _referenceWidth = 400.0;

  /// 将水印元素绘制到 [sourceImage] 上，返回合成后的 RGBA 字节。
  Future<Uint8List> render({
    required ui.Image sourceImage,
    required List<WatermarkElement> elements,
  }) async {
    final imageWidth = sourceImage.width;
    final imageHeight = sourceImage.height;
    final scale = imageWidth / _referenceWidth;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 1. 绘制源图像作为底图
    canvas.drawImage(sourceImage, ui.Offset.zero, ui.Paint());

    // 2. 依次绘制每个文本元素
    for (final element in elements) {
      if (element.type == WatermarkElementType.image) {
        // 图片元素渲染待后续任务实现（当前仅支持文本/日期时间）
        continue;
      }
      _drawTextElement(
        canvas,
        element,
        imageWidth.toDouble(),
        imageHeight.toDouble(),
        scale,
      );
    }

    // 3. 录制为 Picture 并转为 Image
    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(imageWidth, imageHeight);

    // 4. 取 RGBA 字节
    final byteData = await outputImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw StateError('WatermarkRenderer: failed to encode output image');
    }
    return byteData.buffer.asUint8List();
  }

  void _drawTextElement(
    ui.Canvas canvas,
    WatermarkElement element,
    double imageWidth,
    double imageHeight,
    double scale,
  ) {
    final absoluteFontSize = element.fontSize * imageWidth;
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

    // 约束宽度使用图像宽度（避免换行，使 maxIntrinsicWidth 反映真实文本宽度）
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: imageWidth));

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    // 计算锚点像素坐标（元素相对坐标 × 图像尺寸）
    final anchorX = element.x * imageWidth;
    final anchorY = element.y * imageHeight;

    // 根据对齐方式计算文本左上角坐标（相对锚点的偏移）
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
    // y 锚点视为文本基线顶部偏上一点，使视觉位置更贴合
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
}
