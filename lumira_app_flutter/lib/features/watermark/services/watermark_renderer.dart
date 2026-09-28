import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/watermark_template.dart';
import 'watermark_layout.dart';

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
/// 1. 由 [WatermarkLayout] 计算输出画布尺寸、照片区域与白板基准矩形
/// 2. 以 [ui.PictureRecorder] + [ui.Canvas] 录制绘制指令
/// 3. 绘制白卡（拍立得）/ 照片 / 内描边
/// 4. 每个元素按其 [WatermarkElement.space]（photo/frame）选择坐标基准矩形，
///    字号 / 阴影由 [WatermarkElementMetrics] 换算，位置由
///    [WatermarkTextPlacement] 换算
/// 5. 通过 [ui.Picture.toImage] 转为 [ui.Image] 并取 rawRgba 字节
///
/// 本类不读文件、不依赖 context：日期由调用方通过 [captureDate] 注入。
class WatermarkRenderer {
  /// 将 [template] 渲染到 [sourceImage] 上，返回合成结果（RGBA 字节 + 尺寸）。
  ///
  /// [captureDate]：照片真实拍摄时间；`dateTime` 类型元素用它格式化，
  /// 为空时回退当天（[DateTime.now]）。其余元素类型忽略该参数。
  Future<WatermarkRenderResult> render({
    required ui.Image sourceImage,
    required WatermarkTemplate template,
    DateTime? captureDate,
  }) async {
    final frame = template.frame;
    final type = frame.type;
    final layout = WatermarkLayout.compute(
      photoW: sourceImage.width.toDouble(),
      photoH: sourceImage.height.toDouble(),
      frame: frame,
    );
    final cardRect = layout.cardRect;
    final photoRect = layout.photoRect;
    final photoOrigin = photoRect.topLeft;
    // 注：不把投影烘焙进输出图像。投影仅用于屏幕展示（如编辑页预览），
    // 若写入成片会在白边下方留下一条灰/黑线，因此这里直接以卡片边界作为画布。
    final outputW = layout.outputWidth;
    final outputH = layout.outputHeight;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // 画布底色：以卡片颜色（强制不透明）铺满整个输出，避免任何未绘制区域
    // （透明像素）被 JPEG 编码成黑色。
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, outputW.toDouble(), outputH.toDouble()),
      ui.Paint()..color = frame.color.withAlpha(0xFF),
    );

    if (type == WatermarkFrameType.polaroid) {
      final paint = ui.Paint();
      if (frame.borderFill == WatermarkBorderFill.gradient) {
        paint.shader = watermarkFrameGradientShader(frame, cardRect);
      } else {
        paint.color = frame.color;
      }
      if (frame.borderRadius > 0) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              cardRect, ui.Radius.circular(frame.borderRadius * sourceImage.width)),
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
      final stroke = frame.borderRatio * sourceImage.width;
      final paint = ui.Paint()
        ..color = frame.color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke;
      final inner = photoRect.deflate(stroke / 2);
      if (frame.borderRadius > 0) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              inner, ui.Radius.circular(frame.borderRadius * sourceImage.width)),
          paint,
        );
      } else {
        canvas.drawRect(inner, paint);
      }
    }

    // 元素
    for (final element in template.elements) {
      if (element.type == WatermarkElementType.image) continue;
      _drawTextElement(
        canvas,
        element,
        layout.baseFor(element.space),
        _textFor(element, captureDate),
      );
    }

    // 画布圆角裁剪（拍立得/内描边且 borderRadius>0）
    if (type != WatermarkFrameType.none && frame.borderRadius > 0) {
      final clipRect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, outputW.toDouble(), outputH.toDouble()),
        ui.Radius.circular(frame.borderRadius * sourceImage.width),
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

  /// 元素实际绘制的文本：`dateTime` 忽略 [WatermarkElement.text]，按真实拍摄日期格式化。
  String _textFor(WatermarkElement element, DateTime? captureDate) {
    if (element.type == WatermarkElementType.dateTime) {
      return formatWatermarkDate(captureDate ?? DateTime.now());
    }
    return element.text;
  }

  void _drawTextElement(
    ui.Canvas canvas,
    WatermarkElement element,
    ui.Rect base, // 坐标空间基准矩形
    String text,
  ) {
    final metrics = WatermarkElementMetrics.of(element, base.width);

    // 构建段落
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: element.textAlign,
      fontSize: metrics.fontSize,
      fontWeight: metrics.fontWeight,
      fontStyle: metrics.fontStyle,
      fontFamily: metrics.fontFamily,
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(
        ui.TextStyle(
          color: metrics.color,
          fontSize: metrics.fontSize,
          fontWeight: metrics.fontWeight,
          fontStyle: metrics.fontStyle,
          fontFamily: metrics.fontFamily,
          letterSpacing: metrics.letterSpacing,
          shadows: metrics.shadows,
        ),
      )
      ..addText(text);

    // 约束宽度使用基准矩形宽度
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: base.width));

    final placement = WatermarkTextPlacement.compute(
      element: element,
      base: base,
      textWidth: paragraph.maxIntrinsicWidth,
      textHeight: paragraph.height,
    );

    canvas.save();
    canvas.translate(placement.anchorX, placement.anchorY);
    if (element.rotation != 0.0) {
      canvas.rotate(element.rotation);
    }
    canvas.translate(placement.offsetX, placement.offsetY);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    canvas.restore();
  }
}