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

      // 3. 顶部照片区：铺满 1080x980，center-crop
      const photoTop = 110;
      const photoH = 980;
      final photoRect = ui.Rect.fromLTWH(
          0, photoTop.toDouble(), cardW.toDouble(), photoH.toDouble());

      // 计算 center-crop 源矩形（对齐目标比例后居中裁剪，横/竖图均不留两侧空白）
      final srcW = srcImage.width.toDouble();
      final srcH = srcImage.height.toDouble();
      const dstAspect = cardW / photoH; // 1080 / 980
      final srcAspect = srcW / srcH;
      final srcRect = srcAspect > dstAspect
          ? ui.Rect.fromLTWH(
              (srcW - srcH * dstAspect) / 2, 0,
              srcH * dstAspect, srcH)
          : ui.Rect.fromLTWH(
              0, (srcH - srcW / dstAspect) / 2,
              srcW, srcW / dstAspect);

      // 4. 绘制
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

      // 照片（center-crop 铺满）
      canvas.drawImageRect(
        srcImage,
        srcRect,
        photoRect,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      srcImage.dispose();

      // 5. 参数区：两列网格（label 上 / value 下，紧凑排布）
      const labelStyle = TextStyle(
        color: ui.Color(0xFFC9A96E),
        fontSize: 20,
        fontWeight: ui.FontWeight.w600,
      );
      const valueStyle = TextStyle(
        color: ui.Color(0xFFE5E0D8),
        fontSize: 22,
      );

      // Dart 2.19 不支持 records，用 MapEntry 承载 label/value
      final items = <MapEntry<String, String>>[
        MapEntry('相机', exif.cameraModel ?? ''),
        MapEntry('焦距', exif.focalLength ?? ''),
        MapEntry('光圈', exif.fNumber ?? ''),
        MapEntry('ISO', exif.iso ?? ''),
        MapEntry('快门', exif.shutterSpeed ?? ''),
        MapEntry('时间', exif.timestamp ?? ''),
        MapEntry('场景', exif.sceneName ?? ''),
        MapEntry('模板', exif.template ?? ''),
      ].where((it) => it.value.isNotEmpty).toList();

      const gap = 32;
      final colW = (cardW - padding * 2 - gap) / 2;
      const rowH = 70;
      final gridTop = photoTop + photoH + 48;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final col = i % 2;
        final row = i ~/ 2;
        final x = padding + col * (colW + gap);
        final y = (gridTop + row * rowH).toDouble();

        final labelTp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(text: item.key, style: labelStyle);
        labelTp.layout(maxWidth: colW);
        labelTp.paint(canvas, ui.Offset(x, y));

        final valueTp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(text: item.value, style: valueStyle);
        valueTp.layout(maxWidth: colW);
        valueTp.paint(canvas, ui.Offset(x, y + 30));
      }

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

      // 编码 PNG 并保存（try/finally 确保 resultImage 释放，避免 toByteData 失败时泄漏）
      try {
        final pngBytes =
            await resultImage.toByteData(format: ui.ImageByteFormat.png);
        if (pngBytes == null) {
          throw StateError('toByteData(png) 返回 null');
        }
        await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());
      } finally {
        resultImage.dispose();
      }

      debugPrint('[exif-card] 生成: ${sw.elapsedMilliseconds}ms');
      return outputPath;
    } catch (e, st) {
      debugPrint('[exif-card] 失败: $e\n$st');
      rethrow;
    }
  }
}
