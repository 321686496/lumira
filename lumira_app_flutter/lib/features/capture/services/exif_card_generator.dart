import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// EXIF 信息（用于 EXIF 卡片显示）
class ExifInfo {
  final String? cameraModel;
  final String? focalLength;
  final String? fNumber;
  final String? iso;
  final String? shutterSpeed;
  final String? timestamp;
  final String? sceneName;
  final String? template;

  const ExifInfo({
    this.cameraModel,
    this.focalLength,
    this.fNumber,
    this.iso,
    this.shutterSpeed,
    this.timestamp,
    this.sceneName,
    this.template,
  });
}

/// 生成 EXIF 卡片 PNG（缩略图 + 相机参数 + 场景/模板信息）
class ExifCardGenerator {
  ExifCardGenerator._();

  static Future<String> generate({
    required String photoPath,
    required String outputPath,
    required ExifInfo exif,
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 解码原图
      final bytes = await File(photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();

      // 2. 卡片尺寸：竖版 1080x1620（3:4.5），适合分享
      const cardW = 1080;
      const cardH = 1620;
      const padding = 48;
      const thumbH = 600;
      final thumbW = (srcImage.width * thumbH / srcImage.height).round();

      // 3. 绘制
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // 背景
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, cardW.toDouble(), cardH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF1C1A17),
      );

      // 顶部标题
      final titlePainter = TextPainter(textDirection: ui.TextDirection.ltr);
      titlePainter.text = const TextSpan(
        text: 'EXIF',
        style: TextStyle(
          color: ui.Color(0xFFC9A96E),
          fontSize: 36,
          fontWeight: ui.FontWeight.w700,
        ),
      );
      titlePainter.layout();
      titlePainter.paint(canvas, ui.Offset(padding.toDouble(), 32));

      // 缩略图（居中）
      final thumbX = (cardW - thumbW) / 2;
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(0, 0, srcImage.width.toDouble(),
            srcImage.height.toDouble()),
        ui.Rect.fromLTWH(thumbX, 110, thumbW.toDouble(), thumbH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      srcImage.dispose();

      // 信息行
      double y = 110 + thumbH + 40;
      const labelStyle = TextStyle(
        color: ui.Color(0xFFC9A96E),
        fontSize: 22,
        fontWeight: ui.FontWeight.w600,
      );
      const valueStyle = TextStyle(
        color: ui.Color(0xFFE5E0D8),
        fontSize: 22,
      );

      void drawRow(String label, String? value) {
        if (value == null || value.isEmpty) return;
        final tp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(
            text: '$label    ',
            style: labelStyle,
            children: [TextSpan(text: value, style: valueStyle)],
          );
        tp.layout(maxWidth: (cardW - padding * 2).toDouble());
        tp.paint(canvas, ui.Offset(padding.toDouble(), y));
        y += 40;
      }

      drawRow('相机', exif.cameraModel);
      drawRow('焦距', exif.focalLength);
      drawRow('光圈', exif.fNumber);
      drawRow('ISO', exif.iso);
      drawRow('快门', exif.shutterSpeed);
      drawRow('时间', exif.timestamp);
      drawRow('场景', exif.sceneName);
      drawRow('模板', exif.template);

      // 底部水印
      final watermark = TextPainter(textDirection: ui.TextDirection.ltr)
        ..text = const TextSpan(
          text: 'Lumira · 摄影学院',
          style: TextStyle(
            color: ui.Color(0xFFC9A96E),
            fontSize: 18,
            fontStyle: ui.FontStyle.italic,
          ),
        );
      watermark.layout();
      watermark.paint(canvas,
          ui.Offset((cardW - watermark.width) / 2, cardH - 50));

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(cardW, cardH);
      picture.dispose();

      final pngBytes =
          await resultImage.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes == null) {
        throw StateError('toByteData(png) 返回 null');
      }
      await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      resultImage.dispose();

      debugPrint('[exif-card] 生成: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[exif-card] 失败: $e\n$st');
      rethrow;
    }
  }
}
