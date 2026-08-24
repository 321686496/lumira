import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// EXIF 信息（用于 EXIF 卡片显示）
class ExifInfo {
  final String? cameraModel;
  final String? make;
  final String? focalLength;
  final String? fNumber;
  final String? iso;
  final String? shutterSpeed;
  final String? exposureCompensation;
  final String? whiteBalance;
  final String? resolution;
  final String? fileSize;
  final String? location;
  final String? timestamp;
  final String? sceneName;
  final String? template;

  const ExifInfo({
    this.cameraModel,
    this.make,
    this.focalLength,
    this.fNumber,
    this.iso,
    this.shutterSpeed,
    this.exposureCompensation,
    this.whiteBalance,
    this.resolution,
    this.fileSize,
    this.location,
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
      const padding = 52;

      // 3. 顶部照片区：铺满 1080x820，center-crop（比例约 4:3，横/竖图均合适）
      const photoTop = 112;
      const photoH = 820;
      final photoRect = ui.Rect.fromLTWH(
          0, photoTop.toDouble(), cardW.toDouble(), photoH.toDouble());

      // 计算 center-crop 源矩形（对齐目标比例后居中裁剪，横/竖图均不留两侧空白）
      final srcW = srcImage.width.toDouble();
      final srcH = srcImage.height.toDouble();
      const dstAspect = cardW / photoH; // 1080 / 820
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
          letterSpacing: 2,
        ),
      );
      titlePainter.layout();
      titlePainter.paint(canvas, ui.Offset(padding.toDouble(), 30));

      // 照片（center-crop 铺满）
      canvas.drawImageRect(
        srcImage,
        srcRect,
        photoRect,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      srcImage.dispose();

      // 5. 信息区：分组渲染（拍摄参数 / 创作信息），提升字号与对比、对齐整齐
      const labelStyle = TextStyle(
        color: ui.Color(0xFFC9A96E),
        fontSize: 21,
        fontWeight: ui.FontWeight.w600,
      );
      const valueStyle = TextStyle(
        color: ui.Color(0xFFF0ECE4),
        fontSize: 24,
      );
      const sectionStyle = TextStyle(
        color: ui.Color(0xFF8A8378),
        fontSize: 24,
        fontWeight: ui.FontWeight.w700,
        letterSpacing: 3,
      );

      // 拍摄参数（EXIF 物理/相机参数）
      final shootParams = <MapEntry<String, String>>[
        MapEntry('相机', exif.cameraModel ?? ''),
        MapEntry('分辨率', exif.resolution ?? ''),
        MapEntry('文件大小', exif.fileSize ?? ''),
        MapEntry('焦距', exif.focalLength ?? ''),
        MapEntry('光圈', exif.fNumber ?? ''),
        MapEntry('ISO', exif.iso ?? ''),
        MapEntry('快门', exif.shutterSpeed ?? ''),
        MapEntry('曝光补偿', exif.exposureCompensation ?? ''),
        MapEntry('白平衡', exif.whiteBalance ?? ''),
        MapEntry('位置', exif.location ?? ''),
      ].where((it) => it.value.isNotEmpty).toList();

      // 创作信息（场景/模板/时间）
      final creativeParams = <MapEntry<String, String>>[
        MapEntry('场景', exif.sceneName ?? ''),
        MapEntry('模板', exif.template ?? ''),
        MapEntry('时间', exif.timestamp ?? ''),
      ].where((it) => it.value.isNotEmpty).toList();

      const gapX = 40;
      const colW = (cardW - padding * 2 - gapX) / 2;
      const rowH = 66;
      const sectionGap = 26;
      var cursorY = (photoTop + photoH + 52).toDouble();

      double renderSection(String title, List<MapEntry<String, String>> items) {
        final titleTp = TextPainter(textDirection: ui.TextDirection.ltr)
          ..text = TextSpan(text: title, style: sectionStyle);
        titleTp.layout();
        titleTp.paint(canvas, ui.Offset(padding.toDouble(), cursorY));
        cursorY += 46; // 组标题留白

        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          final col = i % 2;
          final row = i ~/ 2;
          final x = padding + col * (colW + gapX);
          final y = cursorY + row * rowH;

          final labelTp = TextPainter(textDirection: ui.TextDirection.ltr)
            ..text = TextSpan(text: item.key, style: labelStyle);
          labelTp.layout(maxWidth: colW);
          labelTp.paint(canvas, ui.Offset(x, y.toDouble()));

          final valueTp = TextPainter(textDirection: ui.TextDirection.ltr)
            ..text = TextSpan(text: item.value, style: valueStyle);
          valueTp.layout(maxWidth: colW);
          valueTp.paint(canvas, ui.Offset(x, y.toDouble() + 28));
        }
        cursorY += (items.length / 2).ceil() * rowH;
        return cursorY;
      }

      renderSection('拍摄参数', shootParams);
      cursorY += sectionGap;
      if (creativeParams.isNotEmpty) {
        renderSection('创作信息', creativeParams);
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
